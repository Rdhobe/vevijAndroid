import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class AdminVisitReportsPage extends StatefulWidget {
  const AdminVisitReportsPage({super.key});

  @override
  State<AdminVisitReportsPage> createState() => _AdminVisitReportsPageState();
}

class _AdminVisitReportsPageState extends State<AdminVisitReportsPage> {
  String selectedPeriod = 'This Month';
  String selectedSupervisor = 'All';
  String selectedSite = 'All';
  DateTime? customStartDate;
  DateTime? customEndDate;
  bool isGeneratingReport = false;
  bool showFilters = true;
  
  List<String> supervisors = ['All'];
  final List<String> sites = [];

  final List<String> periods = [
    'Today',
    'This Week',
    'This Month', 
    'Last Month',
    'Last 3 Months',
    'Custom Range'
  ];

  @override
  void initState() {
    super.initState();
    _fetchSites();
    _loadSupervisors();
  }

  void _fetchSites() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .orderBy('createdAt', descending: true)
          .get();
      if (mounted) {
        setState(() {
          sites.clear();
          sites.add('All');
          for (var doc in snapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;
            sites.add(data['name'] ?? 'Unnamed Site');
          }
        });
      }
    } catch (e) {
      print('Error fetching sites: $e');
    }
  }

  Future<void> _loadSupervisors() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('designation', isEqualTo: 'Supervisor')
          .get();
      
      setState(() {
        supervisors = ['All', 'Group Export'];
        supervisors.addAll(
          snapshot.docs.map((doc) => (doc.data() as Map<String, dynamic>)['empName'] ?? 'Unknown')
        );
      });
    } catch (e) {
      print('Error loading supervisors: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 600 && size.width <= 1024;
    final isMobile = size.width <= 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Visit Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (isDesktop || isTablet)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: isGeneratingReport ? null : _generateExcelReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigo,
                  elevation: 0,
                ),
                icon: Icon(Icons.download, size: 20),
                label: Text('Export'),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.download),
              onPressed: isGeneratingReport ? null : _generateExcelReport,
              tooltip: 'Export to Excel',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            child: _buildFilterSection(isDesktop, isTablet, isMobile),
          ),

          // Summary Cards
          _buildResponsiveSummarySection(isDesktop, isTablet, isMobile),

          // Visits List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getAllVisits(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var visits = _applyFilters(snapshot.data!);

                if (visits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text(
                          'No visit reports found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                visits.sort((a, b) {
                  var aTime = a['timestamp'] as Timestamp?;
                  var bTime = b['timestamp'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: EdgeInsets.all(isDesktop ? 24 : 16),
                  itemCount: visits.length,
                  itemBuilder: (context, index) {
                    return _buildResponsiveVisitCard(visits[index], isDesktop, isTablet);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Filter Toggle Header
          InkWell(
            onTap: () => setState(() => showFilters = !showFilters),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.indigo, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    showFilters ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          
          // Filter Content
          AnimatedCrossFade(
            firstChild: Container(),
            secondChild: Container(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 16,
                0,
                isDesktop ? 24 : 16,
                16,
              ),
              child: isDesktop 
                  ? _buildDesktopFilters()
                  : _buildMobileFilters(isMobile),
            ),
            crossFadeState: showFilters 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildDropdown(
                value: selectedPeriod,
                label: 'Period',
                items: periods,
                onChanged: (value) {
                  setState(() {
                    selectedPeriod = value!;
                    if (selectedPeriod != 'Custom Range') {
                      customStartDate = null;
                      customEndDate = null;
                    }
                  });
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildDropdown(
                value: selectedSite,
                label: 'Site',
                items: sites,
                onChanged: (value) => setState(() => selectedSite = value!),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isGeneratingReport ? null : _generateExcelReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: isGeneratingReport 
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.file_download, size: 20),
                  label: Text(
                    isGeneratingReport ? 'Generating...' : 'Generate Report',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (selectedPeriod == 'Custom Range') ...[
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDateSelector('From Date', customStartDate, _selectStartDate)),
              SizedBox(width: 16),
              Expanded(child: _buildDateSelector('To Date', customEndDate, _selectEndDate)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMobileFilters(bool isMobile) {
    return Column(
      children: [
        _buildDropdown(
          value: selectedPeriod,
          label: 'Period',
          items: periods,
          onChanged: (value) {
            setState(() {
              selectedPeriod = value!;
              if (selectedPeriod != 'Custom Range') {
                customStartDate = null;
                customEndDate = null;
              }
            });
          },
        ),
        SizedBox(height: 12),
        _buildDropdown(
          value: selectedSite,
          label: 'Site',
          items: sites,
          onChanged: (value) => setState(() => selectedSite = value!),
        ),
        if (selectedPeriod == 'Custom Range') ...[
          SizedBox(height: 12),
          _buildDateSelector('From Date', customStartDate, _selectStartDate),
          SizedBox(height: 12),
          _buildDateSelector('To Date', customEndDate, _selectEndDate),
        ],
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: isGeneratingReport ? null : _generateExcelReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: isGeneratingReport 
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.file_download, size: 20),
            label: Text(
              isGeneratingReport ? 'Generating...' : 'Generate Report',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.indigo, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.calendar_today, color: Colors.indigo, size: 20),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Text(
          date != null 
              ? DateFormat('dd/MM/yyyy').format(date)
              : 'Select date',
          style: TextStyle(
            color: date != null ? Colors.black87 : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveSummarySection(bool isDesktop, bool isTablet, bool isMobile) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllVisits(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        var visits = _applyFilters(snapshot.data!);

        int totalVisits = visits.length;
        Map<String, List<Map<String, dynamic>>> visitsBySupervisor = {};
        for (var visit in visits) {
          String supervisor = visit['supervisorName'] ?? 'Unknown';
          if (!visitsBySupervisor.containsKey(supervisor)) {
            visitsBySupervisor[supervisor] = [];
          }
          visitsBySupervisor[supervisor]!.add(visit);
        }

        int totalManpower = visits.fold(0, (acc, visit) => acc + (visit['manpower'] as int? ?? 0));
        int totalDoorsTarget = visits.fold(0, (acc, visit) => acc + (visit['doors']['target'] as int? ?? 0));
        int totalDoorsAchieved = visits.fold(0, (acc, visit) => acc + (visit['doors']['achieved'] as int? ?? 0));
        
        double avgEfficiency = totalVisits > 0 
            ? visits.fold(0.0, (sacc, visit) => sacc + _calculateEfficiency(visit)) / totalVisits 
            : 0.0;

        if (isDesktop) {
          return Container(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(child: _buildSummaryCard('Total Visits', totalVisits.toString(), Colors.blue, Icons.location_on)),
                SizedBox(width: 16),
                Expanded(child: _buildSummaryCard('Supervisors', visitsBySupervisor.length.toString(), Colors.purple, Icons.people)),
                SizedBox(width: 16),
                Expanded(child: _buildSummaryCard('Total Manpower', totalManpower.toString(), Colors.orange, Icons.groups)),
                SizedBox(width: 16),
                Expanded(child: _buildSummaryCard('Doors', '$totalDoorsAchieved/$totalDoorsTarget', Colors.teal, Icons.door_front_door)),
                SizedBox(width: 16),
                Expanded(child: _buildSummaryCard('Avg Efficiency', '${avgEfficiency.toStringAsFixed(0)}%', Colors.green, Icons.trending_up)),
              ],
            ),
          );
        } else if (isTablet) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Total Visits', totalVisits.toString(), Colors.blue, Icons.location_on)),
                    SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Supervisors', visitsBySupervisor.length.toString(), Colors.purple, Icons.people)),
                    SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Avg Efficiency', '${avgEfficiency.toStringAsFixed(0)}%', Colors.green, Icons.trending_up)),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Total Manpower', totalManpower.toString(), Colors.orange, Icons.groups)),
                    SizedBox(width: 12),
                    Expanded(child: _buildSummaryCard('Doors', '$totalDoorsAchieved/$totalDoorsTarget', Colors.teal, Icons.door_front_door)),
                  ],
                ),
              ],
            ),
          );
        } else {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard('Visits', totalVisits.toString(), Colors.blue, Icons.location_on)),
                    SizedBox(width: 8),
                    Expanded(child: _buildSummaryCard('Efficiency', '${avgEfficiency.toStringAsFixed(0)}%', Colors.green, Icons.trending_up)),
                    Expanded(child: _buildSummaryCard('Manpower', totalManpower.toString(), Colors.orange, Icons.groups)),
                    SizedBox(width: 8),
                    Expanded(child: _buildSummaryCard('Doors', '$totalDoorsAchieved/$totalDoorsTarget', Colors.teal, Icons.door_front_door)),
                  ],
                ),
                
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveVisitCard(Map<String, dynamic> visit, bool isDesktop, bool isTablet) {
    double efficiency = _calculateEfficiency(visit);
    Color efficiencyColor = efficiency >= 80 
        ? Colors.green 
        : efficiency >= 60 
            ? Colors.orange 
            : Colors.red;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo,
                  radius: isDesktop ? 24 : 20,
                  child: Text(
                    (visit['supervisorName'] as String).substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 18 : 16,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visit['supervisorName'],
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        visit['site'],
                        style: TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.w500,
                          fontSize: isDesktop ? 14 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: efficiencyColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${efficiency.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Info Grid
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.calendar_today, visit['date'], Colors.blue),
                _buildInfoChip(Icons.access_time, visit['time'], Colors.orange),
                _buildInfoChip(Icons.groups, 'Manpower: ${visit['manpower']}', Colors.green),
              ],
            ),
            
            SizedBox(height: 16),
            
            Text(
              'Project: ${visit['project']}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Progress Section
            if (isDesktop || isTablet)
              Row(
                children: [
                  Expanded(
                    child: _buildProgressItem(
                      'Doors',
                      visit['doors']['achieved'] ?? 0,
                      visit['doors']['target'] ?? 0,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 24),
                  Expanded(
                    child: _buildProgressItem(
                      'Architrave',
                      visit['architrave']['achieved'] ?? 0,
                      visit['architrave']['target'] ?? 0,
                      Colors.green,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildProgressItem(
                    'Doors',
                    visit['doors']['achieved'] ?? 0,
                    visit['doors']['target'] ?? 0,
                    Colors.blue,
                  ),
                  SizedBox(height: 12),
                  _buildProgressItem(
                    'Architrave',
                    visit['architrave']['achieved'] ?? 0,
                    visit['architrave']['target'] ?? 0,
                    Colors.green,
                  ),
                ],
              ),
            
            if (visit['remarks'] != null && (visit['remarks'] as String).isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: flutter.Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          'Remarks',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      visit['remarks'],
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: 12),
            
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${visit['location']['latitude'].toStringAsFixed(4)}, ${visit['location']['longitude'].toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _getTimeAgo(visit['timestamp'] as Timestamp?),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: flutter.Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, int achieved, int target, Color color) {
    double percentage = target > 0 ? (achieved / target) * 100 : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
            Text(
              '$achieved / $target',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Keep all existing methods (_selectStartDate, _selectEndDate, _generateExcelReport, etc.)
  // [Previous implementation methods remain the same]

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: customStartDate ?? DateTime.now().subtract(Duration(days: 30)),
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        customStartDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: customEndDate ?? DateTime.now(),
      firstDate: customStartDate ?? DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        customEndDate = picked;
      });
    }
  }

  Future<void> _generateExcelReport() async {
    if (selectedPeriod == 'Custom Range' && (customStartDate == null || customEndDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select both start and end dates for custom range')),
      );
      return;
    }

    setState(() {
      isGeneratingReport = true;
    });

    try {
      var allVisits = await _getAllVisits();
      var filteredVisits = _applyFilters(allVisits);

      if (filteredVisits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No data available for the selected filters')),
        );
        return;
      }

      if (selectedSupervisor == 'Group Export') {
        await _generateGroupReport(filteredVisits);
      } else {
        await _generateSingleReport(filteredVisits);
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isGeneratingReport = false;
      });
    }
  }

  Future<void> _generateSingleReport(List<Map<String, dynamic>> visits) async {
    visits.sort((a, b) {
      var aTime = a['timestamp'] as Timestamp?;
      var bTime = b['timestamp'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    var excel = Excel.createExcel();
    Sheet sheet = excel['Visit Reports'];

    List<String> headers = [
      'Date', 'Time', 'Supervisor', 'Site', 'Project', 'Manpower',
      'Doors Target', 'Doors Achieved', 'Doors %',
      'Architrave Target', 'Architrave Achieved', 'Architrave %',
      'Overall Efficiency %', 'Remarks', 'Location'
    ];

    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4F46E5'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    for (int i = 0; i < visits.length; i++) {
      var visit = visits[i];
      var rowIndex = i + 1;
      
      var doorsTarget = visit['doors']['target'] ?? 0;
      var doorsAchieved = visit['doors']['achieved'] ?? 0;
      var doorsPercentage = doorsTarget > 0 ? (doorsAchieved / doorsTarget * 100) : 0;
      
      var architraveTarget = visit['architrave']['target'] ?? 0;
      var architraveAchieved = visit['architrave']['achieved'] ?? 0;
      var architravePercentage = architraveTarget > 0 ? (architraveAchieved / architraveTarget * 100) : 0;
      
      var efficiency = _calculateEfficiency(visit);

      List<CellValue> rowData = [
        TextCellValue(visit['date']?.toString() ?? ''),
        TextCellValue(visit['time']?.toString() ?? ''),
        TextCellValue(visit['supervisorName']?.toString() ?? ''),
        TextCellValue(visit['site']?.toString() ?? ''),
        TextCellValue(visit['project']?.toString() ?? ''),
        IntCellValue(visit['manpower'] ?? 0),
        IntCellValue(doorsTarget),
        IntCellValue(doorsAchieved),
        TextCellValue('${doorsPercentage.toStringAsFixed(1)}%'),
        IntCellValue(architraveTarget),
        IntCellValue(architraveAchieved),
        TextCellValue('${architravePercentage.toStringAsFixed(1)}%'),
        TextCellValue('${efficiency.toStringAsFixed(1)}%'),
        TextCellValue(visit['remarks']?.toString() ?? ''),
        TextCellValue('${visit['location']['latitude'].toStringAsFixed(6)}, ${visit['location']['longitude'].toStringAsFixed(6)}'),
      ];

      for (int j = 0; j < rowData.length; j++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
        cell.value = rowData[j];
        
        if (j == 12) {
          if (efficiency >= 80) {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#10B981'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
          } else if (efficiency >= 60) {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F59E0B'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
          } else {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#EF4444'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
          }
        }
      }
    }

    await _addSummaryToSheet(sheet, visits, visits.length + 3);
    await _saveAndShareExcel(excel, 'Visit_Report_${_getFileNameSuffix()}.xlsx');
  }

  Future<void> _generateGroupReport(List<Map<String, dynamic>> visits) async {
    var excel = Excel.createExcel();
    
    Map<String, List<Map<String, dynamic>>> visitsBySupervisor = {};
    for (var visit in visits) {
      String supervisor = visit['supervisorName'] ?? 'Unknown';
      if (!visitsBySupervisor.containsKey(supervisor)) {
        visitsBySupervisor[supervisor] = [];
      }
      visitsBySupervisor[supervisor]!.add(visit);
    }

    Sheet summarySheet = excel['Summary'];
    await _createSummarySheet(summarySheet, visitsBySupervisor);

    for (var entry in visitsBySupervisor.entries) {
      String supervisorName = entry.key.replaceAll(RegExp(r'[^\w\s]'), '');
      if (supervisorName.length > 25) supervisorName = supervisorName.substring(0, 25);
      
      Sheet supervisorSheet = excel[supervisorName];
      await _createSupervisorSheet(supervisorSheet, entry.value, entry.key);
    }

    excel.delete('Sheet1');
    await _saveAndShareExcel(excel, 'Group_Visit_Report_${_getFileNameSuffix()}.xlsx');
  }

  Future<void> _createSummarySheet(Sheet sheet, Map<String, List<Map<String, dynamic>>> visitsBySupervisor) async {
    var titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('VISIT REPORTS SUMMARY');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 16, backgroundColorHex: ExcelColor.fromHexString('#4F46E5'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('Period: ${_getPeriodText()}');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');

    List<String> summaryHeaders = [
      'Supervisor', 'Total Visits', 'Avg Manpower', 'Doors Target', 'Doors Achieved',
      'Architrave Target', 'Architrave Achieved', 'Avg Efficiency %'
    ];

    int headerRow = 4;
    for (int i = 0; i < summaryHeaders.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow));
      cell.value = TextCellValue(summaryHeaders[i]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#E5E7EB'));
    }

    int dataRow = headerRow + 1;
    int grandTotalVisits = 0;
    int grandTotalManpower = 0;
    int grandTotalDoorsTarget = 0;
    int grandTotalDoorsAchieved = 0;
    int grandTotalArchitraveTarget = 0;
    int grandTotalArchitraveAchieved = 0;
    double grandTotalEfficiency = 0;

    for (var entry in visitsBySupervisor.entries) {
      var visits = entry.value;
      var totalVisits = visits.length;
      var totalManpower = visits.fold(0, (acc, visit) => acc + (visit['manpower'] as int? ?? 0));
      var totalDoorsTarget = visits.fold(0, (acc, visit) => acc + (visit['doors']['target'] as int? ?? 0));
      var totalDoorsAchieved = visits.fold(0, (acc, visit) => acc + (visit['doors']['achieved'] as int? ?? 0));
      var totalArchitraveTarget = visits.fold(0, (acc, visit) => acc + (visit['architrave']['target'] as int? ?? 0));
      var totalArchitraveAchieved = visits.fold(0, (acc, visit) => acc + (visit['architrave']['achieved'] as int? ?? 0));
      var avgEfficiency = totalVisits > 0 ? visits.fold(0.0, (acc, visit) => acc + _calculateEfficiency(visit)) / totalVisits : 0.0;

      grandTotalVisits += totalVisits;
      grandTotalManpower += totalManpower;
      grandTotalDoorsTarget += totalDoorsTarget;
      grandTotalDoorsAchieved += totalDoorsAchieved;
      grandTotalArchitraveTarget += totalArchitraveTarget;
      grandTotalArchitraveAchieved += totalArchitraveAchieved;
      grandTotalEfficiency += avgEfficiency;

      List<CellValue> rowData = [
        TextCellValue(entry.key),
        IntCellValue(totalVisits),
        TextCellValue(totalVisits > 0 ? (totalManpower / totalVisits).toStringAsFixed(1) : '0'),
        IntCellValue(totalDoorsTarget),
        IntCellValue(totalDoorsAchieved),
        IntCellValue(totalArchitraveTarget),
        IntCellValue(totalArchitraveAchieved),
        TextCellValue('${avgEfficiency.toStringAsFixed(1)}%'),
      ];

      for (int i = 0; i < rowData.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataRow)).value = rowData[i];
      }
      dataRow++;
    }

    dataRow++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: dataRow)).value = TextCellValue('GRAND TOTAL');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: dataRow)).cellStyle = CellStyle(bold: true);
    
    List<CellValue> totalRowData = [
      TextCellValue(''),
      IntCellValue(grandTotalVisits),
      TextCellValue(grandTotalVisits > 0 ? (grandTotalManpower / grandTotalVisits).toStringAsFixed(1) : '0'),
      IntCellValue(grandTotalDoorsTarget),
      IntCellValue(grandTotalDoorsAchieved),
      IntCellValue(grandTotalArchitraveTarget),
      IntCellValue(grandTotalArchitraveAchieved),
      TextCellValue(visitsBySupervisor.isNotEmpty ? '${(grandTotalEfficiency / visitsBySupervisor.length).toStringAsFixed(1)}%' : '0%'),
    ];

    for (int i = 1; i < totalRowData.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataRow));
      cell.value = totalRowData[i];
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'));
    }
  }

  Future<void> _createSupervisorSheet(Sheet sheet, List<Map<String, dynamic>> visits, String supervisorName) async {
    visits.sort((a, b) {
      var aTime = a['timestamp'] as Timestamp?;
      var bTime = b['timestamp'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    var titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('VISIT REPORTS - $supervisorName');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 14, backgroundColorHex: ExcelColor.fromHexString('#4F46E5'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));

    List<String> headers = [
      'Date', 'Time', 'Site', 'Project', 'Manpower',
      'Doors Target', 'Doors Achieved', 'Doors %',
      'Architrave Target', 'Architrave Achieved', 'Architrave %',
      'Overall Efficiency %', 'Remarks'
    ];

    int headerRow = 2;
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#E5E7EB'));
    }

    for (int i = 0; i < visits.length; i++) {
      var visit = visits[i];
      var rowIndex = headerRow + 1 + i;
      
      var doorsTarget = visit['doors']['target'] ?? 0;
      var doorsAchieved = visit['doors']['achieved'] ?? 0;
      var doorsPercentage = doorsTarget > 0 ? (doorsAchieved / doorsTarget * 100) : 0;
      
      var architraveTarget = visit['architrave']['target'] ?? 0;
      var architraveAchieved = visit['architrave']['achieved'] ?? 0;
      var architravePercentage = architraveTarget > 0 ? (architraveAchieved / architraveTarget * 100) : 0;
      
      var efficiency = _calculateEfficiency(visit);

      List<CellValue> rowData = [
        TextCellValue(visit['date']?.toString() ?? ''),
        TextCellValue(visit['time']?.toString() ?? ''),
        TextCellValue(visit['site']?.toString() ?? ''),
        TextCellValue(visit['project']?.toString() ?? ''),
        IntCellValue(visit['manpower'] ?? 0),
        IntCellValue(doorsTarget),
        IntCellValue(doorsAchieved),
        TextCellValue('${doorsPercentage.toStringAsFixed(1)}%'),
        IntCellValue(architraveTarget),
        IntCellValue(architraveAchieved),
        TextCellValue('${architravePercentage.toStringAsFixed(1)}%'),
        TextCellValue('${efficiency.toStringAsFixed(1)}%'),
        TextCellValue(visit['remarks']?.toString() ?? ''),
      ];

      for (int j = 0; j < rowData.length; j++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex));
        cell.value = rowData[j];
        
        if (j == 11) {
          if (efficiency >= 80) {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#10B981'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
          } else if (efficiency >= 60) {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F59E0B'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
          } else {
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#EF4444'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
          }
        }
      }
    }

    await _addSummaryToSheet(sheet, visits, visits.length + headerRow + 3);
  }

  Future<void> _addSummaryToSheet(Sheet sheet, List<Map<String, dynamic>> visits, int startRow) async {
    var summaryTitleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow));
    summaryTitleCell.value = TextCellValue('SUMMARY STATISTICS');
    summaryTitleCell.cellStyle = CellStyle(bold: true, fontSize: 14, backgroundColorHex: ExcelColor.fromHexString('#4F46E5'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));

    var totalVisits = visits.length;
    var totalManpower = visits.fold(0, (acc, visit) => acc + (visit['manpower'] as int? ?? 0));
    var totalDoorsTarget = visits.fold(0, (acc, visit) => acc + (visit['doors']['target'] as int? ?? 0));
    var totalDoorsAchieved = visits.fold(0, (acc, visit) => acc + (visit['doors']['achieved'] as int? ?? 0));
    var totalArchitraveTarget = visits.fold(0, (acc, visit) => acc + (visit['architrave']['target'] as int? ?? 0));
    var totalArchitraveAchieved = visits.fold(0, (acc, visit) => acc + (visit['architrave']['achieved'] as int? ?? 0));
    var avgEfficiency = totalVisits > 0 ? visits.fold(0.0, (acc, visit) => acc + _calculateEfficiency(visit)) / totalVisits : 0.0;

    Map<String, int> siteVisits = {};
    for (var visit in visits) {
      String site = visit['site'] ?? 'Unknown';
      siteVisits[site] = (siteVisits[site] ?? 0) + 1;
    }

    List<List<CellValue>> summaryData = [
      [TextCellValue(''), TextCellValue('')],
      [TextCellValue('Total Visits:'), IntCellValue(totalVisits)],
      [TextCellValue('Total Manpower:'), IntCellValue(totalManpower)],
      [TextCellValue('Average Manpower per Visit:'), TextCellValue(totalVisits > 0 ? (totalManpower / totalVisits).toStringAsFixed(1) : '0')],
      [TextCellValue(''), TextCellValue('')],
      [TextCellValue('Doors - Total Target:'), IntCellValue(totalDoorsTarget)],
      [TextCellValue('Doors - Total Achieved:'), IntCellValue(totalDoorsAchieved)],
      [TextCellValue('Doors - Achievement Rate:'), TextCellValue(totalDoorsTarget > 0 ? '${(totalDoorsAchieved / totalDoorsTarget * 100).toStringAsFixed(1)}%' : '0%')],
      [TextCellValue(''), TextCellValue('')],
      [TextCellValue('Architrave - Total Target:'), IntCellValue(totalArchitraveTarget)],
      [TextCellValue('Architrave - Total Achieved:'), IntCellValue(totalArchitraveAchieved)],
      [TextCellValue('Architrave - Achievement Rate:'), TextCellValue(totalArchitraveTarget > 0 ? '${(totalArchitraveAchieved / totalArchitraveTarget * 100).toStringAsFixed(1)}%' : '0%')],
      [TextCellValue(''), TextCellValue('')],
      [TextCellValue('Overall Average Efficiency:'), TextCellValue('${avgEfficiency.toStringAsFixed(1)}%')],
      [TextCellValue(''), TextCellValue('')],
      [TextCellValue('SITE-WISE BREAKDOWN:'), TextCellValue('')],
    ];

    for (var entry in siteVisits.entries) {
      summaryData.add([TextCellValue(entry.key), IntCellValue(entry.value)]);
    }

    summaryData.addAll([
      [TextCellValue(''), TextCellValue('')],
      [TextCellValue('PERFORMANCE ANALYSIS:'), TextCellValue('')],
      [TextCellValue('High Performance (≥80%):'), IntCellValue(visits.where((v) => _calculateEfficiency(v) >= 80).length)],
      [TextCellValue('Medium Performance (60-79%):'), IntCellValue(visits.where((v) => _calculateEfficiency(v) >= 60 && _calculateEfficiency(v) < 80).length)],
      [TextCellValue('Needs Improvement (<60%):'), IntCellValue(visits.where((v) => _calculateEfficiency(v) < 60).length)],
    ]);

    for (int i = 0; i < summaryData.length; i++) {
      var rowIndex = startRow + 1 + i;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = summaryData[i][0];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = summaryData[i][1];
      
      var firstCellText = summaryData[i][0].toString();
      if (firstCellText.endsWith(':') && firstCellText != '') {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = CellStyle(bold: true);
      }
    }
  }

  Future<void> _saveAndShareExcel(Excel excel, String fileName) async {
    var directory = await getApplicationDocumentsDirectory();
    var filePath = '${directory.path}/$fileName';
    
    List<int>? fileBytes = excel.save();
    if (fileBytes != null) {
      File file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      await Share.shareXFiles([XFile(filePath)], text: 'Visit Report for ${_getPeriodText()}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report generated and ready to share!'), backgroundColor: Colors.green),
      );
    }
  }

  String _getPeriodText() {
    if (selectedPeriod == 'Custom Range') {
      if (customStartDate != null && customEndDate != null) {
        return '${DateFormat('dd/MM/yyyy').format(customStartDate!)} to ${DateFormat('dd/MM/yyyy').format(customEndDate!)}';
      }
      return 'Custom Range';
    }
    return selectedPeriod;
  }

  String _getFileNameSuffix() {
    var period = selectedPeriod.replaceAll(' ', '_');
    var supervisor = selectedSupervisor == 'All' ? 'All_Supervisors' : selectedSupervisor.replaceAll(' ', '_');
    var site = selectedSite == 'All' ? 'All_Sites' : selectedSite.replaceAll(' ', '_');
    var timestamp = DateFormat('ddMMyyyy_HHmm').format(DateTime.now());
    
    return '${period}_${supervisor}_${site}_$timestamp';
  }

  Future<List<Map<String, dynamic>>> _getAllVisits() async {
    try {
      QuerySnapshot supervisorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('designation', isEqualTo: 'Supervisor')
          .get();

      List<Map<String, dynamic>> allVisits = [];

      for (var supervisorDoc in supervisorsSnapshot.docs) {
        var supervisorData = supervisorDoc.data() as Map<String, dynamic>;
        var supervisorId = supervisorDoc.id;
        var supervisorName = supervisorData['empName'] ?? 'Unknown';

        QuerySnapshot visitsSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(supervisorId)
            .collection('visits')
            .get();

        for (var visitDoc in visitsSnapshot.docs) {
          var visitData = visitDoc.data() as Map<String, dynamic>;
          visitData['supervisorId'] = supervisorId;
          visitData['supervisorName'] = supervisorName;
          visitData['visitId'] = visitDoc.id;
          allVisits.add(visitData);
        }
      }

      return allVisits;
    } catch (e) {
      print('Error getting all visits: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> visits) {
    return visits.where((visit) {
      if (selectedSupervisor != 'All' && selectedSupervisor != 'Group Export' && 
          visit['supervisorName'] != selectedSupervisor) {
        return false;
      }

      if (selectedSite != 'All' && visit['site'] != selectedSite) {
        return false;
      }

      if (selectedPeriod != 'All') {
        var visitTimestamp = visit['timestamp'] as Timestamp?;
        if (visitTimestamp != null) {
          var visitDate = visitTimestamp.toDate();
          var now = DateTime.now();
          
          switch (selectedPeriod) {
            case 'Today':
              var today = DateTime(now.year, now.month, now.day);
              if (visitDate.isBefore(today)) return false;
              break;
            case 'This Week':
              var weekStart = now.subtract(Duration(days: now.weekday - 1));
              if (visitDate.isBefore(weekStart)) return false;
              break;
            case 'This Month':
              var monthStart = DateTime(now.year, now.month, 1);
              if (visitDate.isBefore(monthStart)) return false;
              break;
            case 'Last Month':
              var lastMonthStart = DateTime(now.year, now.month - 1, 1);
              var lastMonthEnd = DateTime(now.year, now.month, 1);
              if (visitDate.isBefore(lastMonthStart) || visitDate.isAfter(lastMonthEnd)) return false;
              break;
            case 'Last 3 Months':
              var threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
              if (visitDate.isBefore(threeMonthsAgo)) return false;
              break;
            case 'Custom Range':
              if (customStartDate != null && customEndDate != null) {
                if (visitDate.isBefore(customStartDate!) || 
                    visitDate.isAfter(customEndDate!.add(Duration(days: 1)))) {
                  return false;
                }
              }
              break;
          }
        }
      }

      return true;
    }).toList();
  }

  double _calculateEfficiency(Map<String, dynamic> visit) {
    int doorsTarget = visit['doors']['target'] ?? 0;
    int doorsAchieved = visit['doors']['achieved'] ?? 0;
    int architraveTarget = visit['architrave']['target'] ?? 0;
    int architraveAchieved = visit['architrave']['achieved'] ?? 0;
    
    int totalTarget = doorsTarget + architraveTarget;
    int totalAchieved = doorsAchieved + architraveAchieved;
    
    if (totalTarget == 0) return 0;
    
    return (totalAchieved / totalTarget) * 100;
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    
    var now = DateTime.now();
    var visitTime = timestamp.toDate();
    var difference = now.difference(visitTime);
    
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