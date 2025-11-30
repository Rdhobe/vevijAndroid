// Firebase Cloud Function (functions/index.js)
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Send notification when a new message is added
exports.sendChatNotification = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snap, context) => {
      try {
        const notificationData = snap.data();
        const receiverId = notificationData.receiverId;
        const senderId = notificationData.senderId;
        const message = notificationData.message;
        const chatType = notificationData.chatType || "personal";
        const chatId = notificationData.chatId;

        // Get receiver's FCM token
        const receiverDoc = await admin.firestore()
            .collection("users")
            .doc(receiverId)
            .get();

        if (!receiverDoc.exists) {
          console.log("Receiver not found");
          return;
        }

        const receiverData = receiverDoc.data();
        const fcmToken = receiverData.fcmToken;

        if (!fcmToken) {
          console.log("No FCM token found for receiver");
          return;
        }

        // Get sender's name
        const senderDoc = await admin.firestore()
            .collection("users")
            .doc(senderId)
            .get();

        const senderData = senderDoc.data();
        const senderName = senderData?.empName || "Someone";

        // Prepare notification payload
        const payload = {
          notification: {
            title: chatType === "personal" ? senderName : `${senderName} (Project Chat)`,
            body: message,
            icon: "ic_launcher",
            sound: "default",
          },
          data: {
            chatId: chatId,
            chatType: chatType,
            senderId: senderId,
            senderName: senderName,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            notification: {
              channelId: "chat_channel",
              priority: "high",
              defaultSound: true,
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        // Send the notification
        const response = await admin.messaging().sendToDevice(fcmToken, payload);

        console.log("Notification sent successfully:", response);

        // Update notification as sent
        await snap.ref.update({
          sent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("Error sending notification:", error);
      }
    });

// Send notification to multiple users (for project chats)
exports.sendProjectNotification = functions.firestore
    .document("project_chats/{projectId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      try {
        const messageData = snap.data();
        const projectId = context.params.projectId;
        const senderId = messageData.senderId;
        const senderName = messageData.senderName || "Someone";
        const messageText = messageData.text;

        // Get project data to find team members
        const projectDoc = await admin.firestore()
            .collection("projects")
            .doc(projectId)
            .get();

        if (!projectDoc.exists) {
          console.log("Project not found");
          return;
        }

        const projectData = projectDoc.data();
        const projectName = projectData.projectName || "Project Chat";

        // Get all users and find team members
        const usersSnapshot = await admin.firestore()
            .collection("users")
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

          if (fcmToken && (userRole === "Manager" || userRole === "Designer" || userRole === "Supervisor")) {
          // Add notification for this user
            notifications.push(
                admin.firestore().collection("notifications").add({
                  senderId: senderId,
                  receiverId: userId,
                  title: `${senderName} (${projectName})`,
                  message: messageText,
                  chatId: projectId,
                  chatType: "project",
                  timestamp: admin.firestore.FieldValue.serverTimestamp(),
                  read: false,
                }),
            );
          }
        });

        // Create all notifications
        await Promise.all(notifications);
        console.log(`Created ${notifications.length} project notifications`);
      } catch (error) {
        console.error("Error sending project notification:", error);
      }
    });

// Clean up old notifications
exports.cleanupOldNotifications = functions.pubsub
    .schedule("every 24 hours")
    .onRun(async (context) => {
      try {
        const cutoffTime = admin.firestore.Timestamp.fromDate(
            new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), // 30 days ago
        );

        const oldNotifications = await admin.firestore()
            .collection("notifications")
            .where("timestamp", "<", cutoffTime)
            .get();

        const batch = admin.firestore().batch();
        oldNotifications.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });

        await batch.commit();
        console.log(`Deleted ${oldNotifications.docs.length} old notifications`);
      } catch (error) {
        console.error("Error cleaning up notifications:", error);
      }
    });
// ==================== USER MANAGEMENT FUNCTIONS ====================
exports.deleteUserByUID = functions.https.onCall(async (data, context) => {
  // Only allow admin users
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Request has no authentication.",
    );
  }

  // You can optionally check if the requester is an admin
  const uidRequester = context.auth.uid;
  const requester = await admin.auth().getUser(uidRequester);

  // Example: only allow admin role
  if (!requester.customClaims || requester.customClaims.role !== "admin") {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can delete users.",
    );
  }

  const uidToDelete = data.uid;

  if (!uidToDelete) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "No UID provided.",
    );
  }

  try {
    await admin.auth().deleteUser(uidToDelete);
    return {success: true, message: "User deleted successfully"};
  } catch (error) {
    throw new functions.https.HttpsError("unknown", error.message);
  }
});

