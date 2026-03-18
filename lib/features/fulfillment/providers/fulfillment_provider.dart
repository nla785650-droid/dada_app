import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/service_execution_model.dart';

// ══════════════════════════════════════════════════════════════
// FulfillmentState：页面级状态容器
// ══════════════════════════════════════════════════════════════

class FulfillmentState {
  const FulfillmentState({
    this.execution,
    this.isLoading = false,
    this.isSubmitting = false,
    this.uploadProgress = 0.0,
    this.error,
    this.pendingPhotoFile,
    this.pendingLocationText,
  });

  final ServiceExecution? execution;
  final bool isLoading;
  final bool isSubmitting;
  final double uploadProgress;
  final String? error;

  // 临时暂存：达人拍照后、用户确认前的照片文件
  final File? pendingPhotoFile;
  final String? pendingLocationText;

  bool get hasData => execution != null;

  FulfillmentState copyWith({
    ServiceExecution? execution,
    bool? isLoading,
    bool? isSubmitting,
    double? uploadProgress,
    String? error,
    File? pendingPhotoFile,
    String? pendingLocationText,
    bool clearPending = false,
    bool clearError = false,
  }) {
    return FulfillmentState(
      execution:           execution ?? this.execution,
      isLoading:           isLoading ?? this.isLoading,
      isSubmitting:        isSubmitting ?? this.isSubmitting,
      uploadProgress:      uploadProgress ?? this.uploadProgress,
      error:               clearError ? null : (error ?? this.error),
      pendingPhotoFile:    clearPending ? null : (pendingPhotoFile ?? this.pendingPhotoFile),
      pendingLocationText: clearPending ? null : (pendingLocationText ?? this.pendingLocationText),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FulfillmentNotifier：履约流程状态管理
// ══════════════════════════════════════════════════════════════

class FulfillmentNotifier extends StateNotifier<FulfillmentState> {
  FulfillmentNotifier() : super(const FulfillmentState());

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  // ────────────────────────────────────────
  // 初始化：加载订单 + 所有节点数据
  // ────────────────────────────────────────

  Future<void> load(String bookingId, {bool isProvider = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. 获取订单详情（含达人和买家信息）
      final bookingData = await _db
          .from('bookings')
          .select('''
            id, status, amount, booking_date, start_time, end_time,
            provider_id, customer_id,
            posts!bookings_post_id_fkey (title, cover_image),
            provider:profiles!bookings_provider_id_fkey (
              display_name, avatar_url
            )
          ''')
          .eq('id', bookingId)
          .single();

      // 2. 获取所有节点打卡记录
      final checkpointsData = await _db
          .from('booking_checkpoints')
          .select()
          .eq('booking_id', bookingId)
          .order('created_at');

      final checkpoints = (checkpointsData as List)
          .map((e) => BookingCheckpoint.fromJson(e))
          .toList();

      // 3. 推断当前节点（已完成的节点中最后一个的下一个）
      final currentNode = _inferCurrentNode(bookingData['status'] as String, checkpoints);

      final providerInfo = bookingData['provider'] as Map<String, dynamic>? ?? {};
      final postInfo = bookingData['posts'] as Map<String, dynamic>? ?? {};

      state = state.copyWith(
        isLoading: false,
        execution: ServiceExecution(
          bookingId:     bookingId,
          currentNode:   currentNode,
          checkpoints:   checkpoints,
          providerName:  providerInfo['display_name'] as String? ?? '达人',
          providerAvatar: providerInfo['avatar_url'] as String? ?? '',
          serviceName:   postInfo['title'] as String? ?? '服务',
          bookingDate:   DateTime.parse(bookingData['booking_date'] as String),
          startTime:     bookingData['start_time'] as String,
          endTime:       bookingData['end_time'] as String,
          amount:        (bookingData['amount'] as num).toDouble(),
          maskedPhone:   '138****8888', // 生产环境由 Edge Function 返回虚拟号
          isProvider:    isProvider,
        ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载失败：$e');
    }
  }

  ServiceNode _inferCurrentNode(String bookingStatus, List<BookingCheckpoint> checkpoints) {
    if (checkpoints.isEmpty) return ServiceNode.aboutToDepart;
    // 已完成节点的最后一个
    final lastCompleted = checkpoints.last.node;
    return lastCompleted.next ?? ServiceNode.finished;
  }

  // ────────────────────────────────────────
  // 达人打卡：非 arrived 节点（无需照片）
  // ────────────────────────────────────────

  Future<void> advanceNode({
    String? locationText,
    double? lat,
    double? lng,
  }) async {
    final exec = state.execution;
    if (exec == null) return;

    final nodeToRecord = exec.currentNode;
    if (nodeToRecord.requiresPhoto) return; // arrived 节点走 submitArrivalPhoto

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _db.from('booking_checkpoints').insert({
        'booking_id':    exec.bookingId,
        'node':          nodeToRecord.value,
        'location_text': locationText,
        'location_lat':  lat,
        'location_lng':  lng,
      });

      // 本地乐观更新
      final newCheckpoint = BookingCheckpoint(
        id:           '',
        bookingId:    exec.bookingId,
        node:         nodeToRecord,
        locationText: locationText,
        locationLat:  lat,
        locationLng:  lng,
        createdAt:    DateTime.now(),
      );
      final updatedCheckpoints = [...exec.checkpoints, newCheckpoint];
      final nextNode = nodeToRecord.next ?? ServiceNode.finished;

      state = state.copyWith(
        isSubmitting: false,
        execution: exec.copyWith(
          currentNode:  nextNode,
          checkpoints:  updatedCheckpoints,
        ),
      );
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: '打卡失败：$e');
    }
  }

  // ────────────────────────────────────────
  // 暂存 arrived 核验照（待用户预览确认）
  // ────────────────────────────────────────

  void setPendingArrivalPhoto(File photo, String locationText) {
    state = state.copyWith(
      pendingPhotoFile:    photo,
      pendingLocationText: locationText,
    );
  }

  void clearPendingPhoto() {
    state = state.copyWith(clearPending: true);
  }

  // ────────────────────────────────────────
  // 提交 arrived 核验照（上传 + 写入 DB）
  // ────────────────────────────────────────

  Future<void> submitArrivalPhoto({
    required double? lat,
    required double? lng,
  }) async {
    final exec = state.execution;
    final photoFile = state.pendingPhotoFile;
    final locationText = state.pendingLocationText ?? '未知位置';
    if (exec == null || photoFile == null) return;

    state = state.copyWith(isSubmitting: true, uploadProgress: 0.0, clearError: true);
    try {
      // 1. 上传照片到 Supabase Storage
      final uid = _uid ?? 'anon';
      final path =
          '$uid/checkpoints/${exec.bookingId}_arrived_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _db.storage.from('realtime-photos').upload(
        path,
        photoFile,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      state = state.copyWith(uploadProgress: 0.7);

      final photoUrl =
          _db.storage.from('realtime-photos').getPublicUrl(path);

      // 2. 写入 checkpoint（is_verified_shot = true 标记此照片为受控拍摄）
      await _db.from('booking_checkpoints').insert({
        'booking_id':       exec.bookingId,
        'node':             ServiceNode.arrived.value,
        'photo_url':        photoUrl,
        'is_verified_shot': true, // ← 核心标记：防照骗、不可逆
        'location_text':    locationText,
        'location_lat':     lat,
        'location_lng':     lng,
      });
      state = state.copyWith(uploadProgress: 1.0);

      // 3. 本地更新
      final newCheckpoint = BookingCheckpoint(
        id: '', bookingId: exec.bookingId,
        node:          ServiceNode.arrived,
        photoUrl:      photoUrl,
        isVerifiedShot: true,
        locationText:  locationText,
        locationLat:   lat,
        locationLng:   lng,
        createdAt:     DateTime.now(),
      );

      state = state.copyWith(
        isSubmitting: false,
        clearPending: true,
        execution: exec.copyWith(
          currentNode: ServiceNode.inProgress,
          checkpoints: [...exec.checkpoints, newCheckpoint],
        ),
      );
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: '上传失败：$e');
    }
  }

  // ────────────────────────────────────────
  // 买家确认到达（触发资金部分释放）
  // ────────────────────────────────────────

  Future<void> confirmArrival(String checkpointId) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _db.from('booking_checkpoints').update({
        'confirmed_by_customer': true,
        'confirmed_at':          DateTime.now().toIso8601String(),
      }).eq('id', checkpointId);

      // 本地更新
      final exec = state.execution!;
      final updatedCheckpoints = exec.checkpoints.map((c) {
        if (c.node == ServiceNode.arrived) {
          return c.copyWith(
            confirmedByCustomer: true,
            confirmedAt: DateTime.now(),
          );
        }
        return c;
      }).toList();

      state = state.copyWith(
        isSubmitting: false,
        execution: exec.copyWith(checkpoints: updatedCheckpoints),
      );
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: '确认失败：$e');
    }
  }

  // ────────────────────────────────────────
  // Realtime 订阅（节点变化实时推送）
  // ────────────────────────────────────────

  RealtimeChannel? _channel;

  void subscribeRealtime(String bookingId) {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('checkpoints_$bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'booking_checkpoints',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: bookingId,
          ),
          callback: (payload) {
            final newCp = BookingCheckpoint.fromJson(payload.newRecord);
            final exec = state.execution;
            if (exec == null) return;
            // 避免本地已有（乐观更新）重复插入
            if (exec.checkpoints.any((c) => c.node == newCp.node)) return;
            final updatedCheckpoints = [...exec.checkpoints, newCp];
            final nextNode = newCp.node.next ?? ServiceNode.finished;
            state = state.copyWith(
              execution: exec.copyWith(
                currentNode: nextNode,
                checkpoints: updatedCheckpoints,
              ),
            );
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

// ── Provider ──
final fulfillmentProvider =
    StateNotifierProvider.autoDispose<FulfillmentNotifier, FulfillmentState>(
  (_) => FulfillmentNotifier(),
);
