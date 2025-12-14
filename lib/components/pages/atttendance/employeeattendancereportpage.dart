import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:vevij/components/imports.dart';
import 'dart:convert';

class AttendanceReportPage extends StatefulWidget {
  const AttendanceReportPage({super.key});

  @override
  State<AttendanceReportPage> createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter state
  DateTimeRange? _dateRange;
  Set<String> _statusFilters = {'All'};
  bool _showLateOnly = false;
  bool _showOvertimeOnly = false;

  String _sortBy = 'date_desc';
  bool _isFilterExpanded = false;

  // Data state
  bool _isLoading = true;
  List<AttendanceRecord> _records = [];
  Map<String, dynamic> _statistics = {};
  int _currentPage = 0;
  final int _rowsPerPage = 20;

  // User info
  String _userName = '';
  String _empId = '';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _setDefaultDateRange();
    _loadReport();
  }

  Future<void> _loadUserInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
        _userName = user.displayName ?? 'User';
      });

      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final employee = Employee.fromMap(
            userDoc.data() as Map<String, dynamic>,
          );
          setState(() {
            _empId = employee.empCode;
            _userName = employee.empName;
          });
        }
      } catch (e) {
        print('❌ Error loading user info: $e');
        setState(() => _empId = 'N/A');
      }
    }
  }

  void _setDefaultDateRange() {
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  Future<void> _loadReport() async {
    if (_userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      Query query = _firestore
          .collection('attendance')
          .where('userId', isEqualTo: _userId);

      if (_dateRange != null) {
        final startTimestamp = Timestamp.fromDate(_dateRange!.start);
        final endTimestamp = Timestamp.fromDate(
          DateTime(
            _dateRange!.end.year,
            _dateRange!.end.month,
            _dateRange!.end.day,
            23,
            59,
            59,
          ),
        );

        query = query
            .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
            .where('createdAt', isLessThanOrEqualTo: endTimestamp)
            .orderBy('createdAt', descending: true);
      }

      final snapshot = await query.get();
      List<AttendanceRecord> records = snapshot.docs
          .map(
            (doc) => AttendanceRecord.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();

      // Apply filters
      records = records.where((record) {
        // Status filter
        if (!_statusFilters.contains('All')) {
          if (!_statusFilters.contains(record.type1)) return false;
        }

        // Late filter
        if (_showLateOnly) {
          if (record.lateHrs <= 0) return false;
        }

        // Overtime filter
        if (_showOvertimeOnly) {
          if (record.otHrs <= 0) return false;
        }

        // Distance filter

        return true;
      }).toList();

      // Apply sorting
      records.sort((a, b) {
        switch (_sortBy) {
          case 'date_asc':
            return a.createdAt.compareTo(b.createdAt);
          case 'date_desc':
            return b.createdAt.compareTo(a.createdAt);
          case 'hours_high':
            return b.totHrs.compareTo(a.totHrs);
          case 'hours_low':
            return a.totHrs.compareTo(b.totHrs);

          default:
            return 0;
        }
      });

      _calculateStatistics(records);

      setState(() {
        _records = records;
        _isLoading = false;
        _currentPage = 0;
      });

      await _cacheReport(records);
    } catch (e) {
      print('❌ Error loading report: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load report: ${e.toString()}');
    }
  }

  Future<void> _cacheReport(List<AttendanceRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'statistics': _statistics,
        'recordCount': records.length,
      };
      await prefs.setString('report_cache_$_userId', json.encode(cacheData));
    } catch (e) {
      print('❌ Error caching report: $e');
    }
  }

  void _calculateStatistics(List<AttendanceRecord> records) {
    int totalDays = 0;
    int presentDays = 0;
    int halfDays = 0;
    int absentDays = 0;
    double totalHours = 0.0;

    int lateArrivals = 0;
    double totalLateHours = 0.0;
    double totalBreakMinutes = 0.0;
    int onTimeArrivals = 0;
    double totalOvertimeHours = 0.0;

    for (final record in records) {
      totalDays++;
      totalHours += record.totHrs;

      totalOvertimeHours += record.otHrs;

      if (record.type1 == 'DP')
        presentDays++;
      else if (record.type1 == 'HD')
        halfDays++;
      else if (record.type1 == 'ABS')
        absentDays++;

      if (record.lateHrs > 0) {
        lateArrivals++;
        totalLateHours += record.lateHrs;
      } else if (record.inTime != null && record.type1 != 'ABS') {
        onTimeArrivals++;
      }

      // Parse break time (format: HH:MM:SS or HH:MM)
      try {
        final breakTime = record.totalBreakTime ?? '00:00:00';
        final breakParts = breakTime.split(':');
        if (breakParts.length >= 2) {
          totalBreakMinutes +=
              int.parse(breakParts[0]) * 60 + int.parse(breakParts[1]);
        }
      } catch (e) {
        // Invalid format, skip
      }
    }

    final workingDays = presentDays + halfDays;
    final avgHours = workingDays > 0 ? totalHours / workingDays : 0.0;

    final avgBreak = totalDays > 0 ? totalBreakMinutes / totalDays : 0.0;
    final punctualityRate = totalDays > 0
        ? (onTimeArrivals / totalDays) * 100
        : 0.0;
    final attendanceRate = totalDays > 0
        ? (workingDays / totalDays) * 100
        : 0.0;

    _statistics = {
      'totalDays': totalDays,
      'presentDays': presentDays,
      'halfDays': halfDays,
      'absentDays': absentDays,
      'workingDays': workingDays,
      'totalHours': totalHours,
      'avgHours': avgHours,

      'lateArrivals': lateArrivals,
      'totalLateHours': totalLateHours,
      'onTimeArrivals': onTimeArrivals,
      'avgBreak': avgBreak,
      'punctualityRate': punctualityRate,
      'attendanceRate': attendanceRate,
      'totalOvertimeHours': totalOvertimeHours,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Attendance Report', style: TextStyle(color: Colors.black)),
        leading: BackButton(color: Colors.black),
      ),
      body: CustomScrollView(
        controller: ScrollController(),
        slivers: [
          SliverToBoxAdapter(child: _buildFilterPanel()),
          if (_isLoading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_records.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else ...[
            SliverToBoxAdapter(child: _buildSummaryDashboard()),
            SliverToBoxAdapter(child: _buildInsightsSection()),
            SliverToBoxAdapter(child: _buildDataTable()),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _records.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showExportOptions,
              icon: Icon(Icons.download),
              label: Text('Export'),
              backgroundColor: Colors.indigo,
            )
          : null,
    );
  }

  Widget _buildFilterPanel() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.filter_list, color: Colors.indigo),
            title: Text(
              'Filters',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(
                _isFilterExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              onPressed: () =>
                  setState(() => _isFilterExpanded = !_isFilterExpanded),
            ),
          ),
          if (_isFilterExpanded) ...[
            Divider(),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRangeSelector(),
                  SizedBox(height: 16),
                  _buildStatusFilter(),
                  SizedBox(height: 16),
                  _buildAdditionalFilters(),
                  SizedBox(height: 16),
                  _buildSortOptions(),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _resetFilters,
                        child: Text('Reset'),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _loadReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickFilter('Today', () {
              final now = DateTime.now();
              setState(() => _dateRange = DateTimeRange(start: now, end: now));
            }),
            _buildQuickFilter('This Week', () {
              final now = DateTime.now();
              final start = now.subtract(Duration(days: now.weekday - 1));
              setState(
                () => _dateRange = DateTimeRange(start: start, end: now),
              );
            }),
            _buildQuickFilter('This Month', () {
              final now = DateTime.now();
              final start = DateTime(now.year, now.month, 1);
              final end = DateTime(now.year, now.month + 1, 0);
              setState(
                () => _dateRange = DateTimeRange(start: start, end: end),
              );
            }),
            _buildQuickFilter('Last Month', () {
              final now = DateTime.now();
              final start = DateTime(now.year, now.month - 1, 1);
              final end = DateTime(now.year, now.month, 0);
              setState(
                () => _dateRange = DateTimeRange(start: start, end: end),
              );
            }),
          ],
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _selectCustomDateRange,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _dateRange == null
                        ? 'Select Custom Range'
                        : '${DateFormat('dd MMM yyyy').format(_dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Icon(Icons.calendar_today, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilter(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.indigo[50],
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['All', 'DP', 'HD', 'ABS'].map((status) {
            final isSelected = _statusFilters.contains(status);
            return FilterChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (status == 'All') {
                    _statusFilters = {'All'};
                  } else {
                    _statusFilters.remove('All');
                    if (selected) {
                      _statusFilters.add(status);
                    } else {
                      _statusFilters.remove(status);
                    }
                    if (_statusFilters.isEmpty) {
                      _statusFilters = {'All'};
                    }
                  }
                });
              },
              selectedColor: Colors.indigo[100],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAdditionalFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Filters',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        CheckboxListTile(
          title: Text('Late Arrivals Only'),
          value: _showLateOnly,
          onChanged: (val) => setState(() => _showLateOnly = val ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: Text('Overtime Hours Only'),
          value: _showOvertimeOnly,
          onChanged: (val) => setState(() => _showOvertimeOnly = val ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _sortBy,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            DropdownMenuItem(
              value: 'date_desc',
              child: Text('Date (Newest First)'),
            ),
            DropdownMenuItem(
              value: 'date_asc',
              child: Text('Date (Oldest First)'),
            ),
            DropdownMenuItem(
              value: 'hours_high',
              child: Text('Hours (High to Low)'),
            ),
            DropdownMenuItem(
              value: 'hours_low',
              child: Text('Hours (Low to High)'),
            ),
          ],
          onChanged: (val) => setState(() => _sortBy = val ?? 'date_desc'),
        ),
      ],
    );
  }

  Widget _buildSummaryDashboard() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard(
                'Working Days',
                '${_statistics['workingDays'] ?? 0}',
                '${(_statistics['attendanceRate'] ?? 0).toStringAsFixed(1)}%',
                Icons.calendar_today,
                Colors.blue,
              ),
              _buildStatCard(
                'Total Hours',
                '${(_statistics['totalHours'] ?? 0).toStringAsFixed(1)}',
                'Avg: ${(_statistics['avgHours'] ?? 0).toStringAsFixed(1)}h',
                Icons.access_time,
                Colors.green,
              ),
              _buildStatCard(
                'Late Arrivals',
                '${_statistics['lateArrivals'] ?? 0}',
                '${(_statistics['totalLateHours'] ?? 0).toStringAsFixed(1)}h late',
                Icons.warning,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    final punctuality = _statistics['punctualityRate'] ?? 0.0;
    final avgHours = _statistics['avgHours'] ?? 0.0;

    final avgBreak = _statistics['avgBreak'] ?? 0.0;

    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInsightItem(
              Icons.check_circle,
              'You were on time ${punctuality.toStringAsFixed(0)}% of the days',
              Colors.green,
            ),
            _buildInsightItem(
              Icons.schedule,
              'Your average work duration is ${avgHours.toStringAsFixed(1)} hours',
              Colors.blue,
            ),

            if (avgBreak > 0)
              _buildInsightItem(
                Icons.coffee,
                'Average break time: ${avgBreak.toStringAsFixed(0)} minutes',
                Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(IconData icon, String text, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, _records.length);
    final pageRecords = _records.sublist(startIndex, endIndex);

    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Detailed Records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Day',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Login',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Hours',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Break',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: pageRecords.map((record) {
                return DataRow(
                  cells: [
                    DataCell(Text(record.date)),
                    DataCell(Text(record.day)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(record.inTime ?? '—'),
                          if (record.lateHrs > 0)
                            Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.warning,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                    DataCell(Text(record.outTime ?? '—')),
                    DataCell(Text('${record.totHrs.toStringAsFixed(1)}')),
                    DataCell(Text(record.totalBreakTime ?? '00:00')),

                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(record.type1).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          record.type1,
                          style: TextStyle(
                            color: _getStatusColor(record.type1),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${startIndex + 1}-$endIndex of ${_records.length}',
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text('${_currentPage + 1}'),
                    IconButton(
                      icon: Icon(Icons.chevron_right),
                      onPressed: endIndex < _records.length
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 100, color: Colors.grey[300]),
            SizedBox(height: 24),
            Text(
              'No Records Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(color: Colors.grey[500]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetFilters,
              icon: Icon(Icons.refresh),
              label: Text('Reset Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DP':
        return Colors.green;
      case 'HD':
        return Colors.orange;
      case 'ABS':
        return Colors.red;
      case 'WO':
      case 'WOP':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _resetFilters() {
    setState(() {
      _setDefaultDateRange();
      _statusFilters = {'All'};
      _showLateOnly = false;
      _showOvertimeOnly = false;

      _sortBy = 'date_desc';
    });
    _loadReport();
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Report',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text('Export as PDF'),
              subtitle: Text('Formatted report with charts'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPdf();
              },
            ),
            ListTile(
              leading: Icon(Icons.table_chart, color: Colors.green),
              title: Text('Export as CSV'),
              subtitle: Text('Spreadsheet format'),
              onTap: () {
                Navigator.pop(context);
                _exportAsCsv();
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.blue),
              title: Text('Share Report'),
              subtitle: Text('Share via other apps'),
              onTap: () {
                Navigator.pop(context);
                _shareReport();
              },
            ),
            ListTile(
              leading: Icon(Icons.print, color: Colors.orange),
              title: Text('Print Report'),
              subtitle: Text('Print directly'),
              onTap: () {
                Navigator.pop(context);
                _printReport();
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.red),
              title: Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Attendance Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Employee: $_userName | ID: $_empId',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Period: ${DateFormat('dd MMM yyyy').format(_dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Summary Statistics',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Metric',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Value',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  _buildPdfTableRow(
                    'Total Days',
                    '${_statistics['totalDays']}',
                  ),
                  _buildPdfTableRow(
                    'Working Days',
                    '${_statistics['workingDays']}',
                  ),
                  _buildPdfTableRow(
                    'Present Days',
                    '${_statistics['presentDays']}',
                  ),
                  _buildPdfTableRow('Half Days', '${_statistics['halfDays']}'),
                  _buildPdfTableRow(
                    'Absent Days',
                    '${_statistics['absentDays']}',
                  ),
                  _buildPdfTableRow(
                    'Total Hours',
                    '${(_statistics['totalHours'] ?? 0).toStringAsFixed(2)}',
                  ),
                  _buildPdfTableRow(
                    'Average Hours/Day',
                    '${(_statistics['avgHours'] ?? 0).toStringAsFixed(2)}',
                  ),
                  _buildPdfTableRow(
                    'Late Arrivals',
                    '${_statistics['lateArrivals']}',
                  ),
                  _buildPdfTableRow(
                    'Total Late Hours',
                    '${(_statistics['totalLateHours'] ?? 0).toStringAsFixed(2)}',
                  ),
                  _buildPdfTableRow(
                    'Punctuality Rate',
                    '${(_statistics['punctualityRate'] ?? 0).toStringAsFixed(1)}%',
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Detailed Records',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1.5),
                  6: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Date',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Login',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Logout',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Hours',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Late',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),

                      pw.Padding(
                        padding: pw.EdgeInsets.all(4),
                        child: pw.Text(
                          'Status',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ..._records.map((record) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            record.date,
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            record.inTime ?? '—',
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            record.outTime ?? '—',
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            '${record.totHrs.toStringAsFixed(1)}',
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            '${record.lateHrs.toStringAsFixed(1)}',
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),

                        pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text(
                            record.type1,
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/attendance_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'attendance_report_$_userName.pdf',
      );

      _showSuccess('PDF generated successfully');
    } catch (e) {
      _showError('Failed to generate PDF: $e');
    }
  }

  pw.TableRow _buildPdfTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 10)),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  Future<void> _exportAsCsv() async {
    try {
      final csv = _generateCsv();
      await Clipboard.setData(ClipboardData(text: csv));
      _showSuccess('CSV copied to clipboard (${_records.length} records)');
    } catch (e) {
      _showError('Failed to export CSV: $e');
    }
  }

  String _generateCsv() {
    final headers = [
      'Date',
      'Day',
      'Employee Name',
      'Employee ID',
      'Login Time',
      'Logout Time',
      'Total Hours',
      'Late Hours',
      'OT Hours',
      'Break Time',

      'Status',
    ];

    final sb = StringBuffer();
    sb.writeln(headers.join(','));

    for (final record in _records) {
      final row = [
        '"${record.date}"',
        '"${record.day}"',
        '"$_userName"',
        '"$_empId"',
        '"${record.inTime ?? ''}"',
        '"${record.outTime ?? ''}"',
        '${record.totHrs.toStringAsFixed(2)}',
        '${record.lateHrs.toStringAsFixed(2)}',
        '${record.otHrs.toStringAsFixed(2)}',
        '"${record.totalBreakTime ?? ''}"',

        '"${record.type1}"',
      ];
      sb.writeln(row.join(','));
    }

    return sb.toString();
  }

  Future<void> _shareReport() async {
    try {
      final csv = _generateCsv();
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/attendance_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject:
            'Attendance Report - ${DateFormat('dd MMM yyyy').format(_dateRange!.start)} to ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
        text: 'Please find attached attendance report for $_userName.',
      );
    } catch (e) {
      _showError('Failed to share report: $e');
    }
  }

  Future<void> _printReport() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Attendance Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Employee: $_userName | ID: $_empId',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Period: ${DateFormat('dd MMM yyyy').format(_dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Summary Statistics',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Metric',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Value',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  _buildPdfTableRow(
                    'Working Days',
                    '${_statistics['workingDays']}',
                  ),
                  _buildPdfTableRow(
                    'Total Hours',
                    '${(_statistics['totalHours'] ?? 0).toStringAsFixed(2)}',
                  ),
                  _buildPdfTableRow(
                    'Average Hours',
                    '${(_statistics['avgHours'] ?? 0).toStringAsFixed(2)}',
                  ),
                  _buildPdfTableRow(
                    'Late Arrivals',
                    '${_statistics['lateArrivals']}',
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showError('Failed to print report: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
