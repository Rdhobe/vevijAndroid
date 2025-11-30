import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/tasks/task_model.dart';
import '../utils/helpers.dart';
import 'dart:io';
import 'package:rxdart/rxdart.dart';
class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  DateTime? _selectedDueDate;
  // Stream all tasks (for Admin/HR)
  Stream<List<TaskModel>> streamAllTasks() {
    return _firestore
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromMap(doc.data()))
            .toList());
  }
  Future<void> addCommentWithReply(
  String taskId,
  String userId,
  String message, {
  String? parentCommentId,
  List<String>? attachments,
}) async {
  try {
    final commentData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'userId': userId,
      'message': message,
      'parentCommentId': parentCommentId,
      'attachments': attachments ?? [],
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'likes': [],
    };
    
    await _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .doc(commentData['id'].toString())
        .set(commentData);
    
    // Get task to notify users
    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    final task = TaskModel.fromMap(taskDoc.data()!);
    
    // Notify all involved users except comment author
    final usersToNotify = {...task.watchers, ...task.assignedTo}
        .where((uid) => uid != userId)
        .toList();
        
    await _notifyUsers(
      usersToNotify,
      parentCommentId != null ? 'New Reply' : 'New Comment',
      'New ${parentCommentId != null ? 'reply' : 'comment'} on task: ${task.title}',
      task.id,
    );
  } catch (e) {
    throw Exception('Failed to add comment: $e');
  }
}

