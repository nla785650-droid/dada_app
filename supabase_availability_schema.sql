-- ============================================================
-- 搭哒 · 档期系统 SQL
-- availability_slots：达人可接单时间段
-- ============================================================

-- ── 1. 档期表 ──
CREATE TABLE IF NOT EXISTS public.availability_slots (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  slot_date   DATE        NOT NULL,
  start_time  TIME        NOT NULL,
  end_time    TIME        NOT NULL,
  duration_hours NUMERIC(4,1) GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (end_time - start_time)) / 3600
  ) STORED,
  status      TEXT        NOT NULL DEFAULT 'available'
    CONSTRAINT slot_status_check CHECK (status IN ('available', 'booked', 'blocked')),
  booking_id  UUID        REFERENCES public.bookings(id) ON DELETE SET NULL,
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- 核心约束：同一达人同一日期同一起始时间只能有一条记录
  -- 防止双重预约（double-booking）的数据库层保障
  CONSTRAINT unique_provider_slot UNIQUE (provider_id, slot_date, start_time)
);

-- 达人时间表常用查询索引
CREATE INDEX IF NOT EXISTS idx_availability_provider_date
  ON public.availability_slots (provider_id, slot_date);

CREATE INDEX IF NOT EXISTS idx_availability_status
  ON public.availability_slots (status)
  WHERE status = 'available';

-- updated_at 触发器
CREATE OR REPLACE TRIGGER set_availability_updated_at
  BEFORE UPDATE ON public.availability_slots
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 2. RLS ──
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;

-- 任何人可查看档期（用于前端展示是否可约）
CREATE POLICY "availability_public_read"
  ON public.availability_slots FOR SELECT
  USING (TRUE);

-- 仅达人本人可管理自己的档期
CREATE POLICY "availability_provider_manage"
  ON public.availability_slots FOR ALL
  USING (provider_id = auth.uid());

-- ── 3. 核心 RPC：create_booking_with_lock ──
-- 原子性预约创建，防止并发竞争（两个用户同时预约同一时段）
-- 安全机制：
--   · 使用 SELECT ... FOR UPDATE SKIP LOCKED 实现乐观锁
--   · 检查 status = 'available' 后立即更新为 'booked'
--   · 原子性插入 booking 记录（同一事务）
--   · 若时段已被占用，返回 conflict=true，提示用户
CREATE OR REPLACE FUNCTION public.create_booking_with_lock(
  p_slot_id        UUID,
  p_post_id        UUID,
  p_amount         NUMERIC,
  p_notes          TEXT DEFAULT NULL
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_slot        public.availability_slots%ROWTYPE;
  v_booking_id  UUID;
  v_code        TEXT;
  v_exists      BOOLEAN;
BEGIN
  -- 行锁尝试获取档期（SKIP LOCKED：若被其他事务锁定则立即失败）
  SELECT * INTO v_slot
  FROM public.availability_slots
  WHERE id = p_slot_id
    AND status = 'available'
  FOR UPDATE SKIP LOCKED;

  -- 档期不可用（已被预约或当前正在被其他事务处理）
  IF NOT FOUND THEN
    -- 检查是否真的已被预约，或者只是锁争用
    SELECT EXISTS(
      SELECT 1 FROM public.availability_slots
      WHERE id = p_slot_id AND status != 'available'
    ) INTO v_exists;

    IF v_exists THEN
      RETURN jsonb_build_object(
        'success',  FALSE,
        'conflict', TRUE,
        'message',  '手慢了！该时段刚被其他用户预约，请选择其他时间段'
      );
    ELSE
      RETURN jsonb_build_object(
        'success',  FALSE,
        'conflict', TRUE,
        'message',  '时段繁忙，请稍后重试'
      );
    END IF;
  END IF;

  -- 生成唯一 8 位核销码
  FOR i IN 1..10 LOOP
    v_code := upper(substring(md5(random()::TEXT || clock_timestamp()::TEXT) FROM 1 FOR 8));
    SELECT EXISTS(
      SELECT 1 FROM public.bookings WHERE verification_code = v_code
    ) INTO v_exists;
    EXIT WHEN NOT v_exists;
  END LOOP;

  -- 插入订单记录
  INSERT INTO public.bookings (
    customer_id, provider_id, post_id,
    booking_date, start_time, end_time,
    amount, status, payment_method,
    paid_at, verification_code, notes
  ) VALUES (
    auth.uid(),           -- 当前登录用户为买家
    v_slot.provider_id,
    p_post_id,
    v_slot.slot_date::TEXT,
    v_slot.start_time::TEXT,
    v_slot.end_time::TEXT,
    p_amount,
    'paid',               -- 模拟支付已完成
    'mock',
    NOW(),
    v_code,
    p_notes
  )
  RETURNING id INTO v_booking_id;

  -- 将档期标记为已预约（原子操作，同一事务内）
  UPDATE public.availability_slots
  SET status = 'booked', booking_id = v_booking_id
  WHERE id = p_slot_id;

  -- 向达人发送系统消息
  INSERT INTO public.messages (
    sender_id, receiver_id, booking_id, msg_type, content
  ) VALUES (
    auth.uid(),
    v_slot.provider_id,
    v_booking_id,
    'system',
    format('🎉 新预约！%s 预约了您 %s %s-%s 的服务',
      auth.uid()::TEXT,
      v_slot.slot_date,
      v_slot.start_time,
      v_slot.end_time)
  );

  RETURN jsonb_build_object(
    'success',           TRUE,
    'booking_id',        v_booking_id,
    'verification_code', v_code,
    'message',           '预约成功！'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_booking_with_lock(UUID, UUID, NUMERIC, TEXT)
  TO authenticated;

-- ── 4. 批量生成达人默认档期（供测试/初始化）──
CREATE OR REPLACE FUNCTION public.generate_default_slots(
  p_provider_id UUID,
  p_start_date  DATE DEFAULT CURRENT_DATE,
  p_days        INT  DEFAULT 14
)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_date    DATE;
  v_count   INT := 0;
  v_times   TIME[] := ARRAY['09:00'::TIME, '11:00'::TIME, '14:00'::TIME,
                             '16:00'::TIME, '19:00'::TIME, '21:00'::TIME];
  v_time    TIME;
BEGIN
  FOR day_offset IN 0..(p_days-1) LOOP
    v_date := p_start_date + day_offset;
    FOREACH v_time IN ARRAY v_times LOOP
      INSERT INTO public.availability_slots
        (provider_id, slot_date, start_time, end_time, status)
      VALUES
        (p_provider_id, v_date, v_time, v_time + INTERVAL '2 hours', 'available')
      ON CONFLICT (provider_id, slot_date, start_time) DO NOTHING;
      v_count := v_count + 1;
    END LOOP;
  END LOOP;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_default_slots(UUID, DATE, INT)
  TO authenticated;

-- 开启 Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.availability_slots;
