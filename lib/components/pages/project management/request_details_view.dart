import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
class RequestDetailView extends StatefulWidget {
  final DocumentSnapshot request;
  final String projectId;
  final ScrollController scrollController;

  const RequestDetailView({
    super.key,
    required this.request,
    required this.projectId,
    required this.scrollController,
  });

  @override
  RequestDetailViewState createState() => RequestDetailViewState();
}

class RequestDetailViewState extends State<RequestDetailView> {
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final data = widget.request.data() as Map<String, dynamic>;

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
                  data['materialName'] ?? 'Material Request',
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

          // Status
          _buildRequestStatusChip(data['status'] ?? 'Pending'),
          const SizedBox(height: 16),

          // Request Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quantity:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${data['quantity'] ?? 0} ${data['uom'] ?? 'PCS'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (data['createdAt'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Requested:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatTimestamp(data['createdAt'] as Timestamp),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          if (data['status'] == 'Pending') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateRequestStatus('Processing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Start Processing'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateRequestStatus('Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateRequestStatus('Rejected'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject Request'),
              ),
            ),
          ] else if (data['status'] == 'Processing') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateRequestStatus('Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Complete & Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateRequestStatus('Rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
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
              stream: widget.request.reference
                  .collection('comments')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final comment =
                        snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                    return _buildRequestCommentCard(comment);
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
                onPressed: _addRequestComment,
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

  Widget _buildRequestStatusChip(String status) {
    final Color statusColor = status == 'Approved'
        ? Colors.green
        : status == 'Processing'
        ? Colors.orange
        : status == 'Rejected'
        ? Colors.red
        : Colors.blue;

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

  Widget _buildRequestCommentCard(Map<String, dynamic> comment) {
    final bool isStatusChange = comment['type'] == 'status_change';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isStatusChange ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: isStatusChange
            ? flutter.Border.all(color: Colors.blue[200]!)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isStatusChange)
            Row(
              children: [
                Icon(Icons.update, size: 16, color: Colors.blue[600]),
                const SizedBox(width: 4),
                Text(
                  'Status Update',
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          Text(
            comment['comment'] ?? '',
            style: TextStyle(
              fontSize: 14,
              fontStyle: isStatusChange ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(comment['createdAt'] as Timestamp?),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _updateRequestStatus(String newStatus) async {
    try {
      await widget.request.reference.update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
      });

      // Add status change comment
      await widget.request.reference.collection('comments').add({
        'comment': 'Request status changed to: $newStatus',
        'createdAt': Timestamp.now(),
        'type': 'status_change',
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request $newStatus')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _addRequestComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await widget.request.reference.collection('comments').add({
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
