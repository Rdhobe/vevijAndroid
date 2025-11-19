import 'package:vevij/components/imports.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';


class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailsPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _issuesTabController;
  Map<String, dynamic>? projectData;
  String? _previewType;
  Map<String, dynamic>? _previewData;
  bool _isGenerating = false;
  bool isLoading = true;
  String _searchQuery = '';
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _issuesTabController = TabController(
      length: 2,
      vsync: this,
    ); // Issues sub-tabs
    _loadProjectData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _issuesTabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();
      // update project data
      int totalTasks = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .get()
          .then((snapshot) => snapshot.docs.length);
      int doorsCompletedTasks = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .where('doorFrameHardware', isEqualTo: true)
          .get()
          .then((snapshot) => snapshot.docs.length);
      int architraveCompletedTasks = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .where('architrave', isEqualTo: true)
          .get()
          .then((snapshot) => snapshot.docs.length);
      int handoverCompletedTasks = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .where('handover', isEqualTo: true)
          .get()
          .then((snapshot) => snapshot.docs.length);
      double progress =
          ((doorsCompletedTasks +
                  architraveCompletedTasks +
                  handoverCompletedTasks) /
              totalTasks) *
          100;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({
            'progress': progress.toInt(),
            'lastUpdated': FieldValue.serverTimestamp(),
            'totalTasks': totalTasks,
            'doorFrameHardware': doorsCompletedTasks,
            'architrave': architraveCompletedTasks,
            'handover': handoverCompletedTasks,
          });
      if (doc.exists) {
        setState(() {
          projectData = doc.data();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading project: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF6D28D9), // deep purple background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDashboardTab(),
                          _buildFeedTab(),
                          _buildTasksTab(), // New Tasks tab
                          _buildInventoryTab(),
                          _buildIssuesTab(),
                          _buildReportsTab(),
                          // _buildMembersTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Overview Cards
          const Text(
            'Project Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Overall Progress Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${projectData?['progress'] ?? 0}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: (projectData?['progress'] ?? 0) / 100.0,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Text(
                      '${projectData?['progress'] ?? 0}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Total Tasks Summary
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('tasks')
                .snapshots(),
            builder: (context, tasksSnapshot) {
              if (!tasksSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final tasks = tasksSnapshot.data!.docs;
              int totalTasks = tasks.length;
              int completedTasks = 0;
              int inProgressTasks = 0;
              int pendingTasks = 0;

              // Count task statuses based on handover completion
              for (var task in tasks) {
                final data = task.data() as Map<String, dynamic>;
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

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Tasks',
                          totalTasks.toString(),
                          Icons.task,
                          Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Completed',
                          completedTasks.toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'In Progress',
                          inProgressTasks.toString(),
                          Icons.schedule,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Pending',
                          pendingTasks.toString(),
                          Icons.pending,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),
// Category-wise Inventory
const Text(
  'Category-wise Inventory',
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 16),

StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('projects')
      .doc(widget.projectId)
      .collection('inventory')
      .snapshots(),
  builder: (context, inventorySnapshot) {
    if (!inventorySnapshot.hasData) {
      return Center(child: CircularProgressIndicator());
    }

    // Group inventory by material name
    Map<String, Map<String, dynamic>> inventoryStats = {};

    for (var item in inventorySnapshot.data!.docs) {
      final data = item.data() as Map<String, dynamic>;
      final materialName = data['materialName'] ?? 'Unknown';
      final receivedQty = data['receivedQty'] ?? 0;
      final requiredQty = data['requiredQty'] ?? 0;
      final usedQty = data['usedQty'] ?? 0;
      final totalIssueQty = data['totalIssuedQty'] ?? 0;
      final totalReceivedQty = data['totalReceivedQty'] ?? 0;
      final balIssueQty = data['balIssueQty'] ?? 0;
      final balanceQty = data['balanceQty'] ?? 0;
      final uom = data['uom'] ?? 'PCS';

      if (!inventoryStats.containsKey(materialName)) {
        inventoryStats[materialName] = {
          'receivedQty': 0,
          'requiredQty': 0,
          'usedQty': 0,
          'totalIssuedQty': 0,
          'totalReceivedQty': 0,
          'balIssueQty': 0,
          'balanceQty': 0,
          'uom': uom,
          'items': [], // Store individual inventory items for details
        };
      }

      // Add item details for drilling down
      inventoryStats[materialName]!['items'].add({
        'id': item.id,
        'data': data,
      });

      inventoryStats[materialName]!['receivedQty'] =
          (inventoryStats[materialName]!['receivedQty'] ?? 0) + receivedQty;
      inventoryStats[materialName]!['requiredQty'] =
          (inventoryStats[materialName]!['requiredQty'] ?? 0) + requiredQty;
      inventoryStats[materialName]!['usedQty'] =
          (inventoryStats[materialName]!['usedQty'] ?? 0) + usedQty;
      inventoryStats[materialName]!['totalIssuedQty'] =
          (inventoryStats[materialName]!['totalIssuedQty'] ?? 0) + totalIssueQty;
      inventoryStats[materialName]!['totalReceivedQty'] =
          (inventoryStats[materialName]!['totalReceivedQty'] ?? 0) + totalReceivedQty;
      inventoryStats[materialName]!['balIssueQty'] =
          (inventoryStats[materialName]!['balIssueQty'] ?? 0) + balIssueQty;
      inventoryStats[materialName]!['balanceQty'] =
          (inventoryStats[materialName]!['balanceQty'] ?? 0) + balanceQty;
    }

    return Column(
      children: inventoryStats.entries.map((entry) {
        final materialName = entry.key;
        final stats = entry.value;
        final receivedQty = stats['receivedQty'] ?? 0;
        final requiredQty = stats['requiredQty'] ?? 0;
        final usedQty = stats['usedQty'] ?? 0;
        final totalIssueQty = stats['totalIssuedQty'] ?? 0;
        final totalReceivedQty = stats['totalReceivedQty'] ?? 0;
        final balIssueQty = stats['balIssueQty'] ?? 0;
        final balanceQty = stats['balanceQty'] ?? 0;
        final uom = stats['uom'] ?? 'PCS';
        final items = stats['items'] as List;
        final availableQty = receivedQty - usedQty;
        final usageRate = receivedQty > 0 ? (usedQty / receivedQty) : 0.0;
        final fulfillmentRate = requiredQty > 0 ? (receivedQty / requiredQty) : 0.0;

        return InkWell(
          onTap: () => _showInventoryDetails(
            context,
            materialName,
            items,
            stats,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: flutter.Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              materialName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: availableQty <= 0
                            ? Colors.red[100]
                            : availableQty < requiredQty * 0.2
                            ? Colors.orange[100]
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        availableQty <= 0
                            ? 'Out of Stock'
                            : availableQty < requiredQty * 0.2
                            ? 'Low Stock'
                            : 'In Stock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: availableQty <= 0
                              ? Colors.red[700]
                              : availableQty < requiredQty * 0.2
                              ? Colors.orange[700]
                              : Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Usage Progress Bar
                Row(
                  children: [
                    Text(
                      'Usage: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: usageRate,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          usageRate > 0.8
                              ? Colors.red
                              : usageRate > 0.5
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(usageRate * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: usageRate > 0.8
                            ? Colors.red
                            : usageRate > 0.5
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Fulfillment Progress Bar
                Row(
                  children: [
                    Text(
                      'Fulfillment: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: fulfillmentRate > 1.0 ? 1.0 : fulfillmentRate,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fulfillmentRate >= 1.0
                              ? Colors.green
                              : fulfillmentRate >= 0.5
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(fulfillmentRate * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: fulfillmentRate >= 1.0
                            ? Colors.green
                            : fulfillmentRate >= 0.5
                            ? Colors.orange
                            : Colors.red,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Stats chips
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildInventoryStatChip(
                      'Required',
                      '$requiredQty $uom',
                      Color(0xFF3B82F6),
                    ),
                    _buildInventoryStatChip(
                      'Received',
                      '$receivedQty $uom',
                      Colors.blue,
                    ),
                    _buildInventoryStatChip(
                      'Used',
                      '$usedQty $uom',
                      Colors.green,
                    ),
                    _buildInventoryStatChip(
                      'Available',
                      '$availableQty $uom',
                      availableQty <= 0 ? Colors.red : Colors.purple,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  },
),
          const SizedBox(height: 32),
          // Installation Status by Category
const Text(
  'Installation Status by Category',
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 16),

StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('projects')
      .doc(widget.projectId)
      .collection('tasks')
      .snapshots(),
  builder: (context, tasksSnapshot) {
    if (!tasksSnapshot.hasData) {
      return Center(child: CircularProgressIndicator());
    }

    // Calculate installation status by material group
    Map<String, Map<String, dynamic>> installationStats = {};

    for (var task in tasksSnapshot.data!.docs) {
      final data = task.data() as Map<String, dynamic>;
      final materialGroup = data['materialGroup'] ?? 'Unknown';

      if (!installationStats.containsKey(materialGroup)) {
        installationStats[materialGroup] = {
          'total': 0,
          'doorFrameHardware': 0,
          'architrave': 0,
          'handover': 0,
          'tasks': [], // Store task details for drilling down
        };
      }

      // Add task details to the group
      installationStats[materialGroup]!['tasks'].add({
        'id': task.id,
        'data': data,
      });

      installationStats[materialGroup]!['total'] =
          installationStats[materialGroup]!['total']! +
          ((data['qty'] ?? 1) as int);

      // Check each installation phase completion based on boolean flags
      if (data['doorFrameHardware'] == true) {
        installationStats[materialGroup]!['doorFrameHardware'] =
            installationStats[materialGroup]!['doorFrameHardware']! +
            ((data['qty'] ?? 1) as int);
      }
      if (data['architrave'] == true) {
        installationStats[materialGroup]!['architrave'] =
            installationStats[materialGroup]!['architrave']! +
            ((data['qty'] ?? 1) as int);
      }
      if (data['handover'] == true) {
        installationStats[materialGroup]!['handover'] =
            installationStats[materialGroup]!['handover']! +
            ((data['qty'] ?? 1) as int);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Material Group',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Door+Frame\n+Hardware',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Architrave',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Handover',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Table Rows - Now clickable
          ...installationStats.entries.map((entry) {
            final materialGroup = entry.key;
            final stats = entry.value;
            final total = stats['total']!;
            final doorFrameHardware = stats['doorFrameHardware']!;
            final architrave = stats['architrave']!;
            final handover = stats['handover']!;
            final tasks = stats['tasks'] as List;

            return InkWell(
              onTap: () => _showInstallationDetails(
                context, 
                materialGroup, 
                tasks, 
                total, 
                doorFrameHardware, 
                architrave, 
                handover
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: flutter.Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  materialGroup,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: total > 0 ? handover / total : 0,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              handover == total
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Text(
                        total.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text(
                            '$doorFrameHardware/$total',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: doorFrameHardware == total
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${total > 0 ? ((doorFrameHardware / total) * 100).toInt() : 0}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text(
                            '$architrave/$total',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: architrave == total
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${total > 0 ? ((architrave / total) * 100).toInt() : 0}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text(
                            '$handover/$total',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: handover == total
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${total > 0 ? ((handover / total) * 100).toInt() : 0}%',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  },
),
          
          const SizedBox(height: 32),

          // Recent Activity
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('feed')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: flutter.Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          data['type'] == 'completed'
                              ? Icons.check_circle
                              : data['type'] == 'inventory'
                              ? Icons.inventory
                              : Icons.update,
                          size: 16,
                          color: data['type'] == 'completed'
                              ? Colors.green
                              : data['type'] == 'inventory'
                              ? Colors.blue
                              : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] ?? 'Update',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (data['timestamp'] != null)
                                Text(
                                  _formatTimestamp(
                                    data['timestamp'] as Timestamp,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
// Add this method to your class (outside the build method)
void _showInventoryDetails(
  BuildContext context,
  String materialName,
  List items,
  Map<String, dynamic> stats,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          materialName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inventory Details',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInventorySummaryCard(
                      'Required',
                      '${stats['requiredQty']} ${stats['uom']}',
                      Icons.assignment,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInventorySummaryCard(
                      'Received',
                      '${stats['receivedQty']} ${stats['uom']}',
                      Icons.input,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInventorySummaryCard(
                      'Issued',
                      '${stats['totalIssuedQty']} ${stats['uom']}',
                      Icons.output,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInventorySummaryCard(
                      'Available',
                      '${stats['balanceQty']} ${stats['uom']}',
                      Icons.inventory_2,
                      stats['balanceQty'] <= 0 ? Colors.red : Colors.purple,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tabbed View
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey[600],
                        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        tabs: [
                          Tab(text: 'Received'),
                          Tab(text: 'Issued'),
                          Tab(text: 'Summary'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildReceivedTab(items, scrollController),
                          _buildIssuedTab(items, scrollController),
                          _buildSummaryTab(items, stats, scrollController),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildInventorySummaryCard(String title, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: flutter.Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget _buildReceivedTab(List items, ScrollController scrollController) {
  List<Map<String, dynamic>> allReceivedEntries = [];
  
  for (var item in items) {
    final data = item['data'] as Map<String, dynamic>;
    final receivedEntries = data['receivedEntries'] as List? ?? [];
    final materialName = data['materialName'] ?? 'Unknown';
    
    for (var entry in receivedEntries) {
      allReceivedEntries.add({
        ...entry,
        'materialName': materialName,
        'itemId': item['id'],
      });
    }
  }

  // Sort by date (newest first)
  allReceivedEntries.sort((a, b) {
    try {
      final dateA = DateTime.parse(a['date'].toString().split('.').reversed.join('-'));
      final dateB = DateTime.parse(b['date'].toString().split('.').reversed.join('-'));
      return dateB.compareTo(dateA);
    } catch (e) {
      return 0;
    }
  });

  if (allReceivedEntries.isEmpty) {
    return _buildEmptyState('No received entries found', Icons.input);
  }

  return ListView.builder(
    controller: scrollController,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    itemCount: allReceivedEntries.length,
    itemBuilder: (context, index) {
      final entry = allReceivedEntries[index];
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: flutter.Border.all(color: Colors.green.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.input,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Challan: ${entry['challanNo'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry['qty'] ?? 0} PCS',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Date: ${entry['date'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildIssuedTab(List items, ScrollController scrollController) {
  List<Map<String, dynamic>> allIssuedEntries = [];
  
  for (var item in items) {
    final data = item['data'] as Map<String, dynamic>;
    final issuedEntries = data['issuedEntries'] as List? ?? [];
    final materialName = data['materialName'] ?? 'Unknown';
    
    for (var entry in issuedEntries) {
      allIssuedEntries.add({
        ...entry,
        'materialName': materialName,
        'itemId': item['id'],
      });
    }
  }

  // Sort by date (newest first)
  allIssuedEntries.sort((a, b) {
    try {
      final dateA = DateTime.parse(a['date'].toString().split('.').reversed.join('-'));
      final dateB = DateTime.parse(b['date'].toString().split('.').reversed.join('-'));
      return dateB.compareTo(dateA);
    } catch (e) {
      return 0;
    }
  });

  if (allIssuedEntries.isEmpty) {
    return _buildEmptyState('No issued entries found', Icons.output);
  }

  return ListView.builder(
    controller: scrollController,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    itemCount: allIssuedEntries.length,
    itemBuilder: (context, index) {
      final entry = allIssuedEntries[index];
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: flutter.Border.all(color: Colors.orange.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.output,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Challan: ${entry['challanNo'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry['qty'] ?? 0} PCS',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contractor: ${entry['contractorName'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Date: ${entry['date'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildSummaryTab(List items, Map<String, dynamic> stats, ScrollController scrollController) {
  return SingleChildScrollView(
    controller: scrollController,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.blue[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildOverviewStat(
                      'Total Required',
                      '${stats['requiredQty']} ${stats['uom']}',
                      Icons.assignment,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOverviewStat(
                      'Total Received',
                      '${stats['totalReceivedQty']} ${stats['uom']}',
                      Icons.input,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildOverviewStat(
                      'Total Issued',
                      '${stats['totalIssuedQty']} ${stats['uom']}',
                      Icons.output,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildOverviewStat(
                      'Balance Available',
                      '${stats['balanceQty']} ${stats['uom']}',
                      Icons.inventory_2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Progress Indicators
        _buildProgressSection('Fulfillment Rate', 
          stats['requiredQty'] > 0 ? (stats['totalReceivedQty'] / stats['requiredQty']) : 0,
          Colors.green),
        
        const SizedBox(height: 16),
        
        _buildProgressSection('Usage Rate',
          stats['totalReceivedQty'] > 0 ? (stats['totalIssuedQty'] / stats['totalReceivedQty']) : 0,
          Colors.orange),

        const SizedBox(height: 20),

        // Item Details
        Text(
          'Item Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        ...items.map((item) {
          final data = item['data'] as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: flutter.Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Item ID: ${item['id']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      'Updated: ${data['updatedAt'] != null ? _formatTimestamp(data['updatedAt']) : 'N/A'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildMiniStatChip('Required', '${data['requiredQty']} ${data['uom']}', Colors.blue),
                    _buildMiniStatChip('Received', '${data['receivedQty']} ${data['uom']}', Colors.green),
                    _buildMiniStatChip('Issued', '${data['totalIssuedQty']} ${data['uom']}', Colors.orange),
                    _buildMiniStatChip('Balance', '${data['balanceQty']} ${data['uom']}', Colors.purple),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  );
}

Widget _buildOverviewStat(String title, String value, IconData icon) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 12,
        ),
      ),
    ],
  );
}

Widget _buildProgressSection(String title, double progress, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: progress > 1.0 ? 1.0 : progress,
        backgroundColor: Colors.grey[200],
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    ],
  );
}

Widget _buildMiniStatChip(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: flutter.Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

Widget _buildEmptyState(String message, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    ),
  );
}

// Helper method to format timestamp
String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return 'N/A';
  
  try {
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.parse(timestamp);
    } else {
      return 'Invalid date';
    }
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  } catch (e) {
    return 'Invalid date';
  }
}
void _showInstallationDetails(
  BuildContext context,
  String materialGroup,
  List tasks,
  int total,
  int doorFrameHardware,
  int architrave,
  int handover,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          materialGroup,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$handover of $total completed',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildProgressSummaryCard(
                      'Door+Frame+Hardware',
                      doorFrameHardware,
                      total,
                      Icons.door_front_door,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProgressSummaryCard(
                      'Architrave',
                      architrave,
                      total,
                      Icons.design_services,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProgressSummaryCard(
                      'Handover',
                      handover,
                      total,
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Task List
            Expanded(
              child: DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey[600],
                        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        tabs: [
                          Tab(text: 'All'),
                          Tab(text: 'Pending'),
                          Tab(text: 'In Progress'),
                          Tab(text: 'Completed'),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildTaskList(tasks, 'all', scrollController),
                          _buildTaskList(tasks, 'pending', scrollController),
                          _buildTaskList(tasks, 'in_progress', scrollController),
                          _buildTaskList(tasks, 'completed', scrollController),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildProgressSummaryCard(String title, int completed, int total, IconData icon, Color color) {
  final percentage = total > 0 ? (completed / total * 100).round() : 0;
  
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: flutter.Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          '$completed/$total',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _buildTaskList(List tasks, String filter, ScrollController scrollController) {
  List filteredTasks = tasks.where((task) {
    final data = task['data'] as Map<String, dynamic>;
    final handover = data['handover'] ?? false;
    final doorFrameHardware = data['doorFrameHardware'] ?? false;
    
    switch (filter) {
      case 'pending':
        return !doorFrameHardware;
      case 'in_progress':
        return doorFrameHardware && !handover;
      case 'completed':
        return handover;
      default:
        return true;
    }
  }).toList();

  if (filteredTasks.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No ${filter == 'all' ? '' : filter} tasks found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  return ListView.builder(
    controller: scrollController,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    itemCount: filteredTasks.length,
    itemBuilder: (context, index) {
      final task = filteredTasks[index];
      final data = task['data'] as Map<String, dynamic>;
      final handover = data['handover'] ?? false;
      final doorFrameHardware = data['doorFrameHardware'] ?? false;
      final architrave = data['architrave'] ?? false;
      
      String status;
      Color statusColor;
      IconData statusIcon;
      
      if (handover) {
        status = 'Completed';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      } else if (doorFrameHardware) {
        status = 'In Progress';
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
      } else {
        status = 'Pending';
        statusColor = Colors.red;
        statusIcon = Icons.pending;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: flutter.Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['flatNo'].toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['location'] ?? 'No location specified',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress indicators
            Row(
              children: [
                _buildMiniProgressIndicator(
                  'Door+Frame+Hardware',
                  doorFrameHardware,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildMiniProgressIndicator(
                  'Architrave',
                  architrave,
                  Colors.orange,
                ),
                const SizedBox(width: 12),
                _buildMiniProgressIndicator(
                  'Handover',
                  handover,
                  Colors.green,
                ),
              ],
            ),
            
            if (data['qty'] != null && data['qty'] > 1) ...[
              const SizedBox(height: 8),
              Text(
                'Quantity: ${data['qty']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

Widget _buildMiniProgressIndicator(String label, bool isCompleted, Color color) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: isCompleted ? color : Colors.grey[200],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    ),
  );
}
  // Helper method for inventory stat chips
  Widget _buildInventoryStatChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
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
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.projectName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (projectData != null)
                  Text(
                    'Status: ${projectData!['status'] ?? 'Active'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
              ],
            ),
          ),
          //refresh button
          IconButton(
            onPressed: () {
              // Refresh the project data
              _loadProjectData();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${projectData?['progress'] ?? 0}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF3B82F6),
        labelColor: const Color(0xFF3B82F6),
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Feed'),
          Tab(text: 'Tasks'),
          Tab(text: 'Inventory'),
          Tab(text: 'Issues & Requests'),
          Tab(text: 'Documentations'),
          // Tab(text: 'Members'),
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('feed')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rss_feed, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('No updates yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final feedItem = snapshot.data!.docs[index];
            final data = feedItem.data() as Map<String, dynamic>;
            return _buildFeedItem(
              data['title'] ?? 'Task Update',
              data['description'] ?? '',
              data['timestamp'] as Timestamp?,
              data['type'] ?? 'update',
            );
          },
        );
      },
    );
  } 
  Widget _buildFeedItem(
    String title,
    String description,
    Timestamp? timestamp,
    String type,
  ) {
    final IconData icon = type == 'completed'
        ? Icons.check_circle
        : Icons.update;
    final Color color = type == 'completed' ? Colors.green : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: Colors.grey[600])),
                ],
                if (timestamp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF3B82F6),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Inventory List'),
              Tab(text: 'Statistics'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildInventoryList(), _buildInventoryStats()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Calculate overall stats
        int totalItems = snapshot.data!.docs.length;
        int totalUsed = 0;
        int totalBalance = 0;
        int totalReceived = 0;
        int totalRequired = 0;

        // Category-wise stats
        Map<String, Map<String, int>> categoryStats = {};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final materialName = (data['materialName'] ?? '')
              .toString()
              .toLowerCase();
          final category = _categorizeItem(materialName);

          // Overall stats
          totalUsed += (data['totalIssuedQty'] ?? 0) as int;
          totalReceived += (data['totalReceivedQty'] ?? 0) as int;
          totalBalance += (data['balIssueQty'] ?? 0) as int;
          totalRequired += (data['requiredQty'] ?? 0) as int;

          // Category stats
          if (!categoryStats.containsKey(category)) {
            categoryStats[category] = {
              'items': 0,
              'required': 0,
              'received': 0,
              'issued': 0,
              'balance': 0,
            };
          }

          categoryStats[category]!['items'] =
              categoryStats[category]!['items']! + 1;
          categoryStats[category]!['required'] =
              categoryStats[category]!['required']! +
              ((data['requiredQty'] ?? 0) as double).toInt();
          categoryStats[category]!['received'] =
              categoryStats[category]!['received']! +
              ((data['totalReceivedQty'] ?? 0) as int);
          categoryStats[category]!['issued'] =
              categoryStats[category]!['issued']! +
              ((data['totalIssuedQty'] ?? 0) as int);
          categoryStats[category]!['balance'] =
              categoryStats[category]!['balance']! +
              ((data['balIssueQty'] ?? 0) as int);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Summary Section
              _buildOverallSummary(
                totalItems,
                totalRequired,
                totalReceived,
                totalUsed,
                totalBalance,
              ),

              const SizedBox(height: 24),

              // Progress Overview
              _buildProgressOverview(totalRequired, totalReceived, totalUsed),

              const SizedBox(height: 24),

              // Category-wise Breakdown
              Text(
                'Category Breakdown',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),

              ...categoryStats.entries
                  .map((entry) => _buildCategoryCard(entry.key, entry.value))
                  .toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverallSummary(
    int totalItems,
    int totalRequired,
    int totalReceived,
    int totalUsed,
    int totalBalance,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: Colors.indigo, size: 28),
              const SizedBox(width: 12),
              Text(
                'Project Overview',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Items',
                  totalItems.toString(),
                  Icons.inventory_2,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Required',
                  totalRequired.toString(),
                  Icons.assignment,
                  Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Received',
                  totalReceived.toString(),
                  Icons.input,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Issued',
                  totalUsed.toString(),
                  Icons.output,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressOverview(
    int totalRequired,
    int totalReceived,
    int totalUsed,
  ) {
    double receivedProgress = totalRequired > 0
        ? (totalReceived / totalRequired)
        : 0;
    double usedProgress = totalReceived > 0 ? (totalUsed / totalReceived) : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.purple, size: 24),
              const SizedBox(width: 12),
              Text(
                'Progress Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Material Reception Progress
          _buildProgressBar(
            'Material Reception',
            '${(receivedProgress * 100).toStringAsFixed(1)}%',
            receivedProgress,
            Colors.green,
            '$totalReceived of $totalRequired received',
          ),

          const SizedBox(height: 16),

          // Material Usage Progress
          _buildProgressBar(
            'Material Usage',
            '${(usedProgress * 100).toStringAsFixed(1)}%',
            usedProgress,
            Colors.orange,
            '$totalUsed of $totalReceived used',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    String title,
    String percentage,
    double progress,
    Color color,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Text(
              percentage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildCategoryCard(String category, Map<String, int> stats) {
    final categoryInfo = _getCategoryInfo(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: flutter.Border.all(
          color: categoryInfo['color'].withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryInfo['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categoryInfo['icon'],
                  color: categoryInfo['color'],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '${stats['items']} items',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              _buildCategoryMiniStat(
                '${stats['balance']}',
                'Available',
                Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Category Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildCategoryStatItem(
                  'Required',
                  '${stats['required']}',
                  Icons.assignment_outlined,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildCategoryStatItem(
                  'Received',
                  '${stats['received']}',
                  Icons.input,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildCategoryStatItem(
                  'Issued',
                  '${stats['issued']}',
                  Icons.output,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryMiniStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Helper function to categorize items
  String _categorizeItem(String materialName) {
    materialName = materialName.toLowerCase().trim();

    // Hardware & Fasteners
    if (materialName.contains('screw') ||
        materialName.contains('bolt') ||
        materialName.contains('nail') ||
        materialName.contains('fastener') ||
        materialName.contains('rivet')) {
      return 'Hardware & Fasteners';
    }

    // Adhesives & Sealants
    if (materialName.contains('glue') ||
        materialName.contains('adhesive') ||
        materialName.contains('sealant') ||
        materialName.contains('tape')) {
      return 'Adhesives & Sealants';
    }

    // Foam & Insulation
    if (materialName.contains('foam') ||
        materialName.contains('insulation') ||
        materialName.contains('padding')) {
      return 'Foam & Insulation';
    }

    // Trim & Finishing
    if (materialName.contains('architrave') ||
        materialName.contains('trim') ||
        materialName.contains('molding') ||
        materialName.contains('finish')) {
      return 'Trim & Finishing';
    }

    // Electrical
    if (materialName.contains('wire') ||
        materialName.contains('cable') ||
        materialName.contains('electrical') ||
        materialName.contains('switch') ||
        materialName.contains('socket')) {
      return 'Electrical';
    }

    // Plumbing
    if (materialName.contains('pipe') ||
        materialName.contains('plumbing') ||
        materialName.contains('valve') ||
        materialName.contains('fitting')) {
      return 'Plumbing';
    }

    // Doors & Frames
    if (materialName.contains('door') ||
        materialName.contains('frame') ||
        materialName.contains('jamb') ||
        materialName.contains('threshold') ||
        materialName.contains('hinge') ||
        materialName.contains('handle') ||
        materialName.contains('lock') ||
        materialName.contains('knob')) {
      return 'Doors & Frames';
    }

    // Default category
    return 'General Materials';
  }

  // Helper function to get category info
  Map<String, dynamic> _getCategoryInfo(String category) {
    switch (category) {
      case 'Hardware & Fasteners':
        return {'icon': Icons.construction, 'color': Colors.grey[700]};
      case 'Adhesives & Sealants':
        return {'icon': Icons.format_color_fill, 'color': Colors.amber[700]};
      case 'Foam & Insulation':
        return {'icon': Icons.layers, 'color': Colors.blue[700]};
      case 'Trim & Finishing':
        return {'icon': Icons.auto_fix_high, 'color': Colors.purple[700]};
      case 'Electrical':
        return {'icon': Icons.electrical_services, 'color': Colors.yellow[700]};
      case 'Plumbing':
        return {'icon': Icons.plumbing, 'color': Colors.cyan[700]};
      case 'Doors & Frames':
        return {'icon': Icons.door_sliding, 'color': Colors.brown[700]};
      default:
        return {'icon': Icons.inventory_2, 'color': Colors.indigo[700]};
    }
  }

  Widget _buildInventoryList() {
    return Column(
      children: [
        // Add Item and More Options Button
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addInventoryItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showUpdateInventoryDialog,
                icon: const Icon(Icons.update),
                label: const Text('Update Inventory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (String value) {
                  switch (value) {
                    case 'upload_excel':
                      _uploadInventoryExcel();
                      break;
                    case 'download_report':
                      _downloadInventoryReport();
                      break;
                    case 'download_format':
                      _downloadExcelFormat();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'upload_excel',
                    child: Row(
                      children: [
                        Icon(Icons.upload_file, size: 20),
                        SizedBox(width: 8),
                        Text('Upload Excel'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'download_report',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 8),
                        Text('Download Report'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'download_format',
                    child: Row(
                      children: [
                        Icon(Icons.file_download, size: 20),
                        SizedBox(width: 8),
                        Text('Download Format'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Inventory List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('inventory')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No inventory items',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final item = snapshot.data!.docs[index];
                  final data = item.data() as Map<String, dynamic>;

                  return _buildInventoryCard(
                    data['materialName'] ?? 'Unknown Item',
                    data['requiredQty'] ?? 0,
                    data['totalReceivedQty'] ?? 0,
                    data['totalIssuedQty'] ?? 0,
                    data['uom'] ?? 'PCS',
                    data['receivedEntries'] ?? [],
                    data['issuedEntries'] ?? [],
                    List<Map<String, dynamic>>.from(data['editHistory'] ?? []), // Edit history
                    (materialName) => _handleEditItem(materialName, item.id), // Edit callback
                    (materialName) => _handleDeleteItem(materialName, item.id), // Delete callback
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
void _handleEditItem(String materialName, String itemId) async{
  if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.editInventoryProject)) 
  {
  _showEditDialog(materialName, itemId);
  }
  else{
    await ErrorDialog.show(
      context,
      title: 'Permission Denied', 
      message: 'You do not have permission to edit inventory items.');
  }
}
void _handleDeleteItem(String materialName, String itemId) async {
  if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.deleteInventoryProject)) 
  {
  // Show confirmation dialog and delete item
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$materialName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteInventoryItem(itemId);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  }
  else{
    await ErrorDialog.show(
      context,
      title: 'Permission Denied', 
      message: 'You do not have permission to delete inventory items.');
  }
}

// Method to delete inventory item from Firestore
void _deleteInventoryItem(String itemId) async {
  try {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('inventory')
        .doc(itemId)
        .delete();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error deleting item: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Method to show edit dialog (you'll need to implement this based on your requirements)
void _showEditDialog(String materialName, String itemId) {
  // Implement your edit dialog/page here
  // This could navigate to an edit page or show a dialog with edit form
  print('Edit item: $materialName with ID: $itemId');
  
  // Example: Navigate to edit page
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EditInventoryPage(
        projectId: widget.projectId,
        itemId: itemId,
        materialName: materialName,
      ),
    ),
  );
}

  Future<void> _addInventoryItem() async {
    final nameController = TextEditingController();
    final requiredQtyController = TextEditingController();
    final receivedQtyController = TextEditingController();
    final usedQtyController = TextEditingController();
    final uomController = TextEditingController();
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.addInventoryProject)) 
        {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Inventory Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Material Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: requiredQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Required Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: receivedQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Received Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usedQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Used Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: uomController,
                decoration: const InputDecoration(
                  labelText: 'Unit of Measurement',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., PCS, KG, M',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(widget.projectId)
                    .collection('inventory')
                    .add({
                      'materialName': nameController.text,
                      'requiredQty':
                          int.tryParse(requiredQtyController.text) ?? 0,
                      'receivedQty':
                          int.tryParse(receivedQtyController.text) ?? 0,
                      'usedQty': int.tryParse(usedQtyController.text) ?? 0,
                      'uom': uomController.text.isNotEmpty
                          ? uomController.text
                          : 'PCS',
                      'addedAt': Timestamp.now(),
                    });

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Inventory item added successfully!'),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );}
    else{
      await ErrorDialog.show(
        context,
        title: 'Permission Denied', 
        message: 'You do not have permission to add inventory items.');
    }
  }
  Widget _buildStatChip(String label, int value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

  // Modified Excel upload to only import material name and required qty
  Future<void> _processInventoryExcel(Sheet table) async {
    final batch = FirebaseFirestore.instance.batch();
    final inventoryRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('inventory');

    // Find the material data starting from row with "MATERIAL NAME"
    int materialStartRow = -1;
    for (int i = 0; i < table.maxRows; i++) {
      final cellValue = table
          .cell(CellIndex.indexByString('A${i + 1}'))
          .value
          ?.toString();
      if (cellValue == 'MATERIAL NAME') {
        materialStartRow = i + 1; // Next row after header
        break;
      }
    }

    if (materialStartRow == -1) {
      throw Exception(
        'Material data not found in Excel file. Please ensure the header "MATERIAL NAME" exists in column A.',
      );
    }

    // Process each material row (only material name and required qty)
    for (int row = materialStartRow; row < table.maxRows; row++) {
      final materialNameCell = table.cell(
        CellIndex.indexByString('A${row + 1}'),
      );
      final requiredQtyCell = table.cell(
        CellIndex.indexByString('B${row + 1}'),
      );

      if (materialNameCell.value == null) continue;

      final materialName = materialNameCell.value.toString().trim();
      if (materialName.isEmpty) continue;

      final requiredQty =
          int.tryParse(requiredQtyCell.value?.toString() ?? '0') ?? 0;

      // Create document with only basic info
      final docRef = inventoryRef.doc();
      batch.set(docRef, {
        'materialName': materialName,
        'requiredQty': requiredQty,
        'totalReceivedQty': 0, // Will be updated by supervisor
        'totalIssuedQty': 0, // Will be updated by supervisor
        'balanceQty': requiredQty, // Initially equals required qty
        'balIssueQty': 0, // Initially zero
        'uom': 'PCS', // Default UOM
        'receivedEntries': [], // Empty initially
        'issuedEntries': [], // Empty initially
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Updated download format function (simplified for material name and required qty only)
  Future<void> _downloadExcelFormat() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Inventory'];

      // Set up the simplified format structure
      // Row 1: Headers
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
        'MATERIAL NAME',
      );
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
        'REQUIRED QTY',
      );

      // Sample data
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'FASTNER',
      );
      sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue('800');

      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('FOAM');
      sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue('30');

      sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
        'NOVA GLUE',
      );
      sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue('30');

      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(
        'BLUE SCREW',
      );
      sheet.cell(CellIndex.indexByString('B5')).value = TextCellValue('800');

      sheet.cell(CellIndex.indexByString('A6')).value = TextCellValue(
        'ARCHITRAVE',
      );
      sheet.cell(CellIndex.indexByString('B6')).value = TextCellValue('500');

      // Save and download
      final fileBytes = excel.save();
      if (fileBytes != null) {
        await _downloadFile(fileBytes, 'inventory_import_template.xlsx');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading format: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // File download helper
  Future<void> _downloadFile(List<int> bytes, String filename) async {
    // Mobile download
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);

    // Share the file
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: filename,
    );
  }

 Widget _buildInventoryCard(
  String materialName,
  int requiredQty,
  int totalReceivedQty,
  int totalIssueQty,
  String uom,
  List receivedEntries,
  List issuedEntries,
  List<Map<String, dynamic>>? editHistory, // New parameter for edit history
  Function(String)? onEdit,
  Function(String)? onDelete,
) {
  final balanceQty = requiredQty - totalReceivedQty;
  final balIssueQty = totalReceivedQty - totalIssueQty;

  final Color balanceColor = balanceQty <= 0 ? Colors.green : Colors.red;
  final Color issueBalanceColor = balIssueQty > 0 ? Colors.green : Colors.red;

  return GestureDetector(
    onTap: () {
      // Navigate to details page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InventoryDetailsPage(
            materialName: materialName,
            requiredQty: requiredQty,
            totalReceivedQty: totalReceivedQty,
            totalIssueQty: totalIssueQty,
            uom: uom,
            receivedEntries: receivedEntries,
            issuedEntries: issuedEntries,
            editHistory: editHistory ?? [],
          ),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  materialName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: issueBalanceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Available: $balIssueQty $uom',
                      style: TextStyle(
                        color: issueBalanceColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                    onSelected: (String value) {
                      if (value == 'edit') {
                        onEdit?.call(materialName);
                      } else if (value == 'delete') {
                        onDelete?.call(materialName);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // First Row - Required, Total Received, Balance
          Row(
            children: [
              _buildStatChip('Required', requiredQty, Colors.blue),
              const SizedBox(width: 8),
              _buildStatChip('Total Received', totalReceivedQty, Colors.green),
              const SizedBox(width: 8),
              _buildStatChip('Balance', balanceQty.abs(), balanceColor),
            ],
          ),
          const SizedBox(height: 8),

          // Second Row - Total Issue, Balance Issue
          Row(
            children: [
              _buildStatChip('Total Issue', totalIssueQty, Colors.orange),
              const SizedBox(width: 8),
              _buildStatChip('Bal Issue', balIssueQty, issueBalanceColor),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Tap to view details indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Tap to view details',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  void _createInventoryReport(Sheet sheet, List<QueryDocumentSnapshot> docs) {
    try { 
    // Project info
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'INVENTORY REPORT',
    );
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
      'Generated on: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
    );

    // Headers
    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
      'MATERIAL NAME',
    );
    sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue(
      'REQUIRED QTY',
    );
    sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue(
      'TOTAL RECEIVED QTY',
    );
    sheet.cell(CellIndex.indexByString('D4')).value = TextCellValue(
      'BALANCE QTY',
    );
    sheet.cell(CellIndex.indexByString('E4')).value = TextCellValue(
      'TOTAL ISSUE QTY',
    );
    sheet.cell(CellIndex.indexByString('F4')).value = TextCellValue(
      'AVAILABLE QTY',
    );

    // Add material data
    for (int i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>;
      final row = 5 + i;

      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        data['materialName'] ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(
        data['requiredQty'] ?? 0,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        data['totalReceivedQty'] ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = IntCellValue(
        data['balanceQty'] ?? 0,
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = IntCellValue(
        data['totalIssuedQty'] ?? 0,
      );
      sheet.cell(CellIndex.indexByString('F$row')).value = IntCellValue(
        data['balIssueQty'] ?? 0,
      );
    }

    // Add detailed entries section
    int currentRow = 6 + docs.length;

    for (int i = 0; i < docs.length; i++) {
      final data = docs[i].data() as Map<String, dynamic>;
      final materialName = data['materialName'] ?? '';
      final receivedEntries = data['receivedEntries'] ?? [];
      final issuedEntries = data['issuedEntries'] ?? [];

      if (receivedEntries.isNotEmpty || issuedEntries.isNotEmpty) {
        currentRow += 2;
        sheet.cell(CellIndex.indexByString('A$currentRow')).value =
            TextCellValue('MATERIAL: $materialName');
        currentRow++;

        if (receivedEntries.isNotEmpty) {
          sheet.cell(CellIndex.indexByString('A$currentRow')).value =
              TextCellValue('RECEIVED ENTRIES:');
          currentRow++;
          sheet.cell(CellIndex.indexByString('A$currentRow')).value =
              TextCellValue('Challan No');
          sheet.cell(CellIndex.indexByString('B$currentRow')).value =
              TextCellValue('Date');
          sheet.cell(CellIndex.indexByString('C$currentRow')).value =
              TextCellValue('Quantity');
          currentRow++;

          for (var entry in receivedEntries) {
            sheet.cell(CellIndex.indexByString('A$currentRow')).value =
                TextCellValue(entry['challanNo'] ?? '');
            sheet.cell(CellIndex.indexByString('B$currentRow')).value =
                TextCellValue(entry['date'] ?? '');
            sheet.cell(CellIndex.indexByString('C$currentRow')).value =
                IntCellValue(entry['qty'] ?? 0);
            currentRow++;
          }
        }

        if (issuedEntries.isNotEmpty) {
          currentRow++;
          sheet.cell(CellIndex.indexByString('A$currentRow')).value =
              TextCellValue('ISSUED ENTRIES:');
          currentRow++;
          sheet.cell(CellIndex.indexByString('A$currentRow')).value =
              TextCellValue('Challan No');
          sheet.cell(CellIndex.indexByString('B$currentRow')).value =
              TextCellValue('Date');
          sheet.cell(CellIndex.indexByString('C$currentRow')).value =
              TextCellValue('Quantity');
          sheet.cell(CellIndex.indexByString('D$currentRow')).value =
              TextCellValue('Contractor');
          currentRow++;

          for (var entry in issuedEntries) {
            sheet.cell(CellIndex.indexByString('A$currentRow')).value =
                TextCellValue(entry['challanNo'] ?? '');
            sheet.cell(CellIndex.indexByString('B$currentRow')).value =
                TextCellValue(entry['date'] ?? '');
            sheet.cell(CellIndex.indexByString('C$currentRow')).value =
                IntCellValue(entry['qty'] ?? 0);
            sheet.cell(CellIndex.indexByString('D$currentRow')).value =
                TextCellValue(entry['contractorName'] ?? '');
            currentRow++;
          }
        }
      }
    }
    }catch(e){
      print('Error creating inventory report: $e');
    }
  }

  // Download report function
  Future<void> _downloadInventoryReport() async {
    try {
      // Fetch inventory data
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .get();

      var excel = Excel.createExcel();
      Sheet sheet = excel['Inventory Report'];

      // Create report
      _createInventoryReport(sheet, snapshot.docs);

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await _downloadFile(fileBytes, 'inventory_report_$timestamp.xlsx');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fixed Upload Excel function
  Future<void> _uploadInventoryExcel() async {
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.addInventoryProject)) 
        {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      print('File picker result: $result');

      if (result != null && result.files.single.path != null) {
        final file = result.files.first;

        // Read bytes from file path instead of using file.bytes
        Uint8List bytes;
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          // Read file from path
          final dartFile = File(file.path!);
          bytes = await dartFile.readAsBytes();
        } else {
          throw Exception('Unable to read file data');
        }

        // Parse Excel file
        var excel = Excel.decodeBytes(bytes);
        var table = excel.tables[excel.tables.keys.first];

        if (table == null) {
          throw Exception('No data found in Excel file');
        }

        // Process the Excel data (only material name and required qty)
        await _processInventoryExcel(table);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error uploading inventory: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading inventory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    }else{
      await ErrorDialog.show(
        context,
        title: 'Permission Denied', 
        message: 'You do not have permission to upload inventory items.');
    }
  }

  // Show Update Inventory Dialog
  void _showUpdateInventoryDialog() async {
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.updateInventoryProject)) 
        {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: UpdateInventoryDialog(projectId: widget.projectId),
          ),
        );
      },
    );
    }
    else{
      await ErrorDialog.show(
        context,
        title: 'Permission Denied', 
        message: 'You do not have permission to update inventory items.');
    }
  }

  // INTEGRATED ISSUES TAB - This replaces your existing _buildIssuesTab()
  Widget _buildIssuesTab() {
    _issuesTabController = TabController(length: 2, vsync: this);
    return Column(
      children: [
        TabBar(
          controller: _issuesTabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Issues'),
            Tab(text: 'Requests'),
          ],
        ),
        Expanded(
          child: Stack(
            children: [
              TabBarView(
                controller: _issuesTabController,
                children: [_buildIssuesList(), _buildRequestsList()],
              ),
              // Floating Action Button that changes based on active tab
              Positioned(bottom: 16, right: 16, child: _buildTabSpecificFAB()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabSpecificFAB() {
    return AnimatedBuilder(
      animation: _issuesTabController,
      builder: (context, child) {
        final isIssuesTab = _issuesTabController.index == 0;
        return FloatingActionButton.extended(
          onPressed: isIssuesTab ? _showAddIssueDialog : _showAddRequestDialog,
          backgroundColor: const Color(0xFF3B82F6),
          icon: Icon(isIssuesTab ? Icons.add : Icons.request_page),
          label: Text(isIssuesTab ? 'Add Issue' : 'Send Request'),
        );
      },
    );
  }

  void _showAddIssueDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final commentController = TextEditingController();
    String selectedPriority = 'Medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report New Issue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Issue Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Comment',
                    border: OutlineInputBorder(),
                    hintText: 'Add any additional details...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Low', 'Medium', 'High'].map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Text(priority),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPriority = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter issue title')),
                  );
                  return;
                }

                if (descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter description')),
                  );
                  return;
                }

                try {
                  final issueRef = await FirebaseFirestore.instance
                      .collection('projects')
                      .doc(widget.projectId)
                      .collection('issues')
                      .add({
                        'title': titleController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'priority': selectedPriority,
                        'status': 'Open',
                        'createdAt': Timestamp.now(),
                        'updatedAt': Timestamp.now(),
                      });

                  // Add initial comment if provided
                  if (commentController.text.trim().isNotEmpty) {
                    await issueRef.collection('comments').add({
                      'comment': commentController.text.trim(),
                      'createdAt': Timestamp.now(),
                      'type': 'initial',
                    });
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Issue reported successfully'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Report Issue'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRequestDialog() {
    final materialController = TextEditingController();
    final quantityController = TextEditingController();
    final commentController = TextEditingController();
    String selectedUom = 'PCS';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Material Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: materialController,
                  decoration: const InputDecoration(
                    labelText: 'Material Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Request Details',
                    border: OutlineInputBorder(),
                    hintText: 'Add specifications, urgency, etc...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedUom,
                  decoration: const InputDecoration(
                    labelText: 'Unit of Measure',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                        'PCS',
                        'KG',
                        'M',
                        'L',
                        'M²',
                        'M³',
                        'BOX',
                        'SET',
                        'TON',
                        'ROLL',
                      ].map((uom) {
                        return DropdownMenuItem(value: uom, child: Text(uom));
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedUom = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (materialController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter material name')),
                  );
                  return;
                }

                final quantity = int.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid quantity'),
                    ),
                  );
                  return;
                }

                try {
                  final requestRef = await FirebaseFirestore.instance
                      .collection('projects')
                      .doc(widget.projectId)
                      .collection('requests')
                      .add({
                        'materialName': materialController.text.trim(),
                        'quantity': quantity,
                        'uom': selectedUom,
                        'status': 'Pending',
                        'createdAt': Timestamp.now(),
                        'updatedAt': Timestamp.now(),
                      });

                  // Add initial comment if provided
                  if (commentController.text.trim().isNotEmpty) {
                    await requestRef.collection('comments').add({
                      'comment': commentController.text.trim(),
                      'createdAt': Timestamp.now(),
                      'type': 'initial',
                    });
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request sent successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIssueDetails(DocumentSnapshot issue) {
    final data = issue.data() as Map<String, dynamic>;
    print(data);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => IssueDetailView(
          issue: issue,
          projectId: widget.projectId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showRequestDetails(DocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    print(data);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => RequestDetailView(
          request: request,
          projectId: widget.projectId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Widget _buildIssuesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('issues')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.report_problem, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No issues reported',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the "Add Issue" button to report an issue',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 80,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final issue = snapshot.data!.docs[index];
            final data = issue.data() as Map<String, dynamic>;

            return _buildIssueCard(
              issue,
              data['title'] ?? 'Issue',
              data['description'] ?? '',
              data['priority'] ?? 'Medium',
              data['status'] ?? 'Open',
              data['createdAt'] as Timestamp?,
            );
          },
        );
      },
    );
  }

  Widget _buildIssueCard(
    DocumentSnapshot issue,
    String title,
    String description,
    String priority,
    String status,
    Timestamp? createdAt,
  ) {
    final Color priorityColor = priority == 'High'
        ? Colors.red
        : priority == 'Medium'
        ? Colors.orange
        : Colors.green;
    final Color statusColor = status == 'Resolved'
        ? Colors.green
        : status == 'In Progress'
        ? Colors.orange
        : Colors.red;

    return GestureDetector(
      onTap: () => _showIssueDetails(issue),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: flutter.Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priority,
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description.length > 100
                    ? '${description.substring(0, 100)}...'
                    : description,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (createdAt != null)
                  Text(
                    'Reported: ${_formatTimestamp(createdAt)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                Text(
                  'Tap to view details',
                  style: TextStyle(
                    color: const Color(0xFF3B82F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.request_page, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('No requests made', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text(
                  'Tap the "Send Request" button to create a material request',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 80,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final request = snapshot.data!.docs[index];
            final data = request.data() as Map<String, dynamic>;

            return _buildRequestCard(
              request,
              data['materialName'] ?? 'Material Request',
              data['quantity'] ?? 0,
              data['uom'] ?? 'PCS',
              data['status'] ?? 'Pending',
              data['createdAt'] as Timestamp?,
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard(
    DocumentSnapshot request,
    String materialName,
    int quantity,
    String uom,
    String status,
    Timestamp? createdAt,
  ) {
    final Color statusColor = status == 'Approved'
        ? Colors.green
        : status == 'Processing'
        ? Colors.orange
        : status == 'Rejected'
        ? Colors.red
        : Colors.blue;

    return GestureDetector(
      onTap: () => _showRequestDetails(request),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: flutter.Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    materialName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Quantity: $quantity $uom',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (createdAt != null)
                  Text(
                    'Requested: ${_formatTimestamp(createdAt)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                Text(
                  'Tap to view details',
                  style: TextStyle(
                    color: const Color(0xFF3B82F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildReportsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Export and Dashboard Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateInventoryReport,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Generate Inventory Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateInstallationReport,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generate Installation Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateEntryRecipe,
                  icon: const Icon(Icons.receipt),
                  label: const Text('Generate Entry Recipe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 238, 125, 18),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateIssueRecipe,
                  icon: const Icon(Icons.assignment),
                  label: const Text('Generate Material Issue Recipe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Preview Section
          if (_previewType != null && _previewData != null)
            _buildPreviewSection(),

          // Previous Reports List
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Previous Reports & Recipes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.projectId)
                        .collection('reports')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No reports generated yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final report = snapshot.data!.docs[index];
                          final data = report.data() as Map<String, dynamic>;

                          return ListTile(
                            leading: Icon(
                              _getIconForReportType(data['type'] ?? ''),
                              color: const Color(0xFF3B82F6),
                            ),
                            title: Text(data['name'] ?? 'Report'),
                            subtitle: Text(
                              _formatTimestamp(data['createdAt'] as Timestamp?),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () => _viewReport(report.id, data),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _downloadFromStorage(data),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preview: $_previewType',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _previewType = null;
                      _previewData = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                border: flutter.Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildPreviewContent(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showExportDialog(),
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _saveToFirebase(),
                  icon: const Icon(Icons.save),
                  label: const Text('Save to Reports'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    switch (_previewType) {
      case 'Inventory Report':
        return _buildInventoryPreview();
      case 'Installation Report':
        return _buildInstallationPreview();
      case 'Entry Recipe':
        return _buildEntryRecipePreview();
      case 'Issue Recipe':
        return _buildIssueRecipePreview();
      default:
        return const Center(child: Text('No preview available'));
    }
  }

  Widget _buildInventoryPreview() {
    final inventoryData =
        _previewData!['inventoryData'] as List<DocumentSnapshot>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: Colors.yellow[300],
            padding: const EdgeInsets.all(8),
            child: const Center(
              child: Text(
                'Inventory Report Format',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Project Info
          Container(
            color: Colors.yellow[100],
            child: Table(
              border: TableBorder.all(),
              children: [
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'NAME OF PROJECT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(widget.projectName),
                    ),
                  ],
                ),
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'NAME OF CUSTOMER',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('VIMAN NAGAR SHUBH VENTURES LLP'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Materials Table
          Container(
            decoration: BoxDecoration(border: flutter.Border.all()),
            child: Column(
              children: [
                // Table Header
                Container(
                  color: Colors.yellow[200],
                  child: const Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'MATERIAL NAME',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'REQUIRED QTY',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'TOTAL RECEIVED QTY',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'BAL QTY',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Data
                ...inventoryData.take(3).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Container(
                    decoration: const BoxDecoration(
                      border: flutter.Border(bottom: BorderSide()),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(data['materialName'] ?? ''),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('${data['requiredQty'] ?? 0}'),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('${data['totalReceivedQty'] ?? 0}'),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('${data['balanceQty'] ?? 0}'),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          if (inventoryData.length > 3)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '... and ${inventoryData.length - 3} more items',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstallationPreview() {
    final tasksData = _previewData!['tasksData'] as List<DocumentSnapshot>;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: Colors.yellow[300],
            padding: const EdgeInsets.all(8),
            child: const Center(
              child: Text(
                'FLAT WISE & PROJECT WISE INSTALLATION REPORT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Project Info
          Text('PROJECT NAME: ${widget.projectName}'),
          Text('CUSTOMER NAME: ${projectData?['customerName']}'),
          Text(
            'REPORT DATE: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
          ),
          const SizedBox(height: 16),
          // Installation Table Preview
          Container(
            decoration: BoxDecoration(border: flutter.Border.all()),
            child: Column(
              children: [
                // Header Row
                Container(
                  color: Colors.yellow[200],
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            'BUILDING',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            'FLAT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            'MATERIAL GROUP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            'TOTAL%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Data Rows
                ...List.generate(tasksData.length, (index) {
                  // doorFrameHardware/architrave/handover is in bool format and needs to be converted in 0 and 1
                  final task = tasksData[index].data() as Map<String, dynamic>;
                  task['doorFrameHardware'] = task['doorFrameHardware'] == true
                      ? 1
                      : 0;
                  task['architrave'] = task['architrave'] == true ? 1 : 0;
                  task['handover'] = task['handover'] == true ? 1 : 0;
                  //add totalWorkDone in data formula if doorFrameHardware 1 then 60% if architrave 1 then 30% if handover 1 then 10%
                  task['totalWorkDone'] =
                      (task['doorFrameHardware'] == 1 ? 60 : 0) +
                      (task['architrave'] == 1 ? 30 : 0) +
                      (task['handover'] == 1 ? 10 : 0);
                  return Container(
                    decoration: const BoxDecoration(
                      border: flutter.Border(bottom: BorderSide()),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Text(
                              task['buildingNo'] ?? '',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              task['flatNo'] ?? '',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Text(
                              task['materialGroup'] ?? '',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Text(
                              '${(task['totalWorkDone'] ?? 0).toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRecipePreview() {
    final groupedEntries =
        _previewData!['groupedEntries']
            as Map<String, List<Map<String, dynamic>>>;

    if (groupedEntries.isEmpty) {
      return const Center(child: Text('No entry data available'));
    }

    // Show the first recipe as preview
    final firstChallan = groupedEntries.keys.first;
    final firstGroup = groupedEntries[firstChallan]!;
    final firstEntry = firstGroup.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: Colors.yellow[300],
            padding: const EdgeInsets.all(8),
            child: const Center(
              child: Text(
                'On Site Material Receipt Entry',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Recipe count info
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue[50],
            child: Text(
              'Total Recipes: ${groupedEntries.length} (Showing preview of Challan: $firstChallan)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          // Receipt Info
          Table(
            border: TableBorder.all(),
            children: [
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Challan No'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(firstEntry['challanNo'] ?? ''),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Contractor'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(firstEntry['contractorName'] ?? ''),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Receipt Date'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(firstEntry['date'] ?? ''),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Project Name'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(widget.projectName),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Materials Table
          Container(
            decoration: BoxDecoration(border: flutter.Border.all()),
            child: Column(
              children: [
                Container(
                  color: Colors.yellow[200],
                  child: const Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'MATERIAL NAME',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'UOM',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'REQUIRED QTY',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'RECEIVED QTY',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Show all materials for this challan
                ...firstGroup
                    .map(
                      (entry) => Container(
                        decoration: const BoxDecoration(
                          border: flutter.Border(bottom: BorderSide()),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(entry['materialName'] ?? ''),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(entry['uom'] ?? 'NOS'),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('${entry['requiredQty'] ?? 0}'),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('${entry['receivedQty'] ?? 0}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
          if (groupedEntries.length > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '... and ${groupedEntries.length - 1} more recipe(s)',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIssueRecipePreview() {
    final groupedEntries =
        _previewData!['groupedEntries']
            as Map<String, List<Map<String, dynamic>>>;

    if (groupedEntries.isEmpty) {
      return const Center(child: Text('No issue data available'));
    }

    // Show the first recipe as preview
    final firstChallan = groupedEntries.keys.first;
    final firstGroup = groupedEntries[firstChallan]!;
    final firstEntry = firstGroup.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: Colors.yellow[300],
            padding: const EdgeInsets.all(8),
            child: const Center(
              child: Text(
                'Material Issue to Contractors',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Recipe count info
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue[50],
            child: Text(
              'Total Recipes: ${groupedEntries.length} (Showing preview of Challan: $firstChallan)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          // Transaction Info
          Table(
            border: TableBorder.all(),
            children: [
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Transaction Date'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(firstEntry['date'] ?? ''),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Challan No'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(firstEntry['challanNo'] ?? ''),
                  ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Project Name'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(widget.projectName),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Contractor'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(firstEntry['contractorName'] ?? ''),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Materials Table
          Container(
            decoration: BoxDecoration(border: flutter.Border.all()),
            child: Column(
              children: [
                Container(
                  color: Colors.yellow[200],
                  child: const Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'MATERIAL NAME',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'UOM',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'RECEIVED QTY',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'ISSUE QTY',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Show all materials for this challan
                ...firstGroup
                    .map(
                      (entry) => Container(
                        decoration: const BoxDecoration(
                          border: flutter.Border(bottom: BorderSide()),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(entry['materialName'] ?? ''),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(entry['uom'] ?? 'NOS'),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${entry['totalReceivedQty'] ?? 0}',
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('${entry['issueQty'] ?? 0}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
          if (groupedEntries.length > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '... and ${groupedEntries.length - 1} more recipe(s)',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generateInventoryReport() async {
    setState(() {
      _isGenerating = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .get();

      setState(() {
        _previewType = 'Inventory Report';
        _previewData = {'inventoryData': snapshot.docs, 'type': 'inventory'};
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _showErrorSnackBar('Error generating report: $e');
    }
  }

  Future<void> _generateInstallationReport() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .get();

      setState(() {
        _previewType = 'Installation Report';
        _previewData = {
          'tasksData': tasksSnapshot.docs,
          'type': 'installation',
        };
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _showErrorSnackBar('Error generating report: $e');
    }
  }

  Future<void> _generateEntryRecipe() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .where('receivedEntries', isNotEqualTo: [])
          .get();

      // Group all received entries by date and challan number
      List<Map<String, dynamic>> allEntries = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final receivedEntries = data['receivedEntries'] as List<dynamic>? ?? [];

        for (var entry in receivedEntries) {
          final entryMap = entry as Map<String, dynamic>;
          allEntries.add({
            'materialName': data['materialName'],
            'uom': data['uom'] ?? 'NOS',
            'requiredQty': data['requiredQty'] ?? 0,
            'challanNo': entryMap['challanNo'],
            'contractorName': entryMap['contractorName'],
            'date': entryMap['date'],
            'receivedQty': entryMap['qty'],
            'docId': doc.id,
          });
        }
      }

      // Group entries by challan number to create separate recipes
      Map<String, List<Map<String, dynamic>>> groupedEntries = {};
      for (var entry in allEntries) {
        final challanNo = entry['challanNo'] as String;
        if (!groupedEntries.containsKey(challanNo)) {
          groupedEntries[challanNo] = [];
        }
        groupedEntries[challanNo]!.add(entry);
      }

      setState(() {
        _previewType = 'Entry Recipe';
        _previewData = {
          'groupedEntries': groupedEntries,
          'type': 'entry_recipe',
        };
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _showErrorSnackBar('Error generating recipe: $e');
    }
  }

  Future<void> _generateIssueRecipe() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .where('issuedEntries', isNotEqualTo: [])
          .get();

      // Group all issued entries by date and challan number
      List<Map<String, dynamic>> allEntries = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final issuedEntries = data['issuedEntries'] as List<dynamic>? ?? [];

        for (var entry in issuedEntries) {
          final entryMap = entry as Map<String, dynamic>;
          allEntries.add({
            'materialName': data['materialName'],
            'uom': data['uom'] ?? 'NOS',
            'totalReceivedQty': data['totalReceivedQty'] ?? 0,
            'challanNo': entryMap['challanNo'],
            'contractorName': entryMap['contractorName'],
            'date': entryMap['date'],
            'issueQty': entryMap['qty'],
            'docId': doc.id,
          });
        }
      }

      // Group entries by challan number to create separate recipes
      Map<String, List<Map<String, dynamic>>> groupedEntries = {};
      for (var entry in allEntries) {
        final challanNo = entry['challanNo'] as String;
        if (!groupedEntries.containsKey(challanNo)) {
          groupedEntries[challanNo] = [];
        }
        groupedEntries[challanNo]!.add(entry);
      }

      setState(() {
        _previewType = 'Issue Recipe';
        _previewData = {
          'groupedEntries': groupedEntries,
          'type': 'issue_recipe',
        };
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      _showErrorSnackBar('Error generating recipe: $e');
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Export Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Excel (.xlsx)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportFile('excel');
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('PDF'),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportFile('pdf');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportFile(String format) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${_previewType?.toLowerCase().replaceAll(' ', '_')}_$timestamp';

      if (format == 'excel') {
        final excel = await _createExcelFile();
        final fileBytes = excel.save();
        if (fileBytes != null) {
          await _downloadFile(fileBytes, '$fileName.xlsx');
          _showSuccessNotification('$fileName.xlsx');
        }
      } else if (format == 'pdf') {
        final pdf = await _createPdfFile();
        final pdfBytes = await pdf.save();
        await _downloadFile(pdfBytes, '$fileName.pdf');
        _showSuccessNotification('$fileName.pdf');
      }
    } catch (e) {
      _showErrorSnackBar('Error exporting file: $e');
    }
  }

  Future<Excel> _createExcelFile() async {
    final excel = Excel.createExcel();
    Sheet sheet;

    switch (_previewType) {
      case 'Inventory Report':
        sheet = excel['Inventory Report'];
        _createInventoryExcel(sheet);
        break;
      case 'Installation Report':
        sheet = excel['Installation Report'];
        _createInstallationExcel(sheet);
        break;
      case 'Entry Recipe':
        sheet = excel['Entry Recipe'];
        _createEntryRecipeExcel(sheet);
        break;
      case 'Issue Recipe':
        sheet = excel['Issue Recipe'];
        _createIssueRecipeExcel(sheet);
        break;
      default:
        sheet = excel['Sheet1'];
    }

    return excel;
  }

  void _createInventoryExcel(Sheet sheet) {
    final inventoryData =
        _previewData!['inventoryData'] as List<DocumentSnapshot>;

    // Header
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'INVENTORY REPORT FORMAT',
    );
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
      'NAME OF PROJECT',
    );
    sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue(
      widget.projectName,
    );
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
      'NAME OF CUSTOMER',
    );
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(
      'VIMAN NAGAR SHUBH VENTURES LLP',
    );

    // Table Headers
    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(
      'MATERIAL NAME',
    );
    sheet.cell(CellIndex.indexByString('B5')).value = TextCellValue(
      'REQUIRED QTY',
    );
    sheet.cell(CellIndex.indexByString('C5')).value = TextCellValue(
      'TOTAL RECEIVED QTY',
    );
    sheet.cell(CellIndex.indexByString('D5')).value = TextCellValue('BAL QTY');
    sheet.cell(CellIndex.indexByString('E5')).value = TextCellValue(
      'TOTAL ISSUE QTY',
    );
    sheet.cell(CellIndex.indexByString('F5')).value = TextCellValue(
      'BAL ISSUE QTY',
    );

    // Data rows
    for (int i = 0; i < inventoryData.length; i++) {
      final data = inventoryData[i].data() as Map<String, dynamic>;
      final row = 6 + i;

      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        data['materialName'] ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(
        data['requiredQty'] ?? 0,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        data['totalReceivedQty'] ?? 0,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = IntCellValue(
        data['balanceQty'] ?? 0,
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = IntCellValue(
        data['totalIssuedQty'] ?? 0,
      );
      sheet.cell(CellIndex.indexByString('F$row')).value = IntCellValue(
        data['balIssueQty'] ?? 0,
      );
    }
  }

  void _createInstallationExcel(Sheet sheet) {
    try {
      final tasksData = _previewData!['tasksData'] as List<DocumentSnapshot>;

      // Header
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
        'FLAT WISE & PROJECT WISE INSTALLATION REPORT',
      );
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
        'PROJECT NAME: ${widget.projectName}',
      );
      sheet.cell(CellIndex.indexByString('C2')).value = TextCellValue(
        'CUSTOMER NAME: ${projectData?['customerName']}',
      );
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'REPORT DATE: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      );

      // Table Headers
      final headers = [
        'BUILDING NO',
        'FLAT NO',
        'MATERIAL GROUP',
        'LOCATION',
        'DOOR + FRAME+ HARDWARE',
        'ARCHITRAVE',
        'HANDOVER',
        'TOTAL WORK DONE',
        'REMARK',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4))
            .value = TextCellValue(
          headers[i],
        );
      }

      // Data rows
      for (var task in tasksData) {
        final taskData = task.data() as Map<String, dynamic>;
        final row = 5 + tasksData.indexOf(task);
        // doorFrameHardware/architrave/handover is in bool format and needs to be converted in 0 and 1
        taskData['doorFrameHardware'] = taskData['doorFrameHardware'] == true
            ? 1
            : 0;
        taskData['architrave'] = taskData['architrave'] == true ? 1 : 0;
        taskData['handover'] = taskData['handover'] == true ? 1 : 0;
        //add totalWorkDone in data formula if doorFrameHardware 1 then 60% if architrave 1 then 30% if handover 1 then 10%
        taskData['totalWorkDone'] =
            (taskData['doorFrameHardware'] == 1 ? 60 : 0) +
            (taskData['architrave'] == 1 ? 30 : 0) +
            (taskData['handover'] == 1 ? 10 : 0);
        print(taskData);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = TextCellValue(
          taskData['buildingNo'] ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(
          taskData['flatNo'] ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(
          taskData['materialGroup'] ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = TextCellValue(
          taskData['location'] ?? '',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = IntCellValue(
          taskData['doorFrameHardware'] ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = IntCellValue(
          taskData['architrave'] ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = IntCellValue(
          taskData['handover'] ?? 0,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = TextCellValue(
          '${(taskData['totalWorkDone'] ?? 0).toStringAsFixed(2)}%',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = TextCellValue(
          taskData['remark'] ?? '',
        );
      }
    } catch (e) {
      print('Error creating installation Excel: $e');
    }
  }

  void _createEntryRecipeExcel(Sheet sheet) {
    final groupedEntries =
        _previewData!['groupedEntries']
            as Map<String, List<Map<String, dynamic>>>;

    int currentRow = 1;

    // Create separate sheets or sections for each challan
    for (String challanNo in groupedEntries.keys) {
      final entries = groupedEntries[challanNo]!;
      final firstEntry = entries.first;

      // Header for each recipe
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'On Site Material Receipt Entry - Challan: $challanNo',
      );
      currentRow += 2;

      // Receipt Info
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Challan No',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
          )
          .value = TextCellValue(
        challanNo,
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Contractor',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
          )
          .value = TextCellValue(
        firstEntry['contractorName'] ?? '',
      );
      currentRow++;

      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Receipt Date',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
          )
          .value = TextCellValue(
        firstEntry['date'] ?? '',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Project Name',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
          )
          .value = TextCellValue(
        widget.projectName,
      );
      currentRow += 2;

      // Material Headers
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'MATERIAL NAME',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'UOM',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'REQUIRED QTY',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'RECEIVED QTY',
      );
      currentRow++;

      // Data for this challan
      for (var entry in entries) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            )
            .value = TextCellValue(
          entry['materialName'] ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
            )
            .value = TextCellValue(
          entry['uom'] ?? 'NOS',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
            )
            .value = IntCellValue(
          entry['requiredQty'] ?? 0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
            )
            .value = IntCellValue(
          entry['receivedQty'] ?? 0,
        );
        currentRow++;
      }

      currentRow += 3; // Add space between recipes
    }
  }

  void _createIssueRecipeExcel(Sheet sheet) {
    final groupedEntries =
        _previewData!['groupedEntries']
            as Map<String, List<Map<String, dynamic>>>;

    int currentRow = 1;

    // Create separate sections for each challan
    for (String challanNo in groupedEntries.keys) {
      final entries = groupedEntries[challanNo]!;
      final firstEntry = entries.first;

      // Header for each recipe
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Material Issue to Contractors - Challan: $challanNo',
      );
      currentRow += 2;

      // Transaction Info
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Transaction Date',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
          )
          .value = TextCellValue(
        firstEntry['date'] ?? '',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Challan No',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
          )
          .value = TextCellValue(
        challanNo,
      );
      currentRow++;

      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Project Name',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
          )
          .value = TextCellValue(
        widget.projectName,
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'Contractor',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
          )
          .value = TextCellValue(
        firstEntry['contractorName'] ?? '',
      );
      currentRow += 2;

      // Material Headers
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'MATERIAL NAME',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'UOM',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'RECEIVED QTY',
      );
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
          )
          .value = TextCellValue(
        'ISSUE QTY',
      );
      currentRow++;

      // Data for this challan
      for (var entry in entries) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
            )
            .value = TextCellValue(
          entry['materialName'] ?? '',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
            )
            .value = TextCellValue(
          entry['uom'] ?? 'NOS',
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
            )
            .value = IntCellValue(
          entry['totalReceivedQty'] ?? 0,
        );
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
            )
            .value = IntCellValue(
          entry['issueQty'] ?? 0,
        );
        currentRow++;
      }

      currentRow += 3; // Add space between recipes
    }
  }

  Future<pw.Document> _createPdfFile() async {
    final pdf = pw.Document();

    switch (_previewType) {
      case 'Inventory Report':
        _createInventoryPdf(pdf);
        break;
      case 'Installation Report':
        _createInstallationPdf(pdf);
        break;
      case 'Entry Recipe':
        _createEntryRecipePdf(pdf);
        break;
      case 'Issue Recipe':
        _createIssueRecipePdf(pdf);
        break;
    }

    return pdf;
  }

void _createInventoryPdf(pw.Document pdf) {
  final inventoryData = _previewData!['inventoryData'] as List<DocumentSnapshot>;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return [
          // Header with company styling
          pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              children: [
                pw.Text(
                  'INVENTORY REPORT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated on ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Project Information Card
          pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Project Information',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Project Name:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(widget.projectName),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Customer Name:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text('VIMAN NAGAR SHUBH VENTURES LLP'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Materials Table with improved styling
          pw.Text(
            'Inventory Details',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 1,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue100,
                ),
                children: [
                  _buildTableCell('MATERIAL NAME', isHeader: true),
                  _buildTableCell('REQUIRED\nQTY', isHeader: true),
                  _buildTableCell('RECEIVED\nQTY', isHeader: true),
                  _buildTableCell('BALANCE\nQTY', isHeader: true),
                  _buildTableCell('ISSUED\nQTY', isHeader: true),
                  _buildTableCell('REMAINING\nQTY', isHeader: true),
                ],
              ),
              // Data rows
              ...inventoryData.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isEvenRow = inventoryData.indexOf(doc) % 2 == 0;
                
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEvenRow ? PdfColors.grey50 : PdfColors.white,
                  ),
                  children: [
                    _buildTableCell(data['materialName'] ?? ''),
                    _buildTableCell('${data['requiredQty'] ?? 0}', isNumeric: true),
                    _buildTableCell('${data['totalReceivedQty'] ?? 0}', isNumeric: true),
                    _buildTableCell('${data['balanceQty'] ?? 0}', isNumeric: true),
                    _buildTableCell('${data['totalIssuedQty'] ?? 0}', isNumeric: true),
                    _buildTableCell('${data['balIssueQty'] ?? 0}', isNumeric: true),
                  ],
                );
              }).toList(),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Summary section
          pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Total Materials: ${inventoryData.length}'),
                pw.Text('Report Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
              ],
            ),
          ),
        ];
      },
      footer: (pw.Context context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        );
      },
    ),
  );
}
void _createInstallationPdf(pw.Document pdf) {
  final tasksData = _previewData!['tasksData'] as List<DocumentSnapshot>;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape, // Landscape for better table fit
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return [
          // Header
          pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: PdfColors.green900,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              children: [
                pw.Text(
                  'INSTALLATION PROGRESS REPORT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Project: ${widget.projectName}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Report Date: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Progress Legend
          pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _buildProgressLegend('Door + Frame + Hardware', '60%', PdfColors.blue),
                _buildProgressLegend('Architrave Installation', '30%', PdfColors.orange),
                _buildProgressLegend('Handover Complete', '10%', PdfColors.green),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Installation Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1.5),
              8: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.green100),
                children: [
                  _buildTableCell('BUILDING', isHeader: true),
                  _buildTableCell('FLAT', isHeader: true),
                  _buildTableCell('MATERIAL GROUP', isHeader: true),
                  _buildTableCell('LOCATION', isHeader: true),
                  _buildTableCell('DOOR +\nFRAME +\nHARDWARE', isHeader: true),
                  _buildTableCell('ARCHITRAVE', isHeader: true),
                  _buildTableCell('HANDOVER', isHeader: true),
                  _buildTableCell('TOTAL\nPROGRESS', isHeader: true),
                  _buildTableCell('REMARKS', isHeader: true),
                ],
              ),
              // Data rows
              ...tasksData.map((task) {
                final data = task.data() as Map<String, dynamic>;
                final isEvenRow = tasksData.indexOf(task) % 2 == 0;
                
                // Convert boolean to int and calculate progress
                final doorFrameHardware = data['doorFrameHardware'] == true ? 1 : 0;
                final architrave = data['architrave'] == true ? 1 : 0;
                final handover = data['handover'] == true ? 1 : 0;
                final totalProgress = (doorFrameHardware * 60) + (architrave * 30) + (handover * 10);
                
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEvenRow ? PdfColors.grey50 : PdfColors.white,
                  ),
                  children: [
                    _buildTableCell(data['buildingNo'] ?? ''),
                    _buildTableCell(data['flatNo'] ?? ''),
                    _buildTableCell(data['materialGroup'] ?? ''),
                    _buildTableCell(data['location'] ?? ''),
                    _buildTableCell(doorFrameHardware == 1 ? '✓' : '○', isNumeric: true),
                    _buildTableCell(architrave == 1 ? '✓' : '○', isNumeric: true),
                    _buildTableCell(handover == 1 ? '✓' : '○', isNumeric: true),
                    _buildTableCell('$totalProgress%', isNumeric: true),
                    _buildTableCell(data['remark'] ?? ''),
                  ],
                );
              }).toList(),
            ],
          ),
        ];
      },
      footer: (pw.Context context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        );
      },
    ),
  );
}

void _createEntryRecipePdf(pw.Document pdf) {
  final groupedEntries = _previewData!['groupedEntries'] as Map<String, List<Map<String, dynamic>>>;

  for (String challanNo in groupedEntries.keys) {
    final entries = groupedEntries[challanNo]!;
    final firstEntry = entries.first;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: PdfColors.purple900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                children: [
                  pw.Text(
                    'MATERIAL RECEIPT ENTRY',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Challan No: $challanNo',
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Receipt Information
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.purple50),
                    children: [
                      _buildInfoCell('Challan Number:', challanNo),
                      _buildInfoCell('Contractor:', firstEntry['contractorName'] ?? ''),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildInfoCell('Receipt Date:', firstEntry['date'] ?? ''),
                      _buildInfoCell('Project Name:', widget.projectName),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Materials Table
            pw.Text(
              'Materials Received',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple900,
              ),
            ),
            pw.SizedBox(height: 12),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.purple100),
                  children: [
                    _buildTableCell('MATERIAL NAME', isHeader: true),
                    _buildTableCell('UOM', isHeader: true),
                    _buildTableCell('REQUIRED\nQTY', isHeader: true),
                    _buildTableCell('RECEIVED\nQTY', isHeader: true),
                  ],
                ),
                // Data
                ...entries.map((entry) {
                  final isEvenRow = entries.indexOf(entry) % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEvenRow ? PdfColors.grey50 : PdfColors.white,
                    ),
                    children: [
                      _buildTableCell(entry['materialName'] ?? ''),
                      _buildTableCell(entry['uom'] ?? 'NOS', isNumeric: true),
                      _buildTableCell('${entry['requiredQty'] ?? 0}', isNumeric: true),
                      _buildTableCell('${entry['receivedQty'] ?? 0}', isNumeric: true),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount} - Challan: $challanNo',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        },
      ),
    );
  }
}

void _createIssueRecipePdf(pw.Document pdf) {
  final groupedEntries = _previewData!['groupedEntries'] as Map<String, List<Map<String, dynamic>>>;

  for (String challanNo in groupedEntries.keys) {
    final entries = groupedEntries[challanNo]!;
    final firstEntry = entries.first;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                color: PdfColors.red900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                children: [
                  pw.Text(
                    'MATERIAL ISSUE RECIPE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Challan No: $challanNo',
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Transaction Information
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.red50),
                    children: [
                      _buildInfoCell('Transaction Date:', firstEntry['date'] ?? ''),
                      _buildInfoCell('Challan Number:', challanNo),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildInfoCell('Project Name:', widget.projectName),
                      _buildInfoCell('Contractor:', firstEntry['contractorName'] ?? ''),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Materials Table
            pw.Text(
              'Materials Issued',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red900,
              ),
            ),
            pw.SizedBox(height: 12),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.red100),
                  children: [
                    _buildTableCell('MATERIAL NAME', isHeader: true),
                    _buildTableCell('UOM', isHeader: true),
                    _buildTableCell('AVAILABLE\nQTY', isHeader: true),
                    _buildTableCell('ISSUED\nQTY', isHeader: true),
                  ],
                ),
                // Data
                ...entries.map((entry) {
                  final isEvenRow = entries.indexOf(entry) % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEvenRow ? PdfColors.grey50 : PdfColors.white,
                    ),
                    children: [
                      _buildTableCell(entry['materialName'] ?? ''),
                      _buildTableCell(entry['uom'] ?? 'NOS', isNumeric: true),
                      _buildTableCell('${entry['totalReceivedQty'] ?? 0}', isNumeric: true),
                      _buildTableCell('${entry['issueQty'] ?? 0}', isNumeric: true),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount} - Challan: $challanNo',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        },
      ),
    );
  }
}

// Helper methods for consistent table styling
pw.Widget _buildTableCell(String text, {bool isHeader = false, bool isNumeric = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: isHeader ? 10 : 9,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      textAlign: isNumeric ? pw.TextAlign.center : pw.TextAlign.left,
    ),
  );
}

pw.Widget _buildInfoCell(String label, String value) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

pw.Widget _buildProgressLegend(String label, String percentage, PdfColor color) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Column(
      children: [
        pw.Container(
          width: 20,
          height: 20,
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Center(
            child: pw.Text(
              percentage,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
      ],
    ),
  );
}

  void _showSuccessNotification(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloaded successfully: $fileName'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () {
            // Open file implementation
          },
        ),
      ),
    );
  }

  Future<void> _saveToFirebase() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${_previewType?.toLowerCase().replaceAll(' ', '_')}_$timestamp';

      // Create the file based on type
      List<int> fileBytes;
      String fileExtension;

      if (_previewType!.contains('Recipe')) {
        // For recipes, create Excel format
        final excel = await _createExcelFile();
        fileBytes = excel.save()!;
        fileExtension = 'xlsx';
      } else {
        // For reports, create PDF format
        final pdf = await _createPdfFile();
        fileBytes = await pdf.save();
        fileExtension = 'pdf';
      }

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects')
          .child(widget.projectId)
          .child('reports')
          .child('$fileName.$fileExtension');

      await storageRef.putData(Uint8List.fromList(fileBytes));
      final downloadUrl = await storageRef.getDownloadURL();

      // Save metadata to Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('reports')
          .add({
            'name': _previewType!,
            'type': _previewData!['type'],
            'fileName': '$fileName.$fileExtension',
            'downloadUrl': downloadUrl,
            'fileSize': fileBytes.length,
            'createdAt': Timestamp.now(),
            'format': fileExtension,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_previewType!} saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear preview after saving
      setState(() {
        _previewType = null;
        _previewData = null;
      });
    } catch (e) {
      _showErrorSnackBar('Error saving to Firebase: $e');
    }
  }

  Future<void> _downloadFromStorage(Map<String, dynamic> reportData) async {
    try {
      final downloadUrl = reportData['downloadUrl'] as String?;
      final fileName = reportData['fileName'] as String?;

      if (downloadUrl != null && fileName != null) {
        // Download file from Firebase Storage
        final storageRef = FirebaseStorage.instance.refFromURL(downloadUrl);
        final bytes = await storageRef.getData();

        if (bytes != null) {
          await _downloadFile(bytes, fileName);
          _showSuccessNotification(fileName);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error downloading from storage: $e');
    }
  }

  Future<void> _viewReport(String reportId, Map<String, dynamic> data) async {
    try {
      final downloadUrl = data['downloadUrl'] as String?;

      if (downloadUrl != null) {
        // For PDF files, use the printing package to preview
        if (data['format'] == 'pdf') {
          final storageRef = FirebaseStorage.instance.refFromURL(downloadUrl);
          final bytes = await storageRef.getData();

          if (bytes != null) {
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => bytes,
            );
          }
        } else {
          // For Excel files, show a preview dialog or download
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening ${data['name']}...'),
              action: SnackBarAction(
                label: 'Download',
                onPressed: () => _downloadFromStorage(data),
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error viewing report: $e');
    }
  }

  IconData _getIconForReportType(String type) {
    switch (type) {
      case 'inventory':
        return Icons.inventory;
      case 'installation':
        return Icons.build;
      case 'entry_recipe':
        return Icons.receipt;
      case 'issue_recipe':
        return Icons.assignment;
      default:
        return Icons.description;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  // Updated Tasks Tab Widget with Search
  Widget _buildTasksTab() {
    return Column(
      children: [
        // Header with Add Task Button and More Options
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add_task),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF3B82F6)),
                onSelected: (value) {
                  switch (value) {
                    case 'import':
                      _importTasksFromExcel();
                      break;
                    case 'download':
                      _downloadExcelTemplate();
                      break;
                    case 'multi_update':
                      _navigateToMultiUpdatePage();
                      break;
                    case 'delete':
                      _navigateToDeleteTasksPage();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.file_upload, color: Color(0xFF3B82F6)),
                        SizedBox(width: 8),
                        Text('Import Tasks'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, color: Color(0xFF3B82F6)),
                        SizedBox(width: 8),
                        Text('Download Template'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'multi_update',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note, color: Color(0xFF3B82F6)),
                        SizedBox(width: 8),
                        Text('Multi Update'),
                      ],
                    ),
                  ),
                  // Add these to your PopupMenuButton items
const PopupMenuItem(
  value: 'delete',
  child: Row(
    children: [
      Icon(Icons.delete, color: Colors.red),
      SizedBox(width: 8),
      Text('Delete Tasks', style: TextStyle(color: Colors.red)),
    ],
  ),
),
                ],
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by building, flat, material, or location...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF3B82F6)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase().trim();
              });
            },
          ),
        ),

        // Tasks List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('tasks')
                .orderBy('flatNo')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProjectData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No tasks created yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Filter tasks based on search query
              final allTasks = snapshot.data!.docs;
              final filteredTasks = _searchQuery.isEmpty
                  ? allTasks
                  : allTasks.where((task) {
                      final data = task.data() as Map<String, dynamic>;
                      final searchableText = [
                        data['buildingNo']?.toString() ?? '',
                        data['flatNo']?.toString() ?? '',
                        data['materialGroup']?.toString() ?? '',
                        data['location']?.toString() ?? '',
                        data['remark']?.toString() ?? '',
                      ].join(' ').toLowerCase();

                      return searchableText.contains(_searchQuery);
                    }).toList();

              // Show search results info
              if (_searchQuery.isNotEmpty) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Found ${filteredTasks.length} of ${allTasks.length} tasks',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (filteredTasks.isEmpty) ...[
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: const Text('Clear Search'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredTasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No tasks found for "$_searchQuery"',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    child: const Text('Clear Search'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: filteredTasks.length,
                              itemBuilder: (context, index) {
                                final task = filteredTasks[index];
                                final data =
                                    task.data() as Map<String, dynamic>;

                                return _buildTaskCard(
                                  task.id,
                                  data['buildingNo'] ?? '',
                                  data['flatNo']?.toString() ?? '',
                                  data['materialGroup'] ?? '',
                                  data['location'] ?? '',
                                  data['qty'] ?? 0,
                                  data['remark'] ?? '',
                                  data['doorFrameHardware'] ?? false,
                                  data['architrave'] ?? false,
                                  data['handover'] ?? false,
                                  data['createdAt'] as Timestamp?,
                                );
                              },
                            ),
                    ),
                  ],
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = filteredTasks[index];
                  final data = task.data() as Map<String, dynamic>;

                  return _buildTaskCard(
                    task.id,
                    data['buildingNo'] ?? '',
                    data['flatNo']?.toString() ?? '',
                    data['materialGroup'] ?? '',
                    data['location'] ?? '',
                    data['qty'] ?? 0,
                    data['remark'] ?? '',
                    data['doorFrameHardware'] ?? false,
                    data['architrave'] ?? false,
                    data['handover'] ?? false,
                    data['createdAt'] as Timestamp?,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(
    String taskId,
    String buildingNo,
    String flatNo,
    String materialGroup,
    String location,
    int qty,
    String remark,
    bool doorFrameHardware,
    bool architrave,
    bool handover,
    Timestamp? createdAt,
  ) {
    // Calculate progress based on the specified weightage
    double progress = 0.0;
    if (doorFrameHardware) progress += 60.0;
    if (architrave) progress += 30.0;
    if (handover) progress += 10.0;

    Color progressColor = progress == 100
        ? Colors.green
        : progress >= 60
        ? Colors.orange
        : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Building $buildingNo - Flat $flatNo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${progress.toInt()}%',
                  style: TextStyle(
                    color: progressColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Task Details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Material Group', materialGroup),
                    _buildDetailRow('Location', location),
                    _buildDetailRow('Quantity', qty.toString()),
                    if (remark.isNotEmpty) _buildDetailRow('Remark', remark),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Steps with correct weightage
          Column(
            children: [
              _buildProgressStep(
                'Door + Frame + Hardware',
                doorFrameHardware,
                '60%',
                Colors.blue,
              ),
              const SizedBox(height: 8),
              _buildProgressStep(
                'Architrave',
                architrave,
                '30%',
                Colors.orange,
              ),
              const SizedBox(height: 8),
              _buildProgressStep('Handover', handover, '10%', Colors.green),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (createdAt != null)
                Text(
                  'Created: ${_formatTimestamp(createdAt)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ElevatedButton.icon(
                onPressed: () => _navigateToUpdateTaskPage(
                  taskId,
                  buildingNo,
                  flatNo,
                  materialGroup,
                  location,
                  qty,
                  remark,
                  doorFrameHardware,
                  architrave,
                  handover,
                ),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(
    String title,
    bool isCompleted,
    String percentage,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted ? color : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 12)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isCompleted ? color : Colors.grey[600],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            percentage,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Navigate to Update Task Page
  void _navigateToUpdateTaskPage(
    String taskId,
    String buildingNo,
    String flatNo,
    String materialGroup,
    String location,
    int qty,
    String remark,
    bool doorFrameHardware,
    bool architrave,
    bool handover,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateTaskPage(
          projectId: widget.projectId,
          taskId: taskId,
          buildingNo: buildingNo,
          flatNo: flatNo,
          materialGroup: materialGroup,
          location: location,
          qty: qty,
          remark: remark,
          doorFrameHardware: doorFrameHardware,
          architrave: architrave,
          handover: handover,
        ),
      ),
    );
  }

  
Future<void> _importTasksFromExcel() async {
  if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.addtaskProject)) 
        {
  try {
    // Step 1: Pick Excel file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.single.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected')),
      );
      return;
    }

    Uint8List bytes;
    if (result.files.single.bytes != null) {
      bytes = result.files.single.bytes!;
    } else {
      final file = File(result.files.single.path!);
      bytes = await file.readAsBytes();
    }

    final excel = Excel.decodeBytes(bytes);
    // Step 2: Ask for number of floors
    final floorsCount = await showDialog<int>(
      context: context,
      builder: (context) {
        int tempFloors = 1;
        return AlertDialog(
          title: const Text("Select Floors"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Number of Floors",
                  hintText: "e.g. 15",
                ),
                onChanged: (val) {
                  tempFloors = int.tryParse(val) ?? 1;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempFloors),
              child: const Text("Next"),
            ),
          ],
        );
      },
    );

    if (floorsCount == null || floorsCount <= 0) return;

    // Step 3: Parse Excel with better debugging
    final sheet = excel.tables.values.first;
    List<Map<String, dynamic>> floor1Tasks = []; // Store floor 1 tasks separately
    List<Map<String, dynamic>> allTasks = [];

    print("Excel sheet maxRows: ${sheet.maxRows}");
    print("Excel sheet maxColumns: ${sheet.maxColumns}");

    // First, parse floor 1 tasks from Excel
    for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      final row = sheet.row(rowIndex);

      // Debug: Print row data
      print("Row $rowIndex: ${row.map((cell) => cell?.value?.toString() ?? 'null').toList()}");

      // Skip completely empty rows
      if (row.isEmpty ||
          row.every((cell) =>
              cell?.value == null || cell!.value.toString().trim().isEmpty)) {
        continue;
      }

      final buildingNo = _getCellValue(row, 0).trim();
      final flatNoStr = _getCellValue(row, 1).trim();
      final materialGroup = _getCellValue(row, 2).trim();
      final location = _getCellValue(row, 3).trim();
      final qtyStr = _getCellValue(row, 4).trim();
      final remark = row.length > 5 ? _getCellValue(row, 5).trim() : '';

      // Debug: Print parsed values
      print("Parsed - Building: $buildingNo, Flat: $flatNoStr, Material: $materialGroup, Location: $location, Qty: $qtyStr");

      // Validate required fields
      if (buildingNo.isEmpty ||
          flatNoStr.isEmpty ||
          materialGroup.isEmpty ||
          location.isEmpty ||
          qtyStr.isEmpty) {
        print("Skipping row $rowIndex due to empty required fields");
        continue;
      }

      final qty = int.tryParse(qtyStr) ?? 0;
      if (qty <= 0) {
        print("Skipping row $rowIndex due to invalid quantity: $qtyStr");
        continue;
      }

      final flatNo = int.tryParse(flatNoStr) ?? 0;
      if (flatNo == 0) {
        print("Skipping row $rowIndex due to invalid flat number: $flatNoStr");
        continue;
      }

      // Store floor 1 task
      final floor1Task = {
        'buildingNo': buildingNo,
        'flatNo': flatNo,
        'materialGroup': materialGroup,
        'location': location,
        'qty': qty,
        'remark': remark,
      };
      floor1Tasks.add(floor1Task);
      print("Added floor 1 task: $floor1Task");
    }

    print("Floor 1 tasks found: ${floor1Tasks.length}");

    // Now generate tasks for all floors
    for (int floor = 1; floor <= floorsCount; floor++) {
      for (var task in floor1Tasks) {
        // Calculate new flat number: (floor * 100) + (original flat % 100)
        final originalFlat = task['flatNo'] as int;
        final newFlatNo = (floor * 100) + (originalFlat % 100);
        
        allTasks.add({
          'buildingNo': task['buildingNo'],
          'flatNo': newFlatNo.toInt(),
          'materialGroup': task['materialGroup'],
          'location': task['location'],
          'qty': task['qty'],
          'remark': task['remark'],
          'doorFrameHardware': false,
          'architrave': false,
          'handover': false,
          'createdAt': Timestamp.now(),
        });
      }
    }

    print("Total tasks generated: ${allTasks.length}");

    // Step 4: Show enhanced preview
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final floor1Preview = allTasks.where((task) => task['flatNo'].toString().startsWith('1')).take(5).toList();
        final floor2Preview = allTasks.where((task) => task['flatNo'].toString().startsWith('2')).take(3).toList();
        
        return AlertDialog(
          title: const Text("Preview Import"),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("📁 File: ${result.files.single.name}", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("🏢 Floors: $floorsCount"),
                          Text("📊 Total Flats Per Floor: ${floor1Tasks.length}"),
                          Text("📋 Total Tasks: ${allTasks.length}"),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Floor 1 Sample
                  const Text("🔹 Floor 1 Sample (from Excel):", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...floor1Preview.map((task) => Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                    child: Text(
                      "Flat ${task['flatNo']} | ${task['materialGroup']} | ${task['location']} | Qty: ${task['qty']}",
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  )),
                  
                  if (floorsCount > 1) ...[
                    const SizedBox(height: 16),
                    const Text("🔹 Floor 2 Sample (auto-generated):", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...floor2Preview.map((task) => Padding(
                      padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                      child: Text(
                        "Flat ${task['flatNo']} | ${task['materialGroup']} | ${task['location']} | Qty: ${task['qty']}",
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    )),
                  ],
                  
                  if (allTasks.isEmpty) 
                    const Card(
                      color: Colors.orange,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("⚠️ No valid tasks found in Excel file. Please check the file format.", 
                                   style: TextStyle(color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Back"),
            ),
            ElevatedButton(
              onPressed: allTasks.isNotEmpty ? () => Navigator.pop(context, true) : null,
              child: const Text("Import"),
            ),
          ],
        );
      },
    );

    if (proceed != true || allTasks.isEmpty) return;

    // Step 5: Import tasks with progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Importing tasks...'),
          ],
        ),
      ),
    );

    int successCount = 0;
    int errorCount = 0;

    for (var task in allTasks) {
      try {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('tasks')
            .add(task);
        successCount++;
      } catch (e) {
        print("Error importing task: $e");
        errorCount++;
      }
    }

    Navigator.of(context).pop(); // Close loading

    // Step 6: Show result
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Import Results"),
        content: Text(
          "✅ Successfully imported: $successCount\n❌ Errors: $errorCount\n📊 Total: ${allTasks.length}\n🏢 Floors: $floorsCount\n📋 Tasks per floor: ${floor1Tasks.length}",
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  } catch (e) {
    print("Import error: $e");
    if (Navigator.canPop(context)) Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Import failed: $e")),
    );
  }
  }else{
    await ErrorDialog.show(
      context,
      title: "Permission Denied",
      message: "You do not have permission to import tasks. Please contact the administrator.",
    );
  }
}

  // Helper method to safely get cell value
  String _getCellValue(List<Data?> row, int index) {
    if (index >= row.length) return '';
    final cell = row[index];
    if (cell?.value == null) return '';
    return cell!.value.toString();
  }

  void _navigateToMultiUpdatePage() async {
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.addtaskProject)) 
        {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiUpdateTaskPage(projectId: widget.projectId),
      ),
    );
        } else {
      await ErrorDialog.show(
        context,
        title: 'Permission Denied',
        message: 'You do not have permission to update tasks. Please contact the administrator.',
      );
    }
  }
// Add this method to navigate to delete tasks page
void _navigateToDeleteTasksPage() async {
  if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.addtaskProject)) 
        {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DeleteTasksPage(
        projectId: widget.projectId,
      ),
    ),
  );
  } else {
    await ErrorDialog.show(
      context,
      title: 'Permission Denied',
      message: 'You do not have permission to delete tasks. Please contact the administrator.',
    );
  }
}
  // Enhanced Download Excel Template with your specific format
  Future<void> _downloadExcelTemplate() async {
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.addtaskProject)) 
        {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Task Template'];

      // Add headers
      final headers = [
        'BUILDING NO',
        'FLAT NO',
        'MATERIAL GROUP',
        'LOCATION',
        'QTY',
        'REMARK (Optional)',
      ];

      // Style headers
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.blue,
          fontColorHex: ExcelColor.white,
        );
      }

      // Add sample data based on your format
      final sampleData = [
        ['A', '101', 'MAIN DOOR SET', 'MD', '1', 'Main entrance door'],
        ['A', '101', 'BEDROOM DOOR SET', 'BD', '1', 'Master bedroom'],
        ['A', '101', 'BEDROOM DOOR SET', 'CB', '1', 'Child bedroom'],
        ['A', '101', 'TOILET DOOR SET', 'CT', '1', 'Common toilet'],
        ['A', '101', 'TOILET DOOR SET', 'MT', '1', 'Master toilet'],
        ['A', '102', 'MAIN DOOR SET', 'MD', '1', ''],
        ['A', '102', 'BEDROOM DOOR SET', 'BD', '1', ''],
        ['A', '102', 'BEDROOM DOOR SET', 'CB', '1', ''],
        ['A', '102', 'TOILET DOOR SET', 'CT', '1', ''],
        ['A', '102', 'TOILET DOOR SET', 'MT', '1', ''],
        ['B', '201', 'MAIN DOOR SET', 'MD', '1', 'Second floor unit'],
        ['B', '202', 'WINDOW SET', 'LR', '2', 'Living room windows'],
      ];

      for (int rowIndex = 0; rowIndex < sampleData.length; rowIndex++) {
        for (
          int colIndex = 0;
          colIndex < sampleData[rowIndex].length;
          colIndex++
        ) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex + 1,
            ),
          );
          cell.value = TextCellValue(sampleData[rowIndex][colIndex]);
        }
      }

      // Auto-fit columns
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnAutoFit(i);
      }

      // Add instructions sheet
      final instructionsSheet = excel['Instructions'];
      final instructions = [
        ['COLUMN', 'DESCRIPTION', 'REQUIRED', 'EXAMPLE'],
        ['BUILDING NO', 'Building identifier', 'YES', 'A, B, C, etc.'],
        ['FLAT NO', 'Flat/Unit number', 'YES', '101, 102, 201, etc.'],
        [
          'MATERIAL GROUP',
          'Type of door/window set',
          'YES',
          'MAIN DOOR SET, BEDROOM DOOR SET, etc.',
        ],
        ['LOCATION', 'Location code', 'YES', 'MD, BD, CB, CT, MT, etc.'],
        ['QTY', 'Quantity (number)', 'YES', '1, 2, 3, etc.'],
        ['REMARK', 'Additional notes', 'NO', 'Any additional information'],
      ];

      for (int rowIndex = 0; rowIndex < instructions.length; rowIndex++) {
        for (
          int colIndex = 0;
          colIndex < instructions[rowIndex].length;
          colIndex++
        ) {
          final cell = instructionsSheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex,
            ),
          );
          cell.value = TextCellValue(instructions[rowIndex][colIndex]);

          if (rowIndex == 0) {
            cell.cellStyle = CellStyle(
              bold: true,
              backgroundColorHex: ExcelColor.green,
              fontColorHex: ExcelColor.white,
            );
          }
        }
      }

      final bytes = excel.encode();
      if (bytes != null) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: 'task_import_template.xlsx',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Download template error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
      } else {
    await ErrorDialog.show(
      context,
      title: 'Permission Denied',
      message: 'You do not have permission to download the template.',
    );
  }
  }
  void _showErrorMessageDialog(String title, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: Color(0xFF3B82F6))),
          ),
        ],
      );
    },
  );
}
  // Add Task Method (with error handling)
  Future<void> _addTask() async {
    final buildingNoController = TextEditingController();
    final flatNoController = TextEditingController();
    final materialGroupController = TextEditingController();
    final locationController = TextEditingController();
    final qtyController = TextEditingController();
    final remarkController = TextEditingController();
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.addtaskProject)) 
        {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: buildingNoController,
                decoration: const InputDecoration(
                  labelText: 'Building No *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: flatNoController,
                decoration: const InputDecoration(
                  labelText: 'Flat No *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: materialGroupController,
                decoration: const InputDecoration(
                  labelText: 'Material Group *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Remark (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate required fields
              if (buildingNoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Building No is required')),
                );
                return;
              }
              if (flatNoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Flat No is required')),
                );
                return;
              }
              if (materialGroupController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Material Group is required')),
                );
                return;
              }
              if (locationController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location is required')),
                );
                return;
              }
              if (qtyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantity is required')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('projects')
                    .doc(widget.projectId)
                    .collection('tasks')
                    .add({
                      'buildingNo': buildingNoController.text.trim(),
                      'flatNo':int.parse( flatNoController.text.trim()),
                      'materialGroup': materialGroupController.text.trim(),
                      'location': locationController.text.trim(),
                      'qty': int.tryParse(qtyController.text.trim()) ?? 0,
                      'remark': remarkController.text.trim(),
                      'doorFrameHardware': false,
                      'architrave': false,
                      'handover': false,
                      'createdAt': Timestamp.now(),
                    });

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task added successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding task: ${e.toString()}')),
                );
              }
            },
            child: const Text('Add Task'),
          ),
        ],
      ),
      
    );
    }else {
      if (mounted) {
        await ErrorDialog.show(
          context,
          title: 'Permission Denied',
          message: 'You do not have permission to add tasks.',
        );
      }
    }}
    }
