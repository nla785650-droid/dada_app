-- ============================================================
-- 搭哒 · 埋点 & 动态定价 SQL
-- Analytics, A/B Experiments, Pricing Intelligence
-- ============================================================

-- ── 1. user_behaviors：用户行为埋点表 ──
-- 记录粒度到每次卡片交互事件，用于漏斗分析和推荐优化
CREATE TABLE IF NOT EXISTS public.user_behaviors (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  session_id      TEXT,                        -- 前端生成的会话 ID（UUID）
  event_type      TEXT        NOT NULL
    CHECK (event_type IN (
      'card_viewed',       -- 卡片曝光（进入视口）
      'card_swiped_left',  -- 左滑不喜欢
      'card_swiped_right', -- 右滑喜欢
      'card_tapped',       -- 点击进入详情
      'card_rated',        -- 打分
      'post_viewed',       -- 帖子曝光
      'post_liked',        -- 帖子点赞
      'post_shared',       -- 帖子分享
      'booking_started',   -- 开始预约流程
      'booking_paid',      -- 支付成功
      'search_performed',  -- 搜索行为
      'profile_viewed'     -- 达人主页曝光
    )),
  target_id       TEXT,                        -- 被交互对象的 ID（card id/post id/provider id）
  target_type     TEXT,                        -- 'provider' | 'post' | 'booking'
  view_duration   INTEGER,                     -- 停留时长（毫秒），仅 viewed 事件有效
  click_type      TEXT,                        -- 点击类型：'single' | 'double' | 'long_press'
  swipe_velocity  REAL,                        -- 划卡速度（px/ms），越快说明越果断
  ab_group        TEXT,                        -- A/B 实验分组：'control' | 'treatment'
  screen_context  TEXT,                        -- 所在页面：'discover' | 'home' | 'profile'
  extra           JSONB,                       -- 其他自定义字段
  platform        TEXT DEFAULT 'flutter_web',
  app_version     TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 分区索引优化查询性能
CREATE INDEX IF NOT EXISTS idx_behaviors_user_created
  ON public.user_behaviors (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_behaviors_event_type
  ON public.user_behaviors (event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_behaviors_target
  ON public.user_behaviors (target_id, event_type);

CREATE INDEX IF NOT EXISTS idx_behaviors_ab_group
  ON public.user_behaviors (ab_group, event_type);

-- RLS：用户只能写入自己的行为，管理员可读全部
ALTER TABLE public.user_behaviors ENABLE ROW LEVEL SECURITY;

CREATE POLICY "behaviors_user_insert"
  ON public.user_behaviors FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

-- 分析团队使用 Service Role 读取，用户不可自读（防止操纵）
-- 注意：生产环境通过 Supabase Dashboard 或 API 密钥访问分析数据

-- ── 2. ab_experiments：实验配置表 ──
CREATE TABLE IF NOT EXISTS public.ab_experiments (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_key  TEXT        NOT NULL UNIQUE,  -- 如 'discover_card_layout_v2'
  description     TEXT,
  variants        JSONB       NOT NULL,          -- [{"id":"control","weight":50},{"id":"treatment","weight":50}]
  is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
  start_at        TIMESTAMPTZ DEFAULT NOW(),
  end_at          TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.ab_experiments (experiment_key, description, variants)
VALUES (
  'discover_card_layout_v2',
  '划一划卡片布局测试：控制组=原始大图，实验组=紧凑信息卡',
  '[
    {"id": "control",   "weight": 50, "label": "大图沉浸模式"},
    {"id": "treatment", "weight": 50, "label": "紧凑信息模式"}
  ]'::jsonb
) ON CONFLICT (experiment_key) DO NOTHING;

-- ── 3. ai_proof_records：AI 核验履约记录 ──
CREATE TABLE IF NOT EXISTS public.ai_proof_records (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id      UUID        NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  uploader_id     UUID        NOT NULL REFERENCES public.profiles(id),
  photo_url       TEXT        NOT NULL,
  gemini_response JSONB,                        -- 完整的 Gemini API 响应
  is_verified     BOOLEAN     NOT NULL DEFAULT FALSE,
  confidence      REAL,                         -- 置信度 0.0~1.0
  highlights      TEXT[],                       -- AI 生成的高亮时刻文字列表
  generated_review TEXT,                        -- AI 自动生成的评价文本
  verified_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT one_proof_per_booking UNIQUE (booking_id)
);

ALTER TABLE public.ai_proof_records ENABLE ROW LEVEL SECURITY;

-- 订单双方可读 AI 核验结果
CREATE POLICY "ai_proof_booking_parties_read"
  ON public.ai_proof_records FOR SELECT
  USING (
    uploader_id = auth.uid()
    OR booking_id IN (
      SELECT id FROM public.bookings
      WHERE customer_id = auth.uid() OR provider_id = auth.uid()
    )
  );

CREATE POLICY "ai_proof_uploader_insert"
  ON public.ai_proof_records FOR INSERT
  WITH CHECK (uploader_id = auth.uid());

CREATE POLICY "ai_proof_uploader_update"
  ON public.ai_proof_records FOR UPDATE
  USING (uploader_id = auth.uid());

-- ── 4. pricing_signals：定价参考信号表 ──
-- 每次成交后记录，用于训练动态定价模型
CREATE TABLE IF NOT EXISTS public.pricing_signals (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id        UUID        REFERENCES public.bookings(id),
  provider_id       UUID        NOT NULL REFERENCES public.profiles(id),
  style_tags        TEXT[],                     -- 达人风格标签
  location_city     TEXT,                       -- 城市
  ai_aesthetic_score REAL,                     -- AI 审美评分 0~5
  provider_rating   REAL,                       -- 达人综合评分
  transaction_price NUMERIC     NOT NULL,       -- 实际成交金额
  listed_price      NUMERIC,                   -- 标价
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pricing_signals_tags
  ON public.pricing_signals USING GIN (style_tags);

CREATE INDEX IF NOT EXISTS idx_pricing_signals_location
  ON public.pricing_signals (location_city, ai_aesthetic_score);

-- ── 5. RPC：get_price_recommendation（动态定价建议）──
CREATE OR REPLACE FUNCTION public.get_price_recommendation(
  p_style_tags         TEXT[],
  p_location_city      TEXT,
  p_ai_aesthetic_score REAL DEFAULT 3.0,
  p_provider_rating    REAL DEFAULT 4.0
)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  v_avg_price       NUMERIC;
  v_sample_count    INTEGER;
  v_rating_factor   NUMERIC;
  v_aesthetic_factor NUMERIC;
  v_base_price      NUMERIC;
  v_price_low       NUMERIC;
  v_price_high      NUMERIC;
  v_market_percentile INTEGER;
BEGIN
  -- ── Step 1：查找同标签 + 同城市 + 近 90 天成交的平均价 ──
  SELECT
    AVG(transaction_price),
    COUNT(*)
  INTO v_avg_price, v_sample_count
  FROM public.pricing_signals
  WHERE
    -- 标签重叠：至少有 1 个相同的标签
    style_tags && p_style_tags
    AND (location_city = p_location_city OR p_location_city IS NULL)
    AND created_at > NOW() - INTERVAL '90 days';

  -- ── Step 2：若样本不足，扩大到全城市 ──
  IF v_sample_count < 5 THEN
    SELECT
      AVG(transaction_price),
      COUNT(*)
    INTO v_avg_price, v_sample_count
    FROM public.pricing_signals
    WHERE
      style_tags && p_style_tags
      AND created_at > NOW() - INTERVAL '180 days';
  END IF;

  -- ── Step 3：若仍无数据，使用全局兜底均价 ──
  IF v_sample_count = 0 OR v_avg_price IS NULL THEN
    v_avg_price := 200;  -- 全局兜底基准价（元/次）
    v_sample_count := 0;
  END IF;

  v_base_price := v_avg_price;

  -- ── Step 4：评分系数（评分越高，建议价格越高）──
  -- 评分 3.0 → 系数 0.90，评分 4.5 → 系数 1.05，评分 5.0 → 系数 1.15
  v_rating_factor := 0.75 + (p_provider_rating / 5.0) * 0.40;

  -- ── Step 5：AI 审美分系数 ──
  -- 审美分 1 → 系数 0.90，审美分 5 → 系数 1.10
  v_aesthetic_factor := 0.90 + (p_ai_aesthetic_score / 5.0) * 0.20;

  -- ── Step 6：综合调整后的建议中值 ──
  v_base_price := ROUND(v_avg_price * v_rating_factor * v_aesthetic_factor, -1);

  -- ── Step 7：±15% 区间 ──
  v_price_low  := ROUND(v_base_price * 0.85, -1);
  v_price_high := ROUND(v_base_price * 1.15, -1);

  -- ── Step 8：计算该价格在市场中的百分位（分位数估算）──
  SELECT COALESCE(
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE transaction_price <= v_base_price) / NULLIF(COUNT(*), 0)
    )::INTEGER,
    50
  )
  INTO v_market_percentile
  FROM public.pricing_signals
  WHERE style_tags && p_style_tags;

  -- ── 返回建议结果 ──
  RETURN jsonb_build_object(
    'suggested_price',       v_base_price,
    'price_range_low',       v_price_low,
    'price_range_high',      v_price_high,
    'market_avg',            ROUND(v_avg_price, 0),
    'sample_count',          v_sample_count,
    'market_percentile',     v_market_percentile,
    'rating_factor',         ROUND(v_rating_factor, 3),
    'aesthetic_factor',      ROUND(v_aesthetic_factor, 3),
    'confidence',            CASE
                               WHEN v_sample_count >= 20 THEN 'high'
                               WHEN v_sample_count >= 5  THEN 'medium'
                               ELSE 'low'
                             END,
    'advice',                CASE
                               WHEN v_market_percentile >= 80
                                 THEN '你的建议价处于市场高端，适合高品质精准用户'
                               WHEN v_market_percentile >= 50
                                 THEN '价格定位中上，竞争力良好'
                               ELSE
                                 '价格偏低，可适当提升以匹配你的评分'
                             END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_price_recommendation(TEXT[], TEXT, REAL, REAL)
  TO authenticated, anon;

-- ── 6. 行为漏斗分析视图（用于 Dashboard）──
CREATE OR REPLACE VIEW public.funnel_analysis AS
SELECT
  DATE_TRUNC('day', created_at) AS day,
  ab_group,
  COUNT(*) FILTER (WHERE event_type = 'card_viewed')        AS impressions,
  COUNT(*) FILTER (WHERE event_type = 'card_swiped_right')  AS likes,
  COUNT(*) FILTER (WHERE event_type = 'card_tapped')        AS profile_visits,
  COUNT(*) FILTER (WHERE event_type = 'booking_started')    AS booking_starts,
  COUNT(*) FILTER (WHERE event_type = 'booking_paid')       AS conversions,
  -- 关键转化率
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE event_type = 'booking_paid') /
    NULLIF(COUNT(*) FILTER (WHERE event_type = 'card_viewed'), 0), 2
  ) AS impression_to_conversion_pct,
  AVG(view_duration) FILTER (WHERE event_type = 'card_viewed') AS avg_view_duration_ms
FROM public.user_behaviors
GROUP BY 1, 2;

-- ── 7. 用户留存分析视图 ──
CREATE OR REPLACE VIEW public.user_retention AS
SELECT
  DATE_TRUNC('week', first_seen) AS cohort_week,
  COUNT(DISTINCT user_id) AS cohort_size,
  COUNT(DISTINCT user_id) FILTER (
    WHERE last_seen >= first_seen + INTERVAL '7 days'
  ) AS retained_week1,
  COUNT(DISTINCT user_id) FILTER (
    WHERE last_seen >= first_seen + INTERVAL '14 days'
  ) AS retained_week2
FROM (
  SELECT
    user_id,
    MIN(created_at) AS first_seen,
    MAX(created_at) AS last_seen
  FROM public.user_behaviors
  WHERE user_id IS NOT NULL
  GROUP BY user_id
) sub
GROUP BY 1;
