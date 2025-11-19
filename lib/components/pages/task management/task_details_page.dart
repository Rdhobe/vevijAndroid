import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/models/employee/employee.dart';
import 'package:vevij/models/tasks/user_team_role_model.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/auth_service.dart';
import 'package:vevij/services/user_service.dart';
import 'package:vevij/utils/helpers.dart';
import 'package:vevij/components/pages/task management/comments_page.dart';
import 'package:vevij/components/pages/task management/create_task_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskDetailsPage extends StatefulWidget {
  final TaskModel task;
  final TeamRole userRole;

  const TaskDetailsPage({
    super.key, 
    required this.task,
    required this.userRole,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  late TaskModel _task;
  bool _isEditingDueDate = false;
  DateTime? _tempDueDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // FIXED: Don't use Provider in property getters that are called during build
  bool _canEditTask(BuildContext context) {
    return widget.userRole == TeamRole.manager ||
           widget.userRole == TeamRole.admin ||
           widget.userRole == TeamRole.hr;
  }

  bool _canDeleteTask() {
    return widget.userRole == TeamRole.admin ||
           widget.userRole == TeamRole.hr;
  }

  bool _canUpdateStatus(BuildContext context) {
    // Members can only update their assigned tasks
    if (widget.userRole == TeamRole.member) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.uid;
      return _task.assignedTo.contains(currentUserId);
    }
    return widget.userRole != TeamRole.monitor;
  }

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _tempDueDate = _task.dueDate;
  }

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.comment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommentsPage(taskId: _task.id),
                ),
              );
            },
          ),
          if (_canEditTask(context))
            PopupMenuButton<String>(
              onSelected: (value) {
                _handleAction(value, taskService, context);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit Task'),
                ),
                if (_canDeleteTask())
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Task'),
                  ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info Card
            _buildBasicInfoCard(taskService, authService),
            const SizedBox(height: 16),
            
            // Description Card
            _buildDescriptionCard(),
            const SizedBox(height: 16),
            
            // Assignees Card
            _buildAssigneesCard(),
            const SizedBox(height: 16),
            
            // Status Update Section (if user can update status)
            if (_canUpdateStatus(context))
              _buildStatusUpdateSection(taskService, authService),
            
            // Attachments Card
            _buildAttachmentsCard(authService),
            const SizedBox(height: 16),
            
            // Task History
            _buildTaskHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(TaskService taskService, AuthService authService) {
    final isOverdue = Helpers.isOverdue(_task);
    final daysRemaining = Helpers.daysRemaining(_task);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    _task.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(status: _task.status),
              ],
            ),
            const SizedBox(height: 16),
            
            // Priority
            Row(
              children: [
                Icon(
                  Icons.priority_high,
                  color: Color(Helpers.priorityColor(_task.priority)),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Priority: ${Helpers.priorityText(_task.priority)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(Helpers.priorityColor(_task.priority)),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Due Date Section
            _buildDueDateSection(taskService, authService, isOverdue, daysRemaining),
            const SizedBox(height: 12),
            
            // Team Info
            _InfoRow(
              icon: Icons.group_work,
              label: 'Team',
              value: _task.assignedTeamId,
            ),
            
            // Created By
            _InfoRow(
              icon: Icons.person,
              label: 'Created By',
              value: _task.createdBy,
            ),
            
            // Created Date
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Created',
              value: Helpers.formatDateTime(_task.createdAt),
            ),
            
            // Last Updated
            _InfoRow(
              icon: Icons.update,
              label: 'Last Updated',
              value: Helpers.formatDateTime(_task.updatedAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateSection(TaskService taskService, AuthService authService, bool isOverdue, int daysRemaining) {
    final canEditDueDate = _canEditTask(context);

    return Row(
      children: [
        Icon(
          Icons.calendar_today,
          color: isOverdue ? Colors.red : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Due Date',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (_isEditingDueDate && canEditDueDate)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Helpers.formatDate(_tempDueDate!),
                        style: TextStyle(
                          fontSize: 16,
                          color: isOverdue ? Colors.red : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _saveDueDate(taskService, authService),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _isEditingDueDate = false;
                          _tempDueDate = _task.dueDate;
                        });
                      },
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Helpers.formatDate(_task.dueDate),
                        style: TextStyle(
                          fontSize: 16,
                          color: isOverdue ? Colors.red : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'OVERDUE',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (daysRemaining <= 3)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${daysRemaining}d left',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (canEditDueDate)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: _selectNewDueDate,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusUpdateSection(TaskService taskService, AuthService authService) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskStatus>(
              value: _task.status,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: TaskStatus.values.map((status) {
                return DropdownMenuItem<TaskStatus>(
                  value: status,
                  child: Text(Helpers.statusText(status)),
                );
              }).toList(),
              onChanged: _canUpdateStatus(context) ? (newStatus) {
                if (newStatus != null) {
                  _updateTaskStatus(taskService, authService, newStatus);
                }
              } : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTaskStatus(TaskService taskService, AuthService authService, TaskStatus newStatus) async {
    try {
      final currentUserId = authService.currentUser?.uid ?? 'unknown';

      await taskService.updateTask(
        _task.id,
        {'status': newStatus.name},
        by: currentUserId,
      );

      setState(() {
        _task = _task.copyWith(status: newStatus);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _task.description,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assigned To',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_task.assignedTo.isEmpty)
              const Text(
                'No one assigned',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _task.assignedTo.map((userId) {
                  return _AssigneeChip(userId: userId);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsCard(AuthService authService) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attachments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _pickAndUploadAttachment(authService),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Show attachments
            _task.attachments.isEmpty
                ? const Text(
                    'No attachments',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  )
                : Column(
                    children: _task.attachments.map((url) {
                      return ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(_getFileNameFromUrl(url)),
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _downloadAttachment(url),
                        ),
                        onTap: () => _downloadAttachment(url),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHistorySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<TaskService>(context).streamTaskHistory(_task.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final history = snapshot.data ?? [];

                  if (history.isEmpty) {
                    return const Center(
                      child: Text(
                        'No history available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      return _HistoryItem(entry: entry, userId: entry['userId']);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileNameFromUrl(String url) {
    try {
      return url.split('/').last;
    } catch (e) {
      return 'Attachment';
    }
  }

  void _selectNewDueDate() async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: _task.dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate != null) {
      setState(() {
        _tempDueDate = newDate;
        _isEditingDueDate = true;
      });
    }
  }

  void _saveDueDate(TaskService taskService, AuthService authService) async {
    try {
      final currentUserId = authService.currentUser?.uid ?? 'unknown';
      
      await taskService.updateTask(
        _task.id,
        {'dueDate': Timestamp.fromDate(_tempDueDate!)},
        by: currentUserId,
      );

      setState(() {
        _task = _task.copyWith(dueDate: _tempDueDate!);
        _isEditingDueDate = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due date updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update due date: $e')),
      );
    }
  }

  void _handleAction(String value, TaskService taskService, BuildContext context) {
    switch (value) {
      case 'edit':
        if (_canEditTask(context)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateTaskPage(taskToEdit: _task),
            ),
          );
        }
        break;
      case 'delete':
        if (_canDeleteTask()) {
          _showDeleteConfirmation(taskService, context);
        }
        break;
    }
  }

  void _showDeleteConfirmation(TaskService taskService, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteTask(taskService, context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(TaskService taskService, BuildContext context) async {
    try {
      await taskService.deleteTask(_task.id);
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Go back to previous screen
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadAttachment(AuthService authService) async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null) return;

      final filePath = result.files.single.path;
      if (filePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected file not available')));
        return;
      }

      final currentUserId = authService.currentUser?.uid ?? 'unknown';
      final taskService = Provider.of<TaskService>(context, listen: false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await taskService.addAttachmentToTask(_task.id, filePath, currentUserId);

      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attachment uploaded')));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload attachment: $e')));
    }
  }

  Future<void> _downloadAttachment(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open attachment')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open attachment: $e')));
    }
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        Helpers.statusText(status),
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      backgroundColor: Color(Helpers.statusColor(status)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatefulWidget {
  final Map<String, dynamic> entry;
  final String userId;
  const _HistoryItem({required this.entry, required this.userId});

  @override
  State<_HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<_HistoryItem> {
  late Future<String> _userNameFuture;
  @override
  void initState() {
    super.initState();
    _userNameFuture = _fetchUserName();
  }

  Future<String> _fetchUserName() async {
    try {
      // You'll need to implement this based on your UserService
      final Employee? user = await UserService().getUserById(widget.userId);
      return user?.empName ?? 'User ${widget.userId.substring(0, 8)}...';
    } catch (e) {
      return 'Unknown User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = (widget.entry['timestamp'] as Timestamp).toDate();
    
    return FutureBuilder(
      future: _userNameFuture,
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'Loading...';
        final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry['action'] ?? 'Action',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (widget.entry['changes'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatChanges(widget.entry['changes']),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'By: $userName',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        Helpers.formatDateTime(timestamp),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  String _formatChanges(Map<String, dynamic> changes) {
    final changesList = changes.entries.map((e) {
      if (e.key == 'dueDate') {
        return '${e.key}: ${Helpers.formatDate((e.value as Timestamp).toDate())}';
      }
      return '${e.key}: ${e.value}';
    }).toList();
    return changesList.join(', ');
  }
}

class _AssigneeChip extends StatefulWidget {
  final String userId;

  const _AssigneeChip({required this.userId});

  @override
  State<_AssigneeChip> createState() => _AssigneeChipState();
}

class _AssigneeChipState extends State<_AssigneeChip> {
  late Future<String> _userNameFuture;

  @override
  void initState() {
    super.initState();
    _userNameFuture = _fetchUserName();
  }

  Future<String> _fetchUserName() async {
    try {
      // You'll need to implement this based on your UserService
      final Employee? user = await UserService().getUserById(widget.userId);
      return user?.empName ?? 'User ${widget.userId.substring(0, 8)}...';
    } catch (e) {
      return 'Unknown User';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _userNameFuture,
      builder: (context, snapshot) {
        final userName = snapshot.data ?? 'Loading...';
        final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

        return Chip(
          label: Text(
            userName,
            style: const TextStyle(fontSize: 12),
          ),
          avatar: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.blue.shade200,
            child: Text(
              firstLetter,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: Colors.blue.shade50,
        );
      },
    );
  }
}