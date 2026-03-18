import 'package:flutter/foundation.dart';

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.postId,
    required this.customerId,
    required this.providerId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.amount,
    this.paymentMethod = 'mock',
    this.paymentStatus = 'unpaid',
    this.paidAt,
    this.customerNote,
    this.cancelReason,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String customerId;
  final String providerId;
  final DateTime bookingDate;
  final String startTime; // HH:MM
  final String endTime;   // HH:MM
  final String status;    // pending|confirmed|in_progress|completed|cancelled
  final double amount;
  final String paymentMethod;
  final String paymentStatus; // unpaid|paid|refunded
  final DateTime? paidAt;
  final String? customerNote;
  final String? cancelReason;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isPaid => paymentStatus == 'paid';

  String get statusLabel {
    return switch (status) {
      'pending' => '待确认',
      'confirmed' => '已确认',
      'in_progress' => '进行中',
      'completed' => '已完成',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      customerId: json['customer_id'] as String,
      providerId: json['provider_id'] as String,
      bookingDate: DateTime.parse(json['booking_date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      status: json['status'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ?? 'mock',
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      customerNote: json['customer_note'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'customer_id': customerId,
      'provider_id': providerId,
      'booking_date': bookingDate.toIso8601String().split('T').first,
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'paid_at': paidAt?.toIso8601String(),
      'customer_note': customerNote,
      'cancel_reason': cancelReason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Booking copyWith({String? status, String? paymentStatus, DateTime? paidAt}) {
    return Booking(
      id: id,
      postId: postId,
      customerId: customerId,
      providerId: providerId,
      bookingDate: bookingDate,
      startTime: startTime,
      endTime: endTime,
      status: status ?? this.status,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
      customerNote: customerNote,
      cancelReason: cancelReason,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Booking && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
