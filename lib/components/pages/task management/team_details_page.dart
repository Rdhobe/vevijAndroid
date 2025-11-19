import 'package:flutter/material.dart';
import 'package:vevij/models/tasks/team_model.dart';
import 'create_team_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamDetailsPage extends StatefulWidget {
  final TeamModel team;

  const TeamDetailsPage({super.key, required this.team});

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _teamMembersWithDetails = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamMembersWithDetails();
  }

  Future<void> _loadTeamMembersWithDetails() async {
    try {
      print('Loading team members for team: ${widget.team.id}');
      print('Team members list length: ${widget.team.members.length}');
      print('Team memberIds length: ${widget.team.memberIds.length}');

      // If members list is empty but memberIds has data, we need to load members
      if (widget.team.members.isEmpty && widget.team.memberIds.isNotEmpty) {
        print('Members list is empty, loading from memberIds...');
        await _loadMembersFromMemberIds();
      } else if (widget.team.members.isNotEmpty) {
        print('Loading user details for existing members...');
        await _loadUserDetailsForMembers();
      } else {
        print('No members to load');
        setState(() {
          _isLoading = false;
          _teamMembersWithDetails = [];
        });
      }
    } catch (e) {
      print('Error in _loadTeamMembersWithDetails: $e');
      setState(() {
        _isLoading = false;
        _teamMembersWithDetails = _createFallbackMemberData();
      });
    }
  }

  Future<void> _loadMembersFromMemberIds() async {
    try {
      final List<Future<Map<String, dynamic>?>> memberFutures = [];

      for (final userId in widget.team.memberIds) {
        final future = _loadMemberFromUserId(userId);
        memberFutures.add(future);
      }

      final results = await Future.wait(memberFutures);
      final validResults = results.where((result) => result != null).cast<Map<String, dynamic>>().toList();
      
      setState(() {
        _teamMembersWithDetails = validResults;
        _isLoading = false;
      });

      print('Successfully loaded ${_teamMembersWithDetails.length} members from memberIds');
    } catch (e) {
      print('Error loading members from memberIds: $e');
      setState(() {
        _isLoading = false;
        _teamMembersWithDetails = _createFallbackMemberData();
      });
    }
  }

  Future<void> _loadUserDetailsForMembers() async {
    try {
      final List<Future<Map<String, dynamic>?>> memberFutures = [];

      for (final teamMember in widget.team.members) {
        final future = _loadMemberWithUserDetails(teamMember);
        memberFutures.add(future);
      }

      final results = await Future.wait(memberFutures);
      final validResults = results.where((result) => result != null).cast<Map<String, dynamic>>().toList();
      
      setState(() {
        _teamMembersWithDetails = validResults;
        _isLoading = false;
      });

      print('Successfully loaded ${_teamMembersWithDetails.length} members with details');
    } catch (e) {
      print('Error loading user details for members: $e');
      setState(() {
        _isLoading = false;
        _teamMembersWithDetails = _createFallbackMemberData();
      });
    }
  }

  Future<Map<String, dynamic>?> _loadMemberFromUserId(String userId) async {
    try {
      final userData = await _getUserInfo(userId).timeout(const Duration(seconds: 5));
      
      // Create a basic TeamMember object since we don't have the full TeamMember data
      final teamMember = TeamMember(
        userId: userId,
        addedBy: 'Unknown',
        role: 'member',
        joinedAt: DateTime.now(),
      );

      return {
        'teamMember': teamMember,
        'userData': userData,
      };
    } catch (e) {
      print('Error loading member from userId $userId: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadMemberWithUserDetails(TeamMember teamMember) async {
    try {
      final userData = await _getUserInfo(teamMember.userId).timeout(const Duration(seconds: 5));
      
      return {
        'teamMember': teamMember,
        'userData': userData,
      };
    } catch (e) {
      print('Error loading user details for member ${teamMember.userId}: $e');
      
      // Return fallback data
      return {
        'teamMember': teamMember,
        'userData': {
          'name': 'User ${teamMember.userId.substring(0, 8)}...',
          'designation': 'Team ${teamMember.role}',
          'department': 'Not Available',
          'empCode': 'N/A',
          'email': '',
        },
      };
    }
  }

  Future<Map<String, String>> _getUserInfo(String userId) async {
    try {
      print('Loading user info for: $userId');
      
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        print('User document $userId does not exist');
        return {
          'name': 'Unknown User',
          'designation': 'Not Found',
          'department': 'Not Found',
          'empCode': 'N/A',
          'email': '',
        };
      }

      final data = doc.data() as Map<String, dynamic>;
      final name = data['empName']?.toString() ?? 'Unknown User';
      print('User data loaded: $name');
      
      return {
        'name': name,
        'designation': data['designation']?.toString() ?? 'No Designation',
        'department': data['department']?.toString() ?? 'No Department',
        'empCode': data['empCode']?.toString() ?? 'N/A',
        'email': data['email']?.toString() ?? '',
      };
    } catch (e) {
      print('Error in _getUserInfo for $userId: $e');
      return {
        'name': 'Error Loading User',
        'designation': 'Error',
        'department': 'Error',
        'empCode': 'N/A',
        'email': '',
      };
    }
  }

  List<Map<String, dynamic>> _createFallbackMemberData() {
    // Use memberIds if available, otherwise use members list
    if (widget.team.memberIds.isNotEmpty) {
      return widget.team.memberIds.map((userId) {
        return {
          'teamMember': TeamMember(
            userId: userId,
            addedBy: 'Unknown',
            role: 'member',
            joinedAt: DateTime.now(),
          ),
          'userData': {
            'name': 'User ${userId.substring(0, 8)}...',
            'designation': 'Team Member',
            'department': 'Not Available',
            'empCode': 'N/A',
            'email': '',
          },
        };
      }).toList();
    } else {
      return widget.team.members.map((teamMember) {
        return {
          'teamMember': teamMember,
          'userData': {
            'name': 'User ${teamMember.userId.substring(0, 8)}...',
            'designation': 'Team ${teamMember.role}',
            'department': 'Not Available',
            'empCode': 'N/A',
            'email': '',
          },
        };
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateTeamPage(teamId: widget.team.id),
                ),
              ).then((_) {
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                  });
                  _loadTeamMembersWithDetails();
                }
              });
            },
            tooltip: 'Edit Team',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingWidget()
          : _buildContentWidget(),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading team details...'),
        ],
      ),
    );
  }

  Widget _buildContentWidget() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTeamInfoCard(),
          const SizedBox(height: 20),
          _buildMembersSection(),
          const SizedBox(height: 20),
          _buildStatisticsSection(),
        ],
      ),
    );
  }

  Widget _buildTeamInfoCard() {
    final totalMembers = _teamMembersWithDetails.isNotEmpty 
        ? _teamMembersWithDetails.length 
        : (widget.team.memberIds.isNotEmpty ? widget.team.memberIds.length : widget.team.members.length);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  radius: 30,
                  child: Icon(
                    Icons.group,
                    size: 30,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.team.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalMembers members',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.team.description.isNotEmpty) ...[
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(widget.team.description),
              const SizedBox(height: 12),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem('Members', totalMembers.toString()),
                _buildInfoItem('Created', _formatDate(widget.team.createdAt)),
                _buildInfoItem('Updated', _formatDate(widget.team.updatedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    final totalMembers = _teamMembersWithDetails.isNotEmpty 
        ? _teamMembersWithDetails.length 
        : (widget.team.memberIds.isNotEmpty ? widget.team.memberIds.length : widget.team.members.length);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Team Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(totalMembers.toString()),
                  backgroundColor: Colors.blue[100],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_teamMembersWithDetails.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No members in this team',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _teamMembersWithDetails.map((memberData) {
                  final teamMember = memberData['teamMember'] as TeamMember;
                  final userData = memberData['userData'] as Map<String, dynamic>;
                  
                  return _buildMemberCard(teamMember, userData);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(TeamMember teamMember, Map<String, dynamic> userData) {
    final name = userData['name']?.toString() ?? 'Unknown User';
    final designation = userData['designation']?.toString() ?? 'No Designation';
    final department = userData['department']?.toString() ?? 'No Department';
    final empCode = userData['empCode']?.toString() ?? 'N/A';
    final email = userData['email']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColorFromName(name),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (empCode != 'N/A') 
              Text('ID: $empCode'),
            Text('$department • $designation'),
            if (email.isNotEmpty)
              Text(
                email,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(teamMember.role),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _capitalizeFirst(teamMember.role),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (teamMember.addedBy.isNotEmpty && teamMember.addedBy != 'Unknown')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Added by: ${_getShortUserId(teamMember.addedBy)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  'Joined: ${_formatDate(teamMember.joinedAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline, size: 20, color: Colors.blue),
          onPressed: () {
            _showMemberDetails(teamMember, userData);
          },
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('tasks')
          .where('assignedTeamId', isEqualTo: widget.team.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Error loading tasks: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Team Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.assignment, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No tasks assigned to this team',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final tasks = snapshot.data!.docs;
        final totalTasks = tasks.length;
        final pendingTasks = tasks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending' || data['status'] == 'Pending';
        }).length;
        final inProgressTasks = tasks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'inProgress' || data['status'] == 'In Progress';
        }).length;
        final completedTasks = tasks.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'completed' || data['status'] == 'Completed';
        }).length;

        final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

        return Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Team Performance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completion Progress: ${(progress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 0.7 ? Colors.green : 
                              progress >= 0.4 ? Colors.orange : Colors.red,
                            ),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Task statistics
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', totalTasks.toString(), Colors.blue),
                    _buildStatItem('Pending', pendingTasks.toString(), Colors.orange),
                    _buildStatItem('In Progress', inProgressTasks.toString(), Colors.blue.shade700),
                    _buildStatItem('Completed', completedTasks.toString(), Colors.green),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Color _getColorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    final index = name.length % colors.length;
    return colors[index];
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'lead':
        return Colors.green;
      case 'senior':
        return Colors.orange;
      case 'member':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _getShortUserId(String userId) {
    if (userId.length <= 8) return userId;
    return '${userId.substring(0, 4)}...${userId.substring(userId.length - 4)}';
  }

  void _showMemberDetails(TeamMember teamMember, Map<String, dynamic> userData) {
    final name = userData['name']?.toString() ?? 'Unknown User';
    final designation = userData['designation']?.toString() ?? 'No Designation';
    final department = userData['department']?.toString() ?? 'No Department';
    final empCode = userData['empCode']?.toString() ?? 'N/A';
    final email = userData['email']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getColorFromName(name),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name),
                subtitle: Text(designation),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Employee ID', empCode),
              _buildDetailRow('Department', department),
              _buildDetailRow('Designation', designation),
              if (email.isNotEmpty)
                _buildDetailRow('Email', email),
              const SizedBox(height: 8),
              const Divider(),
              _buildDetailRow('Team Role', _capitalizeFirst(teamMember.role)),
              _buildDetailRow('Joined Team', _formatDate(teamMember.joinedAt)),
              _buildDetailRow('User ID', _getShortUserId(teamMember.userId)),
              if (teamMember.addedBy.isNotEmpty && teamMember.addedBy != 'Unknown')
                _buildDetailRow('Added by', _getShortUserId(teamMember.addedBy)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}