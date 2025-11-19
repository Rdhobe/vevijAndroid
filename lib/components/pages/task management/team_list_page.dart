import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vevij/services/user_team_role_service.dart';
import 'package:vevij/models/tasks/user_team_role_model.dart';
import 'package:vevij/components/pages/task management/create_team_page.dart';
import 'package:vevij/components/pages/task%20management/team_tasks_page.dart';
import 'package:vevij/components/pages/task management/notifications_page.dart';
import 'package:vevij/components/pages/task management/analytics_page.dart';
class TeamListPage extends StatefulWidget {
  const TeamListPage({super.key});

  @override
  State<TeamListPage> createState() => _TeamListPageState();
}

class _TeamListPageState extends State<TeamListPage> {
  final UserTeamRoleService _roleService = UserTeamRoleService();
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (mounted) {
          setState(() {
            _currentUserId = user.uid;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        throw Exception('User not authenticated');
      }
    } catch (e) {
      print('Error loading current user: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Authentication Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please sign in to access teams'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadCurrentUser();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
        actions: [
          _buildCreateTeamButton(),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage()));
            },
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsPage()));
            },
            tooltip: 'Profile',
          ),

        ],
      ),
      body: _buildTeamList(),
    );
  }

  Widget _buildCreateTeamButton() {
    return FutureBuilder<bool>(
      future: _roleService.canUserCreateTeam(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const IconButton(
            icon: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            onPressed: null,
          );
        }

        if (snapshot.hasError || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        return IconButton(
          icon: const Icon(Icons.group_add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateTeamPage(),
              ),
            );
          },
          tooltip: 'Create New Team',
        );
      },
    );
  }

  Widget _buildTeamList() {
    return StreamBuilder<List<UserTeamRole>>(
      stream: _roleService.getUserTeams(_currentUserId!),
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
                const Text(
                  'Error Loading Teams',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final teams = snapshot.data ?? [];

        if (teams.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final team = teams[index];
            return _TeamCard(team: team);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return FutureBuilder<bool>(
      future: _roleService.canUserCreateTeam(_currentUserId!),
      builder: (context, snapshot) {
        final canCreateTeam = snapshot.data ?? false;
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                'No Teams Available',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                canCreateTeam 
                  ? 'Create your first team to get started'
                  : 'You are not a member of any teams yet',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (canCreateTeam)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateTeamPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group_add),
                  label: const Text('Create Team'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamCard extends StatelessWidget {
  final UserTeamRole team;

  const _TeamCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(team.role),
          child: Icon(
            Icons.group,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          team.teamName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Chip(
              label: Text(
                _getRoleText(team.role),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              backgroundColor: _getRoleColor(team.role),
            ),
            const SizedBox(height: 4),
            Text(
              'Joined: ${_formatDate(team.joinedAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeamTasksPage(
                teamId: team.teamId,
                teamName: team.teamName,
                userRole: team.role,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(TeamRole role) {
    switch (role) {
      case TeamRole.hr:
        return Colors.purple;
      case TeamRole.admin:
        return Colors.red;
      case TeamRole.manager:
        return Colors.orange;
      case TeamRole.monitor:
        return Colors.blue;
      case TeamRole.member:
        return Colors.green;
      case TeamRole.none:
        return Colors.grey;
    }
  }

  String _getRoleText(TeamRole role) {
    switch (role) {
      case TeamRole.hr:
        return 'HR';
      case TeamRole.admin:
        return 'Admin';
      case TeamRole.manager:
        return 'Manager';
      case TeamRole.monitor:
        return 'Monitor';
      case TeamRole.member:
        return 'Member';
      case TeamRole.none:
        return 'No Access';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}