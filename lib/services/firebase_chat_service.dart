import 'package:vevij/components/imports.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ================== PERSONAL CHAT METHODS ==================

  // Send chat request
  Future<bool> sendChatRequest(String receiverId) async {
    try {
      if (currentUserId == null) return false;

      // Check if request already exists
      var existingRequest = await _firestore
          .collection('chat_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('Request already sent');
      }

      // Check if chat already exists
      var existingChat = await _firestore
          .collection('personal_chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in existingChat.docs) {
        var participants = List<String>.from(doc['participants']);
        if (participants.contains(receiverId)) {
          throw Exception('Chat already exists');
        }
      }

      await _firestore.collection('chat_requests').add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending chat request: $e');
      return false;
    }
  }

  // Accept chat request
  Future<bool> acceptChatRequest(String requestId, String senderId) async {
    try {
      if (currentUserId == null) return false;

      // Create personal chat
      var chatRef = await _firestore.collection('personal_chats').add({
        'participants': [currentUserId, senderId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Update request status
      await _firestore.collection('chat_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'chatId': chatRef.id,
      });

      return true;
    } catch (e) {
      print('Error accepting chat request: $e');
      return false;
    }
  }

  // Reject chat request
  Future<bool> rejectChatRequest(String requestId) async {
    try {
      await _firestore.collection('chat_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error rejecting chat request: $e');
      return false;
    }
  }

  // Send personal message
  Future<bool> sendPersonalMessage(String chatId, String message, String otherUserId) async {
    try {
      if (currentUserId == null || message.trim().isEmpty) return false;

      // Add message to chat
      await _firestore
          .collection('personal_chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': message.trim(),
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update last message and increment unread count for other user
      await _firestore.collection('personal_chats').doc(chatId).update({
        'lastMessage': message.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount_$otherUserId': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Error sending personal message: $e');
      return false;
    }
  }

  // Mark personal messages as read
  Future<void> markPersonalMessagesAsRead(String chatId) async {
    try {
      if (currentUserId == null) return;

      await _firestore.collection('personal_chats').doc(chatId).update({
        'unreadCount_$currentUserId': 0,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get personal chats stream
  Stream<QuerySnapshot> getPersonalChatsStream() {
    if (currentUserId == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('personal_chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // Get personal messages stream
  Stream<QuerySnapshot> getPersonalMessagesStream(String chatId) {
    return _firestore
        .collection('personal_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get chat requests stream
  Stream<QuerySnapshot> getChatRequestsStream() {
    if (currentUserId == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('chat_requests')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // ================== PROJECT CHAT METHODS ==================

  // Send project message
  Future<bool> sendProjectMessage(String projectId, String message, String projectName) async {
    try {
      if (currentUserId == null || message.trim().isEmpty) return false;

      // Get current user data
      var userDoc = await _firestore.collection('users').doc(currentUserId).get();
      var userData = userDoc.data();
      var senderName = userData?['name'] ?? 'Unknown User';

      // Add message to project chat
      await _firestore
          .collection('project_chats')
          .doc(projectId)
          .collection('messages')
          .add({
        'text': message.trim(),
        'senderId': currentUserId,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get all team members to update unread counts
      var projectDoc = await _firestore.collection('projects').doc(projectId).get();
      if (projectDoc.exists) {
        var projectData = projectDoc.data() as Map<String, dynamic>;
        
        // Get all team member user IDs (you'll need to implement proper user ID lookup)
        List<String> teamMemberIds = await _getTeamMemberIds(projectData['members']);
        
        Map<String, dynamic> updateData = {
          'projectId': projectId,
          'projectName': projectName,
          'lastMessage': message.trim(),
          'lastMessageTime': FieldValue.serverTimestamp(),
        };

        // Increment unread count for all team members except sender
        for (String memberId in teamMemberIds) {
          if (memberId != currentUserId) {
            updateData['unreadCount_$memberId'] = FieldValue.increment(1);
          }
        }

        await _firestore.collection('project_chats').doc(projectId).set(updateData, SetOptions(merge: true));
      }

      return true;
    } catch (e) {
      print('Error sending project message: $e');
      return false;
    }
  }

  // Mark project messages as read
  Future<void> markProjectMessagesAsRead(String projectId) async {
    try {
      if (currentUserId == null) return;

      await _firestore.collection('project_chats').doc(projectId).update({
        'unreadCount_$currentUserId': 0,
      });
    } catch (e) {
      print('Error marking project messages as read: $e');
    }
  }

  // Helper method to get team member user IDs from names
  Future<List<String>> _getTeamMemberIds(Map<String, dynamic>? members) async {
    List<String> memberIds = [];
    
    if (members == null) return memberIds;

    try {
      // Get all users to match names with IDs
      var usersSnapshot = await _firestore.collection('users').get();
      Map<String, String> nameToIdMap = {};
      
      for (var doc in usersSnapshot.docs) {
        var userData = doc.data();
        if (userData['name'] != null) {
          nameToIdMap[userData['name'].toString().toLowerCase()] = doc.id;
        }
      }

      // Add manager ID
      if (members['manager'] != null) {
        String? managerId = nameToIdMap[members['manager'].toString().toLowerCase()];
        if (managerId != null) memberIds.add(managerId);
      }

      // Add designers IDs
      if (members['designers'] != null) {
        List<dynamic> designers = members['designers'];
        for (var designer in designers) {
          String? designerId = nameToIdMap[designer.toString().toLowerCase()];
          if (designerId != null) memberIds.add(designerId);
        }
      }

      // Add supervisors IDs
      if (members['supervisors'] != null) {
        List<dynamic> supervisors = members['supervisors'];
        for (var supervisor in supervisors) {
          String? supervisorId = nameToIdMap[supervisor.toString().toLowerCase()];
          if (supervisorId != null) memberIds.add(supervisorId);
        }
      }

    } catch (e) {
      print('Error getting team member IDs: $e');
    }

    return memberIds;
  }

  // Get project messages stream
  Stream<QuerySnapshot> getProjectMessagesStream(String projectId) {
    return _firestore
        .collection('project_chats')
        .doc(projectId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get projects stream
  Stream<QuerySnapshot> getProjectsStream() {
    return _firestore.collection('projects').snapshots();
  }

  // ================== USER METHODS ==================

  // Get users stream
  Stream<QuerySnapshot> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      var doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // ================== UTILITY METHODS ==================

  // Format timestamp for display
  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    var dateTime = timestamp.toDate();
    var now = DateTime.now();
    var difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Format message time
  String formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    var dateTime = timestamp.toDate();
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Check if user is in project team
  Future<bool> isUserInProject(String projectId, String userId) async {
    try {
      var projectDoc = await _firestore.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return false;

      var projectData = projectDoc.data() as Map<String, dynamic>;
      var members = projectData['members'] as Map<String, dynamic>?;
      
      if (members == null) return false;

      // Check manager
      if (members['manager'] == userId) return true;

      // Check designers
      var designers = members['designers'] as List<dynamic>?;
      if (designers != null && designers.contains(userId)) return true;

      // Check supervisors
      var supervisors = members['supervisors'] as List<dynamic>?;
      if (supervisors != null && supervisors.contains(userId)) return true;

      return false;
    } catch (e) {
      print('Error checking user in project: $e');
      return false;
    }
  }

  // Get project team members
  Future<List<Map<String, dynamic>>> getProjectTeamMembers(String projectId) async {
    try {
      var projectDoc = await _firestore.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return [];

      var projectData = projectDoc.data() as Map<String, dynamic>;
      var members = projectData['members'] as Map<String, dynamic>?;
      
      if (members == null) return [];

      List<Map<String, dynamic>> teamMembers = [];

      // Add manager
      if (members['manager'] != null) {
        teamMembers.add({
          'name': members['manager'],
          'role': 'Manager'
        });
      }

      // Add designers
      var designers = members['designers'] as List<dynamic>?;
      if (designers != null) {
        for (var designer in designers) {
          teamMembers.add({
            'name': designer,
            'role': 'Designer'
          });
        }
      }

      // Add supervisors
      var supervisors = members['supervisors'] as List<dynamic>?;
      if (supervisors != null) {
        for (var supervisor in supervisors) {
          teamMembers.add({
            'name': supervisor,
            'role': 'Supervisor'
          });
        }
      }

      return teamMembers;
    } catch (e) {
      print('Error getting project team members: $e');
      return [];
    }
  }

  // Delete personal chat
  Future<bool> deletePersonalChat(String chatId) async {
    try {
      if (currentUserId == null) return false;

      // Delete all messages first
      var messagesSnapshot = await _firestore
          .collection('personal_chats')
          .doc(chatId)
          .collection('messages')
          .get();

      WriteBatch batch = _firestore.batch();
      
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document
      batch.delete(_firestore.collection('personal_chats').doc(chatId));
      
      await batch.commit();
      return true;
    } catch (e) {
      print('Error deleting personal chat: $e');
      return false;
    }
  }

  // Search users by name or role
  Future<List<DocumentSnapshot>> searchUsers(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      var snapshot = await _firestore
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('name', isLessThanOrEqualTo: query.toLowerCase() + '\uf8ff')
          .get();

      return snapshot.docs;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
}