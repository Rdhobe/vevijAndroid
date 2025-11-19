import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vevij/models/tasks/team_model.dart';
import 'package:vevij/services/team_service.dart';
import 'package:vevij/components/pages/task management/create_team_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'team_details_page.dart';
class TeamManagementPage extends StatefulWidget {
  const TeamManagementPage({super.key});

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const CreateTeamPage())
              );
            },
            tooltip: 'Create New Team',
          ),
        ]
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Teams List
            Expanded(
              child: _buildTeamsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teams').snapshots(),
      builder: (context, teamSnapshot) {
        if (teamSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!teamSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final teams = teamSnapshot.data!.docs;

        if (teams.isEmpty) {
          return _buildEmptyState();
        }

        return StreamBuilder<List<TeamModel>>(
          stream: Provider.of<TeamService>(context).streamAllTeams(),
          builder: (context, teamModelSnapshot) {
            if (!teamModelSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final teamModels = teamModelSnapshot.data!;
            
            return ListView.builder(
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final teamDoc = teams[index];
                final teamId = teamDoc.id;
                final teamData = teamDoc.data() as Map<String, dynamic>;
                final teamName = teamData['teamName'] ?? 'Unnamed Team';
                
                // Find corresponding TeamModel
                final teamModel = teamModels.firstWhere(
                  (model) => model.id == teamId,
                  orElse: () => TeamModel(
                    id: teamId,
                    name: teamName,
                    description: teamData['description'] ?? '',
                    members: [],
                    createdBy: teamData['createdBy'] ?? '',
                    memberIds: List<String>.from(teamData['memberIds'] ?? []),
                    createdAt: (teamData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                    updatedAt: (teamData['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  ),
                );

                return _TeamCard(team: teamModel);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No Teams Created',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first team to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateTeamPage()),
              );
            },
            icon: const Icon(Icons.group_add),
            label: const Text('Create Team'),
          ),
        ],
      ),
    );
  }
}

class _TeamCard extends StatefulWidget {
  final TeamModel team;

  const _TeamCard({required this.team});

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  bool _isMounted = false;
  
  @override
  void initState() {
    super.initState();
    _isMounted = true;
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamService = Provider.of<TeamService>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(
            Icons.group,
            color: Colors.blue[800],
            size: 24,
          ),
        ),
        title: Text(
          widget.team.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              widget.team.description.isEmpty ? 'No description' : widget.team.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${widget.team.members.length} members',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(widget.team.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: _TeamActionsButton(
          team: widget.team,
          teamService: teamService,
        ),
        onTap: () {
          _showTeamDetails(context, widget.team);
        },
      ),
    );
  }

  void _showTeamDetails(BuildContext context, TeamModel team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailsPage(team: team),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _TeamActionsButton extends StatelessWidget {
  final TeamModel team;
  final TeamService teamService;

  const _TeamActionsButton({
    required this.team,
    required this.teamService,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () {
        _showActionsBottomSheet(context);
      },
    );
  }

  void _showActionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamDetailsPage(team: team),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Edit Team'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateTeamPage(teamId: team.id),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Team'),
              onTap: () {
                Navigator.pop(context);
                _deleteTeam(context, teamService);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTeam(BuildContext context, TeamService teamService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text(
          'Are you sure you want to delete "${team.name}"? '
          'This action cannot be undone and all team data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await teamService.deleteTeam(team.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Team "${team.name}" deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete team: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
