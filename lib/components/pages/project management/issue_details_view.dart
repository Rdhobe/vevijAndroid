
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class IssueDetailView extends StatefulWidget {
  final DocumentSnapshot issue;
  final String projectId;
  final ScrollController scrollController;

  const IssueDetailView({
    super.key,
    required this.issue,
    required this.projectId,
    required this.scrollController,
  });

  @override
  IssueDetailViewState createState() => IssueDetailViewState();
}

class IssueDetailViewState extends State<IssueDetailView> {
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final data = widget.issue.data() as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  data['title'] ?? 'Issue',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status and Priority
          Row(
            children: [
              _buildStatusChip(data['status'] ?? 'Open'),
              const SizedBox(width: 8),
              _buildPriorityChip(data['priority'] ?? 'Medium'),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            'Description',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            data['description'] ?? 'No description provided',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateIssueStatus('In Progress'),
                  child: const Text('Start Work'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateIssueStatus('Resolved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Mark Resolved'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Comments Section
          const Text(
            'Comments & Updates',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),

          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.issue.reference
                  .collection('comments')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final comment =
                        snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                    return _buildCommentCard(comment);
                  },
                );
              },
            ),
          ),

          // Add Comment
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addComment,
                icon: const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final Color statusColor = status == 'Resolved'
        ? Colors.green
        : status == 'In Progress'
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: statusColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    final Color priorityColor = priority == 'High'
        ? Colors.red
        : priority == 'Medium'
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$priority Priority',
        style: TextStyle(
          color: priorityColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment['comment'] ?? '', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(comment['createdAt'] as Timestamp?),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _updateIssueStatus(String newStatus) async {
    try {
      await widget.issue.reference.update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
      });

      // Add status change comment
      await widget.issue.reference.collection('comments').add({
        'comment': 'Status changed to: $newStatus',
        'createdAt': Timestamp.now(),
        'type': 'status_change',
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await widget.issue.reference.collection('comments').add({
        'comment': _commentController.text.trim(),
        'createdAt': Timestamp.now(),
        'type': 'user_comment',
      });

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
