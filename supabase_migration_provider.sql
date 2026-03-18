-- ============================================================
-- 搭哒 Migration: 达人入驻功能
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. 为 profiles 表新增达人字段
-- ────────────────────────────────────────────────────────────

-- 达人类型枚举
CREATE TYPE provider_type_enum AS ENUM (
  'cos_commission',  -- Cos 委托
  'photography',     -- 摄影陪拍
  'companion'        -- 社交陪玩
);

-- 审核状态枚举
CREATE TYPE verification_status_enum AS ENUM (
  'unapplied',  -- 未申请
  'pending',    -- 审核中
  'approved',   -- 已通过
  'rejected'    -- 已拒绝
);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_provider           BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS provider_type         provider_type_enum,
  ADD COLUMN IF NOT EXISTS service_details       JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS portfolio_urls        TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS verification_status   verification_status_enum DEFAULT 'unapplied',
  ADD COLUMN IF NOT EXISTS rejection_reason      TEXT,
  ADD COLUMN IF NOT EXISTS applied_at            TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approved_at           TIMESTAMPTZ;

-- ────────────────────────────────────────────────────────────
-- 2. provider_applications 独立申请表（保留完整申请记录）
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.provider_applications (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider_type       provider_type_enum NOT NULL,

  -- 通用字段
  region              TEXT,              -- 所在城市/地区
  price_per_hour      NUMERIC(10, 2),    -- 基础定价（元/时）
  self_intro          TEXT,              -- 自我介绍

  -- Cos 委托专属
  height_cm           INT,               -- 身高
  skilled_characters  TEXT[],            -- 擅长角色列表
  cos_photos          TEXT[],            -- 近期 Cos 照（URL）
  life_photos         TEXT[],            -- 生活照（URL）

  -- 摄影陪拍专属
  camera_gear         TEXT,              -- 设备型号
  style_tags          TEXT[],            -- 擅长风格标签
  portfolio_photos    TEXT[],            -- 作品集（至少6张）

  -- 社交陪玩专属
  personal_tags       TEXT[],            -- 个人标签
  service_scope       TEXT,              -- 服务范围描述
  verification_video  TEXT,              -- 真实视频核验 URL

  -- 通用存储（动态表单扩展字段）
  extra_details       JSONB DEFAULT '{}',

  -- 状态流转
  status              verification_status_enum NOT NULL DEFAULT 'pending',
  rejection_reason    TEXT,
  reviewed_by         UUID REFERENCES public.profiles(id),
  submitted_at        TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at         TIMESTAMPTZ,

  -- 协议确认
  agreed_to_terms     BOOLEAN NOT NULL DEFAULT FALSE,
  agreed_at           TIMESTAMPTZ
);

-- RLS
ALTER TABLE public.provider_applications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "applications_owner_all" ON public.provider_applications
  FOR ALL USING (auth.uid() = user_id);

-- 索引
CREATE INDEX idx_applications_user ON public.provider_applications(user_id);
CREATE INDEX idx_applications_status ON public.provider_applications(status);

-- ────────────────────────────────────────────────────────────
-- 3. Supabase Storage：portfolios bucket
--    在控制台手动创建，或通过以下 SQL 方式
-- ────────────────────────────────────────────────────────────
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('portfolios', 'portfolios', true)
-- ON CONFLICT (id) DO NOTHING;

-- CREATE POLICY "portfolios_auth_upload" ON storage.objects
--   FOR INSERT TO authenticated
--   WITH CHECK (bucket_id = 'portfolios' AND auth.uid()::text = (storage.foldername(name))[1]);

-- CREATE POLICY "portfolios_public_read" ON storage.objects
--   FOR SELECT USING (bucket_id = 'portfolios');
