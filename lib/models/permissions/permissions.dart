// permission.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Permission {
  final String id;
  final String name;
  final String type;
  final List<String> functions;
  final DateTime createdAt;

  Permission({
    required this.id,
    required this.name,
    required this.type,
    required this.functions,
    required this.createdAt,
  });

  factory Permission.fromMap(Map<String, dynamic> map, String id) {
    return Permission(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      functions: List<String>.from(map['functions'] ?? []),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'functions': functions,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Permission copyWith({
    String? name,
    String? type,
    List<String>? functions,
    DateTime? createdAt,
  }) {
    return Permission(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      functions: functions ?? this.functions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}