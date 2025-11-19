import 'package:vevij/components/imports.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize notifications
  static Future<void> initialize() async {
    // Request permission for notifications
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
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Get and store FCM token
    await _updateFCMToken();

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_updateFCMToken);
  }

  // Handle background messages
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Handling a background message: ${message.messageId}");
    await _showNotification(message);
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print("Handling a foreground message: ${message.messageId}");
    
    // Show local notification for foreground messages
    await _showNotification(message);
  }

  // Handle notification tap when app is opened from background
  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print("Message clicked: ${message.messageId}");
    // Navigate to specific chat based on message data
    // You can implement navigation logic here
  }

  // Handle local notification tap
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    print("Local notification tapped: ${notificationResponse.payload}");
    // Handle notification tap - navigate to specific chat
  }

  // Show local notification
  static Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Messages',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: message.data['chatId'], // Pass chat ID for navigation
    );
  }

  // Update FCM token in Firestore
  static Future<void> _updateFCMToken([String? token]) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final fcmToken = token ?? await _firebaseMessaging.getToken();
        if (fcmToken != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'fcmToken': fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          print('FCM Token updated: $fcmToken');
        }
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Send notification to specific user
  static Future<void> sendNotificationToUser({
    required String receiverId,
    required String title,
    required String body,
    required String chatId,
    required String chatType, // 'personal' or 'project'
    Map<String, String>? additionalData,
  }) async {
    try {
      // Get receiver's FCM token
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final receiverData = receiverDoc.data();
      final fcmToken = receiverData?['fcmToken'];

      if (fcmToken != null) {
        // Prepare notification data
        final notificationData = {
          'chatId': chatId,
          'chatType': chatType,
          'senderId': _auth.currentUser?.uid ?? '',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          ...?additionalData,
        };

        // Store notification in Firestore (for your existing system)
        await _firestore.collection('notifications').add({
          'senderId': _auth.currentUser?.uid,
          'receiverId': receiverId,
          'title': title,
          'message': body,
          'chatId': chatId,
          'chatType': chatType,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        // Send FCM notification using Cloud Function or HTTP API
        await _sendFCMNotification(
          token: fcmToken,
          title: title,
          body: body,
          data: notificationData,
        );
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send FCM notification via HTTP API
  static Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    // Note: You'll need to implement this using either:
    // 1. Cloud Functions (recommended)
    // 2. HTTP API call to FCM (requires server key)
    // 3. Admin SDK from your backend
    
    print('Would send FCM notification:');
    print('Token: $token');
    print('Title: $title');
    print('Body: $body');
    print('Data: $data');
    
    // For now, this is a placeholder. See the Cloud Function example below.
  }

  // Get current FCM token
  static Future<String?> getFCMToken() async {
    return  _firebaseMessaging.getToken();
  }

  // Subscribe to topic (for project notifications)
  static Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }
}