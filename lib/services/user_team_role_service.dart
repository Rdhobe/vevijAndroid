import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vevij/models/tasks/team_model.dart';
import 'package:vevij/models/employee/employee.dart';
import 'package:vevij/models/tasks/user_team_role_model.dart';

class UserTeamRoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<TeamRole> getUserRoleInTeam(String teamId, String userId) async {
    try {
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) {
        throw Exception('Team not found');
      }

      final team = TeamModel.fromMap(teamDoc.data()!);
      final member = team.members.firstWhere(
        (m) => m.userId == userId,
        orElse: () => TeamMember(
          userId: '',
          addedBy: '',
          role: 'none',
          joinedAt: DateTime.now(),
        ),
      );

      if (member.role == 'none') {
        return TeamRole.none;
      }

      switch (member.role.toLowerCase()) {
        case 'admin':
          return TeamRole.admin;
        case 'manager':
          return TeamRole.manager;
        case 'monitor':
          return TeamRole.monitor;
        case 'member':
          return TeamRole.member;
        default:
          return TeamRole.member;
      }
    } catch (e) {
      print('Error getting user role in team: $e');
      throw Exception('Failed to determine user role: $e');
    }
  }

  Future<bool> _isGlobalHr(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final user = Employee.fromMap(userDoc.data()!);
      // Assuming 'designation' field indicates HR or superadmin status

      return user.designation.toLowerCase().contains('hr') ||
          user.designation.toLowerCase().contains('superadmin');
    } catch (e) {
      print('Error checking HR status: $e');
      return false;
    }
  }

  // Public method to check if user is SuperAdmin or HR
  Future<bool> isUserSuperAdminOrHr(String userId) async {
    return _isGlobalHr(userId);
  }

  // Get all teams for SuperAdmin/HR users
  Stream<List<UserTeamRole>> getAllTeams() {
    return _firestore.collection('teams').snapshots().map((snapshot) {
      final teams = <UserTeamRole>[];
      for (final doc in snapshot.docs) {
        final team = TeamModel.fromMap(doc.data());
        teams.add(
          UserTeamRole(
            teamId: doc.id,
            teamName: team.name,
            role: TeamRole.hr,
            joinedAt: team.createdAt,
          ),
        );
      }
      // Sort by team name
      teams.sort((a, b) => a.teamName.compareTo(b.teamName));
      return teams;
    });
  }

  Stream<List<UserTeamRole>> getUserTeams(String userId) {
    return _firestore.collection('teams').snapshots().asyncMap((
      snapshot,
    ) async {
      final teams = <UserTeamRole>[];
      final isHr = await _isGlobalHr(userId);

      for (final doc in snapshot.docs) {
        final team = TeamModel.fromMap(doc.data());

        // Check if user is a member of this team
        final member = team.members.firstWhere(
          (m) => m.userId == userId,
          orElse: () => TeamMember(
            userId: '',
            addedBy: '',
            role: 'none',
            joinedAt: DateTime.now(),
          ),
        );

        if (isHr) {
          // HR can see all teams, but should show their actual role if they're a member
          if (member.role != 'none') {
            // HR user is also a team member, get their actual team role
            final role = await getUserRoleInTeam(doc.id, userId);
            teams.add(
              UserTeamRole(
                teamId: doc.id,
                teamName: team.name,
                role: role,
                joinedAt: member.joinedAt,
              ),
            );
          } else {
            // HR user is not a member, show as HR role
            teams.add(
              UserTeamRole(
                teamId: doc.id,
                teamName: team.name,
                role: TeamRole.hr,
                joinedAt: team.createdAt,
              ),
            );
          }
        } else {
          // Regular users see only teams they're members of
          if (member.role != 'none') {
            final role = await getUserRoleInTeam(doc.id, userId);
            teams.add(
              UserTeamRole(
                teamId: doc.id,
                teamName: team.name,
                role: role,
                joinedAt: member.joinedAt,
              ),
            );
          }
        }
      }

      // Sort by team name
      teams.sort((a, b) => a.teamName.compareTo(b.teamName));
      return teams;
    });
  }

  Future<bool> canUserCreateTeam(String userId) async {
    try {
      return await _isGlobalHr(userId);
    } catch (e) {
      print('Error checking team creation permission: $e');
      return false;
    }
  }

  Future<bool> canUserAccessTeam(String teamId, String userId) async {
    try {
      final role = await getUserRoleInTeam(teamId, userId);
      return role != TeamRole.none;
    } catch (e) {
      print('Error checking team access: $e');
      return false;
    }
  }
}