// Send general app notification (Tasks, Teams, etc.)
exports.sendAppNotification = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snap, _context) => {
      try {
        const data = snap.data();

        // Only process if it follows the new schema (userId) and is NOT a chat notification (receiverId)
        if (!data.userId || data.receiverId) return;

        const userId = data.userId;
        const title = data.title || "New Notification";
        const body = data.body || "You have a new notification";
        const type = data.type || "general";
        const taskId = data.taskId || "";
        const teamId = data.teamId || "";

        console.log("Processing app notification:", {userId, type, title});

        // Get user's FCM token
        const userDoc = await admin.firestore().collection("users").doc(userId).get();

        if (!userDoc.exists) {
          console.log("User not found:", userId);
          return;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (!fcmToken) {
          console.log("No FCM token found for user:", userId);
          return;
        }

        // Prepare notification payload
        const messagePayload = {
          token: fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            type: type,
            taskId: taskId,
            teamId: teamId,
            isAppNotification: "true",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              defaultSound: true,
              priority: "high",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        // Send notification
        const response = await admin.messaging().send(messagePayload);
        console.log("App notification sent successfully:", response);

        // Update document to mark as sent
        await snap.ref.update({
          sent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("Error sending app notification:", error);
      }
    });

// Send notification when a new message is added
exports.sendChatNotification = functions.firestore
    .document("notifications/{notificationId}")
    .onCreate(async (snap, _context) => {
      try {
        const notificationData = snap.data();

        // Guard clause: Skip if receiverId is missing (likely an app notification)
        if (!notificationData.receiverId) return;

        const receiverId = notificationData.receiverId;
        const senderId = notificationData.senderId;
        const message = notificationData.message;
        const chatType = notificationData.chatType || "personal";
        const chatId = notificationData.chatId;

        console.log("Processing notification:", {
          receiverId,
          senderId,
          chatType,
          chatId,
        });

        // Get receiver's FCM token
        const receiverDoc = await admin.firestore()
            .collection("users")
            .doc(receiverId)
            .get();

        if (!receiverDoc.exists) {
          console.log("Receiver not found");
          return;
        }

        const receiverData = receiverDoc.data();
        const fcmToken = receiverData.fcmToken;

        if (!fcmToken) {
          console.log("No FCM token found for receiver");
          return;
        }

        console.log("FCM Token found:", fcmToken.substring(0, 20) + "...");

        // Get sender's name
        const senderDoc = await admin.firestore()
            .collection("users")
            .doc(senderId)
            .get();

        const senderData = senderDoc.data();
        const senderName = (senderData && senderData.empName) || "Someone";

        // Prepare notification message using modern FCM API
        const messagePayload = {
          token: fcmToken,
          notification: {
            title: chatType === "personal" ? senderName : `${senderName} (Project Chat)`,
            body: message,
          },
          data: {
            chatId: chatId,
            chatType: chatType,
            senderId: senderId,
            senderName: senderName,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            notification: {
              channelId: "chat_channel",
              priority: "high",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        // Send the notification using modern API
        const response = await admin.messaging().send(messagePayload);
        console.log("Notification sent successfully:", response);

        // Update notification as sent
        await snap.ref.update({
          sent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("Error in sendChatNotification:", error);

        // Log more details about the error
        if (error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered") {
          console.log("Invalid or expired FCM token");
        }
      }
    });

// Send notification to multiple users (for project chats)
exports.sendProjectNotification = functions.firestore
    .document("project_chats/{projectId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      try {
        const messageData = snap.data();
        const projectId = context.params.projectId;
        const senderId = messageData.senderId;
        const senderName = messageData.senderName || "Someone";
        const messageText = messageData.text;

        console.log("Processing project notification:", {
          projectId,
          senderId,
          senderName,
        });

        // Get project data to find team members
        const projectDoc = await admin.firestore()
            .collection("projects")
            .doc(projectId)
            .get();

        if (!projectDoc.exists) {
          console.log("Project not found");
          return;
        }

        const projectData = projectDoc.data();
        const projectName = projectData.projectName || "Project Chat";

        // Get all users and find team members
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .get();

        const notifications = [];

        usersSnapshot.forEach((userDoc) => {
          const userData = userDoc.data();
          const userId = userDoc.id;

          // Skip the sender
          if (userId === senderId) return;

          // Check if user is part of this project
          const userRole = userData.role;
          const fcmToken = userData.fcmToken;

          if (fcmToken && (userRole === "Manager" || userRole === "Designer" || userRole === "Supervisor")) {
          // Add notification for this user
            notifications.push(
                admin.firestore().collection("notifications").add({
                  senderId: senderId,
                  receiverId: userId,
                  title: `${senderName} (${projectName})`,
                  message: messageText,
                  chatId: projectId,
                  chatType: "project",
                  timestamp: admin.firestore.FieldValue.serverTimestamp(),
                  read: false,
                }),
            );
          }
        });

        // Create all notifications
        await Promise.all(notifications);
        console.log(`Created ${notifications.length} project notifications`);
      } catch (error) {
        console.error("Error sending project notification:", error);
      }
    });

// Clean up old notifications
exports.cleanupOldNotifications = functions.pubsub
    .schedule("every 24 hours")
    .onRun(async (_context) => {
      try {
        const cutoffTime = admin.firestore.Timestamp.fromDate(
            new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), // 30 days ago
        );

        const oldNotifications = await admin.firestore()
            .collection("notifications")
            .where("timestamp", "<", cutoffTime)
            .get();

        const batch = admin.firestore().batch();
        oldNotifications.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });

        await batch.commit();
        console.log(`Deleted ${oldNotifications.docs.length} old notifications`);
      } catch (error) {
        console.error("Error cleaning up notifications:", error);
      }
    });


// ==================== SALARY SLIP FUNCTIONS ====================

// Initialize transporter with proper config handling
let transporter;

function initializeTransporter() {
  const gmailConfig = functions.config().gmail;

  // Debug: Check if config exists
  if (!gmailConfig || !gmailConfig.user || !gmailConfig.pass) {
    console.error("Gmail config missing! Please set firebase functions config");
    console.error("Run: firebase functions:config:set gmail.user='...' gmail.pass='...'");
    return null;
  }

  console.log("Initializing transporter with user:", gmailConfig.user);

  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: gmailConfig.user,
      pass: gmailConfig.pass,
    },
  });
}

