import 'package:vevij/components/imports.dart';

class NotificationModel {
  final bool isRead;
  final String message;
  final DateTime timestamp;
  final String title;
  final String type;
  final String userId;

  NotificationModel({
    required this.isRead,
    required this.message,
    required this.timestamp,
    required this.title,
    required this.type,
    required this.userId,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      isRead: map['isRead'] ?? false,
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isRead': isRead,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'title': title,
      'type': type,
      'userId': userId,
    };
  }

  NotificationModel copyWith({
    bool? isRead,
    String? message,
    DateTime? timestamp,
    String? title,
    String? type,
    String? userId,
  }) {
    return NotificationModel(
      isRead: isRead ?? this.isRead,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      type: type ?? this.type,
      userId: userId ?? this.userId,
    );
  }

  @override
  String toString() {
    return 'NotificationModel(title: $title, message: $message, isRead: $isRead, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is NotificationModel &&
        other.isRead == isRead &&
        other.message == message &&
        other.timestamp == timestamp &&
        other.title == title &&
        other.type == type &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return isRead.hashCode ^
        message.hashCode ^
        timestamp.hashCode ^
        title.hashCode ^
        type.hashCode ^
        userId.hashCode;
  }
}