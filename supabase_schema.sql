-- ============================================================
-- 搭哒 (Dada) Supabase 数据库建表脚本
-- ============================================================

-- 启用 uuid 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. profiles 用户资料表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username      TEXT UNIQUE NOT NULL,
  display_name  TEXT,
  avatar_url    TEXT,
  bio           TEXT,
  role          TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'provider')),
  -- provider 专属字段
  categories    TEXT[],           -- 服务分类：cosplay / photo / game
  price_min     NUMERIC(10, 2),
  price_max     NUMERIC(10, 2),
  location      TEXT,
  rating        NUMERIC(3, 2) DEFAULT 0,
  review_count  INT DEFAULT 0,
  is_verified   BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- RLS 策略
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_public_read" ON public.profiles
  FOR SELECT USING (TRUE);

CREATE POLICY "profiles_owner_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- 新用户注册时自动创建 profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 2. posts 服务内容表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.posts (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  category      TEXT NOT NULL CHECK (category IN ('cosplay', 'photo', 'game', 'other')),
  images        TEXT[] NOT NULL DEFAULT '{}',  -- Supabase Storage URLs
  cover_image   TEXT,
  price         NUMERIC(10, 2) NOT NULL,
  price_unit    TEXT DEFAULT '次' CHECK (price_unit IN ('次', '小时', '天')),
  tags          TEXT[],
  location      TEXT,
  is_active     BOOLEAN DEFAULT TRUE,
  view_count    INT DEFAULT 0,
  like_count    INT DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- RLS 策略
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "posts_public_read" ON public.posts
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY "posts_owner_insert" ON public.posts
  FOR INSERT WITH CHECK (auth.uid() = provider_id);

CREATE POLICY "posts_owner_update" ON public.posts
  FOR UPDATE USING (auth.uid() = provider_id);

CREATE POLICY "posts_owner_delete" ON public.posts
  FOR DELETE USING (auth.uid() = provider_id);

-- ============================================================
-- 3. bookings 订单与档期表
-- ============================================================
CREATE TABLE IF NOT EXISTS public.bookings (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id         UUID NOT NULL REFERENCES public.posts(id) ON DELETE RESTRICT,
  customer_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  provider_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  -- 时间档期
  booking_date    DATE NOT NULL,
  start_time      TIME NOT NULL,
  end_time        TIME NOT NULL,
  -- 订单状态流转: pending -> confirmed -> in_progress -> completed / cancelled
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled')),
  -- 支付信息
  amount          NUMERIC(10, 2) NOT NULL,
  payment_method  TEXT DEFAULT 'mock' CHECK (payment_method IN ('mock', 'alipay', 'wechat')),
  payment_status  TEXT DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
  paid_at         TIMESTAMPTZ,
  -- 备注
  customer_note   TEXT,
  cancel_reason   TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  -- 档期冲突检查：同一 provider 同一日期同一时段不可重复预约
  CONSTRAINT no_overlap EXCLUDE USING gist (
    provider_id WITH =,
    booking_date WITH =,
    tsrange(
      (booking_date + start_time)::TIMESTAMP,
      (booking_date + end_time)::TIMESTAMP
    ) WITH &&
  ) WHERE (status NOT IN ('cancelled'))
);

-- 需要 btree_gist 扩展支持 EXCLUDE 约束
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- RLS 策略
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "bookings_customer_read" ON public.bookings
  FOR SELECT USING (auth.uid() = customer_id OR auth.uid() = provider_id);

CREATE POLICY "bookings_customer_insert" ON public.bookings
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

CREATE POLICY "bookings_parties_update" ON public.bookings
  FOR UPDATE USING (auth.uid() = customer_id OR auth.uid() = provider_id);

-- ============================================================
-- 4. messages 私信消息表（Supabase Realtime）
-- ============================================================
CREATE TABLE IF NOT EXISTS public.messages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  booking_id  UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  content     TEXT NOT NULL,
  is_read     BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 开启 Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- RLS 策略
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_parties_read" ON public.messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "messages_sender_insert" ON public.messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- ============================================================
-- 5. 索引优化
-- ============================================================
CREATE INDEX idx_posts_provider ON public.posts(provider_id);
CREATE INDEX idx_posts_category ON public.posts(category);
CREATE INDEX idx_posts_created ON public.posts(created_at DESC);
CREATE INDEX idx_bookings_customer ON public.bookings(customer_id);
CREATE INDEX idx_bookings_provider ON public.bookings(provider_id);
CREATE INDEX idx_bookings_date ON public.bookings(booking_date);
CREATE INDEX idx_messages_receiver ON public.messages(receiver_id, created_at DESC);
