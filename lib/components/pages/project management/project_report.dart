  import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ProjectReportPage extends StatefulWidget {
  final String? specificProjectId;

  const ProjectReportPage({super.key, this.specificProjectId});

  @override
  State<ProjectReportPage> createState() => _ProjectReportPageState();
}

class _ProjectReportPageState extends State<ProjectReportPage> {
  // Filter states
  String _timeFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  String _reportType = 'overview';
  String _projectFilter = 'all';
  List<String> _selectedMetrics = ['progress', 'tasks', 'inventory', 'issues'];
  
  // Data states
  List<Map<String, dynamic>> _projectsData = [];
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isDisposed = false;

  // Chart data
  List<ChartData> _progressData = [];
  List<ChartData> _taskCompletionData = [];
  List<ChartData> _inventoryUsageData = [];
  @override
  void initState() {
    super.initState();
    _initializeFilters();
    _loadReportData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _initializeFilters() {
    if (widget.specificProjectId != null) {
      _projectFilter = widget.specificProjectId!;
    }
    
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
  }

  Future<void> _loadReportData() async {
    if (_isDisposed) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _fetchProjectsData();
      await _calculateAnalytics();
      await _prepareChartData();
    } catch (e) {
      print('Error loading report data: $e');
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (!_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchProjectsData() async {
    QuerySnapshot projectsSnapshot;
    
    if (_projectFilter == 'all') {
      projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .get();
    } else {
      projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where(FieldPath.documentId, isEqualTo: _projectFilter)
          .get();
    }

    List<Map<String, dynamic>> projectsData = [];

    for (var projectDoc in projectsSnapshot.docs) {
      final projectData = projectDoc.data() as Map<String, dynamic>;
      final projectId = projectDoc.id;

      final tasksData = await _getTasksData(projectId);
      final inventoryData = await _getInventoryData(projectId);
      final issuesData = await _getIssuesData(projectId);

      projectsData.add({
        'id': projectId,
        'name': projectData['name'] ?? 'Unnamed Project',
        'progress': (projectData['progress'] ?? 0).toDouble(),
        'status': projectData['status'] ?? 'Active',
        'startDate': projectData['startDate'],
        'endDate': projectData['endDate'],
        'totalTasks': tasksData['totalTasks'],
        'completedTasks': tasksData['completedTasks'],
        'inProgressTasks': tasksData['inProgressTasks'],
        'pendingTasks': tasksData['pendingTasks'],
        'inventoryStats': inventoryData,
        'issuesStats': issuesData,
        'lastUpdated': projectData['lastUpdated'] ?? Timestamp.now(),
      });
    }

    if (!_isDisposed) {
      setState(() => _projectsData = projectsData);
    }
  }

  Future<Map<String, dynamic>> _getTasksData(String projectId) async {
    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .get();

    int totalTasks = tasksSnapshot.docs.length;
    int completedTasks = 0;
    int inProgressTasks = 0;
    int pendingTasks = 0;

    for (var task in tasksSnapshot.docs) {
      final data = task.data();
      final handover = data['handover'] ?? false;
      final doorFrameHardware = data['doorFrameHardware'] ?? false;

      if (handover) {
        completedTasks++;
      } else if (doorFrameHardware) {
        inProgressTasks++;
      } else {
        pendingTasks++;
      }
    }

    return {
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'inProgressTasks': inProgressTasks,
      'pendingTasks': pendingTasks,
      'completionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0,
    };
  }

  Future<Map<String, dynamic>> _getInventoryData(String projectId) async {
    final inventorySnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('inventory')
        .get();

    int totalItems = inventorySnapshot.docs.length;
    int totalRequired = 0;
    int totalReceived = 0;
    int totalIssued = 0;
    int lowStockItems = 0;
    int outOfStockItems = 0;

    for (var item in inventorySnapshot.docs) {
      final data = item.data();
      final requiredQty = (data['requiredQty'] ?? 0).toInt();
      final receivedQty = (data['totalReceivedQty'] ?? 0).toInt();
      final issuedQty = (data['totalIssuedQty'] ?? 0).toInt();
      final balanceQty = (data['balanceQty'] ?? 0).toInt();

      totalRequired += requiredQty as int;
      totalReceived += receivedQty as int;
      totalIssued += issuedQty as int;

      if (balanceQty <= 0) {
        outOfStockItems++;
      } else if (balanceQty < requiredQty * 0.2) {
        lowStockItems++;
      }
    }

    return {
      'totalItems': totalItems,
      'totalRequired': totalRequired,
      'totalReceived': totalReceived,
      'totalIssued': totalIssued,
      'utilizationRate': totalReceived > 0 ? (totalIssued / totalReceived * 100) : 0,
      'fulfillmentRate': totalRequired > 0 ? (totalReceived / totalRequired * 100) : 0,
      'lowStockItems': lowStockItems,
      'outOfStockItems': outOfStockItems,
    };
  }

  Future<Map<String, dynamic>> _getIssuesData(String projectId) async {
    final issuesSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('issues')
        .get();

    int totalIssues = issuesSnapshot.docs.length;
    int openIssues = 0;
    int inProgressIssues = 0;
    int resolvedIssues = 0;
    int highPriorityIssues = 0;

    for (var issue in issuesSnapshot.docs) {
      final data = issue.data();
      final status = data['status'] ?? 'Open';
      final priority = data['priority'] ?? 'Medium';

      switch (status) {
        case 'Open':
          openIssues++;
          break;
        case 'In Progress':
          inProgressIssues++;
          break;
        case 'Resolved':
          resolvedIssues++;
          break;
      }

      if (priority == 'High') {
        highPriorityIssues++;
      }
    }

    return {
      'totalIssues': totalIssues,
      'openIssues': openIssues,
      'inProgressIssues': inProgressIssues,
      'resolvedIssues': resolvedIssues,
      'resolutionRate': totalIssues > 0 ? (resolvedIssues / totalIssues * 100) : 0,
      'highPriorityIssues': highPriorityIssues,
    };
  }

  Future<void> _calculateAnalytics() async {
    if (_projectsData.isEmpty || _isDisposed) return;

    int totalProjects = _projectsData.length;
    int activeProjects = _projectsData.where((p) => p['status'] == 'Active').length;
    int completedProjects = _projectsData.where((p) => p['progress'] == 100).length;
    
    double avgProgress = _projectsData.map((p) => p['progress'] as double).reduce((a, b) => a + b) / totalProjects;
    
    int totalTasks = _projectsData.map((p) => p['totalTasks'] as int).reduce((a, b) => a + b);
    int completedTasks = _projectsData.map((p) => p['completedTasks'] as int).reduce((a, b) => a + b);
    
    Map<String, dynamic> inventoryStats = _projectsData
        .map((p) => p['inventoryStats'] as Map<String, dynamic>)
        .fold({
          'totalItems': 0,
          'totalRequired': 0,
          'totalReceived': 0,
          'totalIssued': 0,
          'lowStockItems': 0,
          'outOfStockItems': 0,
        }, (acc, stats) {
          return {
            'totalItems': acc['totalItems'] + (stats['totalItems'] as int),
            'totalRequired': acc['totalRequired'] + (stats['totalRequired'] as int),
            'totalReceived': acc['totalReceived'] + (stats['totalReceived'] as int),
            'totalIssued': acc['totalIssued'] + (stats['totalIssued'] as int),
            'lowStockItems': acc['lowStockItems'] + (stats['lowStockItems'] as int),
            'outOfStockItems': acc['outOfStockItems'] + (stats['outOfStockItems'] as int),
          };
        });

    Map<String, dynamic> issuesStats = _projectsData
        .map((p) => p['issuesStats'] as Map<String, dynamic>)
        .fold({
          'totalIssues': 0,
          'openIssues': 0,
          'resolvedIssues': 0,
          'highPriorityIssues': 0,
        }, (acc, stats) {
          return {
            'totalIssues': acc['totalIssues'] + (stats['totalIssues'] as int),
            'openIssues': acc['openIssues'] + (stats['openIssues'] as int),
            'resolvedIssues': acc['resolvedIssues'] + (stats['resolvedIssues'] as int),
            'highPriorityIssues': acc['highPriorityIssues'] + (stats['highPriorityIssues'] as int),
          };
        });

    if (!_isDisposed) {
      setState(() {
        _analyticsData = {
          'totalProjects': totalProjects,
          'activeProjects': activeProjects,
          'completedProjects': completedProjects,
          'avgProgress': avgProgress,
          'totalTasks': totalTasks,
          'completedTasks': completedTasks,
          'taskCompletionRate': totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0,
          'inventoryStats': inventoryStats,
          'issuesStats': issuesStats,
          'inventoryUtilization': inventoryStats['totalReceived'] > 0 
              ? (inventoryStats['totalIssued'] / inventoryStats['totalReceived'] * 100) 
              : 0,
          'issueResolutionRate': issuesStats['totalIssues'] > 0
              ? (issuesStats['resolvedIssues'] / issuesStats['totalIssues'] * 100)
              : 0,
        };
      });
    }
  }

  Future<void> _prepareChartData() async {
    if (_isDisposed) return;

    _progressData = [
      ChartData('0-25%', _projectsData.where((p) => p['progress'] <= 25).length),
      ChartData('26-50%', _projectsData.where((p) => p['progress'] > 25 && p['progress'] <= 50).length),
      ChartData('51-75%', _projectsData.where((p) => p['progress'] > 50 && p['progress'] <= 75).length),
      ChartData('76-99%', _projectsData.where((p) => p['progress'] > 75 && p['progress'] < 100).length),
      ChartData('100%', _projectsData.where((p) => p['progress'] == 100).length),
    ];

    _taskCompletionData = [
      ChartData('Completed', _analyticsData['completedTasks'] ?? 0),
      ChartData('In Progress', _projectsData.map((p) => p['inProgressTasks'] as int).reduce((a, b) => a + b)),
      ChartData('Pending', _projectsData.map((p) => p['pendingTasks'] as int).reduce((a, b) => a + b)),
    ];

    final inventoryStats = _analyticsData['inventoryStats'] ?? {};
    _inventoryUsageData = [
      ChartData('Required', inventoryStats['totalRequired'] ?? 0),
      ChartData('Received', inventoryStats['totalReceived'] ?? 0),
      ChartData('Issued', inventoryStats['totalIssued'] ?? 0),
      ChartData('Balance', (inventoryStats['totalReceived'] ?? 0) - (inventoryStats['totalIssued'] ?? 0)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Project Analytics & Reports'),
        actions: [
          PopupMenuButton<String>(
              onSelected: (value) => _handleExportAction(value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                const PopupMenuItem(value: 'excel', child: Text('Export as Excel')),
                const PopupMenuItem(value: 'email', child: Text('Send via Email')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Export',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(isMobile, isTablet),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildReportContent(isMobile, isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Project Analytics & Reports',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!isMobile)
            PopupMenuButton<String>(
              onSelected: (value) => _handleExportAction(value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                const PopupMenuItem(value: 'excel', child: Text('Export as Excel')),
                const PopupMenuItem(value: 'email', child: Text('Send via Email')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Export',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          if (isMobile)
            IconButton(
              onPressed: () => _showExportOptions(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.download, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _handleExportAction('pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                _handleExportAction('excel');
              },
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Send via Email'),
              onTap: () {
                Navigator.pop(context);
                _handleExportAction('email');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: flutter.Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Time Filter - Responsive layout
          if (isMobile) ...[
            _buildMobileFilterSection(),
          ] else ...[
            _buildDesktopFilterSection(isTablet),
          ],
          
          // Metrics Selection for custom reports
          if (_reportType == 'custom') ...[
            const SizedBox(height: 12),
            const Text('Select Metrics:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildMetricChip('Progress', 'progress'),
                _buildMetricChip('Tasks', 'tasks'),
                _buildMetricChip('Inventory', 'inventory'),
                _buildMetricChip('Issues', 'issues'),
                _buildMetricChip('Financial', 'financial'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileFilterSection() {
    return Column(
      children: [
        // Time Period
        Row(
          children: [
            const Text('Time:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _timeFilter,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('This Week')),
                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                  DropdownMenuItem(value: 'quarter', child: Text('This Quarter')),
                  DropdownMenuItem(value: 'year', child: Text('This Year')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                ],
                onChanged: (value) => setState(() => _timeFilter = value!),
              ),
            ),
          ],
        ),
        if (_timeFilter == 'custom') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _selectStartDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _startDate != null 
                        ? DateFormat('dd/MM/yy').format(_startDate!)
                        : 'Start Date',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: _selectEndDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _endDate != null 
                        ? DateFormat('dd/MM/yy').format(_endDate!)
                        : 'End Date',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        
        // Report Type and Project
        Row(
          children: [
            const Text('Report:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _reportType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'overview', child: Text('Overview')),
                  DropdownMenuItem(value: 'detailed', child: Text('Detailed')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom')),
                ],
                onChanged: (value) => setState(() => _reportType = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Project:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: _projectFilter,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All Projects')),
                  ..._projectsData.map((project) => 
                    DropdownMenuItem(
                      value: project['id'],
                      child: Text(
                        project['name'],
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ),
                ],
                onChanged: (value) => setState(() => _projectFilter = value!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopFilterSection(bool isTablet) {
    return Column(
      children: [
        // Time Filter Row
        Row(
          children: [
            const Text('Time Period:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: _timeFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Time')),
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'week', child: Text('This Week')),
                DropdownMenuItem(value: 'month', child: Text('This Month')),
                DropdownMenuItem(value: 'quarter', child: Text('This Quarter')),
                DropdownMenuItem(value: 'year', child: Text('This Year')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
              ],
              onChanged: (value) => setState(() => _timeFilter = value!),
            ),
            if (_timeFilter == 'custom') ...[
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _selectStartDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_startDate != null 
                    ? DateFormat('dd/MM/yyyy').format(_startDate!)
                    : 'Start Date'
                ),
              ),
              TextButton.icon(
                onPressed: _selectEndDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_endDate != null 
                    ? DateFormat('dd/MM/yyyy').format(_endDate!)
                    : 'End Date'
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        
        // Report Type and Project Filter
        Row(
          children: [
            const Text('Report Type:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: _reportType,
              items: const [
                DropdownMenuItem(value: 'overview', child: Text('Overview Report')),
                DropdownMenuItem(value: 'detailed', child: Text('Detailed Report')),
                DropdownMenuItem(value: 'custom', child: Text('Custom Report')),
              ],
              onChanged: (value) => setState(() => _reportType = value!),
            ),
            const SizedBox(width: 32),
            const Text('Project:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: _projectFilter,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Projects')),
                ..._projectsData.map((project) => 
                  DropdownMenuItem(
                    value: project['id'],
                    child: Text(project['name']),
                  )
                ),
              ],
              onChanged: (value) => setState(() => _projectFilter = value!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricChip(String label, String value) {
    final isSelected = _selectedMetrics.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedMetrics.add(value);
          } else {
            _selectedMetrics.remove(value);
          }
        });
      },
    );
  }

  Widget _buildReportContent(bool isMobile, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: [
          // Summary Cards
          _buildSummaryCards(isMobile, isTablet),
          const SizedBox(height: 24),
          
          // Charts Section
          _buildChartsSection(isMobile, isTablet),
          const SizedBox(height: 24),
          
          // Detailed Data Tables
          _buildDetailedTables(isMobile),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isMobile, bool isTablet) {
    final crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.2 : 1.5,
      children: [
        _buildSummaryCard(
          'Total Projects',
          _analyticsData['totalProjects'].toString(),
          Icons.business_center,
          Colors.blue,
          isMobile,
        ),
        _buildSummaryCard(
          'Avg Progress',
          '${_analyticsData['avgProgress']?.toStringAsFixed(1) ?? '0'}%',
          Icons.trending_up,
          Colors.green,
          isMobile,
        ),
        _buildSummaryCard(
          'Task Completion',
          '${_analyticsData['taskCompletionRate']?.toStringAsFixed(1) ?? '0'}%',
          Icons.task_alt,
          Colors.orange,
          isMobile,
        ),
        _buildSummaryCard(
          'Inventory Utilization',
          '${_analyticsData['inventoryUtilization']?.toStringAsFixed(1) ?? '0'}%',
          Icons.inventory,
          Colors.purple,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isMobile ? 20 : 24),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isMobile ? 10 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(bool isMobile, bool isTablet) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Charts in responsive layout
            if (isMobile) ...[
              _buildMobileCharts(),
            ] else if (isTablet) ...[
              _buildTabletCharts(),
            ] else ...[
              _buildDesktopCharts(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCharts() {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: SfCircularChart(
            title: ChartTitle(text: 'Progress Distribution'),
            legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries>[
              DoughnutSeries<ChartData, String>(
                dataSource: _progressData,
                xValueMapper: (ChartData data, _) => data.x,
                yValueMapper: (ChartData data, _) => data.y,
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              )
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: SfCircularChart(
            title: ChartTitle(text: 'Task Status'),
            legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries>[
              PieSeries<ChartData, String>(
                dataSource: _taskCompletionData,
                xValueMapper: (ChartData data, _) => data.x,
                yValueMapper: (ChartData data, _) => data.y,
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              )
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 300,
          child: SfCartesianChart(
            title: ChartTitle(text: 'Inventory Overview'),
            primaryXAxis: CategoryAxis(),
            series: <CartesianSeries<ChartData, String>>[
              ColumnSeries<ChartData, String>(
                dataSource: _inventoryUsageData,
                xValueMapper: (ChartData data, _) => data.x,
                yValueMapper: (ChartData data, _) => data.y,
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletCharts() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 300,
                child: SfCircularChart(
                  title: ChartTitle(text: 'Progress Distribution'),
                  legend: Legend(isVisible: true),
                  series: <CircularSeries>[
                    DoughnutSeries<ChartData, String>(
                      dataSource: _progressData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 300,
                child: SfCircularChart(
                  title: ChartTitle(text: 'Task Status'),
                  legend: Legend(isVisible: true),
                  series: <CircularSeries>[
                    PieSeries<ChartData, String>(
                      dataSource: _taskCompletionData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: SfCartesianChart(
            title: ChartTitle(text: 'Inventory Overview'),
            primaryXAxis: CategoryAxis(),
            series: <CartesianSeries<ChartData, String>>[
              ColumnSeries<ChartData, String>(
                dataSource: _inventoryUsageData,
                xValueMapper: (ChartData data, _) => data.x,
                yValueMapper: (ChartData data, _) => data.y,
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopCharts() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 300,
                child: SfCircularChart(
                  title: ChartTitle(text: 'Progress Distribution'),
                  legend: Legend(isVisible: true),
                  series: <CircularSeries>[
                    DoughnutSeries<ChartData, String>(
                      dataSource: _progressData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    )
                  ],
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 300,
                child: SfCircularChart(
                  title: ChartTitle(text: 'Task Status'),
                  legend: Legend(isVisible: true),
                  series: <CircularSeries>[
                    PieSeries<ChartData, String>(
                      dataSource: _taskCompletionData,
                      xValueMapper: (ChartData data, _) => data.x,
                      yValueMapper: (ChartData data, _) => data.y,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: SfCartesianChart(
            title: ChartTitle(text: 'Inventory Overview'),
            primaryXAxis: CategoryAxis(),
            series: <CartesianSeries<ChartData, String>>[
              ColumnSeries<ChartData, String>(
                dataSource: _inventoryUsageData,
                xValueMapper: (ChartData data, _) => data.x,
                yValueMapper: (ChartData data, _) => data.y,
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedTables(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: isMobile ? 12 : 24,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 60,
                columns: [
                  DataColumn(
                    label: Text('Project', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  ),
                  DataColumn(
                    label: Text('Progress', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  ),
                  DataColumn(
                    label: Text('Tasks', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  ),
                  if (!isMobile) DataColumn(
                    label: Text('Inventory', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  ),
                  if (!isMobile) DataColumn(
                    label: Text('Issues', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  ),
                  DataColumn(
                    label: Text('Status', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                  ),
                ],
                rows: _projectsData.map((project) => DataRow(cells: [
                  DataCell(
                    Text(
                      project['name'],
                      style: TextStyle(fontSize: isMobile ? 11 : 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(Text(
                    '${project['progress']}%',
                    style: TextStyle(fontSize: isMobile ? 11 : 13),
                  )),
                  DataCell(Text(
                    '${project['completedTasks']}/${project['totalTasks']}',
                    style: TextStyle(fontSize: isMobile ? 11 : 13),
                  )),
                  if (!isMobile) DataCell(Text(
                    '${project['inventoryStats']['utilizationRate']?.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: isMobile ? 11 : 13),
                  )),
                  if (!isMobile) DataCell(Text(
                    '${project['issuesStats']['resolutionRate']?.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: isMobile ? 11 : 13),
                  )),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: project['status'] == 'Active' ? Colors.green[100] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        project['status'],
                        style: TextStyle(
                          color: project['status'] == 'Active' ? Colors.green[800] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                    ),
                  ),
                ])).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate && !_isDisposed) {
      setState(() => _startDate = picked);
    }
  }

  void _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate && !_isDisposed) {
      setState(() => _endDate = picked);
    }
  }

  void _handleExportAction(String action) async {
    if (_isDisposed) return;
    
    setState(() => _isGenerating = true);
    
    try {
      switch (action) {
        case 'pdf':
          await _generatePdfReport();
          break;
        case 'excel':
          await _generateExcelReport();
          break;
        case 'email':
          await _sendEmailReport();
          break;
      }
    } catch (e) {
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (!_isDisposed) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _generatePdfReport() async {
    final pdfDoc = pw.Document();
    
    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (pw.Context context) => [
          _buildPdfHeader(),
          _buildPdfSummary(),
          _buildPdfCharts(),
          _buildPdfDetailedTable(),
        ],
      ),
    );

    final bytes = await pdfDoc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'project_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildPdfHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Project Analytics Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Generated on: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Time Period: ${_getTimePeriodText()}',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfSummary() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPdfSummaryItem('Total Projects', _analyticsData['totalProjects'].toString()),
          _buildPdfSummaryItem('Avg Progress', '${_analyticsData['avgProgress']?.toStringAsFixed(1)}%'),
          _buildPdfSummaryItem('Task Completion', '${_analyticsData['taskCompletionRate']?.toStringAsFixed(1)}%'),
          _buildPdfSummaryItem('Inventory Utilization', '${_analyticsData['inventoryUtilization']?.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildPdfCharts() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text('Charts and Analytics', style: const pw.TextStyle(fontSize: 16)),
    );
  }

  pw.Widget _buildPdfDetailedTable() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Table(
        border: pw.TableBorder.all(),
        children: [
          pw.TableRow(
            children: [
              pw.Padding(child: pw.Text('Project Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
              pw.Padding(child: pw.Text('Progress', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
              pw.Padding(child: pw.Text('Tasks', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
              pw.Padding(child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: const pw.EdgeInsets.all(8)),
            ],
          ),
          ..._projectsData.map((project) => pw.TableRow(
            children: [
              pw.Padding(child: pw.Text(project['name']), padding: const pw.EdgeInsets.all(8)),
              pw.Padding(child: pw.Text('${project['progress']}%'), padding: const pw.EdgeInsets.all(8)),
              pw.Padding(child: pw.Text('${project['completedTasks']}/${project['totalTasks']}'), padding: const pw.EdgeInsets.all(8)),
              pw.Padding(child: pw.Text(project['status']), padding: const pw.EdgeInsets.all(8)),
            ],
          )).toList(),
        ],
      ),
    );
  }

  Future<void> _generateExcelReport() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Project Report'];

    // Add headers
    sheet.cell(CellIndex.indexByString('A1')).value =  TextCellValue('Project Analytics Report');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Generated on: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}');
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Time Period: ${_getTimePeriodText()}');

    // Add summary data
    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('Summary');
    sheet.cell(CellIndex.indexByString('A6')).value = TextCellValue('Total Projects');
    sheet.cell(CellIndex.indexByString('B6')).value = TextCellValue('${_analyticsData['totalProjects']}');

    // Add detailed data
    sheet.cell(CellIndex.indexByString('A8')).value =  TextCellValue('Project Details');
    final headers = ['Project Name', 'Progress', 'Tasks', 'Inventory Utilization', 'Issue Resolution', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 8)).value = TextCellValue(headers[i]);
    }

    for (int i = 0; i < _projectsData.length; i++) {
      final project = _projectsData[i];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 9 + i)).value = TextCellValue(project['name']);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 9 + i)).value = TextCellValue('${project['progress']}%');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 9 + i)).value = TextCellValue('${project['completedTasks']}/${project['totalTasks']}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 9 + i)).value = TextCellValue('${project['inventoryStats']['utilizationRate']?.toStringAsFixed(1)}%');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 9 + i)).value = TextCellValue('${project['issuesStats']['resolutionRate']?.toStringAsFixed(1)}%');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 9 + i)).value = TextCellValue(project['status']);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final Uint8List bytes = Uint8List.fromList(fileBytes);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'project_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
      );
    }
  }

  Future<void> _sendEmailReport() async {
    final reportText = _generateEmailReportText();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email functionality would be implemented with your email service')),
    );
  }

  String _generateEmailReportText() {
    final buffer = StringBuffer();
    buffer.writeln('PROJECT ANALYTICS REPORT');
    buffer.writeln('Generated on: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}');
    buffer.writeln('Time Period: ${_getTimePeriodText()}');
    buffer.writeln();
    buffer.writeln('SUMMARY:');
    buffer.writeln('Total Projects: ${_analyticsData['totalProjects']}');
    buffer.writeln('Average Progress: ${_analyticsData['avgProgress']?.toStringAsFixed(1)}%');
    buffer.writeln('Task Completion Rate: ${_analyticsData['taskCompletionRate']?.toStringAsFixed(1)}%');
    buffer.writeln();
    buffer.writeln('DETAILED REPORT:');
    
    for (var project in _projectsData) {
      buffer.writeln('${project['name']}: ${project['progress']}% progress');
    }
    
    return buffer.toString();
  }

  String _getTimePeriodText() {
    switch (_timeFilter) {
      case 'today':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'quarter':
        return 'This Quarter';
      case 'year':
        return 'This Year';
      case 'custom':
        return '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
      default:
        return 'All Time';
    }
  }
}

class ChartData {
  final String x;
  final int y;

  ChartData(this.x, this.y);
}