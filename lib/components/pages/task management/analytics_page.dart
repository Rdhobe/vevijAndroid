import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vevij/models/tasks/task_model.dart';
import 'package:vevij/services/task_service.dart';
import 'package:vevij/services/auth_service.dart';
import 'package:vevij/utils/helpers.dart';
import 'package:intl/intl.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _currentUserId = authService.currentUser?.uid;
  }

  Map<String, dynamic> _calculateAnalyticsData(List<TaskModel> tasks) {
    final userTasks = tasks.where((task) => task.assignedTo.contains(_currentUserId)).toList();
    final now = DateTime.now();

    // Status Distribution
    final statusDistribution = <String, int>{};
    for (final status in TaskStatus.values) {
      statusDistribution[status.name] = userTasks.where((t) => t.status == status).length;
    }

    // Priority Distribution
    final priorityDistribution = <String, int>{};
    for (final priority in TaskPriority.values) {
      priorityDistribution[priority.name] = userTasks.where((t) => t.priority == priority).length;
    }

    // Monthly Completion Trend (last 6 months)
    final monthlyTrend = <String, int>{};
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM').format(month);
      monthlyTrend[monthKey] = userTasks.where((t) =>
        t.status == TaskStatus.completed &&
        t.updatedAt.year == month.year &&
        t.updatedAt.month == month.month
      ).length;
    }

    // Calculate completion rates and statistics
    final totalTasks = userTasks.length;
    final completedTasks = userTasks.where((t) => t.status == TaskStatus.completed).length;
    final overdueTasks = userTasks.where((t) => Helpers.isOverdue(t)).length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;

    // Average completion time
    final completedTaskTimes = userTasks
        .where((t) => t.status == TaskStatus.completed)
        .map((t) => t.updatedAt.difference(t.createdAt).inDays)
        .toList();
    final avgCompletionTime = completedTaskTimes.isNotEmpty 
        ? completedTaskTimes.reduce((a, b) => a + b) / completedTaskTimes.length 
        : 0;

    return {
      'statusDistribution': statusDistribution,
      'priorityDistribution': priorityDistribution,
      'monthlyTrend': monthlyTrend,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'overdueTasks': overdueTasks,
      'completionRate': completionRate,
      'avgCompletionTime': avgCompletionTime,
      'userTasks': userTasks,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Task Analytics'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: Provider.of<TaskService>(context).streamAllTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tasks = snapshot.data ?? [];
          final analyticsData = _calculateAnalyticsData(tasks);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Summary Cards
                _buildSummaryCards(analyticsData),
                const SizedBox(height: 24),
                
                // Progress Overview
                _buildProgressOverview(analyticsData),
                const SizedBox(height: 24),
                
                // Status Distribution
                _buildStatusDistribution(analyticsData),
                const SizedBox(height: 24),
                
                // Priority Distribution
                _buildPriorityDistribution(analyticsData),
                const SizedBox(height: 24),
                
                // Monthly Trend
                _buildMonthlyTrend(analyticsData),
                const SizedBox(height: 24),
                
                // Performance Insights
                _buildPerformanceInsights(analyticsData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> analyticsData) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _AnalyticsCard(
          title: 'Total Tasks',
          value: analyticsData['totalTasks'].toString(),
          color: Colors.blue,
          icon: Icons.task,
        ),
        _AnalyticsCard(
          title: 'Completed',
          value: analyticsData['completedTasks'].toString(),
          color: Colors.green,
          icon: Icons.check_circle,
        ),
        _AnalyticsCard(
          title: 'Overdue',
          value: analyticsData['overdueTasks'].toString(),
          color: Colors.red,
          icon: Icons.warning,
        ),
        _AnalyticsCard(
          title: 'Completion Rate',
          value: '${analyticsData['completionRate'].toStringAsFixed(1)}%',
          color: Colors.orange,
          icon: Icons.trending_up,
        ),
      ],
    );
  }

  Widget _buildProgressOverview(Map<String, dynamic> analyticsData) {
    final completionRate = analyticsData['completionRate'];
    final totalTasks = analyticsData['totalTasks'] as int;
    final completedTasks = analyticsData['completedTasks'] as int;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: completionRate / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                completionRate >= 80 ? Colors.green : 
                completionRate >= 60 ? Colors.orange : Colors.red,
              ),
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completion Progress',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$completedTasks/$totalTasks tasks',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${completionRate.toStringAsFixed(1)}% completed',
              style: TextStyle(
                fontSize: 14,
                color: completionRate >= 80 ? Colors.green : 
                       completionRate >= 60 ? Colors.orange : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistribution(Map<String, dynamic> analyticsData) {
    final statusData = analyticsData['statusDistribution'] as Map<String, int>;
    final total = analyticsData['totalTasks'] as int;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task Status Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: _getStatusPieSections(statusData, total),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildStatusLegend(statusData),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getStatusPieSections(Map<String, int> data, int total) {
    final colors = [
      Colors.orange, // pending
      Colors.blue,   // inProgress
      Colors.green,  // completed
      Colors.red,    // cancelled
    ];

    int colorIndex = 0;
    return data.entries.map((entry) {
      final percentage = total > 0 ? (entry.value / total * 100) : 0;
      final section = PieChartSectionData(
        color: colors[colorIndex],
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
      colorIndex++;
      return section;
    }).toList();
  }

  Widget _buildStatusLegend(Map<String, int> data) {
    final colors = [Colors.orange, Colors.blue, Colors.green, Colors.red];
    int colorIndex = 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: data.entries.map((entry) {
        final widget = Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[colorIndex],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_getStatusText(entry.key)} (${entry.value})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
        colorIndex++;
        return widget;
      }).toList(),
    );
  }

  Widget _buildPriorityDistribution(Map<String, dynamic> analyticsData) {
    final priorityData = analyticsData['priorityDistribution'] as Map<String, int>;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task Priority Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: priorityData.values.isNotEmpty 
                      ? priorityData.values.reduce((a, b) => a > b ? a : b).toDouble() + 2 
                      : 10,
                  barGroups: _getPriorityBarGroups(priorityData),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final priorities = TaskPriority.values;
                          if (value.toInt() < priorities.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _getPriorityText(priorities[value.toInt()].name),
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _getPriorityBarGroups(Map<String, int> data) {
    final priorities = TaskPriority.values;
    final colors = [
      Colors.green,   // low
      Colors.orange,  // medium
      Colors.deepOrange, // high
      Colors.red,     // urgent
      Colors.purple,  // critical
    ];

    return List.generate(priorities.length, (index) {
      final priority = priorities[index];
      final count = data[priority.name] ?? 0;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: colors[index],
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  Widget _buildMonthlyTrend(Map<String, dynamic> analyticsData) {
    final monthlyTrend = analyticsData['monthlyTrend'] as Map<String, int>;
    final months = monthlyTrend.keys.toList();
    final values = monthlyTrend.values.toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Completion Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                months[value.toInt()],
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString());
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: (months.length - 1).toDouble(),
                  minY: 0,
                  maxY: values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b).toDouble() + 2 : 10,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(months.length, (index) {
                        return FlSpot(index.toDouble(), values[index].toDouble());
                      }),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(show: false),
                      dotData: const FlDotData(show: true),
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

  Widget _buildPerformanceInsights(Map<String, dynamic> analyticsData) {
    final completionRate = analyticsData['completionRate'] ;
    final avgCompletionTime = analyticsData['avgCompletionTime'];
    final totalTasks = analyticsData['totalTasks'] as int;
    final overdueTasks = analyticsData['overdueTasks'] as int;

    List<Widget> insights = [];

    // Completion rate insight
    if (completionRate >= 80) {
      insights.add(_buildInsightItem(
        Icons.emoji_events,
        'Excellent Completion Rate!',
        'You\'re completing ${completionRate.toStringAsFixed(1)}% of your tasks. Keep up the great work!',
        Colors.green,
      ));
    } else if (completionRate >= 60) {
      insights.add(_buildInsightItem(
        Icons.trending_up,
        'Good Progress',
        'You\'re on track with ${completionRate.toStringAsFixed(1)}% completion rate.',
        Colors.orange,
      ));
    } else {
      insights.add(_buildInsightItem(
        Icons.tips_and_updates,
        'Room for Improvement',
        'Try to focus on completing more tasks. Current rate: ${completionRate.toStringAsFixed(1)}%',
        Colors.blue,
      ));
    }

    // Overdue tasks insight
    if (overdueTasks > 0) {
      insights.add(_buildInsightItem(
        Icons.warning,
        'Attention Needed',
        'You have $overdueTasks overdue task${overdueTasks > 1 ? 's' : ''}. Consider prioritizing these.',
        Colors.red,
      ));
    }

    // Average completion time insight
    if (avgCompletionTime > 0) {
      insights.add(_buildInsightItem(
        Icons.schedule,
        'Average Completion Time',
        'Tasks take ${avgCompletionTime.toStringAsFixed(1)} days on average to complete.',
        Colors.purple,
      ));
    }

    if (insights.isEmpty) {
      insights.add(_buildInsightItem(
        Icons.analytics,
        'Start Tracking',
        'Complete more tasks to see personalized insights and recommendations.',
        Colors.grey,
      ));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...insights,
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(IconData icon, String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'inProgress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'low': return 'Low';
      case 'medium': return 'Medium';
      case 'high': return 'High';
      case 'urgent': return 'Urgent';
      case 'critical': return 'Critical';
      default: return priority;
    }
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}