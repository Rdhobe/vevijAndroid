import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/models/tasks/team_model.dart';
import 'package:vevij/models/employee/employee.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/team_service.dart';
import 'package:vevij/services/user_service.dart';
import 'package:vevij/services/auth_service.dart';
import 'package:vevij/utils/helpers.dart';

class CreateTaskPage extends StatefulWidget {
  final TaskModel? taskToEdit;
  final String? initialTeamId;
  const CreateTaskPage({super.key, this.taskToEdit, this.initialTeamId});

  @override
  CreateTaskPageState createState() => CreateTaskPageState();
}

class CreateTaskPageState extends State<CreateTaskPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  TeamModel? _selectedTeam;
  List<TeamModel> _teams = [];
  DateTime? _selectedDueDate;
  TaskPriority _selectedPriority = TaskPriority.medium;
  TaskCategory _selectedCategory = TaskCategory.general;
  String _assignmentType = 'team'; // 'team' or 'individual'

  List<Employee> _selectedAssignees = [];
  List<Employee> _selectedMonitors = [];
  List<Employee> _selectedWatchers = [];

  List<Employee> _availableUsers = [];
  List<Employee> _availableMonitors = [];

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.taskToEdit != null;
    _loadTeamsAndUsers();
  }

  Future<void> _loadTeamsAndUsers() async {
    await Future.wait([_loadTeams(), _loadUsers()]);

    if (_isEditMode && mounted) {
      _populateFieldsForEdit();
    }
  }

  void _populateFieldsForEdit() {
    final task = widget.taskToEdit!;
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _selectedDueDate = task.dueDate;
    _selectedPriority = task.priority;
    _selectedCategory = task.category;

    // Determine assignment type based on team ID
    if (task.assignedTeamId.isEmpty) {
      _assignmentType = 'individual';
    } else {
      _assignmentType = 'team';
      // Set the team - safely handle empty teams list
      if (_teams.isNotEmpty) {
        _selectedTeam = _teams.firstWhere(
          (team) => team.id == task.assignedTeamId,
          orElse: () => _teams.first,
        );
      }
    }

    setState(() {
      // Set assignees, monitors, and watchers from the task
      _selectedAssignees = _availableUsers
          .where((user) => task.assignedTo.contains(user.uid))
          .toList();
      _selectedMonitors = _availableUsers
          .where((user) => task.monitors.contains(user.uid))
          .toList();
      _selectedWatchers = _availableUsers
          .where((user) => task.watchers.contains(user.uid))
          .toList();
    });
  }

  Future<void> _loadTeams() async {
    try {
      print('Loading teams...');
      final teamService = Provider.of<TeamService>(context, listen: false);
      final teams = await teamService.getTeamsList();
      print('Loaded teams: ${teams.length}');

      setState(() {
        _teams = teams;
      });
    } catch (e) {
      print('Error loading teams: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load teams: $e')));
    }
  }

  Future<void> _loadUsers() async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final users = await userService.getAllUsers();
      setState(() {
        _availableUsers = users;
        // Filter for monitors based on designation
        _availableMonitors = users.where((user) {
          final designation = user.designation.toLowerCase();
          return designation.contains('manager') ||
              designation.contains('admin') ||
              designation.contains('hr') ||
              designation.contains('lead') ||
              designation.contains('supervisor') ||
              designation.contains('head');
        }).toList();
      });
    } catch (e) {
      print('Error loading users: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load users')));
    }
  }

  bool _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a task title')));
      return false;
    }

    if (_assignmentType == 'team' && _selectedTeam == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a team')));
      return false;
    }

    if (_selectedDueDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a due date')));
      return false;
    }

    if (_selectedAssignees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one assignee')),
      );
      return false;
    }

    return true;
  }

  Future<void> _continue() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final taskService = Provider.of<TaskService>(context, listen: false);
      final assignedTeamId = _assignmentType == 'team' ? _selectedTeam!.id : '';

      if (_isEditMode) {
        // Update existing task
        final task = widget.taskToEdit!;
        await taskService.updateTask(task.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'assignedTeamId': assignedTeamId,
          'dueDate': Timestamp.fromDate(_selectedDueDate!),
          'priority': _selectedPriority.toString().split('.').last,
          'category': _selectedCategory.toString().split('.').last,
          'estimatedHours': 0.0, // Removed estimated hours
          'assignedTo': _selectedAssignees.map((user) => user.uid).toList(),
          'monitors': _selectedMonitors.map((user) => user.uid).toList(),
          'watchers': _selectedWatchers.map((user) => user.uid).toList(),
          'updatedAt': DateTime.now(),
        }, by: AuthService().currentUser?.uid ?? 'unknown');

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Task updated successfully')));
      } else {
        // Create new task
        final firebaseUser = AuthService().currentUser;
        Employee? currentUser;

        if (firebaseUser != null) {
          final userService = Provider.of<UserService>(context, listen: false);
          currentUser = await userService.getUserById(firebaseUser.uid);
        }

        if (currentUser == null) {
          throw Exception('User not authenticated');
        }

        final task = TaskModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          assignedTeamId: assignedTeamId,
          assignedTo: _selectedAssignees.map((user) => user.uid).toList(),
          createdBy: currentUser.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dueDate: _selectedDueDate!,
          status: TaskStatus.pending,
          priority: _selectedPriority,
          category: _selectedCategory,
          estimatedHours: 0.0, // Removed estimated hours
          monitors: _selectedMonitors.map((user) => user.uid).toList(),
          watchers: _selectedWatchers.map((user) => user.uid).toList(),
        );

        await taskService.createTask(task);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Task created successfully')));
      }

      Navigator.of(context).pop();
    } catch (e) {
      print('Error saving task: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _showUserSelectionDialog(
    List<Employee> users,
    List<Employee> selectedUsers,
    Function(List<Employee>) onSelected,
    String dialogTitle,
  ) {
    // Create a copy for the dialog state
    final tempSelectedUsers = List<Employee>.from(selectedUsers);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(dialogTitle),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isSelected = tempSelectedUsers.any(
                    (u) => u.uid == user.uid,
                  );

                  return CheckboxListTile(
                    title: Text(user.empName),
                    subtitle: Text(user.designation),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setDialogState(() {
                        if (value == true) {
                          tempSelectedUsers.add(user);
                        } else {
                          tempSelectedUsers.removeWhere(
                            (u) => u.uid == user.uid,
                          );
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  onSelected(List.from(tempSelectedUsers));
                  Navigator.of(context).pop();
                },
                child: Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Task' : 'Create New Task'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _isLoading ? null : _continue,
            tooltip: _isEditMode ? 'Update Task' : 'Create Task',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic Information Section
                  _buildBasicInfoSection(),
                  SizedBox(height: 24),

                  // Assignment Type Section
                  _buildAssignmentTypeSection(),
                  SizedBox(height: 24),

                  // Team Selection Section (Conditional)
                  if (_assignmentType == 'team') ...[
                    _buildTeamSelectionSection(),
                    SizedBox(height: 24),
                  ],

                  // Assignees Section
                  _buildAssigneesSection(),
                  SizedBox(height: 24),

                  // Due Date Section
                  _buildDueDateSection(),
                  SizedBox(height: 24),

                  // Additional Settings
                  _buildAdditionalSettingsSection(),
                  SizedBox(height: 24),

                  // Create/Update Button
                  _buildCreateButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Task Title *',
            border: OutlineInputBorder(),
            hintText: 'Enter task title',
          ),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            hintText: 'Enter task description',
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assignment Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _assignmentType,
            isExpanded: true,
            underline: SizedBox(),
            items: [
              DropdownMenuItem(value: 'team', child: Text('Team Assignment')),
              DropdownMenuItem(
                value: 'individual',
                child: Text('Individual Assignment'),
              ),
            ],
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _assignmentType = newValue;
                  // Clear selections when switching types to avoid inconsistencies
                  _selectedAssignees = [];
                  _selectedMonitors = [];
                  if (_assignmentType == 'individual') {
                    _selectedTeam = null;
                  }
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assign to Team *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<TeamModel>(
            value: _selectedTeam,
            isExpanded: true,
            underline: SizedBox(),
            hint: Text(
              'Select a team',
              style: TextStyle(color: Colors.grey[600]),
            ),
            items: _teams.map((TeamModel team) {
              return DropdownMenuItem<TeamModel>(
                value: team,
                child: Text(team.name, style: TextStyle(fontSize: 16)),
              );
            }).toList(),
            onChanged: (TeamModel? newValue) {
              setState(() {
                _selectedTeam = newValue;
                // When team changes, ensure selected assignees/monitors/watchers
                // are members of the newly selected team.
                if (_selectedTeam != null) {
                  final memberIds = _selectedTeam!.memberIds;
                  _selectedAssignees = _selectedAssignees
                      .where((u) => memberIds.contains(u.uid))
                      .toList();
                  _selectedMonitors = _selectedMonitors
                      .where((u) => memberIds.contains(u.uid))
                      .toList();
                  _selectedWatchers = _selectedWatchers
                      .where((u) => memberIds.contains(u.uid))
                      .toList();
                }
              });
            },
          ),
        ),
        if (_selectedTeam != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                SizedBox(width: 8),
                Text(
                  'Selected Team: ${_selectedTeam!.name}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAssigneesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assign To *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            if (_assignmentType == 'team' && _selectedTeam == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please select a team first')),
              );
              return;
            }

            List<Employee> eligibleUsers;
            if (_assignmentType == 'team' && _selectedTeam != null) {
              final memberIds = _selectedTeam!.memberIds;
              eligibleUsers = _availableUsers
                  .where((u) => memberIds.contains(u.uid))
                  .toList();
            } else {
              // Individual assignment - show all users
              eligibleUsers = _availableUsers;
            }

            _showUserSelectionDialog(eligibleUsers, _selectedAssignees, (
              selected,
            ) {
              setState(() {
                _selectedAssignees = selected;
              });
            }, 'Select Assignees');
          },
          icon: Icon(Icons.group_add),
          label: Text('Select Assignees'),
        ),
        if (_selectedAssignees.isNotEmpty) ...[
          SizedBox(height: 12),
          Text(
            'Selected Assignees:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedAssignees
                .map(
                  (user) => Chip(
                    label: Text(user.empName),
                    avatar: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        user.empName[0].toUpperCase(),
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedAssignees.removeWhere(
                          (u) => u.uid == user.uid,
                        );
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ],

        SizedBox(height: 20),
        Text(
          'Monitors',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () {
            if (_assignmentType == 'team' && _selectedTeam == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please select a team first')),
              );
              return;
            }

            List<Employee> eligibleMonitors;
            if (_assignmentType == 'team' && _selectedTeam != null) {
              final memberIds = _selectedTeam!.memberIds;
              eligibleMonitors = _availableMonitors
                  .where((u) => memberIds.contains(u.uid))
                  .toList();
            } else {
              eligibleMonitors = _availableMonitors;
            }

            _showUserSelectionDialog(eligibleMonitors, _selectedMonitors, (
              selected,
            ) {
              setState(() {
                _selectedMonitors = selected;
              });
            }, 'Select Monitors');
          },
          icon: Icon(Icons.visibility),
          label: Text('Select Monitors'),
        ),
        if (_selectedMonitors.isNotEmpty) ...[
          SizedBox(height: 12),
          Text(
            'Selected Monitors:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedMonitors
                .map(
                  (user) => Chip(
                    label: Text(user.empName),
                    avatar: CircleAvatar(
                      backgroundColor: Colors.orange[100],
                      child: Text(
                        user.empName[0].toUpperCase(),
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedMonitors.removeWhere((u) => u.uid == user.uid);
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDueDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _selectDueDate,
          icon: Icon(Icons.calendar_today),
          label: Text(
            _selectedDueDate == null
                ? 'Select Due Date'
                : 'Due: ${Helpers.formatDate(_selectedDueDate!)}',
          ),
        ),
        if (_selectedDueDate != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available, color: Colors.blue[700], size: 16),
                SizedBox(width: 8),
                Text(
                  'Selected: ${Helpers.formatDate(_selectedDueDate!)}',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdditionalSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Settings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 16),

        // Priority
        DropdownButtonFormField<TaskPriority>(
          value: _selectedPriority,
          decoration: InputDecoration(
            labelText: 'Priority',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: TaskPriority.values.map((priority) {
            return DropdownMenuItem<TaskPriority>(
              value: priority,
              child: Text(
                priority.name.toUpperCase(),
                style: TextStyle(
                  color: _getPriorityColor(priority),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedPriority = value!;
            });
          },
        ),

        SizedBox(height: 16),

        // Category
        DropdownButtonFormField<TaskCategory>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: TaskCategory.values.map((category) {
            return DropdownMenuItem<TaskCategory>(
              value: category,
              child: Text(
                category.name.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value!;
            });
          },
        ),
      ],
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.critical:
        return Colors.purple;
      case TaskPriority.urgent:
        return Colors.deepOrange;
    }
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _continue,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          backgroundColor: _isEditMode ? Colors.orange[600] : Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isEditMode ? 'Update Task' : 'Create Task',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
