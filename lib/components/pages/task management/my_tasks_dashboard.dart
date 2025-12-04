import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/auth_service.dart';
import 'package:vevij/components/widgets/task_card_modern.dart';
import 'package:vevij/components/pages/task management/task_details_page.dart';
import 'package:vevij/components/pages/task management/create_task_page.dart';
import 'package:vevij/utils/app_colors.dart';
import 'package:vevij/utils/app_theme.dart';
import 'package:vevij/models/tasks/user_team_role_model.dart';
import 'package:flutter/services.dart';

/// Personal task dashboard showing all tasks assigned to current user
class MyTasksDashboard extends StatefulWidget {
  const MyTasksDashboard({super.key});

  @override
  State<MyTasksDashboard> createState() => _MyTasksDashboardState();
}

class _MyTasksDashboardState extends State<MyTasksDashboard>
    with SingleTickerProviderStateMixin {
  TaskStatus? _selectedFilter;
  TaskPriority? _selectedPriorityFilter;
  late TabController _tabController;
  String _sortBy = 'dueDate'; // dueDate, priority, status

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final taskService = Provider.of<TaskService>(context, listen: false);
    final currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your tasks')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Overdue'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'dueDate',
                child: Text('Sort by Due Date'),
              ),
              const PopupMenuItem(
                value: 'priority',
                child: Text('Sort by Priority'),
              ),
              const PopupMenuItem(
                value: 'status',
                child: Text('Sort by Status'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: taskService.streamTasksForUser(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                  ElevatedButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: snapshot.error.toString())),
                    child: const Text('copy error'),
                  ),
                ],
              ),
            );
          }

          final allTasks = snapshot.data ?? [];
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList(_filterAndSortTasks(allTasks, null)),
              _buildTaskList(_filterAndSortTasks(
                allTasks,
                [TaskStatus.pending, TaskStatus.inProgress],
              )),
              _buildTaskList(_filterAndSortTasks(
                allTasks,
                [TaskStatus.completed],
              )),
              _buildTaskList(_getOverdueTasks(allTasks)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreateTaskPage())),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<TaskModel> _filterAndSortTasks(
    List<TaskModel> tasks,
    List<TaskStatus>? statusFilter,
  ) {
    var filtered = tasks;

    // Apply status filter
    if (statusFilter != null) {
      filtered = filtered.where((t) => statusFilter.contains(t.status)).toList();
    }

    // Apply selected filters
    if (_selectedFilter != null) {
      filtered = filtered.where((t) => t.status == _selectedFilter).toList();
    }

    if (_selectedPriorityFilter != null) {
      filtered = filtered.where((t) => t.priority == _selectedPriorityFilter).toList();
    }

    // Sort tasks
    filtered = List.from(filtered);
    switch (_sortBy) {
      case 'dueDate':
        filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case 'priority':
        filtered.sort((a, b) => _priorityValue(b.priority).compareTo(_priorityValue(a.priority)));
        break;
      case 'status':
        filtered.sort((a, b) => a.status.name.compareTo(b.status.name));
        break;
    }

    return filtered;
  }

  int _priorityValue(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.critical:
        return 5;
      case TaskPriority.urgent:
        return 4;
      case TaskPriority.high:
        return 3;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.low:
        return 1;
    }
  }

  List<TaskModel> _getOverdueTasks(List<TaskModel> tasks) {
    final now = DateTime.now();
    return tasks
        .where((t) =>
            t.dueDate.isBefore(now) && t.status != TaskStatus.completed)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Widget _buildTaskList(List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tasks assigned to you will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Statistics summary
        _buildStatisticsSummary(tasks),
        
        // Task list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spacing4),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final authService = Provider.of<AuthService>(context, listen: false);
              final taskService = Provider.of<TaskService>(context, listen: false);
              
              return TaskCardModern(
                task: task,
                userId: authService.currentUser?.uid ?? '',
                showActions: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailsPage(
                        task: task,
                        userRole: TeamRole.member, // Default, actual role loaded in page
                      ),
                    ),
                  );
                },
                onComplete: () async {
                  try {
                    await taskService.updateTask(
                      task.id,
                      {'status': TaskStatus.completed.name},
                      by: authService.currentUser?.uid,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Task "${task.title}" completed! 🎉'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateTaskPage(
                        initialTeamId: task.assignedTeamId,
                        taskToEdit: task,
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
  }

  Widget _buildStatisticsSummary(List<TaskModel> tasks) {
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).length;
    final inProgressTasks = tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final overdueTasks = tasks.where((t) =>
        t.dueDate.isBefore(DateTime.now()) &&
        t.status != TaskStatus.completed).length;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing4),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              totalTasks.toString(),
              Icons.list_alt,
              AppColors.primary,
            ),
          ),
          const SizedBox(width: AppTheme.spacing2),
          Expanded(
            child: _buildStatCard(
              'In Progress',
              inProgressTasks.toString(),
              Icons.pending_actions,
              AppColors.info,
            ),
          ),
          const SizedBox(width: AppTheme.spacing2),
          Expanded(
            child: _buildStatCard(
              'Completed',
              completedTasks.toString(),
              Icons.check_circle,
              AppColors.success,
            ),
          ),
          const SizedBox(width: AppTheme.spacing2),
          Expanded(
            child: _buildStatCard(
              'Overdue',
              overdueTasks.toString(),
              Icons.warning,
              AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppTheme.spacing1),
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
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Tasks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedFilter == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = null;
                    });
                    Navigator.pop(context);
                  },
                ),
                ...TaskStatus.values.map((status) {
                  return FilterChip(
                    label: Text(status.name),
                    selected: _selectedFilter == status,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected ? status : null;
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Priority:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedPriorityFilter == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPriorityFilter = null;
                    });
                    Navigator.pop(context);
                  },
                ),
                ...TaskPriority.values.map((priority) {
                  return FilterChip(
                    label: Text(priority.name),
                    selected: _selectedPriorityFilter == priority,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPriorityFilter = selected ? priority : null;
                      });
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedFilter = null;
                _selectedPriorityFilter = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
