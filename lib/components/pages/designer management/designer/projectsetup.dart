import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:firebase_auth/firebase_auth.dart';

class ProjectSetupPage extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectSetupPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectSetupPage> createState() => _ProjectSetupPageState();
}

class _ProjectSetupPageState extends State<ProjectSetupPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _teamTabController;
  final PageController _pageController = PageController();
  Map<String, dynamic> _selectedMember = {};

  // Form controllers
  final _projectNameController = TextEditingController();
  final _projectDescriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientContactController = TextEditingController();

  // Project configuration data
  DateTime? _startDate;
  DateTime? _endDate;
  String _projectType = 'Residential';
  String _priority = 'Medium';
  String _projectManager = '';
  final List<Map<String, dynamic>> _teamMembers = [];
  final List<Map<String, dynamic>> _projectPhases = [];
  Map<String, dynamic>? _projectData;
  final List<Map<String, dynamic>> _supervisorsData = [];
  final List<Map<String, dynamic>> _contractorsData = [];
  bool _isLoading = true;

  @override
  void initState() {
    print('project manageer id....$_projectManager');
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _teamTabController = TabController(length: 6, vsync: this);
    _loadProjectData();
  }

  @override
  void dispose() {
    _teamTabController.dispose();
    _tabController.dispose();
    _pageController.dispose();
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    _budgetController.dispose();
    _clientNameController.dispose();
    _clientContactController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (doc.exists) {
        _projectData = doc.data();
        
        // Load supervisors (up to 3)
        final supervisorIds = List<String>.from(_projectData!['assignedSupervisorIds'] ?? []);
        for (var id in supervisorIds) {
          final supervisorSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .get();
          if (supervisorSnap.exists) {
            _supervisorsData.add(supervisorSnap.data()!..['id'] = id);
          }
        }
        
        // Load contractors (multiple)
        final contractorIds = List<String>.from(_projectData!['assignedContractorIds'] ?? []);
        for (var id in contractorIds) {
          final contractorSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .get();
          if (contractorSnap.exists) {
            _contractorsData.add(contractorSnap.data()!..['id'] = id);
          }
        }
        
        _populateFields();
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading project data: $e');
    }
  }

  void _populateFields() {
    if (_projectData != null) {
      _projectNameController.text = _projectData!['name'] ?? widget.projectName;
      _projectDescriptionController.text = _projectData!['description'] ?? '';
      _budgetController.text = _projectData!['budget']?.toString() ?? '';
      _clientNameController.text = _projectData!['clientName'] ?? '';
      _clientContactController.text = _projectData!['clientContact'] ?? '';
      _projectType = _projectData!['type'] ?? 'Residential';
      _priority = _projectData!['priority'] ?? 'Medium';
      _projectManager = _projectData!['projectManager'] ?? '';

      if (_projectData!['startDate'] != null) {
        _startDate = (_projectData!['startDate'] as Timestamp).toDate();
      }
      if (_projectData!['endDate'] != null) {
        _endDate = (_projectData!['endDate'] as Timestamp).toDate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF6D28D9),
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
                          _buildBasicInfoTab(),
                          _buildTeamSetupTab(),
                          _buildReviewTab(),
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
                const Text(
                  'Project Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.projectName,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
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
        labelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(text: 'Basic Info'),
          Tab(text: 'Team'),
          Tab(text: 'Review'),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _projectNameController,
            label: 'Project Name',
            hint: 'Enter project name',
            icon: Icons.business,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _projectDescriptionController,
            label: 'Project Description',
            hint: 'Enter project description',
            icon: Icons.description,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Project Type',
                  value: _projectType,
                  items: ['Residential', 'Commercial', 'Industrial', 'Institutional'],
                  onChanged: (value) => setState(() => _projectType = value!),
                  icon: Icons.category,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'Priority',
                  value: _priority,
                  items: ['Low', 'Medium', 'High', 'Critical'],
                  onChanged: (value) => setState(() => _priority = value!),
                  icon: Icons.priority_high,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Start Date',
                  date: _startDate,
                  onTap: () => _selectDate(context, true),
                  icon: Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateField(
                  label: 'End Date',
                  date: _endDate,
                  onTap: () => _selectDate(context, false),
                  icon: Icons.event,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _budgetController,
            label: 'Budget',
            hint: 'Enter project budget',
            icon: Icons.currency_rupee,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          const Text(
            'Client Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _clientNameController,
            label: 'Client Name',
            hint: 'Enter client name',
            icon: Icons.person,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _clientContactController,
            label: 'Client Contact',
            hint: 'Enter contact number/email',
            icon: Icons.contact_phone,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSetupTab() {
    return Column(
      children: [
        TabBar(
          controller: _teamTabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF3B82F6),
          isScrollable: true,
          labelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Members Overview'),
            Tab(text: 'Supervisors'),
            Tab(text: 'Contractor'),
            Tab(text: 'BDM'),
            Tab(text: 'HOD'),
            Tab(text: 'Designer'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _teamTabController,
            children: [
              _buildMembersOverviewTab(),
              _buildSupervisorsTab(),
              _buildContractorsTab(),
              _buildRoleTab('BDM'),
              _buildRoleTab('HOD'),
              _buildRoleTab('Designer'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Team Members',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Supervisors Section
          Text('Supervisors (${_supervisorsData.length}/3)', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_supervisorsData.isEmpty)
            _buildRoleCard('Supervisor', 'No Supervisors Assigned')
          else
            ..._supervisorsData.map((supervisor) => Card(
              color: Colors.blue.withOpacity(0.1),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                  child: const Icon(Icons.person, color: Color(0xFF3B82F6)),
                ),
                title: Text(supervisor['empName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(supervisor['designation'] ?? 'Supervisor',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
              ),
            )),
          
          const SizedBox(height: 16),
          
          // Contractors Section
          Text('Contractors (${_contractorsData.length})', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_contractorsData.isEmpty)
            _buildRoleCard('Contractor', 'No Contractors Assigned')
          else
            ..._contractorsData.map((contractor) => Card(
              color: Colors.orange.withOpacity(0.1),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: const Icon(Icons.engineering, color: Colors.orange),
                ),
                title: Text(contractor['empName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(contractor['designation'] ?? 'Contractor',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ),
            )),
          
          const SizedBox(height: 16),
          
          // Other Roles
          _buildRoleCard('BDM', _projectData?['assignedBDMName']),
          _buildRoleCard('HOD', _projectData?['assignedHODName']),
          _buildRoleCard('Designer', _projectData?['assignedDesignerName']),
          
          Divider(thickness: 1, color: Colors.grey[300]),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('View Only Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _addTeamMember,
                icon: const Icon(Icons.person_add, color: Colors.white, size: 16),
                label: const Text('Add Member',
                  style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .collection('memberHistory')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error fetching team members'));
              }
              final List<Map<String, dynamic>> teamMembers =
                  snapshot.data?.docs.map((doc) => doc.data()).toList() ?? [];
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: teamMembers.length,
                itemBuilder: (context, index) {
                  final member = teamMembers[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                        child: const Icon(Icons.person, color: Color(0xFF3B82F6)),
                      ),
                      title: Text(member['memberName'] ?? 'Unnamed',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(member['role'] ?? 'No Role Assigned'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _selectedMember = member);
                          _showdeletecomfirm();
                        },
                      ),
                      onTap: () => _showmemberspermissions(context, member),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String role, String? assignedName) {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
          child: const Icon(Icons.person, color: Color(0xFF3B82F6)),
        ),
        title: Text(assignedName ?? 'No $role Assigned',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
      ),
    );
  }

  Widget _buildSupervisorsTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, projectSnapshot) {
        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final projectData = projectSnapshot.data?.data() as Map<String, dynamic>?;
        final supervisorIds = List<String>.from(projectData?['assignedSupervisorIds'] ?? []);
        
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Project Supervisors (${supervisorIds.length}/3)',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (supervisorIds.length < 3)
                    ElevatedButton.icon(
                      onPressed: () => _showRoleSelectionDialog('Supervisor', supervisorIds),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Supervisor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (supervisorIds.isEmpty)
                _buildEmptyRoleCard('Supervisor')
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: supervisorIds.length,
                    itemBuilder: (context, index) {
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(supervisorIds[index])
                            .snapshots(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const Card(child: ListTile(title: Text('Loading...')));
                          }
                          
                          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                          if (userData == null) return const SizedBox.shrink();
                          
                          return _buildAssignedPersonCard(
                            supervisorIds[index],
                            userData,
                            'Supervisor',
                            onRemove: () => _removeRole('Supervisor', supervisorIds[index]),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleTab(String roleName) {
    final roleFieldMap = {
      'BDM': {'id': 'assignedBDMId', 'name': 'assignedBDMName'},
      'HOD': {'id': 'assignedHODId', 'name': 'assignedHODName'},
      'Designer': {'id': 'assignedDesignerId', 'name': 'assignedDesignerName'},
      'Contractor': {'id': 'assignedContractorId', 'name': 'assignedContractorName'},
    };
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, projectSnapshot) {
        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final projectData = projectSnapshot.data?.data() as Map<String, dynamic>?;
        final assignedId = projectData?[roleFieldMap[roleName]!['id']] as String?;
        
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Project $roleName',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => _showRoleSelectionDialog(roleName, []),
                    icon: Icon(assignedId == null ? Icons.person_add : Icons.swap_horiz),
                    label: Text(assignedId == null ? 'Assign $roleName' : 'Reassign $roleName'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (assignedId == null)
                _buildEmptyRoleCard(roleName)
              else
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(assignedId)
                      .snapshots(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                    if (userData == null) return _buildEmptyRoleCard(roleName);
                    
                    return _buildAssignedPersonCard(
                      assignedId,
                      userData,
                      roleName,
                      onRemove: () => _removeRole(roleName, assignedId),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyRoleCard(String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: flutter.Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No $role Assigned',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Assign a $role to this project',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAssignedPersonCard(
    String userId,
    Map<String, dynamic> userData,
    String role,
    {VoidCallback? onRemove}
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: flutter.Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
            backgroundImage: userData['profileImage'] != null && userData['profileImage'].isNotEmpty
                ? NetworkImage(userData['profileImage'])
                : null,
            child: userData['profileImage'] == null || userData['profileImage'].isEmpty
                ? Text((userData['empName'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 24))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userData['empName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(userData['designation'] ?? role,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                if (userData['email'] != null)
                  Text(userData['email'],
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }

  Future<void> _showRoleSelectionDialog(String role, List<String> currentIds) async {
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';
    String getRole(String role) {
      if (role == 'Supervisor') {
       return 'Supervisor';
      }else if (role == 'Contractor') {
        return 'Contractor';
      }else if (role == 'BDM') {
        return 'Business Development Manager';
      }else if (role == 'HOD') {
        return 'Hod';
      }else if (role == 'Designer') {
        return 'Designer';
      }
      return role;
    }
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Select $role'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('designation', isEqualTo: getRole(role))
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text('No ${role}s found'));
                      }
                      
                      final filteredDocs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['empName'] ?? '').toString().toLowerCase();
                        final email = (data['email'] ?? '').toString().toLowerCase();
                        return (searchQuery.isEmpty || name.contains(searchQuery) || email.contains(searchQuery))
                            && !currentIds.contains(doc.id);
                      }).toList();
                      
                      if (filteredDocs.isEmpty) {
                        return const Center(child: Text('No matches found'));
                      }
                      
                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final person = filteredDocs[index];
                          final data = person.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                              backgroundImage: data['profileImage'] != null && data['profileImage'].isNotEmpty
                                  ? NetworkImage(data['profileImage'])
                                  : null,
                              child: data['profileImage'] == null || data['profileImage'].isEmpty
                                  ? Text((data['empName'] ?? 'U')[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(data['empName'] ?? 'Unknown'),
                            subtitle: Text(data['email'] ?? ''),
                            onTap: () {
                              Navigator.of(context).pop();
                              _showRoleConfirmationDialog(person.id, data, role);
                            },
                          );
                        },
                      );
                    },
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
          ],
        ),
      ),
    );
  }

  Future<void> _showRoleConfirmationDialog(
    String userId,
    Map<String, dynamic> userData,
    String role,
  ) async {
    final TextEditingController reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Assign ${userData['empName']} as $role?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _assignRole(userId, userData, role, reasonController.text);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignRole(
    String userId,
    Map<String, dynamic> userData,
    String role,
    String reason,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
      
      if (role == 'Supervisor') {
        // Add to supervisors array (max 3)
        batch.update(projectRef, {
          'assignedSupervisorIds': FieldValue.arrayUnion([userId]),
          'lastUpdated': Timestamp.now(),
        });
      } else if (role == 'Contractor') {
        // Add to contractors array (multiple)
        batch.update(projectRef, {
          'assignedContractorIds': FieldValue.arrayUnion([userId]),
          'lastUpdated': Timestamp.now(),
        });
      } else {
        // Single role assignment
        final roleFieldMap = {
          'BDM': {'id': 'assignedBDMId', 'name': 'assignedBDMName'},
          'HOD': {'id': 'assignedHODId', 'name': 'assignedHODName'},
          'Designer': {'id': 'assignedDesignerId', 'name': 'assignedDesignerName'},
        };
        
        batch.update(projectRef, {
          roleFieldMap[role]!['id']!: userId,
          roleFieldMap[role]!['name']!: userData['empName'] ?? 'Unknown',
          'lastUpdated': Timestamp.now(),
        });
      }
      
      // Add to history
      final historyCollection = (role == 'Supervisor' || role == 'Contractor') 
          ? '${role.toLowerCase()}History' 
          : '${role.toLowerCase()}History';
      batch.set(
        projectRef.collection(historyCollection).doc(),
        {
          '${role.toLowerCase()}Id': userId,
          '${role.toLowerCase()}Name': userData['empName'] ?? 'Unknown',
          '${role.toLowerCase()}Email': userData['email'] ?? '',
          'assignedAt': Timestamp.now(),
          'reason': reason,
          'assignedBy': FirebaseAuth.instance.currentUser?.email ?? 'System',
        },
      );
      
      // Add to feed
      batch.set(
        projectRef.collection('feed').doc(),
        {
          'title': '$role Assigned',
          'description': '${userData['empName']} has been assigned as project $role',
          'timestamp': Timestamp.now(),
          'type': 'assignment',
        },
      );
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$role assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning $role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeRole(String role, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Are you sure you want to remove this $role?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      final projectRef = FirebaseFirestore.instance.collection('projects').doc(widget.projectId);
      
      if (role == 'Supervisor') {
        batch.update(projectRef, {
          'assignedSupervisorIds': FieldValue.arrayRemove([userId]),
          'lastUpdated': Timestamp.now(),
        });
      } else if (role == 'Contractor') {
        batch.update(projectRef, {
          'assignedContractorIds': FieldValue.arrayRemove([userId]),
          'lastUpdated': Timestamp.now(),
        });
      } else {
        final roleFieldMap = {
          'BDM': {'id': 'assignedBDMId', 'name': 'assignedBDMName'},
          'HOD': {'id': 'assignedHODId', 'name': 'assignedHODName'},
          'Designer': {'id': 'assignedDesignerId', 'name': 'assignedDesignerName'},
        };
        
        batch.update(projectRef, {
          roleFieldMap[role]!['id']!: FieldValue.delete(),
          roleFieldMap[role]!['name']!: FieldValue.delete(),
          'lastUpdated': Timestamp.now(),
        });
      }
      
      // Update history
      final historyCollection = (role == 'Supervisor' || role == 'Contractor')
          ? '${role.toLowerCase()}History'
          : '${role.toLowerCase()}History';
      final historyQuery = await projectRef
          .collection(historyCollection)
          .where('${role.toLowerCase()}Id', isEqualTo: userId)
          .where('unassignedAt', isNull: true)
          .get();
          
      for (var doc in historyQuery.docs) {
        batch.update(doc.reference, {
          'unassignedAt': Timestamp.now(),
          'reason': '$role removed',
        });
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$role removed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing $role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showmemberspermissions(
    BuildContext context,
    Map<String, dynamic> member,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => _buildMemberPermissionsDialog(context, member),
    );
  }

  AlertDialog _buildMemberPermissionsDialog(
    BuildContext context,
    Map<String, dynamic> member,
  ) {
    bool isViewOnly = member['isViewOnly'] ?? false;
    bool canEdit = member['canEdit'] ?? false;
    return AlertDialog(
      title: const Text('Permissions'),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('View Only',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Switch(
                    value: isViewOnly,
                    onChanged: (value) {
                      setState(() {
                        isViewOnly = value;
                      });
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Can Edit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Switch(
                    value: canEdit,
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.grey,
                    onChanged: (value) {
                      setState(() {
                        canEdit = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .collection('memberHistory')
                  .where('memberId', isEqualTo: member['memberId'])
                  .get()
                  .then((snapshot) {
                for (var doc in snapshot.docs) {
                  doc.reference.update({
                    'isViewOnly': isViewOnly,
                    'canEdit': canEdit,
                  });
                }
              });
              Navigator.of(context).pop();
              _showSnackBar('Permissions updated');
            } catch (e) {
              _showSnackBar('Error updating permissions: $e');
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _showdeletecomfirm() async {
    await showDialog(
      context: context,
      builder: (context) => _buildDeleteConfirmationDialog(context),
    );
  }

  AlertDialog _buildDeleteConfirmationDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Member'),
      content: Text(
        'Are you sure you want to delete this member? This action cannot be undone.\nmember: ${_selectedMember['memberName']}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            _removeTeamMember(_selectedMember['memberId']);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _removeTeamMember(String memberId) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('memberHistory')
          .where('memberId', isEqualTo: memberId)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
      _showSnackBar('Member removed successfully');
    } catch (e) {
      _showSnackBar('Error removing member: $e');
    }
  }

  Widget _buildReviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Setup Review',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildReviewSection('Basic Information', [
            'Project Name: ${_projectNameController.text}',
            'Type: $_projectType',
            'Priority: $_priority',
            'Budget: ₹${_budgetController.text}',
            'Duration: ${_startDate != null && _endDate != null ? '${_endDate!.difference(_startDate!).inDays} days' : 'Not specified'}',
            'Client: ${_clientNameController.text}',
          ]),
          const SizedBox(height: 20),
          _buildReviewSection(
            'Team Members',
            _teamMembers.isEmpty
                ? ['No team members added']
                : _teamMembers
                    .map((member) => '${member['name']} - ${member['role']}')
                    .toList(),
          ),
          const SizedBox(height: 20),
          _buildReviewSection(
            'Project Phases',
            _projectPhases.isEmpty
                ? ['No phases added']
                : _projectPhases
                    .map((phase) => '${phase['name']} (${phase['duration']} days)')
                    .toList(),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                const SizedBox(height: 8),
                const Text(
                  'Ready to Setup?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review all information above and click "Complete Setup" to finalize your project configuration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
        fillColor: Colors.grey[50],
        filled: true,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
        fillColor: Colors.grey[50],
        filled: true,
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Select Date',
                    style: TextStyle(
                      fontSize: 16,
                      color: date != null ? Colors.black87 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $item',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _addTeamMember() async {
    String searchQuery = '';
    final TextEditingController searchController = TextEditingController();
    final Set<String> selectedMemberIds = {};
    final Map<String, Map<String, dynamic>> selectedMemberData = {};
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select members to add'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search members...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No members found'));
                      }
                      final filteredDocs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['empName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final email = (data['email'] ?? '')
                            .toString()
                            .toLowerCase();
                        return searchQuery.isEmpty ||
                            name.contains(searchQuery) ||
                            email.contains(searchQuery);
                      }).toList();
                      if (filteredDocs.isEmpty) {
                        return const Center(
                          child: Text('No members match your search'),
                        );
                      }
                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final member = filteredDocs[index];
                          final data = member.data() as Map<String, dynamic>;
                          final memberId = member.id;
                          final isSelected = selectedMemberIds.contains(
                            memberId,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  selectedMemberIds.add(memberId);
                                  selectedMemberData[memberId] = data;
                                } else {
                                  selectedMemberIds.remove(memberId);
                                  selectedMemberData.remove(memberId);
                                }
                              });
                            },
                            title: Text(data['empName'] ?? 'Unknown'),
                            subtitle: Text(data['email'] ?? ''),
                            secondary: CircleAvatar(
                              backgroundImage:
                                  data['profileImage'] != null &&
                                      data['profileImage'].isNotEmpty
                                  ? NetworkImage(data['profileImage'])
                                  : null,
                              child:
                                  (data['profileImage'] == null ||
                                      data['profileImage'].isEmpty)
                                  ? Text(
                                      (data['empName'] ?? 'S')[0].toUpperCase(),
                                    )
                                  : null,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedMemberIds.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _showMultiMemberConfirmationDialog(selectedMemberData);
                    },
              child: const Text('Assign Selected'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMultiMemberConfirmationDialog(
    Map<String, Map<String, dynamic>> members,
  ) async {
    final TextEditingController reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign the following members to this project:'),
            const SizedBox(height: 8),
            ...members.values.map(
              (data) => Text("- ${data['empName']} (${data['email']})"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Optional)',
                hintText: 'Enter reason for assignment',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _assignMembers(members, reasonController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Assign All'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignMembers(
    Map<String, Map<String, dynamic>> members,
    String reason,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final entry in members.entries) {
        final memberId = entry.key;
        final memberData = entry.value;
        batch.update(
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId),
          {'lastUpdated': Timestamp.now()},
        );
        batch.set(
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('memberHistory')
              .doc(),
          {
            'memberId': memberId,
            'memberName': memberData['empName'] ?? 'Unknown',
            'memberEmail': memberData['email'] ?? '',
            'assignedAt': Timestamp.now(),
            'role': memberData['designation'] ?? 'Member',
            'reason': reason,
            'assignedBy': FirebaseAuth.instance.currentUser?.email ?? 'System',
            'isViewOnly': false,
            'canEdit': false,
          },
        );
        batch.set(
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('feed')
              .doc(),
          {
            'title': 'Member Assigned',
            'description':
                '${memberData['empName']} has been assigned as project member',
            'timestamp': Timestamp.now(),
            'type': 'assignment',
          },
        );
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Members assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning members: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

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

  Widget _buildContractorsTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, projectSnapshot) {
        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final projectData = projectSnapshot.data?.data() as Map<String, dynamic>?;
        final contractorIds = List<String>.from(projectData?['assignedContractorIds'] ?? []);
        
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Project Contractors (${contractorIds.length})',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () => _showRoleSelectionDialog('Contractor', contractorIds),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Contractor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (contractorIds.isEmpty)
                _buildEmptyRoleCard('Contractor')
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: contractorIds.length,
                    itemBuilder: (context, index) {
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(contractorIds[index])
                            .snapshots(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const Card(child: ListTile(title: Text('Loading...')));
                          }
                          
                          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                          if (userData == null) return const SizedBox.shrink();
                          
                          return _buildAssignedPersonCard(
                            contractorIds[index],
                            userData,
                            'Contractor',
                            onRemove: () => _removeRole('Contractor', contractorIds[index]),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}