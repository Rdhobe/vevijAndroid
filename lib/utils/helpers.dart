import 'package:intl/intl.dart';
import '../models/tasks/task_model.dart';
import 'dart:math';
class Helpers {
  // Date formatting
  static String formatDate(DateTime date, {String format = 'MMM dd, yyyy'}) {
    return DateFormat(format).format(date);
  }

  static String formatDateTime(DateTime date, {String format = 'MMM dd, yyyy HH:mm'}) {
    return DateFormat(format).format(date);
  }

  // Status color mapping
  static int statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 0xFFFFA000; // Amber
      case TaskStatus.inProgress:
        return 0xFF2196F3; // Blue
      case TaskStatus.completed:
        return 0xFF4CAF50; // Green
      case TaskStatus.cancelled:
        return 0xFFF44336; // Red
      // default:
      //   return 0xFF757575; // Grey
    }
  }

  // Priority color mapping
  static int priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 0xFF4CAF50; // Green
      case TaskPriority.medium:
        return 0xFFFFA000; // Amber
      case TaskPriority.high:
        return 0xFFFF5722; // Deep Orange
      case TaskPriority.critical:
        return 0xFFF44336; // Red
      case TaskPriority.urgent:
        return 0xFFF44336; // Red
      // default:
      //   return 0xFF757575; // Grey
    }
  }

  // Calculate days between dates
  static int calculateDaysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }

  // Check if task is overdue
  static bool isOverdue(TaskModel task) {
    return task.dueDate.isBefore(DateTime.now()) && 
           task.status != TaskStatus.completed;
  }

  // Get days remaining
  static int daysRemaining(TaskModel task) {
    final now = DateTime.now();
    return task.dueDate.difference(now).inDays;
  }

  // Format priority text
  static String priorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.critical:
        return 'Critical';
      case TaskPriority.urgent:
        return 'Urgent';
      // default:
      //   return 'Medium';
    }
  }

  // Format status text
  static String statusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
      // default:
      //   return 'Pending';
    }
  }

  // Get status from string
  static TaskStatus statusFromString(String status) {
    return TaskStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => TaskStatus.pending,
    );
  }

  // Get priority from string
  static TaskPriority priorityFromString(String priority) {
    return TaskPriority.values.firstWhere(
      (e) => e.name == priority.toLowerCase(),
      orElse: () => TaskPriority.medium,
    );
  }

  // Calculate progress percentage
  static double calculateProgress(List<TaskModel> tasks) {
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
    return completed / tasks.length;
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}