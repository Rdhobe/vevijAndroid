import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent,
  critical
}

enum TaskCategory {
  general,
  development,
  design,
  marketing,
  sales,
  support,
  documentation,
  testing,
  research,
  maintenance,
  urgent,
  feature,
  bug,
  improvement,
}
class TaskModel {
  final String id;
  final String title;
  final String description;
  final String assignedTeamId;
  final List<String> assignedTo; // Performers
  final List<String> monitors;   // Monitors
  final String createdBy;
  final TaskStatus status;
  final TaskPriority priority;
  final TaskCategory category; // Added category field
  final DateTime dueDate;
  final DateTime? revisedDueDate;
  final double estimatedHours; // Added estimated hours field
  final double? actualHours; // Added actual hours field
  final List<String> attachments;
  final List<String> watchers;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTeamId,
    required this.assignedTo,
    required this.monitors,
    required this.createdBy,
    required this.status,
    required this.priority,
    required this.category, // Added to constructor
    required this.dueDate,
    this.revisedDueDate,
    this.estimatedHours = 0.0, // Default value
    this.actualHours, // Optional field
    this.attachments = const [],
    this.watchers = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assignedTeamId': assignedTeamId,
      'assignedTo': assignedTo,
      'monitors': monitors,
      'createdBy': createdBy,
      'status': status.name,
      'priority': priority.name,
      'category': category.name, // Added to map
      'dueDate': Timestamp.fromDate(dueDate),
      'revisedDueDate': revisedDueDate != null ? Timestamp.fromDate(revisedDueDate!) : null,
      'estimatedHours': estimatedHours, // Added to map
      'actualHours': actualHours, // Added to map
      'attachments': attachments,
      'watchers': watchers,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      assignedTeamId: map['assignedTeamId'] ?? '',
      assignedTo: _toStringList(map['assignedTo']),
      monitors: _toStringList(map['monitors']),
      createdBy: map['createdBy'] ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TaskStatus.pending,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      category: TaskCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => TaskCategory.general,
      ),
      dueDate: _toDateTime(map['dueDate'], fallback: DateTime.now()),
      revisedDueDate: map['revisedDueDate'] != null 
          ? _toDateTime(map['revisedDueDate'])
          : null,
      estimatedHours: (map['estimatedHours'] ?? 0.0).toDouble(), // Parse estimated hours
      actualHours: map['actualHours'] != null ? (map['actualHours'] as num).toDouble() : null, // Parse actual hours
      attachments: _toStringList(map['attachments']),
      watchers: _toStringList(map['watchers']),
      createdAt: _toDateTime(map['createdAt'], fallback: DateTime.now()),
      updatedAt: _toDateTime(map['updatedAt'], fallback: DateTime.now()),
    );
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTeamId,
    List<String>? assignedTo,
    List<String>? monitors,
    String? createdBy,
    TaskStatus? status,
    TaskPriority? priority,
    TaskCategory? category,
    DateTime? dueDate,
    DateTime? revisedDueDate,
    double? estimatedHours,
    double? actualHours,
    List<String>? attachments,
    List<String>? watchers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTeamId: assignedTeamId ?? this.assignedTeamId,
      assignedTo: assignedTo ?? this.assignedTo,
      monitors: monitors ?? this.monitors,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      revisedDueDate: revisedDueDate ?? this.revisedDueDate,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      attachments: attachments ?? this.attachments,
      watchers: watchers ?? this.watchers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


// Helper to safely convert a dynamic value coming from Firestore into List<String>.
// Firestore sometimes stores single values as a String instead of a list; calling
// `List.from` on a String throws `type 'String' is not a subtype of type 'Iterable'`.
List<String> _toStringList(dynamic value) {
  if (value == null) return <String>[];
  if (value is List) {
    // Ensure all entries are strings
    return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
  if (value is String) {
    return [value];
  }
  // If it's some other iterable (e.g., Iterable<dynamic>), try to convert
  if (value is Iterable) {
    return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
  return <String>[];
}

// Helper to safely convert Firestore timestamp-like values into DateTime.
DateTime _toDateTime(dynamic value, {DateTime? fallback}) {
  final fb = fallback ?? DateTime.now();
  if (value == null) return fb;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    // Try ISO-8601 parse, otherwise try int parse
    try {
      return DateTime.parse(value);
    } catch (_) {
      final asInt = int.tryParse(value);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
  }
  if (value is Map && value.containsKey('_seconds')) {
    // Firestore sometimes returns map with _seconds and _nanoseconds
    final seconds = value['_seconds'];
    final nanos = value['_nanoseconds'] ?? 0;
    if (seconds is int || seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000 + (nanos ~/ 1000000));
    }
  }
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return fb;
}