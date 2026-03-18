import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// 服务节点枚举：对应数据库 booking_checkpoints.node 字段
// 顺序严格有序，前端状态机依此流转
// ══════════════════════════════════════════════════════════════

enum ServiceNode {
  aboutToDepart('about_to_depart', '待出发', '🚌', '等待达人出发'),
  departed('departed', '已出发', '🚗', '达人正在赶来'),
  arrived('arrived', '已到达', '📍', '达人已到达，请核验'),
  inProgress('in_progress', '服务中', '✨', '服务正在进行'),
  finished('finished', '已结束', '🎉', '服务已完成');

  const ServiceNode(this.value, this.label, this.emoji, this.description);

  final String value;
  final String label;
  final String emoji;
  final String description;

  static ServiceNode fromValue(String v) =>
      ServiceNode.values.firstWhere((e) => e.value == v,
          orElse: () => ServiceNode.aboutToDepart);

  // 下一个节点（状态机单向流转）
  ServiceNode? get next {
    final idx = ServiceNode.values.indexOf(this);
    if (idx >= ServiceNode.values.length - 1) return null;
    return ServiceNode.values[idx + 1];
  }

  bool get isFirst => this == ServiceNode.aboutToDepart;
  bool get isLast => this == ServiceNode.finished;

  // 达人视角的操作按钮文字
  String get actionLabel => switch (this) {
        ServiceNode.aboutToDepart => '开始出发',
        ServiceNode.departed      => '已到达打卡',
        ServiceNode.arrived       => '开始服务',
        ServiceNode.inProgress    => '结束服务',
        ServiceNode.finished      => '服务已完成',
      };

  // 此节点是否需要拍摄核验照（数据库 is_verified_shot = true）
  bool get requiresPhoto => this == ServiceNode.arrived;

  // 此节点是否需要买家确认
  bool get requiresCustomerConfirm => this == ServiceNode.arrived;

  Color get color => switch (this) {
        ServiceNode.aboutToDepart => const Color(0xFF9B59B6),
        ServiceNode.departed      => const Color(0xFF3498DB),
        ServiceNode.arrived       => const Color(0xFFF39C12),
        ServiceNode.inProgress    => const Color(0xFF27AE60),
        ServiceNode.finished      => const Color(0xFF2ECC71),
      };
}

// ══════════════════════════════════════════════════════════════
// BookingCheckpoint：单个节点数据
// ══════════════════════════════════════════════════════════════

class BookingCheckpoint {
  const BookingCheckpoint({
    required this.id,
    required this.bookingId,
    required this.node,
    this.photoUrl,
    this.isVerifiedShot = false,
    this.locationText,
    this.locationLat,
    this.locationLng,
    this.confirmedByCustomer = false,
    this.confirmedAt,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final ServiceNode node;
  final String? photoUrl;
  final bool isVerifiedShot;
  final String? locationText;
  final double? locationLat;
  final double? locationLng;
  final bool confirmedByCustomer;
  final DateTime? confirmedAt;
  final String? note;
  final DateTime createdAt;

  factory BookingCheckpoint.fromJson(Map<String, dynamic> json) {
    return BookingCheckpoint(
      id:                   json['id'] as String,
      bookingId:            json['booking_id'] as String,
      node:                 ServiceNode.fromValue(json['node'] as String),
      photoUrl:             json['photo_url'] as String?,
      isVerifiedShot:       (json['is_verified_shot'] as bool?) ?? false,
      locationText:         json['location_text'] as String?,
      locationLat:          (json['location_lat'] as num?)?.toDouble(),
      locationLng:          (json['location_lng'] as num?)?.toDouble(),
      confirmedByCustomer:  (json['confirmed_by_customer'] as bool?) ?? false,
      confirmedAt:          json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      note:                 json['note'] as String?,
      createdAt:            DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'booking_id':            bookingId,
        'node':                  node.value,
        'photo_url':             photoUrl,
        'is_verified_shot':      isVerifiedShot,
        'location_text':         locationText,
        'location_lat':          locationLat,
        'location_lng':          locationLng,
        'confirmed_by_customer': confirmedByCustomer,
        'note':                  note,
      };

  BookingCheckpoint copyWith({bool? confirmedByCustomer, DateTime? confirmedAt}) {
    return BookingCheckpoint(
      id: id, bookingId: bookingId, node: node,
      photoUrl: photoUrl, isVerifiedShot: isVerifiedShot,
      locationText: locationText, locationLat: locationLat, locationLng: locationLng,
      confirmedByCustomer: confirmedByCustomer ?? this.confirmedByCustomer,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      note: note, createdAt: createdAt,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ServiceExecution：整合订单 + 所有节点的聚合状态
// ══════════════════════════════════════════════════════════════

class ServiceExecution {
  const ServiceExecution({
    required this.bookingId,
    required this.currentNode,
    required this.checkpoints,
    required this.providerName,
    required this.providerAvatar,
    required this.serviceName,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.amount,
    this.maskedPhone,
    this.isProvider = false,
  });

  final String bookingId;
  final ServiceNode currentNode;
  final List<BookingCheckpoint> checkpoints;
  final String providerName;
  final String providerAvatar;
  final String serviceName;
  final DateTime bookingDate;
  final String startTime;
  final String endTime;
  final double amount;
  final String? maskedPhone;
  final bool isProvider; // true=达人视角, false=买家视角

  // 根据节点值查找对应的 checkpoint（可能为空，表示未到达此节点）
  BookingCheckpoint? checkpointFor(ServiceNode node) {
    try {
      return checkpoints.firstWhere((c) => c.node == node);
    } catch (_) {
      return null;
    }
  }

  // 节点完成状态：有对应 checkpoint 则认为已完成
  bool isNodeCompleted(ServiceNode node) {
    return checkpoints.any((c) => c.node == node);
  }

  // 到达核验是否已被买家确认
  bool get arrivalConfirmed {
    final cp = checkpointFor(ServiceNode.arrived);
    return cp?.confirmedByCustomer ?? false;
  }

  ServiceExecution copyWith({ServiceNode? currentNode, List<BookingCheckpoint>? checkpoints}) {
    return ServiceExecution(
      bookingId: bookingId,
      currentNode: currentNode ?? this.currentNode,
      checkpoints: checkpoints ?? this.checkpoints,
      providerName: providerName, providerAvatar: providerAvatar,
      serviceName: serviceName, bookingDate: bookingDate,
      startTime: startTime, endTime: endTime, amount: amount,
      maskedPhone: maskedPhone, isProvider: isProvider,
    );
  }
}