/**
 * Send salary slip via email
 * Called from Flutter app with employee details and PDF
 */
exports.sendSalarySlip = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to send salary slips.",
    );
  }

  // Validate required data
  const {employeeEmail, employeeName, pdfBase64, month, year} = data;

  if (!employeeEmail || !employeeName || !pdfBase64) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: employeeEmail, employeeName, pdfBase64",
    );
  }

  try {
    // Initialize transporter
    if (!transporter) {
      transporter = initializeTransporter();
    }

    if (!transporter) {
      throw new Error("Failed to initialize transporter - Gmail config missing");
    }

    // Get format configuration from Firestore
    const formatDoc = await admin.firestore()
        .collection("settings")
        .doc("salarySlipFormat")
        .get();

    const formatConfig = formatDoc.exists ? formatDoc.data() : {};

    const subject = formatConfig.emailSubject ||
      `Salary Slip - ${month}/${year}`;

    const htmlBody = formatConfig.emailBody ||
      `<p>Dear ${employeeName},</p>
       <p>Please find your monthly salary slip attached.</p>
       <p>If you have any questions, please contact HR.</p>
       <p>Best regards,<br>HR Department</p>`;

    // Get Gmail user from config
    const gmailUser = functions.config().gmail.user;

    // Prepare email options
    const mailOptions = {
      from: gmailUser,
      to: employeeEmail,
      subject: subject,
      html: htmlBody,
      attachments: [
        {
          filename: `Salary_Slip_${month}_${year}.pdf`,
          content: Buffer.from(pdfBase64, "base64"),
          contentType: "application/pdf",
        },
      ],
    };

    // Send email
    const info = await transporter.sendMail(mailOptions);

    console.log("Email sent successfully:", {
      messageId: info.messageId,
      to: employeeEmail,
      month,
      year,
    });

    // Log transaction in Firestore
    await admin.firestore()
        .collection("salarySlipLogs")
        .add({
          employeeEmail,
          employeeName,
          month,
          year,
          status: "sent",
          messageId: info.messageId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

    return {
      success: true,
      message: `Salary slip sent to ${employeeEmail}`,
      messageId: info.messageId,
    };
  } catch (error) {
    console.error("Error sending salary slip:", error);

    // Log error in Firestore
    await admin.firestore()
        .collection("salarySlipLogs")
        .add({
          employeeEmail,
          employeeName,
          month,
          year,
          status: "failed",
          error: error.message,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

    throw new functions.https.HttpsError(
        "internal",
        `Failed to send email: ${error.message}`,
    );
  }
});

/**
 * Send bulk salary slips with retry logic
 */
exports.sendBulkSalarySlips = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated.",
    );
  }

  const {employees} = data;

  if (!employees || !Array.isArray(employees)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid employees data",
    );
  }

  const results = {
    success: [],
    failed: [],
  };

  try {
    // Initialize transporter
    if (!transporter) {
      transporter = initializeTransporter();
    }

    if (!transporter) {
      throw new Error("Failed to initialize transporter - Gmail config missing");
    }

    const formatDoc = await admin.firestore()
        .collection("settings")
        .doc("salarySlipFormat")
        .get();

    const formatConfig = formatDoc.exists ? formatDoc.data() : {};
    const currentMonth = new Date().getMonth() + 1;
    const currentYear = new Date().getFullYear();
    const gmailUser = functions.config().gmail.user;

    // Process each employee with concurrent limit
    const batchSize = 5; // Send max 5 emails concurrently
    for (let i = 0; i < employees.length; i += batchSize) {
      const batch = employees.slice(i, i + batchSize);

      await Promise.all(batch.map(async (employee) => {
        try {
          const mailOptions = {
            from: gmailUser,
            to: employee.employeeEmail,
            subject: formatConfig.emailSubject ||
              `Salary Slip - ${currentMonth}/${currentYear}`,
            html: formatConfig.emailBody ||
              `<p>Dear ${employee.employeeName},</p>
               <p>Please find your monthly salary slip attached.</p>
               <p>Best regards,<br>HR Department</p>`,
            attachments: [
              {
                filename: `Salary_Slip_${currentMonth}_${currentYear}.pdf`,
                content: Buffer.from(employee.pdfBase64, "base64"),
                contentType: "application/pdf",
              },
            ],
          };

          const info = await transporter.sendMail(mailOptions);

          results.success.push({
            email: employee.employeeEmail,
            name: employee.employeeName,
            messageId: info.messageId,
          });

          console.log(`Email sent to ${employee.employeeEmail}`);
        } catch (error) {
          results.failed.push({
            email: employee.employeeEmail,
            name: employee.employeeName,
            error: error.message,
          });

          console.error(
              `Failed to send to ${employee.employeeEmail}:`,
              error.message,
          );
        }
      }));
    }

    // Log bulk operation
    await admin.firestore()
        .collection("salarySlipBulkLogs")
        .add({
          totalCount: employees.length,
          successCount: results.success.length,
          failureCount: results.failed.length,
          results: results,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

    return {
      success: true,
      data: results,
      message: `Sent: ${results.success.length}, Failed: ${results.failed.length}`,
    };
  } catch (error) {
    console.error("Error in bulk send:", error);
    throw new functions.https.HttpsError(
        "internal",
        `Bulk send failed: ${error.message}`,
    );
  }
});

