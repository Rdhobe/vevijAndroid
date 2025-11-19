import 'package:cloud_firestore/cloud_firestore.dart';

class TeamMember {
  final String userId;
  final String addedBy;
  final String role;
  final DateTime joinedAt;

  TeamMember({
    required this.userId,
    required this.addedBy,
    required this.role,
    required this.joinedAt,
  });

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      userId: map['userId'] ?? '',
      addedBy: map['addedBy'] ?? '',
      role: map['role'] ?? '',
      joinedAt: (map['joinedAt'] is Timestamp)
          ? (map['joinedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'addedBy': addedBy,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}

class TeamModel {
  final String id;
  final String name; // maps to teamName in Firestore
  final String description;
  final String createdBy;
  final List<String> memberIds; // from `memberIds` array
  final List<TeamMember> members; // from `members` array (maps)
  final DateTime createdAt;
  final DateTime updatedAt;

  TeamModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.memberIds,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 🔹 Convert Firestore map → TeamModel
  factory TeamModel.fromMap(Map<String, dynamic> map) {
    return TeamModel(
      id: map['teamId'] ?? '',
      name: map['teamName'] ?? '', // Firestore field: teamName
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      members: (map['members'] as List<dynamic>? ?? [])
          .map((m) => TeamMember.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (map['updatedAt'] is Timestamp)
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// 🔹 Convert TeamModel → Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teamName': name,
      'description': description,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'members': members.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
