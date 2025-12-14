import 'package:vevij/components/imports.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize notifications
  static Future<void> initialize() async {
    try {
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

      try {
        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
      } catch (e) {
        print('Local notifications initialize failed: $e');
      }

      // Handle background messages
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        print('Background handler registration failed: $e');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Get and store FCM token
      await _updateFCMToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_updateFCMToken);
    } catch (e) {
      print('NotificationService.initialize error: $e');
    }
  }

  // Handle background messages
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // Ensure Firebase is available in background isolate
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase may already be initialized; ignore
    }
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

  static Future<void> _updateFCMToken([String? token]) async {
    try {
      token ??= await _firebaseMessaging.getToken();
      final user = _auth.currentUser;
      if (user != null && token != null) {
        await _firestore.collection('users').doc(user.uid).update({'fcmToken': token});
      }
    } catch (e) {
      print('Failed to update FCM token: $e');
    }
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      details,
      payload: message.data.isNotEmpty ? message.data.toString() : null,
    );
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // TODO: navigate based on payload
    print('Notification tapped with payload: ${response.payload}');
  }

  // Simple wrappers used by chat page
  static Future<void> sendNotificationToUser({
    required String receiverId,
    required String title,
    required String body,
    String? chatId,
    String? chatType,
    Map<String, String>? additionalData,
  }) async {
    try {
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final fcmToken = receiverDoc.data()?['fcmToken'];

      // Store notification for in-app listing
      await _firestore.collection('notifications').add({
        'senderId': _auth.currentUser?.uid,
        'receiverId': receiverId,
        'title': title,
        'message': body,
        'chatId': chatId,
        'chatType': chatType,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Placeholder: log token; actual FCM send handled by backend/cloud function
      if (fcmToken != null) {
        print('Would send FCM to token: $fcmToken with data: ${additionalData ?? {}}');
      }
    } catch (e) {
      print('Error sending notification to user: $e');
    }
  }

  static Future<String?> getFCMToken() async {
    try {
      return _firebaseMessaging.getToken();
    } catch (e) {
      print('Failed to get FCM token: $e');
      return null;
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Failed to subscribe to topic $topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Failed to unsubscribe from topic $topic: $e');
    }
  }
}