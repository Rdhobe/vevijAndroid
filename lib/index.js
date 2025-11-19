// Firebase Cloud Function (functions/index.js)
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send notification when a new message is added
exports.sendChatNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notificationData = snap.data();
      const receiverId = notificationData.receiverId;
      const senderId = notificationData.senderId;
      const message = notificationData.message;
      const chatType = notificationData.chatType || 'personal';
      const chatId = notificationData.chatId;

      // Get receiver's FCM token
      const receiverDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();

      if (!receiverDoc.exists) {
        console.log('Receiver not found');
        return;
      }

      const receiverData = receiverDoc.data();
      const fcmToken = receiverData.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token found for receiver');
        return;
      }

      // Get sender's name
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();

      const senderData = senderDoc.data();
      const senderName = senderData?.name || 'Someone';

      // Prepare notification payload
      const payload = {
        notification: {
          title: chatType === 'personal' ? senderName : `${senderName} (Project Chat)`,
          body: message,
          icon: 'ic_launcher',
          sound: 'default',
        },
        data: {
          chatId: chatId,
          chatType: chatType,
          senderId: senderId,
          senderName: senderName,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          notification: {
            channelId: 'chat_channel',
            priority: 'high',
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send the notification
      const response = await admin.messaging().sendToDevice(fcmToken, payload);
      
      console.log('Notification sent successfully:', response);
      
      // Update notification as sent
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      console.error('Error sending notification:', error);
    }
  });

// Send notification to multiple users (for project chats)
exports.sendProjectNotification = functions.firestore
  .document('project_chats/{projectId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      const projectId = context.params.projectId;
      const senderId = messageData.senderId;
      const senderName = messageData.senderName || 'Someone';
      const messageText = messageData.text;

      // Get project data to find team members
      const projectDoc = await admin.firestore()
        .collection('projects')
        .doc(projectId)
        .get();

      if (!projectDoc.exists) {
        console.log('Project not found');
        return;
      }

      const projectData = projectDoc.data();
      const projectName = projectData.projectName || 'Project Chat';

      // Get all users and find team members
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .get();

      const notifications = [];

      usersSnapshot.forEach((userDoc) => {
        const userData = userDoc.data();
        const userId = userDoc.id;

        // Skip the sender
        if (userId === senderId) return;

        // Check if user is part of this project (implement your logic here)
        // This is a simplified version - you might want to store project members differently
        const userRole = userData.role;
        const fcmToken = userData.fcmToken;

        if (fcmToken && (userRole === 'Manager' || userRole === 'Designer' || userRole === 'Supervisor')) {
          // Add notification for this user
          notifications.push(
            admin.firestore().collection('notifications').add({
              senderId: senderId,
              receiverId: userId,
              title: `${senderName} (${projectName})`,
              message: messageText,
              chatId: projectId,
              chatType: 'project',
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              read: false,
            })
          );
        }
      });

      // Create all notifications
      await Promise.all(notifications);
      console.log(`Created ${notifications.length} project notifications`);

    } catch (error) {
      console.error('Error sending project notification:', error);
    }
  });

// Clean up old notifications
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      const cutoffTime = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) // 30 days ago
      );

      const oldNotifications = await admin.firestore()
        .collection('notifications')
        .where('timestamp', '<', cutoffTime)
        .get();

      const batch = admin.firestore().batch();
      oldNotifications.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Deleted ${oldNotifications.docs.length} old notifications`);
    } catch (error) {
      console.error('Error cleaning up notifications:', error);
    }
  });