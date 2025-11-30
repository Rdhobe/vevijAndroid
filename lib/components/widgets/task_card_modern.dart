import 'package:flutter/material.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/utils/app_colors.dart';
import 'package:vevij/utils/app_theme.dart';
import 'dart:ui';

/// Modern task card with glassmorphism and animations
class TaskCardModern extends StatefulWidget {
  final TaskModel task;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final bool showActions;

  const TaskCardModern({
    super.key,
    required this.task,
    this.onTap,
    this.onEdit,
    this.onComplete,
    this.onDelete,
    this.showActions = true,
  });

  @override
  State<TaskCardModern> createState() => _TaskCardModernState();
}

class _TaskCardModernState extends State<TaskCardModern>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.fastAnimation,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getPriorityColor() {
    switch (widget.task.priority) {
      case TaskPriority.low:
        return AppColors.priorityLow;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.high:
        return AppColors.priorityHigh;
      case TaskPriority.urgent:
        return AppColors.priorityUrgent;
      case TaskPriority.critical:
        return AppColors.priorityCritical;
    }
  }

  Color _getStatusColor() {
    switch (widget.task.status) {
      case TaskStatus.pending:
        return AppColors.statusPending;
      case TaskStatus.inProgress:
        return AppColors.statusInProgress;
      case TaskStatus.completed:
        return AppColors.statusCompleted;
      case TaskStatus.cancelled:
        return AppColors.statusCancelled;
    }
  }

  String _getStatusText() {
    switch (widget.task.status) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getPriorityText() {
    switch (widget.task.priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
      case TaskPriority.critical:
        return 'Critical';
    }
  }

  bool _isOverdue() {
    return DateTime.now().isAfter(widget.task.dueDate) &&
        widget.task.status != TaskStatus.completed;
  }

  int _getDaysRemaining() {
    return widget.task.dueDate.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor();
    final statusColor = _getStatusColor();
    final isOverdue = _isOverdue();
    final daysRemaining = _getDaysRemaining();

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacing4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  priorityColor.withOpacity(0.1),
                  priorityColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: _isHovered
                    ? priorityColor.withOpacity(0.5)
                    : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: priorityColor.withOpacity(_isHovered ? 0.3 : 0.1),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: Offset(0, _isHovered ? 8 : 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            // Priority indicator
                            Container(
                              width: 4,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: AppColors.getPriorityGradient(
                                  _getPriorityText(),
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSmall,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing3),

                            // Title and subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.task.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          decoration:
                                              widget.task.status ==
                                                  TaskStatus.completed
                                              ? TextDecoration.lineThrough
                                              : null,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: AppTheme.spacing1),
                                  Text(
                                    widget.task.description.isEmpty
                                        ? 'No description'
                                        : widget.task.description,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Quick actions
                            if (widget.showActions) ...[
                              const SizedBox(width: AppTheme.spacing2),
                              _buildQuickActions(),
                            ],
                          ],
                        ),

                        const SizedBox(height: AppTheme.spacing4),

                        // Badges row
                        Wrap(
                          spacing: AppTheme.spacing2,
                          runSpacing: AppTheme.spacing2,
                          children: [
                            // Status badge
                            _buildBadge(
                              label: _getStatusText(),
                              color: statusColor,
                              icon: Icons.flag,
                            ),

                            // Priority badge
                            _buildBadge(
                              label: _getPriorityText(),
                              color: priorityColor,
                              icon: Icons.priority_high,
                            ),

                            // Due date badge
                            _buildDueDateBadge(isOverdue, daysRemaining),

                            // Assignees count
                            if (widget.task.assignedTo.isNotEmpty)
                              _buildBadge(
                                label:
                                    '${widget.task.assignedTo.length} Assignees',
                                color: AppColors.info,
                                icon: Icons.people,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onComplete != null &&
            widget.task.status != TaskStatus.completed)
          _buildActionButton(
            icon: Icons.check_circle,
            color: AppColors.success,
            onPressed: widget.onComplete,
          ),
        if (widget.onEdit != null)
          _buildActionButton(
            icon: Icons.edit,
            color: AppColors.info,
            onPressed: widget.onEdit,
          ),
        if (widget.onDelete != null)
          _buildActionButton(
            icon: Icons.delete,
            color: AppColors.error,
            onPressed: widget.onDelete,
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      color: color,
      padding: const EdgeInsets.all(AppTheme.spacing1),
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing2,
        vertical: AppTheme.spacing1,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: AppTheme.spacing1),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateBadge(bool isOverdue, int daysRemaining) {
    Color color;
    String label;
    IconData icon;

    if (isOverdue) {
      color = AppColors.error;
      label = 'Overdue';
      icon = Icons.warning;
    } else if (daysRemaining == 0) {
      color = AppColors.warning;
      label = 'Due Today';
      icon = Icons.today;
    } else if (daysRemaining == 1) {
      color = AppColors.warning;
      label = 'Due Tomorrow';
      icon = Icons.calendar_today;
    } else if (daysRemaining <= 3) {
      color = AppColors.accentOrange;
      label = '$daysRemaining days left';
      icon = Icons.calendar_today;
    } else {
      color = AppColors.info;
      label = '$daysRemaining days left';
      icon = Icons.calendar_today;
    }

    return _buildBadge(label: label, color: color, icon: icon);
  }
}
