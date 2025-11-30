
import 'package:vevij/models/tasks/team_model.dart';
import 'package:vevij/components/imports.dart';

class CreateTeamPage extends StatefulWidget {
  final String? teamId; // For editing existing team

  const CreateTeamPage({super.key, this.teamId});

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  List<TeamMember> _members = [];
  List<Employee> _allEmployees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isEditing = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _isEditing = widget.teamId != null;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        _loadEmployees(),
        if (_isEditing) _loadTeamData(),
      ]);
    } catch (e) {
      print('Failed to load data: $e');
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      setState(() {
        _allEmployees = snapshot.docs
            .map((doc) => Employee.fromMap(doc.data()))
            .toList();
        _filteredEmployees = _allEmployees;
      });
    } catch (e) {
      print('Failed to load employees: $e');
      _showError('Failed to load employees: $e');
    }
  }

  Future<void> _loadTeamData() async {
    try {
      final doc = await _firestore.collection('teams').doc(widget.teamId).get();
      if (doc.exists) {
        final team = TeamModel.fromMap(doc.data()!);
        _nameController.text = team.name;
        _descriptionController.text = team.description;
        _members = team.members;
      }
    } catch (e) {
      print('Failed to load team data: $e');
      _showError('Failed to load team data: $e');
    }
  }

  void _filterEmployees(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredEmployees = _allEmployees;
      } else {
        _filteredEmployees = _allEmployees.where((employee) {
          final name = employee.empName.toLowerCase();
          final code = employee.empCode.toLowerCase();
          final department = employee.department.toLowerCase();
          final searchLower = query.toLowerCase();
          
          return name.contains(searchLower) || 
                 code.contains(searchLower) ||
                 department.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _saveTeam() async {
    if (_nameController.text.isEmpty) {
      print('Please enter team name');
      _showError('Please enter team name');
      return;
    }

    if (_members.isEmpty) {
      print('Please add at least one team member');
      _showError('Please add at least one team member');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final teamData = {
        'teamId': _isEditing ? widget.teamId : _firestore.collection('teams').doc().id,
        'teamName': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdBy': AuthService().getCurrentUserId(), // Get from auth
        'memberIds': _members.map((m) => m.userId).toList(),
        'members': _members.map((m) => m.toMap()).toList(),
        'createdAt': _isEditing ? Timestamp.now() : Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      if (_isEditing) {
        // Update existing team
        await _firestore.collection('teams').doc(widget.teamId).update(teamData);
        _showSuccess('Team updated successfully');
      } else {
        // Create new team - use the generated ID as both document ID and teamId
        final newDocRef = _firestore.collection('teams').doc();
        teamData['teamId'] = newDocRef.id;
        teamData['createdAt'] = Timestamp.now();
        await newDocRef.set(teamData);
        _showSuccess('Team created successfully');
      }

      Navigator.pop(context);
    } catch (e) {
      print('Failed to save team: $e');
      _showError('Failed to save team: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMember(Employee employee, String role) {
    // Check if member already exists
    if (_members.any((member) => member.userId == employee.uid)) {
      print('${employee.empName} is already in the team');
      _showError('${employee.empName} is already in the team');
      return;
    }

    final member = TeamMember(
      userId: employee.uid,
      addedBy: AuthService().getCurrentUserId(), // Get from auth
      role: role,
      joinedAt: DateTime.now(),
    );

    setState(() => _members.add(member));
    _showSuccess('${employee.empName} added to team');
  }

  void _removeMember(TeamMember member) {
    final employee = _allEmployees.firstWhere(
      (emp) => emp.uid == member.userId,
      orElse: () => Employee.unknown(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove ${employee.empName} from the team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _members.remove(member));
              Navigator.pop(context);
              _showSuccess('${employee.empName} removed from team');
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _updateMemberRole(TeamMember member, String newRole) {
    setState(() {
      final index = _members.indexWhere((m) => m.userId == member.userId);
      if (index != -1) {
        _members[index] = TeamMember(
          userId: member.userId,
          addedBy: member.addedBy,
          role: newRole,
          joinedAt: member.joinedAt,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Team' : 'Create Team'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          _buildSaveButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: Padding(
  padding: const EdgeInsets.only(right: 12.0, bottom: 8.0),
  child: FloatingActionButton(
    onPressed: _showAddMemberBottomSheet,
    backgroundColor: Colors.deepPurple,
    elevation: 8,
    child: Icon(Icons.add, size: 28),
  ),
),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: IconButton(
        icon: const Icon(Icons.save),
        onPressed: _saveTeam,
        tooltip: 'Save Team',
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Team Details Card
        _buildTeamDetailsCard(),
        
        // Members Section
        Expanded(
          child: _buildMembersSection(),
        ),
      ],
    );
  }

  Widget _buildTeamDetailsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Team Name *',
                border: OutlineInputBorder(),
                hintText: 'Enter team name...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Enter team description...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      children: [
        // Members Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Team Members (${_members.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const Spacer(),
              Text(
                '${_members.length}/50',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Members List
        Expanded(
          child: _members.isEmpty
              ? _buildEmptyMembersState()
              : _buildMembersList(),
        ),
        
        // Add Member Button
        // Container(
        //   padding: const EdgeInsets.all(16),
        //   child: ElevatedButton.icon(
        //     onPressed: () => _showAddMemberBottomSheet(),
        //     icon: const Icon(Icons.person_add),
        //     label: const Text('Add Team Members'),
        //     style: ElevatedButton.styleFrom(
        //       backgroundColor: Colors.blue,
        //       foregroundColor: Colors.white,
        //       minimumSize: const Size(double.infinity, 50),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildMembersList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _members.length,
      itemBuilder: (context, index) => _buildMemberCard(_members[index]),
    );
  }

  Widget _buildMemberCard(TeamMember member) {
    final employee = _allEmployees.firstWhere(
      (emp) => emp.uid == member.userId,
      orElse: () => Employee.unknown(),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            employee.empName.isNotEmpty ? employee.empName[0] : '?',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        title: Text(
          employee.empName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${employee.empCode} • ${employee.department}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'Role: ${member.role}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'change_role',
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Change Role'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Remove', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'change_role') {
              _showRoleChangeDialog(member);
            } else if (value == 'remove') {
              _removeMember(member);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyMembersState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No Team Members',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add team members to get started',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddMemberBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return _AddMemberBottomSheet(
            employees: _filteredEmployees,
            searchQuery: _searchQuery,
            onSearchChanged: (query) {
              _filterEmployees(query);
              setModalState(() {}); // This triggers rebuild of the bottom sheet
            },
            onMemberAdded: _addMember,
            existingMembers: _members,
          );
        },
      ),
    );
  }
  void _showRoleChangeDialog(TeamMember member) {
    final employee = _allEmployees.firstWhere(
      (emp) => emp.uid == member.userId,
      orElse: () => Employee.unknown(),
    );

    String selectedRole = member.role;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${employee.empName}'),
        content: DropdownButtonFormField<String>(
          value: selectedRole,
          items: const [
            DropdownMenuItem(value: 'Manager', child: Text('Manager')),
            DropdownMenuItem(value: 'Monitor', child: Text('Monitor')),
            DropdownMenuItem(value: 'Team Lead', child: Text('Team Lead')),
            DropdownMenuItem(value: 'Senior Member', child: Text('Senior Member')),
            DropdownMenuItem(value: 'Member', child: Text('Member')),
            DropdownMenuItem(value: 'Trainee', child: Text('Trainee')),
          ],
          onChanged: (value) => selectedRole = value!,
          decoration: const InputDecoration(labelText: 'Select Role'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateMemberRole(member, selectedRole);
              Navigator.pop(context);
              _showSuccess('Role updated to $selectedRole');
            },
            child: const Text('Update Role'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _AddMemberBottomSheet extends StatefulWidget {
  final List<Employee> employees;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final Function(Employee, String) onMemberAdded;
  final List<TeamMember> existingMembers;

  const _AddMemberBottomSheet({
    required this.employees,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onMemberAdded,
    required this.existingMembers,
  });

  @override
  State<_AddMemberBottomSheet> createState() => _AddMemberBottomSheetState();
}

class _AddMemberBottomSheetState extends State<_AddMemberBottomSheet> {
  String _selectedRole = 'Member';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  List<Employee> get _availableEmployees {
    final existingUserIds = widget.existingMembers.map((m) => m.userId).toList();
    return widget.employees.where((emp) => !existingUserIds.contains(emp.uid)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Add Team Members',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, ID, or department...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: widget.onSearchChanged,
          ),
          const SizedBox(height: 16),
          
          // Role Selection
          DropdownButtonFormField<String>(
            value: _selectedRole,
            items: const [
              DropdownMenuItem(value: 'Manager', child: Text('Manager')),
              DropdownMenuItem(value: 'Team Lead', child: Text('Team Lead')),
              DropdownMenuItem(value: 'Senior Member', child: Text('Senior Member')),
              DropdownMenuItem(value: 'Member', child: Text('Member')),
              DropdownMenuItem(value: 'Trainee', child: Text('Trainee')),
            ],
            onChanged: (value) => setState(() => _selectedRole = value!),
            decoration: const InputDecoration(
              labelText: 'Default Role for New Members',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Employees List
          Expanded(
            child: _availableEmployees.isEmpty
                ? _buildEmptyEmployeesState()
                : ListView.builder(
                    itemCount: _availableEmployees.length,
                    itemBuilder: (context, index) => _buildEmployeeCard(_availableEmployees[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Employee employee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Text(
            employee.empName[0],
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
        title: Text(
          employee.empName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${employee.empCode}'),
            Text('${employee.department} • ${employee.designation}'),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            widget.onMemberAdded(employee, _selectedRole);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ),
    );
  }

  Widget _buildEmptyEmployeesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No Employees Found',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search criteria',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}