import 'package:flutter/foundation.dart';

@immutable
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.bookingId,
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String? bookingId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  bool isSentBy(String userId) => senderId == userId;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      bookingId: json['booking_id'] as String?,
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'booking_id': bookingId,
      'content': content,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Message && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
