import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/tasks/task_model.dart';
import '../models/tasks/report_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate comprehensive report
  Future<ReportModel> generateReport({
    String? teamId,
    DateTime? start,
    DateTime? end,
    String? reportName = 'Task Report',
  }) async {
    try {
      Query query = _firestore.collection('tasks');
      
      // Apply filters
      if (teamId != null) {
        query = query.where('assignedTeamId', isEqualTo: teamId);
      }
      
      if (start != null && end != null) {
        query = query.where('createdAt', 
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          isLessThanOrEqualTo: Timestamp.fromDate(end),
        );
      }

      final snapshot = await query.get();
      final tasks = snapshot.docs.map((doc) => TaskModel.fromMap(doc.data() as Map<String, dynamic>)).toList();

      // Calculate statistics
      final summaryStats = await _calculateSummaryStats(tasks);
      final chartData = await _generateChartData(tasks);

      // Create report model
      final report = ReportModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        generatedBy: 'current_user_id', // This should come from auth
        generatedAt: DateTime.now(),
        filters: {
          'teamId': teamId,
          'startDate': start?.toIso8601String(),
          'endDate': end?.toIso8601String(),
        },
        summaryStats: summaryStats,
        chartData: chartData,
        reportName: reportName!,
        reportType: teamId != null ? 'Team Report' : 'Overall Report',
      );

      // Save report to Firestore
      await _firestore.collection('reports').doc(report.id).set(report.toMap());

      return report;
    } catch (e) {
      throw Exception('Failed to generate report: $e');
    }
  }

  // Calculate summary statistics
  Future<Map<String, dynamic>> _calculateSummaryStats(List<TaskModel> tasks) async {
    final now = DateTime.now();
    
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).length;
    final overdueTasks = tasks.where((t) => t.dueDate.isBefore(now) && t.status != TaskStatus.completed).length;
    
    // Calculate average completion time
    final completedTasksWithTime = tasks.where((t) => 
      t.status == TaskStatus.completed
    ).toList();
    
    final totalCompletionTime = completedTasksWithTime.fold<Duration>(
      Duration.zero,
      (prev, task) => prev + task.updatedAt.difference(task.createdAt),
    );
    
    final avgCompletionDays = completedTasksWithTime.isNotEmpty 
      ? totalCompletionTime.inDays / completedTasksWithTime.length 
      : 0;

    // Calculate completion rate per team
    final teamStats = <String, Map<String, dynamic>>{};
    for (final task in tasks) {
      if (!teamStats.containsKey(task.assignedTeamId)) {
        teamStats[task.assignedTeamId] = {
          'total': 0,
          'completed': 0,
          'teamName': task.assignedTeamId, // You might want to map this to actual team names
        };
      }
      
      final stats = teamStats[task.assignedTeamId]!;
      stats['total'] = stats['total'] + 1;
      if (task.status == TaskStatus.completed) {
        stats['completed'] = stats['completed'] + 1;
      }
    }

    // Calculate completion percentage for each team
    for (final teamId in teamStats.keys) {
      final stats = teamStats[teamId]!;
      stats['completionRate'] = (stats['completed'] / stats['total'] * 100).toStringAsFixed(1);
    }

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'overdueTasks': overdueTasks,
      'completionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100).toStringAsFixed(1) : '0',
      'avgCompletionDays': avgCompletionDays.toStringAsFixed(1),
      'teamStats': teamStats,
    };
  }

  // Generate chart data
  Future<Map<String, dynamic>> _generateChartData(List<TaskModel> tasks) async {
    // Status distribution
    final statusCount = <String, int>{};
    for (final status in TaskStatus.values) {
      statusCount[status.name] = tasks.where((t) => t.status == status).length;
    }

    // Priority distribution
    final priorityCount = <String, int>{};
    for (final priority in TaskPriority.values) {
      priorityCount[priority.name] = tasks.where((t) => t.priority == priority).length;
    }

    // Tasks per team
    final teamTaskCount = <String, int>{};
    for (final task in tasks) {
      teamTaskCount[task.assignedTeamId] = (teamTaskCount[task.assignedTeamId] ?? 0) + 1;
    }

    // Monthly completion trend (last 6 months)
    final monthlyCompletion = <String, int>{};
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month}';
      monthlyCompletion[monthKey] = tasks.where((t) =>
        t.status == TaskStatus.completed &&
        t.updatedAt.year == month.year &&
        t.updatedAt.month == month.month
      ).length;
    }

    return {
      'statusDistribution': statusCount,
      'priorityDistribution': priorityCount,
      'teamDistribution': teamTaskCount,
      'monthlyTrend': monthlyCompletion,
    };
  }

  // Export to CSV
  Future<String> exportToCSV(ReportModel report, List<TaskModel> tasks) async {
    final List<List<dynamic>> csvData = [];
    
    // Add headers
    csvData.add([
      'Task ID',
      'Title',
      'Description',
      'Assigned Team',
      'Status',
      'Priority',
      'Due Date',
      'Created At',
      'Updated At'
    ]);
    
    // Add task data
    for (final task in tasks) {
      csvData.add([
        task.id,
        task.title,
        task.description,
        task.assignedTeamId,
        task.status.name,
        task.priority.name,
        task.dueDate.toIso8601String(),
        task.createdAt.toIso8601String(),
        task.updatedAt.toIso8601String(),
      ]);
    }
    
    // Convert to CSV
    final csv = const ListToCsvConverter().convert(csvData);
    return csv;
  }

  // Generate PDF (placeholder)
  Future<pw.Document> generatePDF(ReportModel report, List<TaskModel> tasks) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, text: report.reportName),
              pw.Text('Generated on: ${report.generatedAt}'),
              pw.SizedBox(height: 20),
              pw.Text('Summary Statistics:'),
              pw.Text('Total Tasks: ${report.summaryStats['totalTasks']}'),
              pw.Text('Completed Tasks: ${report.summaryStats['completedTasks']}'),
              pw.Text('Overdue Tasks: ${report.summaryStats['overdueTasks']}'),
              pw.Text('Completion Rate: ${report.summaryStats['completionRate']}%'),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }

  // Stream previous reports
  Stream<List<ReportModel>> streamReports() {
    return _firestore
        .collection('reports')
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportModel.fromMap(doc.data()))
            .toList());
  }
}