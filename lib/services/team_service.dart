import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vevij/models/tasks/team_model.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<TeamModel>> getTeamsList() async {
  try {
    final querySnapshot = await _firestore
        .collection('teams')
        .orderBy('teamName')
        .get();
    
    return querySnapshot.docs
        .map((doc) => TeamModel.fromMap(doc.data()))
        .toList();
  } catch (e) {
    print('Error getting teams list: $e');
    throw Exception('Failed to load teams: $e');
  }
}
  // Stream all teams
  Stream<List<TeamModel>> streamAllTeams() {
    return _firestore
        .collection('teams')
        .orderBy('teamName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamModel.fromMap(doc.data()))
            .toList());
  }

  // Create new team
  Future<void> createTeam(TeamModel team) async {
    try {
      await _firestore.collection('teams').doc(team.id).set(team.toMap());
    } catch (e) {
      throw Exception('Failed to create team: $e');
    }
  }

  // Update existing team
  Future<void> updateTeam(String teamId, TeamModel team) async {
    try {
      await _firestore.collection('teams').doc(teamId).update(team.toMap());
    } catch (e) {
      throw Exception('Failed to update team: $e');
    }
  }

  // Delete team
  Future<void> deleteTeam(String teamId) async {
    try {
      await _firestore.collection('teams').doc(teamId).delete();
    } catch (e) {
      throw Exception('Failed to delete team: $e');
    }
  }

  // Add member to team
  Future<void> addTeamMember(String teamId, String userId) async {
    try {
      await _firestore.collection('teams').doc(teamId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to add team member: $e');
    }
  }

  // Remove member from team
  Future<void> removeTeamMember(String teamId, String userId) async {
    try {
      await _firestore.collection('teams').doc(teamId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to remove team member: $e');
    }
  }

  // Get team by ID
  Future<TeamModel?> getTeam(String teamId) async {
    try {
      final doc = await _firestore.collection('teams').doc(teamId).get();
      if (doc.exists) {
        return TeamModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get team: $e');
    }
  }

  // Add member with full TeamMember object
  Future<void> addTeamMemberWithDetails(String teamId, TeamMember member) async {
    try {
      final teamRef = _firestore.collection('teams').doc(teamId);
      
      await _firestore.runTransaction((transaction) async {
        final teamDoc = await transaction.get(teamRef);
        if (teamDoc.exists) {
          final team = TeamModel.fromMap(teamDoc.data()!);
          final updatedMembers = List<TeamMember>.from(team.members)..add(member);
          final updatedMemberIds = List<String>.from(team.memberIds)..add(member.userId);
          
          transaction.update(teamRef, {
            'members': updatedMembers.map((m) => m.toMap()).toList(),
            'memberIds': updatedMemberIds,
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to add team member with details: $e');
    }
  }

  // Remove member with full TeamMember object
  Future<void> removeTeamMemberWithDetails(String teamId, String userId) async {
    try {
      final teamRef = _firestore.collection('teams').doc(teamId);
      
      await _firestore.runTransaction((transaction) async {
        final teamDoc = await transaction.get(teamRef);
        if (teamDoc.exists) {
          final team = TeamModel.fromMap(teamDoc.data()!);
          final updatedMembers = team.members.where((m) => m.userId != userId).toList();
          final updatedMemberIds = team.memberIds.where((id) => id != userId).toList();
          
          transaction.update(teamRef, {
            'members': updatedMembers.map((m) => m.toMap()).toList(),
            'memberIds': updatedMemberIds,
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to remove team member with details: $e');
    }
  }

  // Update member role
  Future<void> updateMemberRole(String teamId, String userId, String newRole) async {
    try {
      final teamRef = _firestore.collection('teams').doc(teamId);
      
      await _firestore.runTransaction((transaction) async {
        final teamDoc = await transaction.get(teamRef);
        if (teamDoc.exists) {
          final team = TeamModel.fromMap(teamDoc.data()!);
          final updatedMembers = team.members.map((member) {
            if (member.userId == userId) {
              return TeamMember(
                userId: member.userId,
                addedBy: member.addedBy,
                role: newRole,
                joinedAt: member.joinedAt,
              );
            }
            return member;
          }).toList();
          
          transaction.update(teamRef, {
            'members': updatedMembers.map((m) => m.toMap()).toList(),
            'updatedAt': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to update member role: $e');
    }
  }

  // Check if team name exists
  Future<bool> doesTeamNameExist(String teamName) async {
    try {
      final snapshot = await _firestore
          .collection('teams')
          .where('teamName', isEqualTo: teamName)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check team name: $e');
    }
  }

  // Get teams by member ID
  Stream<List<TeamModel>> getTeamsByMember(String userId) {
    return _firestore
        .collection('teams')
        .where('memberIds', arrayContains: userId)
        .orderBy('teamName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeamModel.fromMap(doc.data()))
            .toList());
  }

  // Get team members count
  Future<int> getTeamMembersCount(String teamId) async {
    try {
      final doc = await _firestore.collection('teams').doc(teamId).get();
      if (doc.exists) {
        final team = TeamModel.fromMap(doc.data()!);
        return team.members.length;
      }
      return 0;
    } catch (e) {
      throw Exception('Failed to get team members count: $e');
    }
  }
}