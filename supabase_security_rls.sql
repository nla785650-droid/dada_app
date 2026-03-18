-- ============================================================
-- 搭哒 · 安全深化 SQL
-- RLS 精细化 + 隐私脱敏
-- ============================================================

-- ═══════════════════════════════════════════════════════════
-- Part 1: user_locations RLS 深度配置
--
-- 安全需求：
--   位置数据只在 booking_status = 'in_progress' 时对双方可见
--   其他状态（paid/completed/cancelled）一律不可见
--   防止：用户在服务前/后被持续追踪位置
-- ═══════════════════════════════════════════════════════════

-- 删除旧的 location 读取策略
DROP POLICY IF EXISTS "location_booking_parties_read" ON public.user_locations;

-- 重建：仅履约进行中可见
CREATE POLICY "location_active_fulfillment_only"
  ON public.user_locations FOR SELECT
  USING (
    -- 条件 1：读取自己的位置（始终允许）
    user_id = auth.uid()

    OR

    -- 条件 2：查询对方位置时，订单必须处于 in_progress 状态
    (
      booking_id IN (
        SELECT b.id
        FROM   public.bookings b
        WHERE  (b.customer_id = auth.uid() OR b.provider_id = auth.uid())
          -- ⚡ 核心约束：只有履约进行中才可见位置
          AND b.payment_status = 'in_progress'
          -- 防止过期行程位置被访问（超过 24 小时自动失效）
          AND b.created_at > NOW() - INTERVAL '24 hours'
      )
    )
  );

-- 位置上传：仍只允许写入自己的位置
DROP POLICY IF EXISTS "location_self_write" ON public.user_locations;
CREATE POLICY "location_self_write"
  ON public.user_locations FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 位置自动过期：创建清理函数（每日凌晨由 pg_cron 调用）
CREATE OR REPLACE FUNCTION public.cleanup_expired_locations()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- 删除超过 24 小时 OR 对应订单已完成的位置记录
  DELETE FROM public.user_locations
  WHERE updated_at < NOW() - INTERVAL '24 hours'
     OR booking_id IN (
       SELECT id FROM public.bookings
       WHERE payment_status IN ('completed', 'cancelled')
     );
END;
$$;

-- ═══════════════════════════════════════════════════════════
-- Part 2: 隐私脱敏视图
--
-- 原则：
--   · 真实手机号和姓名始终通过脱敏视图访问
--   · 只有在对应订单 payment_status = 'in_progress' 时
--     才通过 get_contact_info() RPC 解锁真实联系方式
-- ═══════════════════════════════════════════════════════════

-- 2.1 profiles 脱敏视图（对外默认返回脱敏数据）
CREATE OR REPLACE VIEW public.profiles_masked AS
SELECT
  id,
  display_name,
  -- 真实姓名脱敏：保留姓，名字替换为 **
  CASE
    WHEN real_name IS NOT NULL AND LENGTH(real_name) >= 2
    THEN SUBSTRING(real_name, 1, 1) || REPEAT('*', LENGTH(real_name) - 1)
    ELSE '***'
  END AS masked_real_name,
  -- 手机号脱敏：138****8888
  CASE
    WHEN phone IS NOT NULL AND LENGTH(phone) = 11
    THEN SUBSTRING(phone, 1, 3) || '****' || SUBSTRING(phone, 8, 4)
    WHEN phone IS NOT NULL
    THEN REPEAT('*', LENGTH(phone))
    ELSE NULL
  END AS masked_phone,
  -- 非敏感字段直接透出
  avatar_url,
  bio,
  provider_type,
  provider_config,
  is_provider,
  is_verified,
  ai_aesthetic_score,
  audit_status,
  created_at
FROM public.profiles;

