import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/models/tasks/team_model.dart';
import 'package:vevij/models/employee/employee.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/team_service.dart';
import 'package:vevij/services/user_service.dart';
import 'package:vevij/components/widgets/task_card_modern.dart';
import 'package:vevij/components/pages/task management/task_details_page.dart';
import 'package:vevij/components/pages/task management/create_task_page.dart';
import 'package:vevij/utils/app_colors.dart';
import 'package:vevij/utils/app_theme.dart';
import 'package:vevij/models/tasks/user_team_role_model.dart';

class AdminTaskDashboard extends StatefulWidget {
  const AdminTaskDashboard({super.key});

  @override
  State<AdminTaskDashboard> createState() => _AdminTaskDashboardState();
}

class _AdminTaskDashboardState extends State<AdminTaskDashboard>
    with SingleTickerProviderStateMixin {
  TaskStatus? _selectedStatusFilter;
  TaskPriority? _selectedPriorityFilter;
  String? _selectedTeamId;
  String? _selectedAssigneeId;
  late TabController _tabController;
  String _sortBy = 'createdAt'; // createdAt, dueDate, priority, status

  List<TeamModel> _teams = [];
  List<Employee> _users = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final userService = Provider.of<UserService>(context, listen: false);

      final teams = await teamService.getTeamsList();
      final users = await userService.getAllUsers();

      if (mounted) {
        setState(() {
          _teams = teams;
          _users = users;
          _users = users;
        });
      }
    } catch (e) {
      print('Error loading filters: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Task Dashboard'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
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
                value: 'createdAt',
                child: Text('Sort by Created Date'),
              ),
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
        stream: taskService.streamAllTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allTasks = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList(_filterAndSortTasks(allTasks, null)),
              _buildTaskList(
                _filterAndSortTasks(allTasks, [
                  TaskStatus.pending,
                  TaskStatus.inProgress,
                ]),
              ),
              _buildTaskList(
                _filterAndSortTasks(allTasks, [TaskStatus.completed]),
              ),
              _buildTaskList(_getOverdueTasks(allTasks)),
            ],
          );
        },
      ),
    );
  }

  List<TaskModel> _filterAndSortTasks(
    List<TaskModel> tasks,
    List<TaskStatus>? statusFilter,
  ) {
    var filtered = tasks;

    // Apply tab status filter
    if (statusFilter != null) {
      filtered = filtered
          .where((t) => statusFilter.contains(t.status))
          .toList();
    }

    // Apply selected status filter
    if (_selectedStatusFilter != null) {
      filtered = filtered
          .where((t) => t.status == _selectedStatusFilter)
          .toList();
    }

    // Apply priority filter
    if (_selectedPriorityFilter != null) {
      filtered = filtered
          .where((t) => t.priority == _selectedPriorityFilter)
          .toList();
    }

    // Apply team filter
    if (_selectedTeamId != null) {
      filtered = filtered
          .where((t) => t.assignedTeamId == _selectedTeamId)
          .toList();
    }

    // Apply assignee filter
    if (_selectedAssigneeId != null) {
      filtered = filtered
          .where((t) => t.assignedTo.contains(_selectedAssigneeId))
          .toList();
    }

    // Sort tasks
    filtered = List.from(filtered);
    switch (_sortBy) {
      case 'createdAt':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'dueDate':
        filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case 'priority':
        filtered.sort(
          (a, b) =>
              _priorityValue(b.priority).compareTo(_priorityValue(a.priority)),
        );
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
    // First apply general filters
    var filtered = _filterAndSortTasks(tasks, null);
    // Then apply overdue logic
    return filtered
        .where(
          (t) => t.dueDate.isBefore(now) && t.status != TaskStatus.completed,
        )
        .toList();
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
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
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

              return TaskCardModern(
                task: task,
                showActions: true, // Admin can always perform actions
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailsPage(
                        task: task,
                        userRole: TeamRole.admin, // Admin view
                      ),
                    ),
                  );
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
    final completedTasks = tasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final inProgressTasks = tasks
        .where((t) => t.status == TaskStatus.inProgress)
        .length;
    final overdueTasks = tasks
        .where(
          (t) =>
              t.dueDate.isBefore(DateTime.now()) &&
              t.status != TaskStatus.completed,
        )
        .length;

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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Tasks'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Filter
                  const Text(
                    'Status:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedStatusFilter == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedStatusFilter = null;
                          });
                          // Update parent state as well
                          this.setState(() {
                            _selectedStatusFilter = null;
                          });
                        },
                      ),
                      ...TaskStatus.values.map((status) {
                        return FilterChip(
                          label: Text(status.name),
                          selected: _selectedStatusFilter == status,
                          onSelected: (selected) {
                            setState(() {
                              _selectedStatusFilter = selected ? status : null;
                            });
                            this.setState(() {
                              _selectedStatusFilter = selected ? status : null;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Priority Filter
                  const Text(
                    'Priority:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                          this.setState(() {
                            _selectedPriorityFilter = null;
                          });
                        },
                      ),
                      ...TaskPriority.values.map((priority) {
                        return FilterChip(
                          label: Text(priority.name),
                          selected: _selectedPriorityFilter == priority,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPriorityFilter = selected
                                  ? priority
                                  : null;
                            });
                            this.setState(() {
                              _selectedPriorityFilter = selected
                                  ? priority
                                  : null;
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Team Filter
                  const Text(
                    'Team:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedTeamId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Teams'),
                      ),
                      ..._teams.map(
                        (team) => DropdownMenuItem(
                          value: team.id,
                          child: Text(team.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedTeamId = value);
                      this.setState(() => _selectedTeamId = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Assignee Filter
                  const Text(
                    'Assignee:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedAssigneeId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Employees'),
                      ),
                      ..._users.map(
                        (user) => DropdownMenuItem(
                          value: user.uid,
                          child: Text(user.empName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedAssigneeId = value);
                      this.setState(() => _selectedAssigneeId = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  this.setState(() {
                    _selectedStatusFilter = null;
                    _selectedPriorityFilter = null;
                    _selectedTeamId = null;
                    _selectedAssigneeId = null;
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
          );
        },
      ),
    );
  }
}
