import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
// Delete Tasks Page Class
class DeleteTasksPage extends StatefulWidget {
  final String projectId;

  const DeleteTasksPage({super.key, required this.projectId});

  @override
  State<DeleteTasksPage> createState() => _DeleteTasksPageState();
}

class _DeleteTasksPageState extends State<DeleteTasksPage> {
  List<QueryDocumentSnapshot> allTasks = [];
  List<QueryDocumentSnapshot> filteredTasks = [];
  List<String> selectedTaskIds = [];
  String searchQuery = '';
  bool isLoading = true;
  bool isDeleting = false;
  bool isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('tasks')
          .orderBy('flatNo')
          .get();

      setState(() {
        allTasks = snapshot.docs;
        filteredTasks = allTasks;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tasks: ${e.toString()}')),
      );
    }
  }

  void _filterTasks(String query) {
    setState(() {
      searchQuery = query.toLowerCase().trim();
      if (searchQuery.isEmpty) {
        filteredTasks = allTasks;
      } else {
        filteredTasks = allTasks.where((task) {
          final data = task.data() as Map<String, dynamic>;
          final searchableText = [
            data['buildingNo']?.toString() ?? '',
            data['flatNo']?.toString() ?? '',
            data['materialGroup']?.toString() ?? '',
            data['location']?.toString() ?? '',
            data['remark']?.toString() ?? '',
          ].join(' ').toLowerCase();

          return searchableText.contains(searchQuery);
        }).toList();
      }

      // Clear selection when filtering
      selectedTaskIds.clear();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedTaskIds.clear();
      }
    });
  }

  void _toggleTaskSelection(String taskId) {
    setState(() {
      if (selectedTaskIds.contains(taskId)) {
        selectedTaskIds.remove(taskId);
      } else {
        selectedTaskIds.add(taskId);
      }
    });
  }

  void _selectAllTasks() {
    setState(() {
      selectedTaskIds = filteredTasks.map((task) => task.id).toList();
    });
  }

  void _clearSelection() {
    setState(() {
      selectedTaskIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6D28D9),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSelectionMode
                              ? 'Delete Tasks (${selectedTaskIds.length} selected)'
                              : 'Delete Tasks',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isSelectionMode
                              ? 'Select tasks to delete'
                              : 'Choose single or multiple tasks to delete',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Selection mode toggle
                  IconButton(
                    onPressed: _toggleSelectionMode,
                    icon: Icon(
                      isSelectionMode ? Icons.close : Icons.checklist,
                      color: Colors.white,
                    ),
                    tooltip: isSelectionMode ? 'Exit selection' : 'Bulk select',
                  ),
                ],
              ),
            ),

            // Content
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
                    // Search and Selection Controls
                    _buildSearchAndControls(),

                    // Tasks List
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildTasksList(),
                    ),

                    // Bottom Action Bar
                    if (isSelectionMode && selectedTaskIds.isNotEmpty)
                      _buildBottomActionBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search tasks to delete...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF3B82F6)),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _filterTasks(''),
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
            onChanged: _filterTasks,
          ),

          // Selection Controls
          if (isSelectionMode) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectAllTasks,
                    icon: const Icon(Icons.select_all),
                    label: const Text('Select All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
                ),
              ],
            ),
          ],

          // Results Info
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Found ${filteredTasks.length} of ${allTasks.length} tasks',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTasksList() {
    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isNotEmpty ? Icons.search_off : Icons.task_alt,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'No tasks found for "$searchQuery"'
                  : 'No tasks to delete',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _filterTasks(''),
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final data = task.data() as Map<String, dynamic>;
        final isSelected = selectedTaskIds.contains(task.id);

        return _buildTaskCard(task, data, isSelected);
      },
    );
  }

  Widget _buildTaskCard(
    QueryDocumentSnapshot task,
    Map<String, dynamic> data,
    bool isSelected,
  ) {
    // Calculate progress
    double progress = 0.0;
    if (data['doorFrameHardware'] == true) progress += 60.0;
    if (data['architrave'] == true) progress += 30.0;
    if (data['handover'] == true) progress += 10.0;

    Color progressColor = progress == 100
        ? Colors.green
        : progress >= 60
        ? Colors.orange
        : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: flutter.Border.all(
          color: isSelected ? Colors.red[300]! : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isSelectionMode
              ? () => _toggleTaskSelection(task.id)
              : () => _showSingleDeleteDialog(task, data),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Selection indicator
                if (isSelectionMode)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red : Colors.transparent,
                      border: flutter.Border.all(
                        color: isSelected ? Colors.red : Colors.grey[400]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),

                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Building ${data['buildingNo']} - Flat ${data['flatNo']}',
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

                      const SizedBox(height: 8),

                      // Details
                      Text(
                        '${data['materialGroup']} - ${data['location']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),

                      Text(
                        'Qty: ${data['qty']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),

                      if (data['remark']?.toString().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Remark: ${data['remark']}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Single delete button
                if (!isSelectionMode)
                  IconButton(
                    onPressed: () => _showSingleDeleteDialog(task, data),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete task',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selectedTaskIds.length} tasks selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'This action cannot be undone',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isDeleting ? null : _showBulkDeleteDialog,
            icon: isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever),
            label: Text(isDeleting ? 'Deleting...' : 'Delete Selected'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSingleDeleteDialog(
    QueryDocumentSnapshot task,
    Map<String, dynamic> data,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Task'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this task?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: flutter.Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Building ${data['buildingNo']} - Flat ${data['flatNo']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('${data['materialGroup']} - ${data['location']}'),
                  Text('Qty: ${data['qty']}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteSingleTask(task.id, data);
    }
  }

  Future<void> _showBulkDeleteDialog() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Multiple Tasks'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${selectedTaskIds.length} tasks?',
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: filteredTasks
                      .where((task) => selectedTaskIds.contains(task.id))
                      .map((task) {
                        final data = task.data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                            border: flutter.Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            'Building ${data['buildingNo']} - Flat ${data['flatNo']} (${data['materialGroup']})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteBulkTasks();
    }
  }

  Future<void> _deleteSingleTask(
    String taskId,
    Map<String, dynamic> data,
  ) async {
    setState(() => isDeleting = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Delete the task
      batch.delete(
        FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('tasks')
            .doc(taskId),
      );

      // Add deletion record to feed
      batch.set(
        FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('feed')
            .doc(),
        {
          'title': 'Task Deleted',
          'description':
              'Task for Building ${data['buildingNo']}, Flat ${data['flatNo']} has been deleted.',
          'timestamp': Timestamp.now(),
          'type': 'task_deletion',
        },
      );

      await batch.commit();

      // Remove from local list
      setState(() {
        allTasks.removeWhere((task) => task.id == taskId);
        filteredTasks.removeWhere((task) => task.id == taskId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting task: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isDeleting = false);
    }
  }

  Future<void> _deleteBulkTasks() async {
    setState(() => isDeleting = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Delete all selected tasks
      for (final taskId in selectedTaskIds) {
        batch.delete(
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('tasks')
              .doc(taskId),
        );
      }

      // Add bulk deletion record to feed
      batch.set(
        FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('feed')
            .doc(),
        {
          'title': 'Bulk Task Deletion',
          'description': '${selectedTaskIds.length} tasks have been deleted.',
          'timestamp': Timestamp.now(),
          'type': 'bulk_task_deletion',
        },
      );

      await batch.commit();

      // Remove from local lists
      setState(() {
        allTasks.removeWhere((task) => selectedTaskIds.contains(task.id));
        filteredTasks.removeWhere((task) => selectedTaskIds.contains(task.id));
        selectedTaskIds.clear();
        isSelectionMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedTaskIds.length} tasks deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting tasks: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isDeleting = false);
    }
  }
}
