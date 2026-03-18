-- ============================================================
-- 搭哒 · 喜欢系统 SQL
-- user_likes：用户对达人的"喜欢"行为记录
-- ============================================================

-- ── 1. user_likes 表 ──
CREATE TABLE IF NOT EXISTS public.user_likes (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_user_id UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- 防止自己喜欢自己
  CONSTRAINT no_self_like CHECK (user_id <> target_user_id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- 联合唯一索引：同一用户对同一达人只能有一条喜欢记录
  -- 防止重复插入，同时作为 upsert 的冲突目标
  CONSTRAINT unique_user_like UNIQUE (user_id, target_user_id)
);

-- 常用查询索引
CREATE INDEX IF NOT EXISTS idx_user_likes_user_id
  ON public.user_likes (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_likes_target_id
  ON public.user_likes (target_user_id);

-- ── 2. RLS 行级安全 ──
ALTER TABLE public.user_likes ENABLE ROW LEVEL SECURITY;

-- 用户只能读取自己发出的喜欢记录
CREATE POLICY "likes_owner_read"
  ON public.user_likes FOR SELECT
  USING (user_id = auth.uid());

-- 用户只能插入自己的喜欢记录（不能冒充他人）
CREATE POLICY "likes_owner_insert"
  ON public.user_likes FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- 用户只能删除自己的喜欢记录（取消喜欢）
CREATE POLICY "likes_owner_delete"
  ON public.user_likes FOR DELETE
  USING (user_id = auth.uid());

-- ── 3. 视图：我的喜欢列表（联查 profiles 获取达人信息）──
-- 便于前端一次查询拿到头像、昵称、标签
CREATE OR REPLACE VIEW public.my_liked_providers AS
SELECT
  ul.id           AS like_id,
  ul.user_id,
  ul.target_user_id,
  ul.created_at   AS liked_at,
  p.display_name,
  p.avatar_url,
  p.provider_type,
  p.provider_config,
  p.audit_status,
  p.is_verified,
  COALESCE(
    (p.provider_config->>'base_price')::NUMERIC,
    0
  )               AS base_price,
  COALESCE(
    (p.provider_config->>'location')::TEXT,
    ''
  )               AS location
FROM
  public.user_likes ul
  JOIN public.profiles p ON p.id = ul.target_user_id;

-- ── 4. Realtime 开启（支持 StreamProvider 实时监听）──
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_likes;

-- ── 5. 互相喜欢检测 RPC（可选，用于"匹配成功"业务）──
-- 检测两个用户是否互相喜欢，用于扩展"双向匹配"功能
CREATE OR REPLACE FUNCTION public.check_mutual_like(other_user_id UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_likes
    WHERE user_id        = auth.uid()
      AND target_user_id = other_user_id
  ) AND EXISTS (
    SELECT 1 FROM public.user_likes
    WHERE user_id        = other_user_id
      AND target_user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.check_mutual_like(UUID) TO authenticated;
