import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/auth_service.dart';
import 'package:vevij/utils/helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vevij/services/user_service.dart';
class CommentsPage extends StatefulWidget {
  final String taskId;

  const CommentsPage({super.key, required this.taskId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Auto-scroll to bottom when new comments are added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    // Rebuild when text changes so the send button enables/disables correctly
    _commentController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Comments'),
      ),
      body: Column(
        children: [
          // Comments List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Provider.of<TaskService>(context).streamComments(widget.taskId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final comments = snapshot.data ?? [];

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _CommentCard(comment: comment);
                  },
                );
              },
            ),
          ),

          // Comment Input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Type your comment...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          _isSubmitting
              ? const CircularProgressIndicator()
              : IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _commentController.text.trim().isEmpty ? null : _submitComment,
                ),
        ],
      ),
    );
  }

  void _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final taskService = Provider.of<TaskService>(context, listen: false);
      final currentUserId = AuthService().currentUser?.uid ?? (await AuthService().getCachedUserData())['userId'] ?? 'unknown';

      await taskService.addComment(
        widget.taskId,
        currentUserId,
        _commentController.text.trim(),
      );

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send comment: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

class _CommentCard extends StatefulWidget {
  final Map<String, dynamic> comment;

  const _CommentCard({required this.comment});

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    try {
      final userId = widget.comment['userId'] as String? ?? '';
      if (userId.isEmpty) {
        setState(() => _displayName = 'Unknown');
        return;
      }

      // Try to get user from provider if available, otherwise call service
      String name = userId;
      try {
        final userService = UserService();
        final user = await userService.getUserById(userId);
        if (user != null && user.empName.isNotEmpty) {
          name = user.empName;
        }
      } catch (e) {
        // fallback to showing uid
        name = userId;
      }

      if (mounted) setState(() => _displayName = name);
    } catch (_) {
      if (mounted) setState(() => _displayName = 'Unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final timestamp = (comment['createdAt'] as Timestamp).toDate();
    final currentUserId = AuthService().currentUser?.uid;
    final isCurrentUser = currentUserId != null && comment['userId'] == currentUserId;

    final firstLetter = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: isCurrentUser ? Colors.blue : Colors.grey,
            child: Text(
              firstLetter,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),

          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user and time
                Row(
                  children: [
                    Text(
                      _displayName.isNotEmpty ? _displayName : (comment['userId'] ?? 'Unknown'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Helpers.formatDateTime(timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Comment Text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentUser 
                        ? Colors.blue.shade50 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    comment['message'] ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

                // Attachments (if any)
                if (comment['attachments'] != null && 
                    (comment['attachments'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: (comment['attachments'] as List<dynamic>).map((attachment) {
                      return Chip(
                        label: Text(attachment.toString().split('/').last),
                        onDeleted: () {
                          // Handle attachment deletion if implemented
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}