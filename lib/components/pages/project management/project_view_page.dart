import 'package:vevij/components/imports.dart';
import 'package:vevij/components/pages/project management/project_report.dart';
class ProjectViewPage extends StatefulWidget {
  const ProjectViewPage({super.key});

  @override
  State<ProjectViewPage> createState() => _ProjectViewPageState();
}

class _ProjectViewPageState extends State<ProjectViewPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _branch = '';
  String _designation = '';
  bool _showGrouped = true;
  String uid = '';
  @override
  void initState() {
    super.initState();
    _updateBranch(_branch);
    _updateDesignation(_designation);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateBranch(String branch) async {
    branch = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get()
        .then((doc) => doc['branch'] ?? '');
    setState(() {
      _branch = branch;
    });
  }
  void _updateDesignation(String designation) async {
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .get();

  if (userDoc.exists) {
    setState(() {
      _designation = userDoc['designation'] ?? '';
      uid = userDoc['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    });
  }

  print('✅ Designation loaded: $_designation');
  print('✅ UID loaded: $uid');
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child:_buildMobileLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildHeader(_branch),
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
                _buildProjectsHeader(),
                _buildSearchAndViewToggle(),
                Expanded(
                  child: _showGrouped 
                      ? _buildGroupedProjectsGrid() 
                      : _buildProjectsList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String branch) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            hoverColor: Colors.blue,
            splashColor: Colors.brown,
            highlightColor: Colors.blueAccent,
            color: Colors.deepPurple,
            icon: const Icon(Icons.arrow_back  ),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                branch.isNotEmpty ? branch[0] : 'G',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch,
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProjectsHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Projects',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showCreateGroupDialog(),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Group'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(width: 5),
                ElevatedButton.icon(
                  onPressed: () => _navigateToCreateProject(),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Project'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(width: 5),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DocumentVaultPage()),
                    );
                  },
                  icon: const Icon(Icons.folder_shared, size: 15),
                  label: const Text('Documents'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                const SizedBox(width: 5),
                ElevatedButton.icon(
                  onPressed: ()async {
                    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjectgroup)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HardwaresetupPage()),
                    );
                    }else{
                     await  ErrorDialog.show(
                        context,
                        title: 'Permission Denied',
                        message: 'You do not have permission to access Hardware Setup.',
                      );
                    }
                  },
                  icon: const Icon(Icons.hardware, size: 15),
                  label: const Text('Hardware'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
                
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search projects...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showGrouped = true;
                    });
                  },
                  icon: Icon(
                    Icons.folder,
                    color: _showGrouped ? Colors.deepPurple : Colors.grey,
                  ),
                  tooltip: 'Grouped View',
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showGrouped = false;
                    });
                  },
                  icon: Icon(
                    Icons.view_list,
                    color: !_showGrouped ? Colors.deepPurple : Colors.grey,
                  ),
                  tooltip: 'List View',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedProjectsGrid() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('projectGroups')
        .orderBy('name', descending: false)
        .snapshots(),
    builder: (context, groupSnapshot) {
      return StreamBuilder<QuerySnapshot>(
        stream: _getProjectsStream(),
        builder: (context, projectSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting ||
              projectSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (groupSnapshot.hasError || projectSnapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }

          final groups = groupSnapshot.data?.docs ?? [];
          final projects = projectSnapshot.data?.docs ?? [];

          // Apply search filtering to projects
          final filteredProjects = projects.where((doc) {
            final projectName = (doc['name'] as String).toLowerCase();
            return projectName.contains(_searchQuery);
          }).toList();

          // ✅ Get only those groups that have projects assigned
          final groupsWithProjects = groups.where((group) {
            final groupId = group.id;
            final hasProjects = filteredProjects.any((project) {
              final data = project.data() as Map<String, dynamic>;
              return data['groupId'] == groupId;
            });
            return hasProjects;
          }).toList();

          // ✅ Ungrouped projects (no groupId)
          final ungroupedProjects = filteredProjects.where((project) {
            final data = project.data() as Map<String, dynamic>;
            return data['groupId'] == null || data['groupId'] == '';
          }).toList();

          // ✅ If there are no projects at all
          if (groupsWithProjects.isEmpty && ungroupedProjects.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No projects found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (groupsWithProjects.isNotEmpty) ...[
                  const Text(
                    'Project Groups',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount;
                      if (constraints.maxWidth > 1200) {
                        crossAxisCount = 4;
                      } else if (constraints.maxWidth > 800) {
                        crossAxisCount = 3;
                      } else if (constraints.maxWidth > 600) {
                        crossAxisCount = 2;
                      } else {
                        crossAxisCount = 1;
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: groupsWithProjects.length,
                        itemBuilder: (context, index) {
                          return _buildProjectGroupCard(
                            groupsWithProjects[index],
                            filteredProjects,
                          );
                        },
                      );
                    },
                  ),
                ],
                if (ungroupedProjects.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  const Text(
                    'Individual Projects',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...ungroupedProjects.map((project) {
                    final data = project.data() as Map<String, dynamic>;
                    return _buildProjectCard(
                      project.id,
                      data['name'] ?? 'Unnamed Project',
                      data['progress'] ?? 0,
                      data['status'] ?? 'Active',
                      data['startDate'],
                      data['endDate'],
                      totalTasks: data['totalTasks'] ?? 0,
                    );
                  }),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

  Widget _buildProjectGroupCard(DocumentSnapshot group, List<DocumentSnapshot> allProjects) {
    final groupData = group.data() as Map<String, dynamic>;
    final groupName = groupData['name'] ?? 'Unnamed Group';
    final groupProjects = allProjects.where((project) {
      final data = project.data() as Map<String, dynamic>;
      return data['groupId'] == group.id;
    }).toList();

    int totalTasks = 0;
    int completedProjects = 0;
    int setupIncompleteProjects = 0;

    for (var project in groupProjects) {
      final data = project.data() as Map<String, dynamic>;
      totalTasks += (data['totalTasks'] ?? 0) as int;
      if (data['progress'] == 100) completedProjects++;
      if (!(data['isSetupComplete'] ?? false)) setupIncompleteProjects++;
    }

    return GestureDetector(
      onTap: () => _showGroupProjectsDialog(group, groupProjects),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.blue.shade100,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleGroupMenuAction(value, group.id, groupName),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Group'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'addProject',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 8),
                            Text('Add Projects'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Group', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                groupName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.assignment,
                    '${groupProjects.length} Projects',
                    Colors.blue.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.task_alt,
                    '$totalTasks Tasks',
                    Colors.green.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupProjectsDialog(DocumentSnapshot group, List<DocumentSnapshot> groupProjects) {
    final groupData = group.data() as Map<String, dynamic>;
    final groupName = groupData['name'] ?? 'Unnamed Group';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          groupName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: groupProjects.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 60, color: Colors.grey),
                              SizedBox(height: 10),
                              Text(
                                'No projects in this group',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(10),
                          itemCount: groupProjects.length,
                          itemBuilder: (context, index) {
                            final project = groupProjects[index];
                            final data = project.data() as Map<String, dynamic>;
                            return _buildProjectCard(
                              project.id,
                              data['name'] ?? 'Unnamed Project',
                              data['progress'] ?? 0,
                              data['status'] ?? 'Active',
                              data['startDate'],
                              data['endDate'],
                              totalTasks: data['totalTasks'] ?? 0,
                              isSubProject: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Stream<QuerySnapshot> _getProjectsStream() {
  final String normalized = _designation.trim().toLowerCase();
  // debug - remove later
  print('Getting projects stream for designation: "$normalized", uid: $uid');

  final base = FirebaseFirestore.instance
      .collection('projects')
      .orderBy('createdAt', descending: true);

  switch (normalized) {
    case 'supervisor':
      // stored as list: assignedSupervisorIds: [uid, ...]
      return base.where('assignedSupervisorIds', arrayContains: uid).snapshots();

    case 'hod': // if HOD is stored as single string, use isEqualTo
      // If your field is a single string use isEqualTo:
      // return base.where('assignedHODId', isEqualTo: uid).snapshots();
      // If it's an array use arrayContains:
      return base.where('assignedHODId', isEqualTo: uid).snapshots();

    case 'designer':
    case 'measurements':
      // If assignedDesignerId is a single string:
      // return base.where('assignedDesignerId', isEqualTo: uid).snapshots();
      // If it's an array:
      return base.where('assignedDesignerId', isEqualTo: uid).snapshots();

    case 'business development manager':
      // Common culprit: field is singular 'assignedBDMId' (string) not an array.
      // If your documents use a single string for BDM:
      // return base.where('assignedBDMId', isEqualTo: uid).snapshots();
      //
      // If your documents store it as an array (assignedBDMIds) use arrayContains:
      // return base.where('assignedBDMIds', arrayContains: uid).snapshots();

      // ===== Example assuming it's stored as single string =====
      return base.where('assignedBDMId', isEqualTo: uid).snapshots();

    case 'superadmin':
    case 'admin':
    case 'hr':
      // full access
      return base.snapshots();

    default:
      // fallback: restrict to supervisor-assigned if unknown designation
      return base.where('assignedSupervisorIds', arrayContains: uid).snapshots();
  }
}

  
  Widget _buildProjectsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getProjectsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No projects found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final projects = snapshot.data!.docs.where((doc) {
          final projectName = (doc['name'] as String).toLowerCase();
          return projectName.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            final data = project.data() as Map<String, dynamic>;

            return _buildProjectCard(
              project.id,
              data['name'] ?? 'Unnamed Project',
              data['progress'] ?? 0,
              data['status'] ?? 'Active',
              data['startDate'],
              data['endDate'],
              totalTasks: data['totalTasks'] ?? 0,
            );
          },
        );
      },
    );
  }

  Widget _buildProjectCard(
    String projectId,
    String title,
    int progress,
    String status,
    Timestamp? startDate,
    Timestamp? endDate, {
    int totalTasks = 0,
    bool isSubProject = false,
  }) {
    final progressColor = progress > 50
        ? Colors.green
        : progress > 0
            ? Colors.orange
            : Colors.grey;

    return GestureDetector(
      onTap: () => _navigateToProjectDetails(projectId, title),
      child: Container(
        margin: EdgeInsets.only(
          bottom: 15,
          left: isSubProject ? 20 : 0,
        ),
        decoration: BoxDecoration(
          color: isSubProject ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:Colors.orange.shade300,
            width: 2,
          ),
          boxShadow: isSubProject
              ? []
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSubProject ? Icons.assignment : Icons.business,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.task_alt,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalTasks Tasks',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (mounted) {
                        _handleMenuAction(value, projectId);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 18),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.bar_chart, size: 18),
                            SizedBox(width: 8),
                            Text('View Report'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'setup',
                        child: Row(
                          children: [
                            Icon(Icons.settings, size: 18),
                            SizedBox(width: 8),
                            Text('Setup Project'),
                          ],
                        ),
                      ),
                      if (!isSubProject)
                        const PopupMenuItem(
                          value: 'addToGroup',
                          child: Row(
                            children: [
                              Icon(Icons.group_add, size: 18),
                              SizedBox(width: 8),
                              Text('Add to Group'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                value: progress / 100,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progressColor,
                                ),
                                strokeWidth: 4,
                              ),
                            ),
                            Text(
                              '$progress%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: progressColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateRange(startDate, endDate),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'Active'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        color: status == 'Active'
                            ? Colors.green[700]
                            : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showCreateGroupDialog() async{
    final TextEditingController groupNameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjectgroup)) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Project Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g., Rama Fusion',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
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
                if (groupNameController.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance.collection('projectGroups').add({
                    'name': groupNameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': FirebaseAuth.instance.currentUser?.uid,
                  });

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Project group created successfully!')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      }
    );
    }else{
      if (mounted) {
        await ErrorDialog.show(
          context,
          title: 'Permission Denied',
          message: 'You do not have permission to create project groups.',
        );
      }
    }
  }

  void _showAddProjectsToGroupDialog(String groupId, String groupName) {
    showDialog(
      context: context,
      builder: (context) {
        Set<String> selectedProjectIds = {};
        TextEditingController searchController = TextEditingController();
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add Projects to $groupName'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search projects...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('projects')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final availableProjects = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['groupId'] == null || data['groupId'] == '';
                          }).toList();

                          final filteredProjects = availableProjects.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['name'] ?? 'Unnamed Project')
                                .toString()
                                .toLowerCase();
                            return name.contains(searchQuery);
                          }).toList();

                          if (filteredProjects.isEmpty) {
                            return const Center(
                              child: Text('No matching projects found'),
                            );
                          }

                          return ListView.builder(
                            itemCount: filteredProjects.length,
                            itemBuilder: (context, index) {
                              final project = filteredProjects[index];
                              final projectData = project.data() as Map<String, dynamic>;
                              final projectId = project.id;
                              final isSelected = selectedProjectIds.contains(projectId);

                              return CheckboxListTile(
                                title: Text(projectData['name'] ?? 'Unnamed Project'),
                                subtitle: Text('Progress: ${projectData['progress'] ?? 0}%'),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedProjectIds.add(projectId);
                                    } else {
                                      selectedProjectIds.remove(projectId);
                                    }
                                  });
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
                ElevatedButton(
                  onPressed: selectedProjectIds.isEmpty
                      ? null
                      : () async {
                          final batch = FirebaseFirestore.instance.batch();

                          for (var projectId in selectedProjectIds) {
                            final docRef = FirebaseFirestore.instance
                                .collection('projects')
                                .doc(projectId);
                            batch.update(docRef, {'groupId': groupId});
                          }

                          await batch.commit();

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${selectedProjectIds.length} project(s) added to $groupName',
                                ),
                              ),
                            );
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleGroupMenuAction(String action, String groupId, String groupName) async{
    switch (action) {
      case 'edit':
        if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjectgroup)) 
        {
        _showEditGroupDialog(groupId, groupName);
        }else{
          if (mounted) {
            await ErrorDialog.show(
              context,
              title: 'Permission Denied',
              message: 'You do not have permission to edit project groups.',
            );
          }
        }
        break;
      case 'addProject':
        if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjectgroup)) 
        {
        _showAddProjectsToGroupDialog(groupId, groupName);
        }else{
          if (mounted) {
            await ErrorDialog.show(
              context,
              title: 'Permission Denied',
              message: 'You do not have permission to add projects to groups.',
            );
          }
        }
        break;
      case 'delete':
        if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjectgroup)) 
        {
        _showDeleteGroupConfirmation(groupId);
        }else{
          if (mounted) {
            await ErrorDialog.show(
              context,
              title: 'Permission Denied',
              message: 'You do not have permission to delete project groups.',
            );
          }
        }
        break;
    }
  }

  void _showEditGroupDialog(String groupId, String currentName) {
    final TextEditingController groupNameController = TextEditingController(text: currentName);
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Project Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: groupNameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
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
                await FirebaseFirestore.instance
                    .collection('projectGroups')
                    .doc(groupId)
                    .update({
                  'name': groupNameController.text.trim(),
                  'description': descriptionController.text.trim(),
                });

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group updated successfully!')),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteGroupConfirmation(String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project Group'),
        content: const Text('Are you sure? Projects in this group will become ungrouped.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteGroup(groupId),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteGroup(String groupId) async {
    try {
      final projectsInGroup = await FirebaseFirestore.instance
          .collection('projects')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in projectsInGroup.docs) {
        final data = doc.data();
        if (data['groupId'] == groupId) {
          batch.update(doc.reference, {'groupId': FieldValue.delete()});
        }
      }

      batch.delete(FirebaseFirestore.instance.collection('projectGroups').doc(groupId));

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project group deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting group: $e')),
        );
      }
    }
  }

  String _formatDateRange(Timestamp? startDate, Timestamp? endDate) {
    if (startDate == null || endDate == null) {
      return 'Start Date - End Date';
    }

    final start = startDate.toDate();
    final end = endDate.toDate();

    return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
  }

  void _navigateToCreateProject()async {
    if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjects)) 
    {Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateProjectPage()),
    );}else{
      if (mounted) {
        await ErrorDialog.show(
          context,
          title: 'Permission Required',
          message: 'You do not have permission to create projects.',
        );
      }
    }
  }

  void _navigateToProjectDetails(String projectId, String projectName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
          ProjectDetailsPage(projectId: projectId, projectName: projectName),
      ),
    );
  }

  void _navigateToProjectSetup(String projectId, String projectName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProjectSetupPage(projectId: projectId, projectName: projectName),
      ),
    );
  }

  void _handleMenuAction(String action, String projectId) async {
    final projectDoc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();
    final projectName = projectDoc['name'] ?? 'Unknown Project';

    switch (action) {
      case 'view':
        _navigateToProjectDetails(projectId, projectName);
        break;
      case 'report':
        if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjects)) 
        {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectReportPage(
              specificProjectId: projectId,
            ),
          ),
        );
        }else{
          if (mounted) {
            await ErrorDialog.show(
              context,
              title: 'Permission Denied',
              message: 'You do not have permission to edit project groups.',
            );
          }
        }
        break;
      case 'edit':
      if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjects)) 
        {
        _showEditProjectDialog(projectId);
        }else{
          if (mounted) {
            await ErrorDialog.show(
              context,
              title: 'Permission Denied',
              message: 'You do not have permission to edit projects.',
            );
          }
        }
        break;
      case 'setup':
      if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjects)) 
        {
        _navigateToProjectSetup(projectId, projectName);
        }else{
          if (mounted) {
            await ErrorDialog.show(
              context,
              title: 'Permission Denied',
              message: 'You do not have permission to setup projects.',
            );
          }
        }
        break;
      case 'addToGroup':
      if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjectgroup)) 
        {
        _showSelectGroupDialog(projectId, projectName);
        }else{
          if (mounted) {
            await ErrorDialog.show(
              context,
              title: 'Permission Denied',
              message: 'You do not have permission to add projects to groups.',
            );
          }
        }
        break;
      case 'delete':
      if (await EmployeePermissionChecker.can(FirebaseAuth.instance.currentUser!.uid, EmployeePermission.manageProjects)) 
        {
        _showDeleteConfirmation(projectId);
        }else{
          if (mounted) {
            await ErrorDialog.show(
              context,
              title: 'Permission Denied',
              message: 'You do not have permission to delete projects.',
            );
          }
        }
        break;
    }
  }

  void _showSelectGroupDialog(String projectId, String projectName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add "$projectName" to Group'),
          content: SizedBox(
            width: double.maxFinite,
            height: 200,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projectGroups')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groups = snapshot.data!.docs;

                if (groups.isEmpty) {
                  return const Center(
                    child: Text('No project groups available.\nCreate a group first.'),
                  );
                }

                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final groupData = group.data() as Map<String, dynamic>;

                    return ListTile(
                      leading: const Icon(Icons.folder, color: Colors.blue),
                      title: Text(groupData['name'] ?? 'Unnamed Group'),
                      subtitle: Text(groupData['description'] ?? ''),
                      onTap: () async {
                        await FirebaseFirestore.instance
                            .collection('projects')
                            .doc(projectId)
                            .update({'groupId': group.id});

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$projectName added to ${groupData['name']}'),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<String> getProjectName(String projectId) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();
    return doc['name'] ?? 'Unknown Project';
  }

  Future<void> _showEditProjectDialog(String projectId) async {
    TextEditingController projectNameController = TextEditingController();
    String projectName = await getProjectName(projectId);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: projectNameController..text = projectName,
                decoration: const InputDecoration(labelText: 'Project Name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                FirebaseFirestore.instance
                    .collection('projects')
                    .doc(projectId)
                    .update({
                  'name': projectNameController.text,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Project updated successfully!'),
                  ),
                );
                setState(() {});
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(String projectId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteProject(projectId),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteProject(String projectId) async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .delete();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting project: $e')),
        );
      }
    }
  }
}