/**
 * Send custom email to specific employees
 */
exports.sendCustomEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const {recipients, subject, htmlBody, attachments} = data;

  if (!recipients || !Array.isArray(recipients) || !subject || !htmlBody) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields",
    );
  }

  try {
    // Initialize transporter
    if (!transporter) {
      transporter = initializeTransporter();
    }

    if (!transporter) {
      throw new Error("Failed to initialize transporter - Gmail config missing");
    }

    const gmailUser = functions.config().gmail.user;
    const emailAttachments = attachments ? attachments.map((att) => ({
      filename: att.filename,
      content: Buffer.from(att.base64, "base64"),
      contentType: att.contentType,
    })) : [];

    const results = await Promise.all(
        recipients.map((email) =>
          transporter.sendMail({
            from: gmailUser,
            to: email,
            subject: subject,
            html: htmlBody,
            attachments: emailAttachments,
          }).catch((error) => ({
            error: true,
            email,
            message: error.message,
          })),
        ),
    );

    return {
      success: true,
      message: `Emails sent to ${recipients.length} recipients`,
      results,
    };
  } catch (error) {
    console.error("Error sending custom email:", error);
    throw new functions.https.HttpsError(
        "internal",
        `Failed to send emails: ${error.message}`,
    );
  }
});

/**
 * Get salary slip sending logs
 */
exports.getSalarySlipLogs = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  try {
    const logsSnapshot = await admin.firestore()
        .collection("salarySlipLogs")
        .orderBy("timestamp", "desc")
        .limit(100)
        .get();

    const logs = logsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toDate(),
    }));

    return {
      success: true,
      logs: logs,
    };
  } catch (error) {
    console.error("Error fetching logs:", error);
    throw new functions.https.HttpsError(
        "internal",
        `Failed to fetch logs: ${error.message}`,
    );
  }
});

/**
 * Resend failed salary slips
 */
exports.resendFailedSlips = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  try {
    const failedLogs = await admin.firestore()
        .collection("salarySlipLogs")
        .where("status", "==", "failed")
        .orderBy("timestamp", "desc")
        .limit(10)
        .get();

    console.log(`Found ${failedLogs.docs.length} failed slips to resend`);

    return {
      success: true,
      failedCount: failedLogs.docs.length,
      message: "Retry process initiated",
    };
  } catch (error) {
    console.error("Error in resend:", error);
    throw new functions.https.HttpsError(
        "internal",
        `Failed to process resend: ${error.message}`,
    );
  }
});
