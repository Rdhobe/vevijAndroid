import 'package:vevij/components/imports.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize notification service
  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request notification permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Get FCM token and save to user document
      String? token = await _firebaseMessaging.getToken();
      if (token != null && _auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) async {
        if (_auth.currentUser != null) {
          await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
            'fcmToken': token,
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Handle app opened from terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Handling a foreground message: ${message.messageId}');
    
    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1976D2),
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      platformChannelSpecifics,
      payload: _createNotificationPayload(message),
    );
  }

  // Create notification payload
  String _createNotificationPayload(RemoteMessage message) {
    Map<String, dynamic> payload = {
      'type': message.data['type'] ?? 'chat',
      'chatId': message.data['chatId'],
      'projectId': message.data['projectId'],
      'senderId': message.data['senderId'],
      'senderName': message.data['senderName'],
    };
    return payload.toString();
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse notificationResponse) {
    if (notificationResponse.payload != null) {
      _navigateToChat(notificationResponse.payload!);
    }
  }

  // Handle message tap from background/terminated
  void _handleMessageTap(RemoteMessage message) {
    String payload = _createNotificationPayload(message);
    _navigateToChat(payload);
  }

  // Navigate to appropriate chat screen
  void _navigateToChat(String payload) {
    // Parse payload and navigate to chat
    // This would need to be integrated with your app's navigation system
    print('Navigate to chat with payload: $payload');
    
    // Example navigation logic:
    /*
    if (payload.contains('personal_chat')) {
      Navigator.pushNamed(context, '/personal_chat', arguments: chatData);
    } else if (payload.contains('project_chat')) {
      Navigator.pushNamed(context, '/project_chat', arguments: projectData);
    }
    */
  }

  // Send push notification to specific user
  Future<void> sendNotificationToUser({
    required String receiverId,
    required String title,
    required String body,
    required String type,
    String? chatId,
    String? projectId,
    String? senderName,
  }) async {
    try {
      // Get receiver's FCM token
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(receiverId).get();
      
      if (!userDoc.exists) return;
      
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      String? fcmToken = userData?['fcmToken'];
      
      if (fcmToken == null) return;

      // Create notification data
      Map<String, dynamic> notificationData = {
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'badge': '1',
        },
        'data': {
          'type': type,
          'senderId': _auth.currentUser?.uid ?? '',
          'senderName': senderName ?? 'Unknown',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        }
      };

      if (chatId != null) notificationData['data']['chatId'] = chatId;
      if (projectId != null) notificationData['data']['projectId'] = projectId;

      // Store notification in Firestore (optional - for notification history)
      await _firestore.collection('notifications').add({
        'receiverId': receiverId,
        'senderId': _auth.currentUser?.uid,
        'title': title,
        'body': body,
        'type': type,
        'chatId': chatId,
        'projectId': projectId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Here you would call your backend service to send the FCM message
      // Since Flutter can't directly send FCM messages, this needs to be done via Cloud Functions
      
      print('Notification prepared for user: $receiverId');
      
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification for personal chat message
  Future<void> sendPersonalChatNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await sendNotificationToUser(
      receiverId: receiverId,
      title: senderName,
      body: message,
      type: 'personal_chat',
      chatId: chatId,
      senderName: senderName,
    );
  }

  // Send notification for project chat message
  Future<void> sendProjectChatNotification({
    required List<String> receiverIds,
    required String senderName,
    required String message,
    required String projectId,
    required String projectName,
  }) async {
    for (String receiverId in receiverIds) {
      if (receiverId != _auth.currentUser?.uid) { // Don't send to sender
        await sendNotificationToUser(
          receiverId: receiverId,
          title: '$projectName - $senderName',
          body: message,
          type: 'project_chat',
          projectId: projectId,
          senderName: senderName,
        );
      }
    }
  }

  // Send notification for chat request
  Future<void> sendChatRequestNotification({
    required String receiverId,
    required String senderName,
  }) async {
    await sendNotificationToUser(
      receiverId: receiverId,
      title: 'New Chat Request',
      body: '$senderName wants to chat with you',
      type: 'chat_request',
      senderName: senderName,
    );
  }

  // Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    if (_auth.currentUser == null) return 0;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: _auth.currentUser!.uid)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    if (_auth.currentUser == null) return;

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: _auth.currentUser!.uid)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();

      for (DocumentSnapshot doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get notification stream
  Stream<QuerySnapshot> getNotificationStream() {
    if (_auth.currentUser == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: _auth.currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Clear old notifications (older than 30 days)
  Future<void> clearOldNotifications() async {
    if (_auth.currentUser == null) return;

    try {
      DateTime thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      
      QuerySnapshot snapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: _auth.currentUser!.uid)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      WriteBatch batch = _firestore.batch();

      for (DocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleared ${snapshot.docs.length} old notifications');
    } catch (e) {
      print('Error clearing old notifications: $e');
    }
  }

  // Update user's online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_auth.currentUser == null) return;

    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // Listen to user's online status
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      Map<String, dynamic>? data = snapshot.data();
      return data?['isOnline'] ?? false;
    });
  }

  // Show in-app notification banner
  void showInAppNotification(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Handle view action
          },
        ),
      ),
    );
  }

  // Dispose
  void dispose() {
    // Clean up any subscriptions if needed
  }
}