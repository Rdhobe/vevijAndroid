import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamRole {
  none,     // No access to team
  member,   // Can view assigned tasks, update status, comment
  monitor,  // Can view all tasks, comment, monitor progress
  manager,  // Can create/edit tasks, assign members, view reports
  admin,    // Full team management (within team)
  hr        // Global HR - access to all teams
}

class UserTeamRole {
  final String teamId;
  final String teamName;
  final TeamRole role;
  final DateTime joinedAt;

  UserTeamRole({
    required this.teamId,
    required this.teamName,
    required this.role,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'role': role.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory UserTeamRole.fromMap(Map<String, dynamic> map) {
    return UserTeamRole(
      teamId: map['teamId'] ?? '',
      teamName: map['teamName'] ?? '',
      role: TeamRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => TeamRole.none,
      ),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
    );
  }
}