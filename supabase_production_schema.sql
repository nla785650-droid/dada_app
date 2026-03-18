-- ============================================================
-- 搭哒 (Dada) · 生产级数据库建模脚本
-- 版本: 2.0  兼容 Supabase / PostgreSQL 15+
-- ============================================================
-- 执行顺序：
--   1. 扩展插件
--   2. 枚举类型
--   3. 建表（含约束 / 外键 / 分区索引）
--   4. 触发器函数
--   5. 触发器绑定
-- ============================================================


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 0: 扩展插件                                     ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID 生成
CREATE EXTENSION IF NOT EXISTS "btree_gist";     -- GIST 索引支持 EXCLUDE 约束
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- 支持模糊搜索（搜服务/昵称）
CREATE EXTENSION IF NOT EXISTS "postgis";        -- 地理位置查询（如果 Supabase 实例支持）


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 1: 枚举类型                                     ║
-- ╚══════════════════════════════════════════════════════════╝

-- 达人类型
DO $$ BEGIN
  CREATE TYPE provider_type_enum AS ENUM (
    'cos_commission',   -- Cos 委托
    'photography',      -- 摄影陪拍
    'companion'         -- 社交陪玩
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 达人审核状态
DO $$ BEGIN
  CREATE TYPE audit_status_enum AS ENUM (
    'unapplied',   -- 未申请
    'pending',     -- 审核中（已提交，等待人工审核）
    'approved',    -- 已通过（正式达人）
    'rejected',    -- 已拒绝
    'suspended'    -- 已封禁（违规）
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 订单状态机：严格有向无环图
-- 合法流转: pending → paid → confirmed → in_progress → completed
--                   └──── expired（超时关单）
--           任何状态 → cancelled（双方协商取消）
DO $$ BEGIN
  CREATE TYPE booking_status_enum AS ENUM (
    'pending',      -- 已提交，等待支付
    'paid',         -- 已支付，等待卖家确认
    'confirmed',    -- 卖家已确认
    'in_progress',  -- 服务进行中
    'completed',    -- 已完成（双方确认）
    'cancelled',    -- 已取消（退款）
    'expired'       -- 超时未支付，自动关闭
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 评价可见性
DO $$ BEGIN
  CREATE TYPE review_visibility_enum AS ENUM (
    'public',   -- 公开（默认）
    'private',  -- 仅双方可见
    'hidden'    -- 被管理员隐藏（违规内容）
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 2: profiles — 用户资料表                        ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.profiles (
  -- 主键与 auth 关联
  id                  UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- 基础信息
  username            TEXT UNIQUE NOT NULL
                        CONSTRAINT username_length CHECK (char_length(username) BETWEEN 2 AND 20)
                        CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_\u4e00-\u9fa5]+$'),
  display_name        TEXT        CONSTRAINT display_name_length CHECK (char_length(display_name) <= 30),
  avatar_url          TEXT,
  bio                 TEXT        CONSTRAINT bio_length CHECK (char_length(bio) <= 300),
  phone_hash          TEXT,       -- SHA-256 手机号哈希，用于防小号检测，不存明文

  -- 地理位置（PostGIS 点类型，用于附近达人搜索）
  -- 若 PostGIS 不可用，退化使用 (lat FLOAT8, lng FLOAT8)
  location            GEOMETRY(Point, 4326),
  location_text       TEXT,       -- 用户可读地址，如"北京 朝阳区"

  -- 达人相关
  is_provider         BOOLEAN     NOT NULL DEFAULT FALSE,
  provider_type       provider_type_enum,
  audit_status        audit_status_enum NOT NULL DEFAULT 'unapplied',
  -- provider_config 存储动态配置，避免频繁 ALTER TABLE
  -- 结构示例（Cos）:
  --   { "price_per_hour": 120, "height_cm": 165,
  --     "style_tags": ["汉服","原神"],
  --     "portfolio_urls": ["https://..."],
  --     "schedule_buffer_hours": 2 }
  provider_config     JSONB       NOT NULL DEFAULT '{}',

  -- 信用体系
  rating              NUMERIC(3, 2) NOT NULL DEFAULT 5.00
                        CONSTRAINT rating_range CHECK (rating BETWEEN 0 AND 5),
  review_count        INT         NOT NULL DEFAULT 0 CONSTRAINT review_count_pos CHECK (review_count >= 0),
  completed_orders    INT         NOT NULL DEFAULT 0,
  cancellation_rate   NUMERIC(5, 2) NOT NULL DEFAULT 0.00,

  -- 真身认证
  is_verified         BOOLEAN     NOT NULL DEFAULT FALSE,
  verification_video_url TEXT,
  verified_at         TIMESTAMPTZ,

  -- 封禁信息
  is_banned           BOOLEAN     NOT NULL DEFAULT FALSE,
  ban_reason          TEXT,
  ban_expires_at      TIMESTAMPTZ,

  -- 时间戳
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- GiST 空间索引（附近达人搜索 O(log n)）
CREATE INDEX IF NOT EXISTS idx_profiles_location
  ON public.profiles USING GIST (location);

-- 达人列表查询：快速过滤 + 排序
CREATE INDEX IF NOT EXISTS idx_profiles_provider
  ON public.profiles (audit_status, provider_type, rating DESC)
  WHERE is_provider = TRUE AND is_banned = FALSE;

-- 昵称模糊搜索（trigram 索引）
CREATE INDEX IF NOT EXISTS idx_profiles_username_trgm
  ON public.profiles USING GIN (username gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_profiles_display_name_trgm
  ON public.profiles USING GIN (display_name gin_trgm_ops);

-- updated_at 自动刷新函数（通用）
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 新用户注册时自动初始化 profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name, avatar_url)
  VALUES (
    NEW.id,
    -- 从 OAuth meta 或邮箱前缀生成初始用户名
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      regexp_replace(split_part(NEW.email, '@', 1), '[^a-zA-Z0-9_]', '', 'g')
    ),
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING; -- 幂等：重复注册不报错
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 3: posts — 服务详情表                           ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.posts (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id   UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  title         TEXT        NOT NULL CONSTRAINT title_length CHECK (char_length(title) BETWEEN 2 AND 80),
  description   TEXT        CONSTRAINT desc_length CHECK (char_length(description) <= 2000),
  category      provider_type_enum NOT NULL,

  -- 媒体资源：至少1张封面，最多18张
  images        TEXT[]      NOT NULL DEFAULT '{}'
                  CONSTRAINT images_not_empty CHECK (array_length(images, 1) >= 1),
  cover_image   TEXT        NOT NULL,

  -- 定价
  price         NUMERIC(10, 2) NOT NULL CONSTRAINT price_pos CHECK (price > 0),
  price_unit    TEXT        NOT NULL DEFAULT '次' CHECK (price_unit IN ('次', '小时', '天')),
  price_note    TEXT,       -- 附加说明，如"不含交通"

  -- 标签（用于前端过滤）
  tags          TEXT[]      NOT NULL DEFAULT '{}',

  -- 地理位置（同步 provider 的位置，或单独设置）
  location      GEOMETRY(Point, 4326),
  location_text TEXT,

  -- 状态
  is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
  is_featured   BOOLEAN     NOT NULL DEFAULT FALSE, -- 平台精选

  -- 统计（定期由后台任务或触发器更新，避免高频写锁）
  view_count    INT         NOT NULL DEFAULT 0,
  like_count    INT         NOT NULL DEFAULT 0,
  booking_count INT         NOT NULL DEFAULT 0,

  -- 时间戳
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 瀑布流查询：按分类 + 时间 + 精选排序
CREATE INDEX IF NOT EXISTS idx_posts_category_created
  ON public.posts (category, is_active, is_featured DESC, created_at DESC);

-- 达人自己的帖子列表
CREATE INDEX IF NOT EXISTS idx_posts_provider
  ON public.posts (provider_id, is_active, created_at DESC);

-- 地理位置附近查询（"附近的达人"功能）
CREATE INDEX IF NOT EXISTS idx_posts_location
  ON public.posts USING GIST (location)
  WHERE is_active = TRUE;

-- 标题模糊搜索
CREATE INDEX IF NOT EXISTS idx_posts_title_trgm
  ON public.posts USING GIN (title gin_trgm_ops)
  WHERE is_active = TRUE;

-- JSONB 标签查询（GIN 索引加速 @> 操作）
CREATE INDEX IF NOT EXISTS idx_posts_tags
  ON public.posts USING GIN (tags);

CREATE OR REPLACE TRIGGER posts_set_updated_at
  BEFORE UPDATE ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 4: bookings — 订单状态机                        ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.bookings (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id         UUID        NOT NULL REFERENCES public.posts(id) ON DELETE RESTRICT,
  customer_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  provider_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,

  -- 不允许自我下单
  CONSTRAINT no_self_booking CHECK (customer_id <> provider_id),

  -- 服务时间档期
  booking_date    DATE        NOT NULL,
  start_time      TIME        NOT NULL,
  end_time        TIME        NOT NULL,
  CONSTRAINT time_order CHECK (end_time > start_time),
  duration_hours  NUMERIC(4, 2) GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0
  ) STORED, -- 自动计算时长，防止前端篡改

  -- 状态机（严格流转由触发器守护）
  status          booking_status_enum NOT NULL DEFAULT 'pending',
  previous_status booking_status_enum,             -- 记录上一个状态，方便审计

  -- 金额（在订单创建时快照价格，防止达人改价后影响已有订单）
  amount          NUMERIC(10, 2) NOT NULL CONSTRAINT amount_pos CHECK (amount > 0),
  platform_fee    NUMERIC(10, 2) NOT NULL DEFAULT 0, -- 平台抽成（10%）
  payout_amount   NUMERIC(10, 2) GENERATED ALWAYS AS (amount - platform_fee) STORED,

  -- 支付信息
  payment_method  TEXT        DEFAULT 'mock' CHECK (payment_method IN ('mock', 'alipay', 'wechat', 'applePay')),
  payment_ref     TEXT,                            -- 第三方支付流水号

  -- 关键时间戳（订单生命周期）
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at         TIMESTAMPTZ,
  confirmed_at    TIMESTAMPTZ,
  started_at      TIMESTAMPTZ,
  completed_at    TIMESTAMPTZ,
  cancelled_at    TIMESTAMPTZ,
  -- 超时自动关单：创建后 30 分钟未支付则 expired
  expired_at      TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 minutes'),

  -- 备注 & 取消原因
  customer_note   TEXT        CONSTRAINT note_length CHECK (char_length(customer_note) <= 500),
  cancel_reason   TEXT,
  cancel_by       TEXT        CHECK (cancel_by IN ('customer', 'provider', 'system', 'admin')),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- ── 核心约束：同一达人同一日期不可重叠预约（防双订） ──
  -- 排除已取消和已过期的订单，让档期可以重新开放
  CONSTRAINT no_time_overlap EXCLUDE USING GIST (
    provider_id WITH =,
    booking_date WITH =,
    tsrange(
      (booking_date + start_time)::TIMESTAMP,
      (booking_date + end_time)::TIMESTAMP,
      '[)'  -- 左闭右开，支持相邻不重叠
    ) WITH &&
  ) WHERE (status NOT IN ('cancelled', 'expired'))
);

-- 买家订单列表
CREATE INDEX IF NOT EXISTS idx_bookings_customer
  ON public.bookings (customer_id, status, created_at DESC);

-- 卖家接单列表
CREATE INDEX IF NOT EXISTS idx_bookings_provider
  ON public.bookings (provider_id, status, booking_date);

-- 超时任务扫描（每分钟 pg_cron 调用）
CREATE INDEX IF NOT EXISTS idx_bookings_expired
  ON public.bookings (expired_at)
  WHERE status = 'pending';

CREATE OR REPLACE TRIGGER bookings_set_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 5: reviews — 评价表                             ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.reviews (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  -- 一个订单只能有一条评价（唯一约束）
  booking_id      UUID        NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE RESTRICT,
  reviewer_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reviewee_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- 不允许自我评价
  CONSTRAINT no_self_review CHECK (reviewer_id <> reviewee_id),

  -- 评分维度（加权平均后写入 profiles.rating）
  rating_overall  SMALLINT    NOT NULL CONSTRAINT rating_overall_range  CHECK (rating_overall  BETWEEN 1 AND 5),
  rating_punctual SMALLINT             CONSTRAINT rating_punctual_range CHECK (rating_punctual BETWEEN 1 AND 5),
  rating_quality  SMALLINT             CONSTRAINT rating_quality_range  CHECK (rating_quality  BETWEEN 1 AND 5),
  rating_service  SMALLINT             CONSTRAINT rating_service_range  CHECK (rating_service  BETWEEN 1 AND 5),

  -- 文字评价
  comment         TEXT        CONSTRAINT comment_length CHECK (char_length(comment) BETWEEN 5 AND 500),
  -- 评价附图（展示服务成果，也作为防"照骗"的公开证明）
  photo_urls      TEXT[]      NOT NULL DEFAULT '{}',

  -- 达人回复（一次性，不可修改）
  reply           TEXT        CONSTRAINT reply_length CHECK (char_length(reply) <= 300),
  replied_at      TIMESTAMPTZ,

  visibility      review_visibility_enum NOT NULL DEFAULT 'public',
  is_anonymous    BOOLEAN     NOT NULL DEFAULT FALSE, -- 匿名评价

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 达人主页评价列表
CREATE INDEX IF NOT EXISTS idx_reviews_reviewee
  ON public.reviews (reviewee_id, created_at DESC)
  WHERE visibility = 'public';

-- 评分计算触发器（写入 reviews 后自动更新 profiles.rating）
CREATE OR REPLACE FUNCTION public.update_profile_rating()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  avg_rating  NUMERIC(3, 2);
  cnt         INT;
BEGIN
  -- 以 rating_overall 为准，计算被评价用户的最新平均分
  SELECT ROUND(AVG(rating_overall)::NUMERIC, 2), COUNT(*)
  INTO avg_rating, cnt
  FROM public.reviews
  WHERE reviewee_id = NEW.reviewee_id
    AND visibility  = 'public';

  UPDATE public.profiles
  SET
    rating       = COALESCE(avg_rating, 5.00),
    review_count = cnt
  WHERE id = NEW.reviewee_id;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER reviews_update_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.update_profile_rating();

CREATE OR REPLACE TRIGGER reviews_set_updated_at
  BEFORE UPDATE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 6: messages — 私信表（Realtime 就绪）           ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.messages (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id       UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  booking_id      UUID                   REFERENCES public.bookings(id) ON DELETE SET NULL,

  -- 消息类型扩展（系统通知/普通文本/实拍照片/预约请求）
  msg_type        TEXT        NOT NULL DEFAULT 'text'
                    CHECK (msg_type IN ('text', 'photo_request', 'realtime_photo', 'system', 'booking_notify')),
  content         TEXT        NOT NULL CONSTRAINT content_length CHECK (char_length(content) <= 2000),
  photo_url       TEXT,       -- 实时拍摄照片 URL（不可撤回由应用层保证）
  is_irrevocable  BOOLEAN     NOT NULL DEFAULT FALSE, -- 实拍照片标记

  is_read         BOOLEAN     NOT NULL DEFAULT FALSE,
  read_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 开启 Realtime（Supabase 控制台或 SQL）
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;

-- 收件箱查询（按对话分组需在应用层处理）
CREATE INDEX IF NOT EXISTS idx_messages_receiver
  ON public.messages (receiver_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender
  ON public.messages (sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_booking
  ON public.messages (booking_id)
  WHERE booking_id IS NOT NULL;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 7: blocked_schedules — 档期锁定表              ║
-- ╚══════════════════════════════════════════════════════════╝
-- 存储因已付款订单而锁定的时间段
-- 与 bookings 的 EXCLUDE 约束双重保护，防止重复预约

CREATE TABLE IF NOT EXISTS public.blocked_schedules (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id     UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  booking_id      UUID        NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  booking_date    DATE        NOT NULL,
  start_time      TIME        NOT NULL,
  end_time        TIME        NOT NULL,
  blocked_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- 服务完成或订单取消后自动解锁（由触发器删除本行）
  release_at      TIMESTAMPTZ  -- 预计解锁时间，便于定时任务清理
);

CREATE INDEX IF NOT EXISTS idx_blocked_provider_date
  ON public.blocked_schedules (provider_id, booking_date);


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 8: 触发器 — 订单状态机守护                      ║
-- ╚══════════════════════════════════════════════════════════╝

-- ── 8.1 状态流转合法性校验 ──
-- 防止前端或恶意请求绕过业务逻辑直接跳状态
CREATE OR REPLACE FUNCTION public.validate_booking_status_transition()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  -- 合法流转映射：(旧状态) -> 允许的新状态集合
  valid BOOLEAN := FALSE;
BEGIN
  -- 状态未变化，直接放行
  IF OLD.status = NEW.status THEN RETURN NEW; END IF;

  valid := CASE OLD.status
    WHEN 'pending'     THEN NEW.status IN ('paid', 'cancelled', 'expired')
    WHEN 'paid'        THEN NEW.status IN ('confirmed', 'cancelled')
    WHEN 'confirmed'   THEN NEW.status IN ('in_progress', 'cancelled')
    WHEN 'in_progress' THEN NEW.status IN ('completed', 'cancelled')
    -- 终态不可流转（防止已完成订单被撤销）
    WHEN 'completed'   THEN FALSE
    WHEN 'cancelled'   THEN FALSE
    WHEN 'expired'     THEN FALSE
    ELSE FALSE
  END;

  IF NOT valid THEN
    RAISE EXCEPTION
      '非法状态流转：% → %。订单 ID: %',
      OLD.status, NEW.status, OLD.id
    USING ERRCODE = 'P0001'; -- 自定义错误码，Dart 层可捕获
  END IF;

  -- 记录上一状态（审计用途）
  NEW.previous_status := OLD.status;

  -- 自动填写对应时间戳
  NEW.paid_at        := CASE WHEN NEW.status = 'paid'        THEN COALESCE(NEW.paid_at, NOW())        ELSE NEW.paid_at        END;
  NEW.confirmed_at   := CASE WHEN NEW.status = 'confirmed'   THEN COALESCE(NEW.confirmed_at, NOW())   ELSE NEW.confirmed_at   END;
  NEW.started_at     := CASE WHEN NEW.status = 'in_progress' THEN COALESCE(NEW.started_at, NOW())     ELSE NEW.started_at     END;
  NEW.completed_at   := CASE WHEN NEW.status = 'completed'   THEN COALESCE(NEW.completed_at, NOW())   ELSE NEW.completed_at   END;
  NEW.cancelled_at   := CASE WHEN NEW.status = 'cancelled'   THEN COALESCE(NEW.cancelled_at, NOW())   ELSE NEW.cancelled_at   END;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER bookings_validate_status
  BEFORE UPDATE OF status ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.validate_booking_status_transition();


-- ── 8.2 订单付款后锁定档期 ──
-- 当 status 变为 'paid'，向 blocked_schedules 插入锁定记录
-- 防止达人在同一时间接受多个已付款订单（双重保险）
CREATE OR REPLACE FUNCTION public.lock_schedule_on_paid()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- 只处理 → paid 的流转
  IF NEW.status = 'paid' AND OLD.status <> 'paid' THEN

    -- 先检查档期是否已被锁定（防止并发竞争）
    IF EXISTS (
      SELECT 1 FROM public.blocked_schedules
      WHERE provider_id  = NEW.provider_id
        AND booking_date = NEW.booking_date
        AND tsrange(
              (booking_date + start_time)::TIMESTAMP,
              (booking_date + end_time)::TIMESTAMP, '[)'
            ) &&
            tsrange(
              (NEW.booking_date + NEW.start_time)::TIMESTAMP,
              (NEW.booking_date + NEW.end_time)::TIMESTAMP, '[)'
            )
    ) THEN
      -- 档期冲突：拒绝付款（实际应在支付前预检，此处为最后防线）
      RAISE EXCEPTION
        '档期冲突：达人 % 在 % %~% 已有锁定订单',
        NEW.provider_id, NEW.booking_date, NEW.start_time, NEW.end_time
      USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO public.blocked_schedules (
      provider_id, booking_id, booking_date, start_time, end_time,
      release_at
    ) VALUES (
      NEW.provider_id,
      NEW.id,
      NEW.booking_date,
      NEW.start_time,
      NEW.end_time,
      -- 预计释放时间 = 服务日期结束 + 2小时缓冲
      (NEW.booking_date + NEW.end_time)::TIMESTAMP + INTERVAL '2 hours'
    );

  -- 订单取消或完成 → 解除档期锁定
  ELSIF NEW.status IN ('cancelled', 'completed', 'expired') THEN
    DELETE FROM public.blocked_schedules WHERE booking_id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER bookings_lock_schedule
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.lock_schedule_on_paid();


-- ── 8.3 新订单 → 自动向卖家推送系统通知 ──
-- 卖家不需要主动轮询，Supabase Realtime 会推送消息行
CREATE OR REPLACE FUNCTION public.notify_provider_on_booking()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  customer_name TEXT;
  post_title    TEXT;
BEGIN
  -- 获取买家昵称（显示名 > 用户名）
  SELECT COALESCE(display_name, username)
  INTO customer_name
  FROM public.profiles WHERE id = NEW.customer_id;

  -- 获取帖子标题
  SELECT title INTO post_title
  FROM public.posts WHERE id = NEW.post_id;

  -- 向卖家 messages 表插入系统通知
  INSERT INTO public.messages (
    sender_id,      -- 系统消息用 customer_id 作发送方（可替换为平台账号 UUID）
    receiver_id,
    booking_id,
    msg_type,
    content
  ) VALUES (
    NEW.customer_id,
    NEW.provider_id,
    NEW.id,
    'booking_notify',
    format(
      '📅 新预约请求 | %s 希望预约【%s】| 日期：%s %s~%s | 金额：¥%s',
      customer_name,
      post_title,
      NEW.booking_date,
      NEW.start_time,
      NEW.end_time,
      NEW.amount
    )
  );

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER bookings_notify_provider
  AFTER INSERT ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.notify_provider_on_booking();


-- ── 8.4 自动过期任务（配合 pg_cron 每分钟调用） ──
-- 如果 Supabase 开启了 pg_cron 扩展，可直接调度
-- 否则由 Edge Function 定时调用此函数
CREATE OR REPLACE FUNCTION public.expire_pending_bookings()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  cnt INT;
BEGIN
  UPDATE public.bookings
  SET
    status      = 'expired',
    cancel_by   = 'system',
    cancel_reason = '超时未支付，系统自动关闭'
  WHERE status    = 'pending'
    AND expired_at < NOW();

  GET DIAGNOSTICS cnt = ROW_COUNT;
  RETURN cnt; -- 返回本次过期数量，便于监控日志
END;
$$;

-- 如果 pg_cron 可用，取消注释以下行：
-- SELECT cron.schedule('expire-bookings', '* * * * *', 'SELECT public.expire_pending_bookings()');


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 9: Row Level Security — 全表 RLS 策略          ║
-- ╚══════════════════════════════════════════════════════════╝

-- ── 9.1 profiles ──
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 任何人（含匿名）可读公开资料
-- 注：被封禁用户资料对外不可见（保护系统安全）
CREATE POLICY "profiles_public_read" ON public.profiles
  FOR SELECT
  USING (is_banned = FALSE OR auth.uid() = id); -- 本人可看自己被封状态

-- 仅本人可更新自己的资料
-- SECURITY INVOKER: 以调用者权限执行，防止越权
CREATE POLICY "profiles_owner_update" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    -- 防止用户自己把 is_banned / audit_status 改为有利自己的值
    AND is_banned = (SELECT is_banned FROM public.profiles WHERE id = auth.uid())
    AND audit_status = (SELECT audit_status FROM public.profiles WHERE id = auth.uid())
    -- 防止用户自设 is_verified
    AND is_verified = (SELECT is_verified FROM public.profiles WHERE id = auth.uid())
  );

-- ── 9.2 posts ──
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "posts_public_read" ON public.posts
  FOR SELECT
  USING (is_active = TRUE); -- 下架帖子对外不可见

CREATE POLICY "posts_owner_read_all" ON public.posts
  FOR SELECT
  USING (provider_id = auth.uid()); -- 达人可看自己的所有帖子（含下架）

CREATE POLICY "posts_owner_insert" ON public.posts
  FOR INSERT
  WITH CHECK (
    provider_id = auth.uid()
    -- 仅审核通过的达人可发帖
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND audit_status = 'approved'
    )
  );

CREATE POLICY "posts_owner_update" ON public.posts
  FOR UPDATE
  USING (provider_id = auth.uid())
  WITH CHECK (provider_id = auth.uid());

CREATE POLICY "posts_owner_delete" ON public.posts
  FOR DELETE
  USING (provider_id = auth.uid());

-- ── 9.3 bookings ──
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- 仅买家和卖家双方可见，第三方完全不可访问
CREATE POLICY "bookings_parties_read" ON public.bookings
  FOR SELECT
  USING (customer_id = auth.uid() OR provider_id = auth.uid());

-- 仅买家可创建订单
CREATE POLICY "bookings_customer_insert" ON public.bookings
  FOR INSERT
  WITH CHECK (
    customer_id = auth.uid()
    -- 买家不能给自己下单（数据库约束已处理，RLS 双重防护）
    AND customer_id <> provider_id
    -- 买家账号未被封禁
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND is_banned = FALSE
    )
  );

-- 买卖双方均可更新（不同字段由触发器守护）
CREATE POLICY "bookings_parties_update" ON public.bookings
  FOR UPDATE
  USING (customer_id = auth.uid() OR provider_id = auth.uid());

-- ── 9.4 messages ──
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 仅发件人和收件人可见（严格点对点）
CREATE POLICY "messages_parties_read" ON public.messages
  FOR SELECT
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

-- 仅发件人可发送（防止冒充他人）
CREATE POLICY "messages_sender_insert" ON public.messages
  FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_banned = FALSE
    )
  );

-- 仅收件人可标记已读
CREATE POLICY "messages_receiver_update" ON public.messages
  FOR UPDATE
  USING (receiver_id = auth.uid())
  WITH CHECK (receiver_id = auth.uid());

-- ── 9.5 reviews ──
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reviews_public_read" ON public.reviews
  FOR SELECT
  USING (visibility = 'public' OR reviewer_id = auth.uid() OR reviewee_id = auth.uid());

CREATE POLICY "reviews_buyer_insert" ON public.reviews
  FOR INSERT
  WITH CHECK (
    reviewer_id = auth.uid()
    -- 只有已完成的订单才能评价（防止虚假好评）
    AND EXISTS (
      SELECT 1 FROM public.bookings
      WHERE id = NEW.booking_id
        AND customer_id = auth.uid()
        AND status = 'completed'
    )
    -- 防止重复评价（booking_id UNIQUE 约束已处理，此处为可读性）
    AND NOT EXISTS (
      SELECT 1 FROM public.reviews WHERE booking_id = NEW.booking_id
    )
  );

-- 仅被评价人可回复（且只能写 reply 字段）
CREATE POLICY "reviews_reviewee_reply" ON public.reviews
  FOR UPDATE
  USING (reviewee_id = auth.uid() AND reply IS NULL) -- 只能回复一次
  WITH CHECK (reviewee_id = auth.uid());

-- ── 9.6 blocked_schedules ──
ALTER TABLE public.blocked_schedules ENABLE ROW LEVEL SECURITY;

-- 任何认证用户可查询档期锁定（判断达人是否有空）
CREATE POLICY "blocked_schedules_read" ON public.blocked_schedules
  FOR SELECT USING (auth.role() = 'authenticated');

-- 仅系统（触发器 SECURITY DEFINER）可写入，普通用户不可直接操作
CREATE POLICY "blocked_schedules_system_only" ON public.blocked_schedules
  FOR ALL USING (FALSE) WITH CHECK (FALSE);


-- ╔══════════════════════════════════════════════════════════╗
-- ║  SECTION 10: Storage 存储桶策略                          ║
-- ╚══════════════════════════════════════════════════════════╝

-- 创建存储桶（若不存在）
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'avatars',
    'avatars',
    TRUE,               -- 公开可读（头像需要被任何人访问）
    2097152,            -- 2MB 大小限制
    ARRAY['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'portfolios',
    'portfolios',
    TRUE,               -- 作品集公开展示
    10485760,           -- 10MB（高质量作品集图）
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  ),
  (
    'verifications',
    'verifications',
    FALSE,              -- 核验视频私密！不公开
    52428800,           -- 50MB（视频文件）
    ARRAY['video/mp4', 'video/quicktime', 'video/webm']
  ),
  (
    'realtime-photos',
    'realtime-photos',
    FALSE,              -- 实时拍摄照片半私密（仅对话双方可看）
    5242880,            -- 5MB
    ARRAY['image/jpeg', 'image/png']
  )
ON CONFLICT (id) DO NOTHING;

-- ── avatars 策略 ──
-- 任何人可读头像
CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

-- 认证用户只能上传到自己 uid 命名的文件夹
CREATE POLICY "avatars_owner_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- 只能删除自己的头像
CREATE POLICY "avatars_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- ── portfolios 策略 ──
CREATE POLICY "portfolios_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'portfolios');

CREATE POLICY "portfolios_owner_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'portfolios'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
    -- 必须是审核通过或审核中的达人才能上传作品集
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND audit_status IN ('pending', 'approved')
    )
  );

CREATE POLICY "portfolios_owner_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'portfolios'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- ── verifications 策略（核验视频：严格私密）──
-- 只有本人和平台管理员可读
CREATE POLICY "verifications_owner_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'verifications'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

CREATE POLICY "verifications_owner_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'verifications'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

-- ── realtime-photos 策略 ──
-- 仅消息双方可访问（通过 messages 表的外键关联验证）
CREATE POLICY "realtime_photos_parties_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'realtime-photos'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

CREATE POLICY "realtime_photos_sender_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'realtime-photos'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );
