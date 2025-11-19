import 'package:vevij/components/imports.dart';

class ProjectGroup {
  final DateTime createdAt;
  final String createdBy;
  final String description;
  final String name;

  ProjectGroup({
    required this.createdAt,
    required this.createdBy,
    required this.description,
    required this.name,
  });

  factory ProjectGroup.fromMap(Map<String, dynamic> map) {
    return ProjectGroup(
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
      description: map['description'] ?? '',
      name: map['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'description': description,
      'name': name,
    };
  }

  ProjectGroup copyWith({
    DateTime? createdAt,
    String? createdBy,
    String? description,
    String? name,
  }) {
    return ProjectGroup(
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      description: description ?? this.description,
      name: name ?? this.name,
    );
  }

  @override
  String toString() {
    return 'ProjectGroup(name: $name, description: $description, createdBy: $createdBy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is ProjectGroup &&
        other.createdAt == createdAt &&
        other.createdBy == createdBy &&
        other.description == description &&
        other.name == name;
  }

  @override
  int get hashCode {
    return createdAt.hashCode ^
        createdBy.hashCode ^
        description.hashCode ^
        name.hashCode;
  }
}