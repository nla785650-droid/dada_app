-- ============================================================
-- 搭哒 · 支付与核销系统 SQL
-- ============================================================

-- ── 1. 扩展 bookings 表 ──
-- verification_code：8位大写字母数字，买家支付后生成，达人扫码核销
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS verification_code TEXT
    CONSTRAINT verification_code_format CHECK (
      verification_code IS NULL OR
      verification_code ~ '^[A-Z0-9]{8}$'  -- 格式约束：8位大写字母数字
    ),
  ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- 核销码唯一索引（一码一单，防止一码核销多单）
CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_verification_code
  ON public.bookings (verification_code)
  WHERE verification_code IS NOT NULL;

-- ── 2. RPC：generate_verification_code ──
-- 支付成功后调用，生成唯一核销码并写入订单
-- 使用 SECURITY DEFINER 确保客户端无法绕过业务逻辑直接写 code
CREATE OR REPLACE FUNCTION public.generate_verification_code(booking_id_input UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  code    TEXT;
  exists  BOOLEAN;
  booking public.bookings%ROWTYPE;
BEGIN
  -- 校验订单归属（调用者必须是订单买家）
  SELECT * INTO booking
  FROM public.bookings
  WHERE id = booking_id_input
    AND customer_id = auth.uid()
    AND status = 'paid'           -- 只允许已支付状态
    AND verification_code IS NULL -- 防止重复生成
  FOR UPDATE;                     -- 行锁，防并发重入

  IF NOT FOUND THEN
    RAISE EXCEPTION '订单不存在、状态不符或已生成核销码' USING ERRCODE = 'P0010';
  END IF;

  -- 生成唯一 8 位大写字母数字码，碰撞重试最多 10 次
  FOR i IN 1..10 LOOP
    code := upper(substring(md5(random()::TEXT || clock_timestamp()::TEXT) FROM 1 FOR 8));
    SELECT EXISTS(
      SELECT 1 FROM public.bookings WHERE verification_code = code
    ) INTO exists;
    EXIT WHEN NOT exists;
  END LOOP;

  -- 写入核销码
  UPDATE public.bookings
  SET verification_code = code
  WHERE id = booking_id_input;

  RETURN code;
END;
$$;

-- ── 3. RPC：verify_booking ──
-- 达人扫码后调用，完成核销
-- 安全设计：
--   · 查找 verification_code 匹配 + 状态为 'paid' 的订单（双重校验）
--   · 使用 FOR UPDATE 防止同一码被两个设备并发核销
--   · 成功后将状态改为 'completed'，记录 verified_at 时间戳
--   · 返回 JSONB，前端据此显示成功/失败信息
CREATE OR REPLACE FUNCTION public.verify_booking(input_code TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  booking_row public.bookings%ROWTYPE;
BEGIN
  -- 清理输入：去除空白、转大写，防止大小写绕过
  input_code := upper(trim(input_code));

  -- 查找目标订单（加行锁防并发）
  SELECT * INTO booking_row
  FROM public.bookings
  WHERE verification_code = input_code
    AND status = 'paid'           -- 只能核销已支付订单
  FOR UPDATE;

  IF NOT FOUND THEN
    -- 不透露是"码不对"还是"状态不对"，统一返回无效，防枚举攻击
    RETURN jsonb_build_object(
      'success', FALSE,
      'message', '核销码无效或订单已核销，请确认买家二维码'
    );
  END IF;

  -- 校验：达人必须是该订单的 provider（防止跨单核销）
  IF booking_row.provider_id <> auth.uid() THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'message', '无权核销此订单'
    );
  END IF;

  -- 执行核销
  UPDATE public.bookings
  SET
    status      = 'completed',
    verified_at = NOW(),
    completed_at = NOW()
  WHERE id = booking_row.id;

  -- 向买家推送系统消息（核销成功通知）
  INSERT INTO public.messages (
    sender_id, receiver_id, booking_id, msg_type, content
  ) VALUES (
    auth.uid(),
    booking_row.customer_id,
    booking_row.id,
    'system',
    format('🎉 服务核销成功！感谢本次使用搭哒，期待下次相遇～ 订单号：%s',
      substring(booking_row.id::TEXT FROM 1 FOR 8))
  );

  RETURN jsonb_build_object(
    'success',     TRUE,
    'message',     '核销成功！服务已完成',
    'booking_id',  booking_row.id,
    'amount',      booking_row.amount,
    'customer_id', booking_row.customer_id
  );
END;
$$;

-- ── 4. 将 verify_booking 开放给认证用户调用 ──
GRANT EXECUTE ON FUNCTION public.verify_booking(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_verification_code(UUID) TO authenticated;
