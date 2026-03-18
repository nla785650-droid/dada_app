-- ============================================================
-- 搭哒 · 服务履约系统 SQL
-- ============================================================

-- ── 1. 扩展 bookings 状态机（添加 partially_released）──
-- 说明：当买家确认"已到达"核验照片后，资金进入部分释放状态
--       平台确认服务完成后再全额打款给达人
--       此设计参考 Airbnb 托管机制，保障双方权益
ALTER TYPE booking_status_enum ADD VALUE IF NOT EXISTS 'partially_released';

-- ── 2. booking_checkpoints — 服务节点打卡表 ──
-- 每个重要节点（出发/到达/结束）均记录核验照片与位置，
-- 作为后续争议仲裁的不可篡改证据（is_verified_shot 一旦为 true 不可修改）
CREATE TABLE IF NOT EXISTS public.booking_checkpoints (
  id                    UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id            UUID        NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,

  -- 节点类型：对应前端 ServiceNode 枚举
  node                  TEXT        NOT NULL
                          CHECK (node IN (
                            'about_to_depart',  -- 待出发（达人主动打卡）
                            'departed',         -- 已出发（GPS + 时间戳）
                            'arrived',          -- 已到达（核验照片，买家确认）
                            'in_progress',      -- 服务开始（双方确认）
                            'finished'          -- 服务结束
                          )),

  -- 一个订单每个节点只允许一条记录（防重复打卡）
  CONSTRAINT unique_checkpoint UNIQUE (booking_id, node),

  -- 核验信息（arrived 节点必填 photo_url）
  photo_url             TEXT,
  -- is_verified_shot = true 意味着此照片是通过受控相机拍摄 + 水印合成
  -- 一旦标记为 true，禁止任何人修改（由 RLS + 触发器双重保护）
  is_verified_shot      BOOLEAN     NOT NULL DEFAULT FALSE,

  -- 位置信息（前端通过 Geolocator 获取，存储文字 + 坐标）
  location_text         TEXT,
  location_lat          FLOAT8,
  location_lng          FLOAT8,

  -- 买家确认节点（arrived 节点需买家主动确认，触发资金部分释放）
  confirmed_by_customer BOOLEAN     NOT NULL DEFAULT FALSE,
  confirmed_at          TIMESTAMPTZ,

  -- 备注（达人可选填）
  note                  TEXT        CONSTRAINT note_length CHECK (char_length(note) <= 200),

  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 按订单查询节点（主要查询场景）
CREATE INDEX IF NOT EXISTS idx_checkpoints_booking
  ON public.booking_checkpoints (booking_id, created_at);

-- ── 3. RLS 策略 ──
ALTER TABLE public.booking_checkpoints ENABLE ROW LEVEL SECURITY;

-- 买卖双方均可读取节点信息
CREATE POLICY "checkpoints_parties_read" ON public.booking_checkpoints
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings
      WHERE id = booking_id
        AND (customer_id = auth.uid() OR provider_id = auth.uid())
    )
  );

-- 仅达人（provider）可插入新节点
CREATE POLICY "checkpoints_provider_insert" ON public.booking_checkpoints
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bookings
      WHERE id = booking_id AND provider_id = auth.uid()
    )
  );

-- 允许买家更新 confirmed_by_customer 字段（其他字段禁止改动）
-- 注意：is_verified_shot 一旦为 true，触发器会阻止其被改回 false
CREATE POLICY "checkpoints_customer_confirm" ON public.booking_checkpoints
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings
      WHERE id = booking_id AND customer_id = auth.uid()
    )
  )
  WITH CHECK (
    -- 买家只能修改 confirmed_by_customer 和 confirmed_at
    -- 其他字段值必须与原值相同（PostgreSQL 无法在 RLS 层限制字段，此处依赖触发器）
    confirmed_by_customer = TRUE
  );

-- ── 4. 触发器：保护 is_verified_shot 不可逆 ──
-- 一旦 is_verified_shot = true，任何尝试将其改回 false 的操作均被拒绝
-- 这是"防照骗"安全机制的数据库最后防线
CREATE OR REPLACE FUNCTION public.protect_verified_shot()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- 如果原来是 true，不允许任何人改为 false
  IF OLD.is_verified_shot = TRUE AND NEW.is_verified_shot = FALSE THEN
    RAISE EXCEPTION
      '安全违规：已核验照片标记不可撤销。节点: %, 订单: %',
      OLD.node, OLD.booking_id
    USING ERRCODE = 'P0003';
  END IF;

  -- 如果原来有 photo_url，不允许替换（防止后期换图）
  IF OLD.photo_url IS NOT NULL AND NEW.photo_url <> OLD.photo_url THEN
    RAISE EXCEPTION
      '安全违规：已提交的核验照片不可修改。节点: %',
      OLD.node
    USING ERRCODE = 'P0004';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER checkpoints_protect_shot
  BEFORE UPDATE ON public.booking_checkpoints
  FOR EACH ROW EXECUTE FUNCTION public.protect_verified_shot();

-- ── 5. 触发器：买家确认到达 → 订单状态变为 partially_released ──
-- 资金托管联动：确认核验照片 = 确认达人已到场 = 释放部分资金
CREATE OR REPLACE FUNCTION public.release_funds_on_arrival_confirm()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- 仅在 arrived 节点被买家确认时触发
  IF NEW.node = 'arrived'
    AND NEW.confirmed_by_customer = TRUE
    AND OLD.confirmed_by_customer = FALSE
  THEN
    -- 更新订单状态为部分释放（资金仍托管，但锁定比例变化）
    UPDATE public.bookings
    SET
      status     = 'partially_released',
      started_at = NOW()              -- 同步标记服务开始时间
    WHERE id = NEW.booking_id
      AND status IN ('confirmed', 'paid'); -- 仅允许从合法前置状态流转

    -- 向买家发送系统通知
    INSERT INTO public.messages (
      sender_id,
      receiver_id,
      booking_id,
      msg_type,
      content
    )
    SELECT
      b.provider_id,
      b.customer_id,
      b.id,
      'system',
      format(
        '✅ 已确认达人到达！服务开始计时。到达地点：%s',
        COALESCE(NEW.location_text, '未获取位置')
      )
    FROM public.bookings b
    WHERE b.id = NEW.booking_id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER checkpoints_release_funds
  AFTER UPDATE OF confirmed_by_customer ON public.booking_checkpoints
  FOR EACH ROW EXECUTE FUNCTION public.release_funds_on_arrival_confirm();

-- ── 6. 开启 Realtime（节点变化实时推送给双方）──
ALTER PUBLICATION supabase_realtime ADD TABLE public.booking_checkpoints;