// Update due date (only for monitors/managers)
Future<void> updateDueDate(
  String taskId,
  DateTime newDueDate,
  String userId,
  String reason,
) async {
  try {
    await _firestore.collection('tasks').doc(taskId).update({
      'revisedDueDate': Timestamp.fromDate(newDueDate),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    
    // Log the due date change
    await _logTaskHistory(
      taskId,
      'Due date revised',
      {
        'oldDueDate': Timestamp.fromDate(_selectedDueDate as DateTime),
        'newDueDate': Timestamp.fromDate(newDueDate),
        'reason': reason,
      },
      userId,
    );
    
    // Notify all task members
    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    final task = TaskModel.fromMap(taskDoc.data()!);
    
    await _notifyUsers(
      [...task.assignedTo, ...task.monitors],
      'Due Date Updated',
      'Task "${task.title}" due date has been revised to ${Helpers.formatDate(newDueDate)}',
      task.id,
    );
  } catch (e) {
    throw Exception('Failed to update due date: $e');
  }
}
  // Stream tasks for specific team
  Stream<List<TaskModel>> streamTasksForTeam(String teamId) {
    return _firestore
        .collection('tasks')
        .where('assignedTeamId', isEqualTo: teamId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromMap(doc.data()))
            .toList());
  }

  // Stream tasks for specific user
  Stream<List<TaskModel>> streamTasksForUser(String userId) {
    // find tasks assigned to a user (either directly or via team) assignedto or monitors to 
     final assignedtasks= _firestore
        .collection('tasks')
        .where('assignedTo', arrayContains: userId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromMap(doc.data()))
            .toList());
    final monitoredtasks= _firestore
        .collection('tasks')
        .where('monitors', arrayContains: userId)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromMap(doc.data()))
            .toList());

    return Rx.merge([assignedtasks, monitoredtasks]);
  }

  // Create new task
  Future<void> createTask(TaskModel task) async {
    try {
      await _firestore.collection('tasks').doc(task.id).set(task.toMap());
      
      // Log task creation in history
      await _logTaskHistory(
        task.id,
        'Task created',
        {'status': task.status.name},
        task.createdBy,
      );
      
      // Notify assigned users
      await _notifyUsers(
        task.assignedTo,
        'New Task Assigned',
        'You have been assigned to task: ${task.title}',
        task.id,
      );
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  // Update task
  Future<void> updateTask(
    String id,
    Map<String, dynamic> data, {
    String? by,
  }) async {
    try {
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection('tasks').doc(id).update(data);
      
      // Log update in history
      if (by != null) {
        await _logTaskHistory(id, 'Task updated', data, by);
      }
      
      // Get task to notify watchers
      final taskDoc = await _firestore.collection('tasks').doc(id).get();
      final task = TaskModel.fromMap(taskDoc.data()!);
      
      // Notify watchers and assignees
      final usersToNotify = {...task.watchers, ...task.assignedTo};
      await _notifyUsers(
        usersToNotify.toList(),
        'Task Updated',
        'Task "${task.title}" has been updated',
        task.id,
      );
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }
  
  Future<void> deleteTask(String taskId) async {
  try {
    await _firestore.collection('tasks').doc(taskId).delete();
    
    // Also delete subcollections (comments, history)
    final commentsSnapshot = await _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .get();
    
    final batch = _firestore.batch();
    for (final doc in commentsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    final historySnapshot = await _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('history')
        .get();
    
    for (final doc in historySnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  } catch (e) {
    throw Exception('Failed to delete task: $e');
  }
}
  // Add comment to task
  Future<void> addComment(
    String taskId,
    String userId,
    String message, {
    List<String>? attachments,
  }) async {
    try {
      final commentData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': userId,
        'message': message,
        'attachments': attachments ?? [],
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };
      
      await _firestore
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .doc(commentData['id'].toString())
          .set(commentData);
      
      // Get task to notify users
      final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
      final task = TaskModel.fromMap(taskDoc.data()!);
      
      // Notify all involved users except comment author
      final usersToNotify = {...task.watchers, ...task.assignedTo}
          .where((uid) => uid != userId)
          .toList();
          
      await _notifyUsers(
        usersToNotify,
        'New Comment',
        'New comment on task: ${task.title}',
        task.id,
      );
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  // Stream comments for a task
  Stream<List<Map<String, dynamic>>> streamComments(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  // Stream task history
  Stream<List<Map<String, dynamic>>> streamTaskHistory(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  // Private method to log task history
  Future<void> _logTaskHistory(
    String taskId,
    String action,
    Map<String, dynamic> changes,
    String userId,
  ) async {
    await _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('history')
        .add({
      'action': action,
      'changes': changes,
      'userId': userId,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Private method to notify users
  Future<void> _notifyUsers(
    List<String> userIds,
    String title,
    String body,
    String taskId,
  ) async {
    for (final userId in userIds) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'taskId': taskId,
        'read': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  // Upload attachment
  Future<String> uploadAttachment(String taskId, String filePath) async {
    try {
      final ref = _storage
          .ref()
          .child('task_attachments/$taskId/${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = await ref.putFile(File(filePath));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload attachment: $e');
    }
  }

  // Stream attachment metadata (stored in subcollection tasks/{taskId}/attachments)
  Stream<List<Map<String, dynamic>>> streamTaskAttachments(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('attachments')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              m['id'] = d.id;
              return m;
            }).toList());
  }

  // Convenience: upload file, create attachment metadata doc and append url to task.attachments
  Future<void> addAttachmentToTask(String taskId, String filePath, String uploadedBy) async {
    try {
      final ref = _storage
          .ref()
          .child('task_attachments/$taskId/${DateTime.now().millisecondsSinceEpoch}');

      final uploadTask = await ref.putFile(File(filePath));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      final storagePath = uploadTask.ref.fullPath;

      // Create metadata doc in subcollection
      await _firestore
          .collection('tasks')
          .doc(taskId)
          .collection('attachments')
          .add({
        'url': downloadUrl,
        'storagePath': storagePath,
        'uploadedBy': uploadedBy,
        'uploadedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Append to task.attachments array for backwards compatibility
      await _firestore.collection('tasks').doc(taskId).update({
        'attachments': FieldValue.arrayUnion([downloadUrl]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Log history entry
      await _logTaskHistory(taskId, 'Attachment added', {'url': downloadUrl}, uploadedBy);
    } catch (e) {
      throw Exception('Failed to add attachment to task: $e');
    }
  }

  // Delete attachment metadata and remove URL from task.attachments; also delete storage object
  Future<void> deleteAttachment(String taskId, String attachmentDocId, String url, String storagePath, String requestedBy) async {
    try {
      final docRef = _firestore.collection('tasks').doc(taskId).collection('attachments').doc(attachmentDocId);

      // Get metadata to verify ownership (optional extra safety)
      final meta = await docRef.get();
      if (!meta.exists) {
        throw Exception('Attachment metadata not found');
      }
      final metaData = meta.data()!;
      final owner = metaData['uploadedBy'] ?? '';
      if (owner != requestedBy) {
        throw Exception('Only the uploader can delete this attachment');
      }

      // Delete storage object if path available
      if (storagePath.isNotEmpty) {
        try {
          await _storage.ref().child(storagePath).delete();
        } catch (_) {
          // ignore storage delete errors (file might be missing)
        }
      }

      // Remove url from task attachments array
      await _firestore.collection('tasks').doc(taskId).update({
        'attachments': FieldValue.arrayRemove([url]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Delete metadata doc
      await docRef.delete();

      // Log history
      await _logTaskHistory(taskId, 'Attachment removed', {'url': url}, requestedBy);
    } catch (e) {
      throw Exception('Failed to delete attachment: $e');
    }
  }
}