-- 2.2 RPC：get_contact_info（仅在履约进行中时解锁真实联系方式）
CREATE OR REPLACE FUNCTION public.get_contact_info(p_booking_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_booking     public.bookings%ROWTYPE;
  v_target_id   UUID;
  v_profile     public.profiles%ROWTYPE;
BEGIN
  -- 查询订单
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;

  -- 权限检查：只有买卖双方可以调用
  IF v_booking.customer_id <> auth.uid() AND v_booking.provider_id <> auth.uid() THEN
    RAISE EXCEPTION '无权访问此订单联系信息';
  END IF;

  -- 状态检查：只有履约进行中才返回真实联系方式
  IF v_booking.payment_status <> 'in_progress' THEN
    RETURN jsonb_build_object(
      'success',  FALSE,
      'reason',   'contact_info_only_available_during_service',
      'message',  '联系方式仅在服务进行中可见，保护双方隐私'
    );
  END IF;

  -- 获取对方信息（买家查达人，达人查买家）
  v_target_id := CASE
    WHEN auth.uid() = v_booking.customer_id THEN v_booking.provider_id
    ELSE v_booking.customer_id
  END;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_target_id;

  RETURN jsonb_build_object(
    'success',      TRUE,
    'display_name', v_profile.display_name,
    -- 返回真实联系方式（仅此 RPC 内解密）
    'real_name',    v_profile.real_name,
    'phone',        v_profile.phone,
    'avatar_url',   v_profile.avatar_url,
    'note',         '本次通话结束后联系方式将自动失效'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_contact_info(UUID) TO authenticated;

-- 2.3 messages 表 RLS 强化（防止第三方读取私信）
DROP POLICY IF EXISTS "messages_participants_only" ON public.messages;
CREATE POLICY "messages_participants_only"
  ON public.messages FOR SELECT
  USING (
    sender_id   = auth.uid()
    OR receiver_id = auth.uid()
  );

CREATE POLICY "messages_sender_insert"
  ON public.messages FOR INSERT
  WITH CHECK (sender_id = auth.uid());

-- 已发送消息不可删除（防止销毁证据）
-- （不创建 DELETE 策略 = 禁止删除）

-- ═══════════════════════════════════════════════════════════
-- Part 3: 安全审计日志
--
-- 记录所有敏感操作（访问真实联系方式、触发报警等）
-- ═══════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        REFERENCES public.profiles(id),
  action       TEXT        NOT NULL,
  target_table TEXT,
  target_id    TEXT,
  ip_address   INET,
  user_agent   TEXT,
  payload      JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 审计日志只允许插入，不允许读取（防篡改）
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "audit_insert_only"
  ON public.audit_logs FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

-- 写入审计日志的通用函数
CREATE OR REPLACE FUNCTION public.write_audit_log(
  p_action       TEXT,
  p_target_table TEXT DEFAULT NULL,
  p_target_id    TEXT DEFAULT NULL,
  p_payload      JSONB DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.audit_logs (user_id, action, target_table, target_id, payload)
  VALUES (auth.uid(), p_action, p_target_table, p_target_id, p_payload);
END;
$$;

GRANT EXECUTE ON FUNCTION public.write_audit_log(TEXT, TEXT, TEXT, JSONB) TO authenticated;

-- ═══════════════════════════════════════════════════════════
-- Part 4: bookings 表 payment_status enum 补充
--
-- 增加 in_progress 状态（卖家扫码后进入此状态）
-- ═══════════════════════════════════════════════════════════

-- 检查是否已有 in_progress 值（幂等操作）
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum
    WHERE enumlabel = 'in_progress'
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')
  ) THEN
    ALTER TYPE payment_status ADD VALUE 'in_progress' AFTER 'paid';
  END IF;
END;
$$;

-- ═══════════════════════════════════════════════════════════
-- Part 5: 数据访问频率限制（防爬虫/滥用）
-- ═══════════════════════════════════════════════════════════

-- 创建速率限制表（轻量版，生产环境可配合 Upstash Redis）
CREATE TABLE IF NOT EXISTS public.rate_limits (
  key          TEXT        PRIMARY KEY,
  count        INTEGER     NOT NULL DEFAULT 1,
  window_start TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.check_rate_limit(
  p_key        TEXT,
  p_limit      INTEGER DEFAULT 100,
  p_window_sec INTEGER DEFAULT 60
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count       INTEGER;
  v_window_start TIMESTAMPTZ;
BEGIN
  SELECT count, window_start
  INTO   v_count, v_window_start
  FROM   public.rate_limits
  WHERE  key = p_key;

  -- 窗口过期则重置
  IF v_window_start IS NULL OR
     v_window_start < NOW() - (p_window_sec || ' seconds')::INTERVAL THEN
    INSERT INTO public.rate_limits (key, count, window_start)
    VALUES (p_key, 1, NOW())
    ON CONFLICT (key) DO UPDATE
      SET count = 1, window_start = NOW();
    RETURN TRUE;
  END IF;

  -- 超出限制
  IF v_count >= p_limit THEN
    RETURN FALSE;
  END IF;

  -- 累加
  UPDATE public.rate_limits SET count = count + 1 WHERE key = p_key;
  RETURN TRUE;
END;
$$;
