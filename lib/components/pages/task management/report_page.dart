import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/models/tasks/team_model.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/team_service.dart';
import 'package:vevij/utils/helpers.dart';
import 'package:vevij/models/tasks/user_team_role_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportPage extends StatefulWidget {
  final String? teamId;
  final TeamRole userRole;

  const ReportPage({
    super.key,
    this.teamId,
    required this.userRole,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedTeam;
  bool _isGenerating = false;
  List<TeamModel> _teams = [];
  List<TaskModel> _filteredTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final teams = await teamService.getTeamsList();
      
      setState(() {
        _teams = teams;
        _selectedTeam = widget.teamId ?? 'all';
        _isLoading = false;
      });
      
      // Load initial filtered tasks
      _loadFilteredTasks();
    } catch (e) {
      print('Error loading teams: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFilteredTasks() async {
    try {
      final taskService = Provider.of<TaskService>(context, listen: false);
      final allTasks = await taskService.streamAllTasks().first;
      
      setState(() {
        _filteredTasks = _applyFilters(allTasks);
      });
    } catch (e) {
      print('Error loading filtered tasks: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tasks: $e')),
      );
    }
  }

  List<TaskModel> _applyFilters(List<TaskModel> tasks) {
    var filtered = tasks;

    // Filter by team
    if (_selectedTeam != null && _selectedTeam != 'all') {
      filtered = filtered.where((task) => task.assignedTeamId == _selectedTeam).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((task) {
        final taskDate = task.createdAt;
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day).add(const Duration(days: 1));
        return taskDate.isAfter(start) && taskDate.isBefore(end);
      }).toList();
    }

    return filtered;
  }

  Map<String, dynamic> _calculateReportData(List<TaskModel> tasks) {
    final now = DateTime.now();
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).length;
    final overdueTasks = tasks.where((t) => Helpers.isOverdue(t)).length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;

    // Status distribution
    final statusDistribution = <String, int>{};
    for (final status in TaskStatus.values) {
      statusDistribution[status.name] = tasks.where((t) => t.status == status).length;
    }

    // Priority distribution
    final priorityDistribution = <String, int>{};
    for (final priority in TaskPriority.values) {
      priorityDistribution[priority.name] = tasks.where((t) => t.priority == priority).length;
    }

    // Monthly trend (last 6 months)
    final monthlyTrend = <String, int>{};
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM').format(month);
      monthlyTrend[monthKey] = tasks.where((t) =>
        t.status == TaskStatus.completed &&
        t.updatedAt.year == month.year &&
        t.updatedAt.month == month.month
      ).length;
    }

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'overdueTasks': overdueTasks,
      'completionRate': completionRate,
      'statusDistribution': statusDistribution,
      'priorityDistribution': priorityDistribution,
      'monthlyTrend': monthlyTrend,
    };
  }

  Future<void> _generatePDFReport() async {
    setState(() => _isGenerating = true);

    try {
      final reportData = _calculateReportData(_filteredTasks);
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Add header
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  text: 'Task Report',

                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Report Period: ${Helpers.formatDate(_startDate!)} to ${Helpers.formatDate(_endDate!)}',
                  style: pw.TextStyle(fontSize: 12),
                ),
                if (_selectedTeam != 'all')
                  pw.Text(
                    'Team: ${_getTeamName(_selectedTeam!)}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                pw.SizedBox(height: 30),
                
                // Summary Section
                pw.Header(level: 1, text: 'Summary'),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPDFStatCard('Total Tasks', reportData['totalTasks'].toString()),
                    _buildPDFStatCard('Completed', reportData['completedTasks'].toString()),
                    _buildPDFStatCard('Overdue', reportData['overdueTasks'].toString()),
                    _buildPDFStatCard('Completion Rate', '${reportData['completionRate']}%'),
                  ],
                ),
                pw.SizedBox(height: 30),
                
                // Task List
                pw.Header(level: 1, text: 'Task Details'),
                pw.SizedBox(height: 10),
                ..._buildTaskListPDF(),
              ],
            );
          },
        ),
      );

      // Save PDF
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/task_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File file = File(path);
      await file.writeAsBytes(await pdf.save());

      await OpenFile.open(path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF report generated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  pw.Widget _buildPDFStatCard(String title, String value) {
    return pw.Container(
      width: 100,
      height: 60,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(value, style:  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  List<pw.Widget> _buildTaskListPDF() {
    if (_filteredTasks.isEmpty) {
      return [pw.Text('No tasks found for the selected filters.')];
    }

    final widgets = <pw.Widget>[];
    
    // Table header
    widgets.add(
      pw.Row(
        children: [
          pw.Expanded(flex: 3, child: pw.Text('Title', style:  pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Status', style:  pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Priority', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Due Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
    
    widgets.add(pw.Divider());
    
    // Task rows
    for (final task in _filteredTasks.take(50)) { // Limit to 50 tasks for PDF
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  task.title.length > 30 ? '${task.title.substring(0, 30)}...' : task.title,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  Helpers.statusText(task.status),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  Helpers.priorityText(task.priority),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  Helpers.formatDate(task.dueDate),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_filteredTasks.length > 50) {
      widgets.add(pw.Text('... and ${_filteredTasks.length - 50} more tasks'));
    }
    
    return widgets;
  }

  Future<void> _exportToCSV() async {
    setState(() => _isGenerating = true);

    try {
      final List<List<dynamic>> csvData = [];
      
      // Add headers
      csvData.add([
        'Task ID',
        'Title',
        'Description',
        'Status',
        'Priority',
        'Category',
        'Due Date',
        'Created Date',
        'Assigned Team',
        'Assigned Count',
        'Estimated Hours',
        'Actual Hours',
      ]);
      
      // Add task data
      for (final task in _filteredTasks) {
        csvData.add([
          task.id,
          task.title,
          task.description,
          Helpers.statusText(task.status),
          Helpers.priorityText(task.priority),
          task.category.name,
          Helpers.formatDate(task.dueDate),
          Helpers.formatDate(task.createdAt),
          _getTeamName(task.assignedTeamId),
          task.assignedTo.length,
          task.estimatedHours,
          task.actualHours ?? '',
        ]);
      }

      // Convert to CSV
      final csv = const ListToCsvConverter().convert(csvData);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/task_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final File file = File(path);
      await file.writeAsString(csv);

      await OpenFile.open(path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export CSV: $e')),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _emailReport() async {
    try {
      // Generate CSV content for attachment
      final List<List<dynamic>> csvData = [];
      csvData.add(['Task Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}']);
      csvData.add(['Report Period', '${Helpers.formatDate(_startDate!)} to ${Helpers.formatDate(_endDate!)}']);
      if (_selectedTeam != 'all') {
        csvData.add(['Team', _getTeamName(_selectedTeam!)]);
      }
      csvData.add([]);
      
      // Add task headers
      csvData.add([
        'Title', 'Status', 'Priority', 'Due Date', 'Team', 'Assigned Count'
      ]);
      
      // Add task data
      for (final task in _filteredTasks.take(100)) { // Limit for email
        csvData.add([
          task.title,
          Helpers.statusText(task.status),
          Helpers.priorityText(task.priority),
          Helpers.formatDate(task.dueDate),
          _getTeamName(task.assignedTeamId),
          task.assignedTo.length,
        ]);
      }

      final csv = const ListToCsvConverter().convert(csvData);
      final csvEncoded = Uri.encodeComponent(csv);
      
      final subject = Uri.encodeComponent('Task Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
      final body = Uri.encodeComponent(
        'Please find the task report attached.\n\n'
        'Report Summary:\n'
        '- Period: ${Helpers.formatDate(_startDate!)} to ${Helpers.formatDate(_endDate!)}\n'
        '${_selectedTeam != 'all' ? '- Team: ${_getTeamName(_selectedTeam!)}\n' : ''}'
        '- Total Tasks: ${_filteredTasks.length}\n'
        '- Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}\n\n'
        'The CSV file contains detailed task information.'
      );
      
      // For email with attachment simulation, we'll include CSV data in body
      // In a real app, you'd use a proper email service with attachments
      final mailto = 'mailto:?subject=$subject&body=$body%0A%0A--- CSV Data ---%0A$csvEncoded';
      
      await launchUrl(Uri.parse(mailto));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open email: $e')),
      );
    }
  }

  String _getTeamName(String teamId) {
    if (teamId == 'all') return 'All Teams';
    final team = _teams.firstWhere((t) => t.id == teamId, orElse: () => TeamModel(
      id: teamId,
      name: 'Unknown Team',
      description: '',
      createdBy: '',
      memberIds: [],
      members: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    return team.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Reports'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters Section
                _buildFiltersSection(),
                
                // Report Preview
                Expanded(
                  child: _buildReportPreview(),
                ),
              ],
            ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Report Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Team Filter
            DropdownButtonFormField<String>(
              value: _selectedTeam,
              decoration: const InputDecoration(
                labelText: 'Team',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Teams')),
                ..._teams.map((team) {
                  return DropdownMenuItem<String>(
                    value: team.id,
                    child: Text(team.name),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() => _selectedTeam = value);
                _loadFilteredTasks();
              },
            ),
            
            const SizedBox(height: 16),
            
            // Date Range
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: 'Start Date',
                    selectedDate: _startDate,
                    onDateSelected: (date) {
                      setState(() => _startDate = date);
                      _loadFilteredTasks();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DatePickerField(
                    label: 'End Date',
                    selectedDate: _endDate,
                    onDateSelected: (date) {
                      setState(() => _endDate = date);
                      _loadFilteredTasks();
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            _isGenerating
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exportToCSV,
                          icon: const Icon(Icons.file_download),
                          label: const Text('Export CSV'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generatePDFReport,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Generate PDF'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _emailReport,
                          icon: const Icon(Icons.email),
                          label: const Text('Email'),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportPreview() {
    final reportData = _calculateReportData(_filteredTasks);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary Cards
          _buildSummaryCards(reportData),
          const SizedBox(height: 24),
          
          // Status Distribution
          _buildStatusDistribution(reportData),
          const SizedBox(height: 24),
          
          // Priority Distribution
          _buildPriorityDistribution(reportData),
          const SizedBox(height: 24),
          
          // Task List Preview
          _buildTaskListPreview(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> reportData) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _SummaryCard(
          title: 'Total Tasks',
          value: reportData['totalTasks'].toString(),
          color: Colors.blue,
          icon: Icons.task,
        ),
        _SummaryCard(
          title: 'Completed',
          value: reportData['completedTasks'].toString(),
          color: Colors.green,
          icon: Icons.check_circle,
        ),
        _SummaryCard(
          title: 'Overdue',
          value: reportData['overdueTasks'].toString(),
          color: Colors.red,
          icon: Icons.warning,
        ),
        _SummaryCard(
          title: 'Completion Rate',
          value: '${reportData['completionRate']}%',
          color: Colors.orange,
          icon: Icons.trending_up,
        ),
      ],
    );
  }

  Widget _buildStatusDistribution(Map<String, dynamic> reportData) {
    final statusData = reportData['statusDistribution'] as Map<String, int>;
    final total = reportData['totalTasks'] as int;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: statusData.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total * 100) : 0;
                return _DistributionRow(
                  label: _getStatusText(entry.key),
                  value: entry.value,
                  percentage: percentage.toInt(),
                  color: _getStatusColor(entry.key),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityDistribution(Map<String, dynamic> reportData) {
    final priorityData = reportData['priorityDistribution'] as Map<String, int>;
    final total = reportData['totalTasks'] as int;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Priority Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: priorityData.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total * 100) : 0;
                return _DistributionRow(
                  label: _getPriorityText(entry.key),
                  value: entry.value,
                  percentage: percentage.toInt(),
                  color: _getPriorityColor(entry.key),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListPreview() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Task List Preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${_filteredTasks.length} tasks'),
                  backgroundColor: Colors.blue.shade100,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _filteredTasks.isEmpty
                ? const Center(
                    child: Column(
                      children: [
                        Icon(Icons.task, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No tasks found for the selected filters',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _filteredTasks.take(10).map((task) => _TaskPreviewItem(task: task)).toList(),
                  ),
            if (_filteredTasks.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and ${_filteredTasks.length - 10} more tasks',
                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'inProgress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'inProgress': return Colors.blue;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'low': return 'Low';
      case 'medium': return 'Medium';
      case 'high': return 'High';
      case 'urgent': return 'Urgent';
      case 'critical': return 'Critical';
      default: return priority;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.red;
      case 'urgent': return Colors.purple;
      case 'critical': return Colors.deepPurple;
      default: return Colors.grey;
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final Function(DateTime?) onDateSelected;

  const _DatePickerField({
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            onDateSelected(date);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  selectedDate != null 
                      ? Helpers.formatDate(selectedDate!)
                      : 'Select date',
                  style: TextStyle(
                    color: selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final int value;
  final int percentage;
  final Color color;

  const _DistributionRow({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label),
          ),
          Text('$value (${percentage.toStringAsFixed(1)}%)'),
        ],
      ),
    );
  }
}

class _TaskPreviewItem extends StatelessWidget {
  final TaskModel task;

  const _TaskPreviewItem({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(task.status.name).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        Helpers.statusText(task.status),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getStatusColor(task.status.name),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task.priority.name).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        Helpers.priorityText(task.priority),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getPriorityColor(task.priority.name),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            Helpers.formatDate(task.dueDate),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'inProgress': return Colors.blue;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.red;
      case 'urgent': return Colors.purple;
      case 'critical': return Colors.deepPurple;
      default: return Colors.grey;
    }
  }
}