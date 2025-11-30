import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vevij/models/tasks/user_team_role_model.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/auth_service.dart';
import 'package:vevij/components/pages/task management/report_page.dart';
import 'package:vevij/components/pages/task management/create_task_page.dart';
import 'package:vevij/components/pages/task management/task_details_page.dart';
import 'package:vevij/components/widgets/task_card_modern.dart';

class TeamTasksPage extends StatefulWidget {
  final String teamId;
  final String teamName;
  final TeamRole userRole;
  final bool isSuperAdminOrHr;

  const TeamTasksPage({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.userRole,
    this.isSuperAdminOrHr = false,
  });

  @override
  State<TeamTasksPage> createState() => _TeamTasksPageState();
}

class _TeamTasksPageState extends State<TeamTasksPage> {
  TaskStatus? _selectedFilter;

  bool get _canCreateTask {
    return widget.userRole == TeamRole.manager ||
        widget.userRole == TeamRole.admin ||
        widget.userRole == TeamRole.hr ||
        widget.isSuperAdminOrHr;
  }

  bool get _canViewReports {
    return widget.userRole != TeamRole.member || widget.isSuperAdminOrHr;
  }

  bool get _canViewAllTasks {
    return widget.userRole != TeamRole.member || widget.isSuperAdminOrHr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName),
        actions: [
          if (_canViewReports)
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportPage(
                      teamId: widget.teamId,
                      userRole: widget.userRole,
                    ),
                  ),
                );
              },
              tooltip: 'View Reports',
            ),
        ],
      ),
      body: _buildTaskList(),
      
    );
  }

  Widget _buildTaskList() {
    return StreamBuilder<List<TaskModel>>(
      stream: _getTasksStream(),
      builder: (context, snapshot) {
        print('StreamBuilder state: ${snapshot.connectionState}');
        print('StreamBuilder hasError: ${snapshot.hasError}');
        print('StreamBuilder hasData: ${snapshot.hasData}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Task stream error: ${snapshot.error}');
          print('Error stack trace: ${snapshot.stackTrace}');
          return _buildErrorState(snapshot.error);
        }

        if (!snapshot.hasData) {
          return _buildEmptyState();
        }

        final tasks = snapshot.data!;
        print('Loaded ${tasks.length} tasks for team ${widget.teamId}');

        final filteredTasks = _selectedFilter == null
            ? tasks
            : tasks.where((t) => t.status == _selectedFilter).toList();

        return Column(
          children: [
            _buildFilterChips(tasks),
            Expanded(
              child: filteredTasks.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return TaskCardModern(
                          task: task,
                          showActions:
                              widget.isSuperAdminOrHr ||
                              widget.userRole == TeamRole.manager ||
                              widget.userRole == TeamRole.admin,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TaskDetailsPage(
                                  task: task,
                                  userRole: widget.userRole,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Stream<List<TaskModel>> _getTasksStream() {
    final taskService = Provider.of<TaskService>(context, listen: false);

    if (_canViewAllTasks) {
      print('Loading ALL tasks for team: ${widget.teamId}');
      return taskService.streamTasksForTeam(widget.teamId);
    } else {
      // For members, filter tasks assigned to them
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.uid;

      print(
        'Loading USER tasks for team: ${widget.teamId}, user: $currentUserId',
      );

      if (currentUserId == null) {
        print('No current user ID found');
        return Stream.value([]);
      }

      return taskService.streamTasksForTeam(widget.teamId).map((tasks) {
        final userTasks = tasks
            .where((task) => task.assignedTo.contains(currentUserId))
            .toList();
        print('Filtered ${userTasks.length} tasks for user $currentUserId');
        return userTasks;
      });
    }
  }

  Widget _buildErrorState(dynamic error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Tasks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Error: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check:\n• Internet connection\n• Firebase permissions\n• Task data structure',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _selectedFilter == null,
            onSelected: (selected) {
              setState(() {
                _selectedFilter = null;
              });
            },
          ),
          ...TaskStatus.values
              .map((status) {
                final count = tasks.where((t) => t.status == status).length;
                if (count == 0) return const SizedBox.shrink();

                return FilterChip(
                  label: Text('${_getStatusText(status)} ($count)'),
                  selected: _selectedFilter == status,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = selected ? status : null;
                    });
                  },
                );
              })
              .where((chip) => chip != const SizedBox.shrink())
              .toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _canCreateTask ? 'No Tasks Created' : 'No Tasks Assigned',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              _canCreateTask
                  ? 'Create the first task for this team'
                  : 'You have no assigned tasks in this team',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (_canCreateTask) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateTaskPage(initialTeamId: widget.teamId),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create First Task'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  
  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }
}
