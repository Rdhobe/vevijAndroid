import 'package:vevij/components/imports.dart';
class ProjectAssignmentStatus {
  final QueryDocumentSnapshot project;
  final bool isAssigned;
  final int assignedMemberCount;
  final List<String> assignedMembers;

  ProjectAssignmentStatus({
    required this.project,
    required this.isAssigned,
    required this.assignedMemberCount,
    required this.assignedMembers,
  });
}

class ProjectManagementPage extends StatefulWidget {
  const ProjectManagementPage({super.key});

  @override
  State<ProjectManagementPage> createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Project Management',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.people, size: 20),
              text: 'Assign Members',
            ),
            Tab(
              icon: Icon(Icons.delete, size: 20),
              text: 'Delete Projects',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AssignMembersFlow(),
          DeleteProjectsFlow(),
        ],
      ),
    );
  }
}

class AssignMembersFlow extends StatefulWidget {
  const AssignMembersFlow({super.key});

  @override
  State<AssignMembersFlow> createState() => _AssignMembersFlowState();
}

class _AssignMembersFlowState extends State<AssignMembersFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  
  String? _selectedRole;
  final Set<String> _selectedMemberIds = {};
  final Set<String> _selectedProjectIds = {};
  
  final List<String> _flowSteps = [
    'Choose Role',
    'Choose Members',
    'Choose Projects',
    'Confirm'
  ];

  void _nextPage() {
    if (_currentPage < _flowSteps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveAssignments();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveAssignments() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      for (final projectId in _selectedProjectIds) {
        for (final memberId in _selectedMemberIds) {
          // Add member to project's memberHistory
          final memberHistoryRef = FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('memberHistory')
              .doc();
          
          batch.set(memberHistoryRef, {
            'memberId': memberId,
            'role': _selectedRole,
            'assignedAt': Timestamp.now(),
            'assignedBy': currentUser?.email ?? 'System',
            'isViewOnly': false,
            'canEdit': false,
          });

          // Add to project feed
          final feedRef = FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('feed')
              .doc();
          
          batch.set(feedRef, {
            'title': 'Member Assigned',
            'description': 'New $_selectedRole assigned to project',
            'timestamp': Timestamp.now(),
            'type': 'assignment',
          });
        }

        // Update project lastUpdated
        final projectRef = FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId);
        
        batch.update(projectRef, {
          'lastUpdated': Timestamp.now(),
        });
      }

      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully assigned $_selectedRole to ${_selectedProjectIds.length} project(s)',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Reset form
        setState(() {
          _selectedRole = null;
          _selectedMemberIds.clear();
          _selectedProjectIds.clear();
          _currentPage = 0;
        });
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving assignments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return _selectedRole != null;
      case 1:
        return _selectedMemberIds.isNotEmpty;
      case 2:
        return _selectedProjectIds.isNotEmpty;
      case 3:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress Indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: const Border(bottom: BorderSide(color: Colors.grey)),
          ),
          child: Column(
            children: [
              // Step Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _flowSteps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;
                  final isActive = index == _currentPage;
                  final isCompleted = index < _currentPage;
                  
                  return Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isActive 
                                  ? const Color(0xFF6D28D9)
                                  : isCompleted
                                    ? Colors.green
                                    : Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: isActive ? Colors.white : Colors.grey[600],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 2,
                                color: isCompleted ? Colors.green : Colors.grey[300],
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? const Color(0xFF6D28D9) : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Progress Text
              Text(
                'Step ${_currentPage + 1} of ${_flowSteps.length}: ${_flowSteps[_currentPage]}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6D28D9),
                ),
              ),
            ],
          ),
        ),
        
        // Content Area
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [
              _buildRoleSelectionPage(),
              _buildMemberSelectionPage(),
              _buildProjectSelectionPage(),
              _buildConfirmationPage(),
            ],
          ),
        ),
        
        // Navigation Buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Colors.grey)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_currentPage > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousPage,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF6D28D9)),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        color: Color(0xFF6D28D9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (_currentPage > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _canProceed ? _nextPage : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _currentPage == _flowSteps.length - 1 ? 'Save Assignments' : 'Continue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelectionPage() {
    final roles = ['Supervisor', 'Contractor', 'BDM', 'HOD', 'Designer', 'Viewer'];
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Role',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the role you want to assign to members',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: roles.length,
              itemBuilder: (context, index) {
                final role = roles[index];
                final isSelected = _selectedRole == role;
                
                return Card(
                  elevation: isSelected ? 4 : 1,
                  color: isSelected ? const Color(0xFF6D28D9).withOpacity(0.1) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF6D28D9) : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedRole = role),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getRoleIcon(role),
                          size: 32,
                          color: isSelected ? const Color(0xFF6D28D9) : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          role,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? const Color(0xFF6D28D9) : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Supervisor':
        return Icons.supervisor_account;
      case 'Contractor':
        return Icons.engineering;
      case 'BDM':
        return Icons.business_center;
      case 'HOD':
        return Icons.leaderboard;
      case 'Designer':
        return Icons.design_services;
      case 'Viewer':
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }

  Widget _buildMemberSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Members',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose members to assign as $_selectedRole (Multiple selection allowed)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('designation', isEqualTo: _getRoleDesignation(_selectedRole))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No members found for $_selectedRole role',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
                
                final members = snapshot.data!.docs;
                
                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final data = member.data() as Map<String, dynamic>;
                    final memberId = member.id;
                    final isSelected = _selectedMemberIds.contains(memberId);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected ? const Color(0xFF6D28D9).withOpacity(0.05) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF6D28D9) : Colors.grey[200]!,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedMemberIds.add(memberId);
                            } else {
                              _selectedMemberIds.remove(memberId);
                            }
                          });
                        },
                        title: Text(
                          data['empName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(data['email'] ?? 'No email'),
                        secondary: CircleAvatar(
                          backgroundColor: const Color(0xFF6D28D9).withOpacity(0.1),
                          backgroundImage: data['profileImage'] != null && data['profileImage'].isNotEmpty
                              ? NetworkImage(data['profileImage'])
                              : null,
                          child: data['profileImage'] == null || data['profileImage'].isEmpty
                              ? Text(
                                  (data['empName'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: Color(0xFF6D28D9)),
                                )
                              : null,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_selectedMemberIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6D28D9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedMemberIds.length} member(s) selected',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getRoleDesignation(String? role) {
    switch (role) {
      case 'Supervisor':
        return 'Supervisor';
      case 'Contractor':
        return 'Contractor';
      case 'BDM':
        return 'Business Development Manager';
      case 'HOD':
        return 'Hod';
      case 'Designer':
        return 'Designer';
      case 'Viewer':
        return 'Viewer';
      default:
        return role ?? '';
    }
  }

  Widget _buildProjectSelectionPage() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Projects',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose projects to assign the selected members to (Multiple selection allowed)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .orderBy('lastUpdated', descending: true)
                .snapshots(),
            builder: (context, projectSnapshot) {
              if (projectSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!projectSnapshot.hasData || projectSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('No projects found'),
                    ],
                  ),
                );
              }
              
              final projects = projectSnapshot.data!.docs;
              
              return FutureBuilder<List<ProjectAssignmentStatus>>(
                future: _getProjectAssignmentStatus(projects),
                builder: (context, assignmentSnapshot) {
                  if (assignmentSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final assignmentStatus = assignmentSnapshot.data ?? [];
                  
                  // Separate projects into assigned and unassigned
                  final assignedProjects = assignmentStatus.where((p) => p.isAssigned).toList();
                  final unassignedProjects = assignmentStatus.where((p) => !p.isAssigned).toList();
                  
                  return ListView(
                    children: [
                      // Assigned Projects Section
                      if (assignedProjects.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Already Assigned',
                          'Members are already assigned to these projects',
                          Icons.check_circle,
                          Colors.green,
                        ),
                        ...assignedProjects.map((projectStatus) => 
                          _buildProjectCard(projectStatus, true)
                        ).toList(),
                        const SizedBox(height: 16),
                      ],
                      
                      // Unassigned Projects Section
                      if (unassignedProjects.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Available Projects',
                          'Members are not assigned to these projects',
                          Icons.folder_open,
                          Colors.blue,
                        ),
                        ...unassignedProjects.map((projectStatus) => 
                          _buildProjectCard(projectStatus, false)
                        ).toList(),
                      ],
                      
                      if (assignedProjects.isEmpty && unassignedProjects.isEmpty)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text('No projects available'),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        if (_selectedProjectIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6D28D9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedProjectIds.length} project(s) selected',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
  Widget _buildSectionHeader(String title, String subtitle, IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
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
}

Widget _buildProjectCard(ProjectAssignmentStatus projectStatus, bool isAlreadyAssigned) {
  final project = projectStatus.project;
  final data = project.data() as Map<String, dynamic>;
  final projectId = project.id;
  final isSelected = _selectedProjectIds.contains(projectId);
  
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: isSelected 
        ? const Color(0xFF6D28D9).withOpacity(0.05)
        : (isAlreadyAssigned ? Colors.green.withOpacity(0.02) : Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: isSelected 
            ? const Color(0xFF6D28D9)
            : (isAlreadyAssigned ? Colors.green : Colors.grey[200]!),
        width: isSelected ? 2 : 1,
      ),
    ),
    child: Stack(
      children: [
        CheckboxListTile(
          value: isSelected,
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                _selectedProjectIds.add(projectId);
              } else {
                _selectedProjectIds.remove(projectId);
              }
            });
          },
          title: Row(
            children: [
              Expanded(
                child: Text(
                  data['name'] ?? 'Unnamed Project',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isAlreadyAssigned ? Colors.green[700] : Colors.black87,
                  ),
                ),
              ),
              if (isAlreadyAssigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Assigned',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['description'] ?? 'No description'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.category, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Type: ${data['type'] ?? 'Not specified'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (projectStatus.assignedMemberCount > 0) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.people, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${projectStatus.assignedMemberCount} member(s)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ],
          ),
          secondary: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isAlreadyAssigned 
                  ? Colors.green.withOpacity(0.2)
                  : _getProjectColor(data['type']),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAlreadyAssigned ? Icons.check_circle : Icons.folder,
              color: isAlreadyAssigned ? Colors.green : Colors.white,
              size: 24,
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        
        // Hover info for assigned projects
        if (isAlreadyAssigned && projectStatus.assignedMembers.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Tooltip(
              message: 'Already assigned members:\n${projectStatus.assignedMembers.join('\n')}',
              triggerMode: TooltipTriggerMode.tap,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
Future<List<ProjectAssignmentStatus>> _getProjectAssignmentStatus(List<QueryDocumentSnapshot> projects) async {
  final List<ProjectAssignmentStatus> statusList = [];
  
  for (final project in projects) {
    final projectId = project.id;
    
    // Check if any of the selected members are already assigned to this project
    bool isAssigned = false;
    int assignedMemberCount = 0;
    final List<String> assignedMembers = [];
    
    for (final memberId in _selectedMemberIds) {
      final assignmentQuery = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('memberHistory')
          .where('memberId', isEqualTo: memberId)
          .where('role', isEqualTo: _selectedRole)
          .limit(1)
          .get();
      
      if (assignmentQuery.docs.isNotEmpty) {
        isAssigned = true;
        assignedMemberCount++;
        
        // Get member name for tooltip
        final memberDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        
        final memberData = memberDoc.data();
        final memberName = memberData?['empName'] ?? 'Unknown';
        assignedMembers.add('• $memberName');
      }
    }
    
    statusList.add(ProjectAssignmentStatus(
      project: project,
      isAssigned: isAssigned,
      assignedMemberCount: assignedMemberCount,
      assignedMembers: assignedMembers,
    ));
  }
  
  // Sort: assigned projects first, then by project name
  statusList.sort((a, b) {
    if (a.isAssigned && !b.isAssigned) return -1;
    if (!a.isAssigned && b.isAssigned) return 1;
    
    final aName = (a.project.data() as Map<String, dynamic>)['name'] ?? '';
    final bName = (b.project.data() as Map<String, dynamic>)['name'] ?? '';
    return aName.compareTo(bName);
  });
  
  return statusList;
}
  Color _getProjectColor(String? type) {
    switch (type) {
      case 'Residential':
        return Colors.blue;
      case 'Commercial':
        return Colors.green;
      case 'Industrial':
        return Colors.orange;
      case 'Institutional':
        return Colors.purple;
      default:
        return const Color(0xFF6D28D9);
    }
  }

  Widget _buildConfirmationPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm Assignment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review the assignment details before saving',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Summary Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSummaryItem('Role', _selectedRole ?? 'Not selected'),
                  const Divider(),
                  _buildSummaryItem('Members', '${_selectedMemberIds.length} selected'),
                  const Divider(),
                  _buildSummaryItem('Projects', '${_selectedProjectIds.length} selected'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ready to assign ${_selectedMemberIds.length} member(s) as $_selectedRole to ${_selectedProjectIds.length} project(s)',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Details Section
          Expanded(
            child: ListView(
              children: [
                _buildDetailSection(
                  'Selected Members',
                  _selectedMemberIds,
                  (id) => StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(id).snapshots(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF6D28D9).withOpacity(0.1),
                          child: Text((data?['empName'] ?? 'U')[0].toUpperCase()),
                        ),
                        title: Text(data?['empName'] ?? 'Loading...'),
                        subtitle: Text(data?['email'] ?? ''),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildDetailSection(
                  'Selected Projects',
                  _selectedProjectIds,
                  (id) => StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('projects').doc(id).snapshots(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getProjectColor(data?['type']),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.folder, color: Colors.white, size: 20),
                        ),
                        title: Text(data?['name'] ?? 'Loading...'),
                        subtitle: Text(data?['type'] ?? 'No type'),
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

  Widget _buildSummaryItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, Set<String> ids, Widget Function(String) builder) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...ids.map((id) => builder(id)).toList(),
          ],
        ),
      ),
    );
  }
}

class DeleteProjectsFlow extends StatefulWidget {
  const DeleteProjectsFlow({super.key});

  @override
  State<DeleteProjectsFlow> createState() => _DeleteProjectsFlowState();
}

class _DeleteProjectsFlowState extends State<DeleteProjectsFlow> {
  final Set<String> _selectedProjectIds = {};
  bool _isDeleting = false;

  Future<void> _confirmAndDelete() async {
    if (_selectedProjectIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete ${_selectedProjectIds.length} project(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjects)) 
        {
          await _deleteProjects();
        }
    }
  }

  Future<void> _deleteProjects() async {
    setState(() => _isDeleting = true);
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final projectId in _selectedProjectIds) {
        final projectRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
        batch.delete(projectRef);
        
        // Also delete subcollections if needed
        // Note: This requires Cloud Functions for deep deletion
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully deleted ${_selectedProjectIds.length} project(s)',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _selectedProjectIds.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting projects: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            border: const Border(bottom: BorderSide(color: Colors.grey)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Projects',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                    Text(
                      'Select projects to delete. This action is permanent and cannot be undone.',
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
        ),
        
        // Project List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .orderBy('lastUpdated', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('No projects found'),
                    ],
                  ),
                );
              }
              
              final projects = snapshot.data!.docs;
              
              return ListView.builder(
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  final data = project.data() as Map<String, dynamic>;
                  final projectId = project.id;
                  final isSelected = _selectedProjectIds.contains(projectId);
                  
                  return Card(
                    margin: const EdgeInsets.all(8),
                    color: isSelected ? Colors.red.withOpacity(0.05) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.red : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedProjectIds.add(projectId);
                          } else {
                            _selectedProjectIds.remove(projectId);
                          }
                        });
                      },
                      title: Text(
                        data['name'] ?? 'Unnamed Project',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['description'] ?? 'No description'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Updated: ${_formatDate(data['lastUpdated'])}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      secondary: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  );
                },
              );
            },
          ),
        ),
        
        // Delete Button
        if (_selectedProjectIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Colors.grey)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedProjectIds.length} project(s) selected for deletion',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isDeleting ? null : _confirmAndDelete,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete, size: 20),
                  label: Text(_isDeleting ? 'Deleting...' : 'Delete Projects'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      return '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}';
    }
    return 'Invalid date';
  }
}