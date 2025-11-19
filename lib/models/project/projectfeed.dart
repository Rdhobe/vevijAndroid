import 'package:vevij/components/imports.dart';

class Feed {
  final String description;
  final String taskId;
  final DateTime timestamp;
  final String title;
  final String type;

  Feed({
    required this.description,
    required this.taskId,
    required this.timestamp,
    required this.title,
    required this.type,
  });

  factory Feed.fromMap(Map<String, dynamic> map) {
    return Feed(
      description: map['description'] ?? '',
      taskId: map['taskId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      title: map['title'] ?? '',
      type: map['type'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'taskId': taskId,
      'timestamp': Timestamp.fromDate(timestamp),
      'title': title,
      'type': type,
    };
  }

  Feed copyWith({
    String? description,
    String? taskId,
    DateTime? timestamp,
    String? title,
    String? type,
  }) {
    return Feed(
      description: description ?? this.description,
      taskId: taskId ?? this.taskId,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'Feed(title: $title, description: $description, type: $type, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Feed &&
        other.description == description &&
        other.taskId == taskId &&
        other.timestamp == timestamp &&
        other.title == title &&
        other.type == type;
  }

  @override
  int get hashCode {
    return description.hashCode ^
        taskId.hashCode ^
        timestamp.hashCode ^
        title.hashCode ^
        type.hashCode;
  }
}