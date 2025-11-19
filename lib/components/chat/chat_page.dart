import 'package:vevij/components/imports.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({ super.key});
  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _personalUnreadCount = 0;
  int _projectUnreadCount = 0;
  int _requestsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToUnreadCounts();
  }

  void _listenToUnreadCounts() {
    // Listen to personal chat requests
    _firestore
        .collection('chat_requests')
        .where('receiverId', isEqualTo: _auth.currentUser?.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _requestsCount = snapshot.docs.length;
        });
      }
    });

    // Listen to personal chats for unread messages
    _firestore
        .collection('personal_chats')
        .where('participants', arrayContains: _auth.currentUser?.uid)
        .snapshots()
        .listen((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        var data = doc.data() ;
        var unreadCount = data['unreadCount_${_auth.currentUser?.uid}'] ?? 0;
        totalUnread += unreadCount as int;
      }
      if (mounted) {
        setState(() {
          _personalUnreadCount = totalUnread;
        });
      }
    });

    // Listen to project chats for unread messages
    _firestore
        .collection('project_chats')
        .snapshots()
        .listen((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        var data = doc.data() ;
        var unreadCount = data['unreadCount_${_auth.currentUser?.uid}'] ?? 0;
        totalUnread += unreadCount as int;
      }
      if (mounted) {
        setState(() {
          _projectUnreadCount = totalUnread;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildBadge(Widget child, int count) {
    if (count == 0) return child;
    
    return Stack(
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vevij Chat', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBadge(Icon(Icons.person), _personalUnreadCount + _requestsCount),
                  SizedBox(width: 8),
                  Text('Personal'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBadge(Icon(Icons.group), _projectUnreadCount),
                  SizedBox(width: 8),
                  Text('Projects'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PersonalChatTab(requestsCount: _requestsCount),
          ProjectChatTab(),
        ],
      ),
    );
  }
}

// Personal Chat Tab
class PersonalChatTab extends StatefulWidget {
  final int requestsCount;
  
  const PersonalChatTab({super.key,required this.requestsCount});

  @override
PersonalChatTabState createState() => PersonalChatTabState();
}

class PersonalChatTabState extends State<PersonalChatTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: TabBar(
              labelColor: Colors.blue[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.blue[700],
              tabs: [
                Tab(text: 'Chats'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Requests'),
                      if (widget.requestsCount > 0) ...[
                        SizedBox(width: 4),
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.requestsCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(text: 'Users'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPersonalChats(),
                _buildChatRequests(),
                _buildUsersList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalChats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('personal_chats')
          .where('participants', arrayContains: _auth.currentUser?.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No chats yet', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chat = snapshot.data!.docs[index];
            var chatData = chat.data() as Map<String, dynamic>;
            var participants = List<String>.from(chat['participants']);
            var otherUserId = participants.firstWhere((id) => id != _auth.currentUser?.uid);
            var unreadCount = chatData['unreadCount_${_auth.currentUser?.uid}'] ?? 0;

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return ListTile(title: Text('Loading...'));
                }

                var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                var userName = userData?['name'] ?? 'Unknown User';
                var userRole = userData?['role'] ?? '';

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[700],
                          child: Text(userName.substring(0, 1).toUpperCase(), 
                                 style: TextStyle(color: Colors.white)),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      userName, 
                      style: TextStyle(
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userRole, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          chat['lastMessage'] ?? '', 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (chat['lastMessageTime'] != null)
                          Text(
                            _formatTime(chat['lastMessageTime'].toDate()),
                            style: TextStyle(
                              fontSize: 12, 
                              color: unreadCount > 0 ? Colors.blue[700] : Colors.grey[600],
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        if (unreadCount > 0) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PersonalChatScreen(
                            chatId: chat.id,
                            otherUserId: otherUserId,
                            otherUserName: userName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

Widget _buildChatRequests() {
  final currentUserId = _auth.currentUser?.uid;

  return StreamBuilder<QuerySnapshot>(
    stream: _firestore
        .collection('chat_requests')
        .where('status', isEqualTo: 'pending')
        .where('receiverId', isEqualTo: currentUserId)
        .snapshots(),
    builder: (context, receivedSnapshot) {
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chat_requests')
            .where('status', isEqualTo: 'pending')
            .where('senderId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, sentSnapshot) {
          if (receivedSnapshot.connectionState == ConnectionState.waiting ||
              sentSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final receivedDocs = receivedSnapshot.data?.docs ?? [];
          final sentDocs = sentSnapshot.data?.docs ?? [];

          final allRequests = [
            ...receivedDocs.map((doc) => {'type': 'received', 'doc': doc}),
            ...sentDocs.map((doc) => {'type': 'sent', 'doc': doc}),
          ];

          if (allRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No pending requests', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: allRequests.length,
            itemBuilder: (context, index) {
              var requestData = allRequests[index];
              var requestDoc = requestData['doc'] as QueryDocumentSnapshot;
              var type = requestData['type'];

              String otherUserId = type == 'received'
                  ? requestDoc['senderId']
                  : requestDoc['receiverId'];

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return ListTile(title: Text('Loading...'));
                  }

                  var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  var userName = userData?['name'] ?? 'Unknown User';
                  var userRole = userData?['role'] ?? '';

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: type == 'received' ? Colors.orange[50] : Colors.blue[50],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: type == 'received' ? Colors.orange[700] : Colors.blue[700],
                        child: Text(userName.substring(0, 1).toUpperCase(),
                            style: TextStyle(color: Colors.white)),
                      ),
                      title: Text(userName, style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '$userRole • ${type == 'received' ? 'Chat request received' : 'Chat request sent'}'),
                      trailing: type == 'received'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _acceptChatRequest(requestDoc.id, requestDoc['senderId']),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _rejectChatRequest(requestDoc.id),
                                ),
                              ],
                            )
                          : IconButton(
                              icon: Icon(Icons.cancel, color: Colors.red),
                              tooltip: "Cancel Request",
                              onPressed: () {
                                _showCancelConfirmationDialog(requestDoc.id);
                              },
                            ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

/// Confirmation dialog for canceling a sent request
void _showCancelConfirmationDialog(String requestId) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Cancel Chat Request'),
          ],
        ),
        content: Text('Are you sure you want to cancel this chat request?'),
        actions: [
          TextButton(
            child: Text('No'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Yes, Cancel'),
            onPressed: () async {
              await _firestore.collection('chat_requests').doc(requestId).delete();
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}
  Widget _buildUsersList() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('users').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData) {
        return Center(child: Text('No users found'));
      }

      var users = snapshot.data!.docs
          .where((doc) => doc.id != _auth.currentUser?.uid)
          .toList();

      return ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          var user = users[index];
          var userData = user.data() as Map<String, dynamic>;

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[700],
                child: Text(
                  (userData['empName'] ?? 'U')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                userData['empName'] ?? 'Unknown User',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(userData['designation'] ?? 'No role'),
              trailing: IconButton(
                icon: Icon(Icons.chat, color: Colors.blue[700]),
                onPressed: () {
                  _showSendRequestConfirmation(user.id, userData['empName'] ?? 'this user');
                },
              ),
            ),
          );
        },
      );
    },
  );
}

/// Shows a confirmation dialog before sending chat request
void _showSendRequestConfirmation(String userId, String userName) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.chat, color: Colors.blue),
            SizedBox(width: 8),
            Text('Send Chat Request'),
          ],
        ),
        content: Text('Do you want to send a chat request to $userName?'),
        actions: [
          TextButton(
            child: Text('No'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Yes, Send'),
            onPressed: () {
              Navigator.pop(context); // close dialog
              _sendChatRequest(userId);
            },
          ),
        ],
      );
    },
  );
}

  Future<void> _sendChatRequest(String receiverId) async {
    try {
      // Check if request already exists
      var existingRequest = await _firestore
          .collection('chat_requests')
          .where('senderId', isEqualTo: _auth.currentUser?.uid)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request already sent')),
        );
        return;
      }

      // Check if chat already exists
      var existingChat = await _firestore
          .collection('personal_chats')
          .where('participants', arrayContains: _auth.currentUser?.uid)
          .get();

      for (var doc in existingChat.docs) {
        var participants = List<String>.from(doc['participants']);
        if (participants.contains(receiverId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chat already exists')),
          );
          return;
        }
      }

      await _firestore.collection('chat_requests').add({
        'senderId': _auth.currentUser?.uid,
        'receiverId': receiverId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat request sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    }
  }

  Future<void> _acceptChatRequest(String requestId, String senderId) async {
    try {
      // Create personal chat
      await _firestore.collection('personal_chats').add({
        'participants': [_auth.currentUser?.uid, senderId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount_${_auth.currentUser?.uid}': 0,
        'unreadCount_$senderId': 0,
      });

      // Update request status
      await _firestore.collection('chat_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat request accepted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $e')),
      );
    }
  }

  Future<void> _rejectChatRequest(String requestId) async {
    try {
      await _firestore.collection('chat_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat request rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject request: $e')),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
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
}

// Project Chat Tab
class ProjectChatTab extends StatelessWidget {
   ProjectChatTab({super.key});
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('projects').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No projects found', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var project = snapshot.data!.docs[index];
            var projectData = project.data() as Map<String, dynamic>;
            
            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('project_chats').doc(project.id).snapshots(),
              builder: (context, chatSnapshot) {
                int unreadCount = 0;
                if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                  var chatData = chatSnapshot.data!.data() as Map<String, dynamic>?;
                  unreadCount = chatData?['unreadCount_${_auth.currentUser?.uid}'] ?? 0;
                }

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.purple[700],
                          child: Icon(Icons.business, color: Colors.white),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      projectData['name'] ?? 'Unnamed Project',
                      style: TextStyle(
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Client: ${projectData['customerName'] ?? 'Unknown'}'),
                        Text('Location: ${projectData['projectAddress'] ?? 'Unknown'}'),
                        Text(
                          'Status: ${projectData['status'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward_ios),
                        if (unreadCount > 0) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectChatScreen(
                            projectId: project.id,
                            projectName: projectData['name'] ?? 'Unnamed Project',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Personal Chat Screen
class PersonalChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const PersonalChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  PersonalChatScreenState createState() => PersonalChatScreenState();
}

class PersonalChatScreenState extends State<PersonalChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  void _markMessagesAsRead() {
    // Mark messages as read when entering chat
    _firestore.collection('personal_chats').doc(widget.chatId).update({
      'unreadCount_${_auth.currentUser?.uid}': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(
                widget.otherUserName.substring(0, 1).toUpperCase(),
                style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherUserName, style: TextStyle(fontSize: 16)),
                  Text('Online', style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                 value: 'clear',
                child: Text('Clear Chat', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                 ),
              PopupMenuItem(
                 value: 'block',
                child: Text('Block User', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                 ),
            ],
            onSelected: (value) {
              // Handle menu actions
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('personal_chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.deepPurple),
                        SizedBox(height: 16),
                        Text('No messages yet. Start the conversation!',
                               style: TextStyle(color: Colors.deepPurple)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var message = snapshot.data!.docs[index];
                    var messageData = message.data() as Map<String, dynamic>;
                    var isMe = messageData['senderId'] == _auth.currentUser?.uid;

                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.deepPurple,
                              child: Text(
                                widget.otherUserName.substring(0, 1).toUpperCase(),
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
                          Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white : Colors.deepPurple,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                                bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  messageData['text'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.black : Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatMessageTime(messageData['timestamp']?.toDate()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe ? Colors.deepPurple : Colors.white70,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue[500],
                              child: Text(
                                'Me',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey[600]),
            onPressed: () {
              // Handle file attachment
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.emoji_emotions, color: Colors.grey[600]),
                    onPressed: () {
                      // Handle emoji picker
                    },
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (text) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: _sendMessage,
            backgroundColor: Colors.blue[700],
            elevation: 2,
            child: Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      var messageText = _messageController.text.trim();
      _messageController.clear();

      // Get sender's name
      var senderDoc = await _firestore.collection('users').doc(_auth.currentUser?.uid).get();
      var senderData = senderDoc.data();
      var senderName = senderData?['name'] ?? 'Someone';

      // Add message to chat
      await _firestore
          .collection('personal_chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': _auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update last message and increment unread count for other user
      await _firestore.collection('personal_chats').doc(widget.chatId).update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount_${widget.otherUserId}': FieldValue.increment(1),
      });

      // Send push notification to the other user
    await NotificationService.sendNotificationToUser(
      receiverId: widget.otherUserId,
      title: senderName,
      body: messageText,
      chatId: widget.chatId,
      chatType: 'personal',
      additionalData: {
        'senderName': senderName,
        'otherUserName': widget.otherUserName,
      },
    );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// Project Chat Screen
class ProjectChatScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectChatScreen({super.key,required this.projectId, required this.projectName});

  @override
  ProjectChatScreenState createState() => ProjectChatScreenState();
}

class ProjectChatScreenState extends State<ProjectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  void _markMessagesAsRead() {
    // Mark messages as read when entering chat
    _firestore.collection('project_chats').doc(widget.projectId).update({
      'unreadCount_${_auth.currentUser?.uid}': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.purple[500],
              radius: 20,
              child: Icon(Icons.business, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.projectName, style: TextStyle(fontSize: 16)),
                  Text('Project Chat', style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              _showProjectInfo();
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                 value: 'details',
                child: Text('Project Details'),
                 ),
              PopupMenuItem(
                 value: 'members',
                child: Text('Team Members'),
                 ),
              PopupMenuItem(
                 value: 'clear',
                child: Text('Clear Chat'),
                 ),
            ],
            onSelected: (value) {
              // Handle menu actions
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('project_chats')
                  .doc(widget.projectId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text('No messages yet. Start the project discussion!',
                               style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var message = snapshot.data!.docs[index];
                    var messageData = message.data() as Map<String, dynamic>;
                    var isMe = messageData['senderId'] == _auth.currentUser?.uid;
                    var isSystemMessage = messageData['type'] == 'system_message' || messageData['type'] == 'system_update';

                    if (isSystemMessage) {
                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              messageData['text'] ?? '',
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }

                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.purple[400],
                              child: Text(
                                (messageData['senderName'] ?? 'U').substring(0, 1).toUpperCase(),
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            SizedBox(width: 8),
                          ],
                          Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.purple[700] : Colors.grey[200],
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: isMe ? Radius.circular(16) : Radius.circular(4),
                                bottomRight: isMe ? Radius.circular(4) : Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      messageData['senderName'] ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                Text(
                                  messageData['text'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatMessageTime(messageData['timestamp']?.toDate()),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe ? Colors.white70 : Colors.grey[600],
                                      ),
                                    ),
                                    if (isMe) ...[
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.done_all,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.purple[500],
                              child: Text(
                                'Me',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey[600]),
            onPressed: () {
              // Handle file attachment
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.emoji_emotions, color: Colors.grey[600]),
                    onPressed: () {
                      // Handle emoji picker
                    },
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (text) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: _sendMessage,
            backgroundColor: Colors.purple[700],
            child: Icon(Icons.send, color: Colors.white),
            elevation: 2,
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      var messageText = _messageController.text.trim();
      _messageController.clear();

      // Get current user data
      var userDoc = await _firestore.collection('users').doc(_auth.currentUser?.uid).get();
      var userData = userDoc.data() ;
      var senderName = userData?['name'] ?? 'Unknown User';

      // Add message to project chat
      await _firestore
          .collection('project_chats')
          .doc(widget.projectId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': _auth.currentUser?.uid,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Get project data to find all team members
      var projectDoc = await _firestore.collection('projects').doc(widget.projectId).get();
      var projectData = projectDoc.data();

      // Update project chat and increment unread count for all team members except sender
      // List<String> allMembers = [];
      // Get all users to find project team members
    var usersSnapshot = await _firestore.collection('users').get();
    
    List<String> teamMemberIds = [];
    
    for (var userDoc in usersSnapshot.docs) {
      var userData = userDoc.data();
      var userId = userDoc.id;
      var userRole = userData['role'];
      
      // Skip the sender
      if (userId == _auth.currentUser?.uid) continue;
      
      // Add logic to determine if user is part of this project
      // This is simplified - you might want to store project members differently
      if (userRole == 'Manager' || userRole == 'Designer' || userRole == 'Supervisor') {
        teamMemberIds.add(userId);
      }
    }
      if (projectData?['members'] != null) {
        var members = projectData!['members'] as Map<String, dynamic>;
        
        // Add manager
        if (members['manager'] != null) {
          // Get manager user ID (you'll need to implement user lookup by name)
          // allMembers.add(managerUserId);
        }
        
        // Add designers and supervisors (similar lookup needed)
      }

      // For now, just update the basic project chat info
      await _firestore.collection('project_chats').doc(widget.projectId).set({
        'projectId': widget.projectId,
        'projectName': widget.projectName,
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      // Send notifications to all team members
    for (String memberId in teamMemberIds) {
      await NotificationService.sendNotificationToUser(
        receiverId: memberId,
        title: '${senderName} (${widget.projectName})',
        body: messageText,
        chatId: widget.projectId,
        chatType: 'project',
        additionalData: {
          'senderName': senderName,
          'projectName': widget.projectName,
        },
      );
    // Update unread count for each member
      await _firestore.collection('project_chats').doc(widget.projectId).update({
        'unreadCount_$memberId': FieldValue.increment(1),
      });
    }
    
  
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  void _showProjectInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Project Information'),
        content: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('projects').doc(widget.projectId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircularProgressIndicator();
            }
            
            var projectData = snapshot.data!.data() as Map<String, dynamic>?;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Project: ${projectData?['projectName'] ?? 'Unknown'}'),
                Text('Client: ${projectData?['clientName'] ?? 'Unknown'}'),
                Text('Location: ${projectData?['location'] ?? 'Unknown'}'),
                Text('Status: ${projectData?['status'] ?? 'Unknown'}'),
                Text('Total Doors: ${projectData?['totalDoors'] ?? 0}'),
                Text('Total Flats: ${projectData?['totalFlats'] ?? 0}'),
                Text('Total Floors: ${projectData?['totalFloors'] ?? 0}'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}