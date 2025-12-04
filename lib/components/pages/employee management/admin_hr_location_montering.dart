import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'adminlocationreport.dart';
import 'package:vevij/models/employee/employee_location_data.dart';

// Conditional imports
import 'package:vevij/components/widgets/mobile_map_widget.dart';

class HRLocationMonitorPage extends StatefulWidget {
  const HRLocationMonitorPage({super.key});

  @override
  State<HRLocationMonitorPage> createState() => _HRLocationMonitorPageState();
}

class _HRLocationMonitorPageState extends State<HRLocationMonitorPage> 
    with TickerProviderStateMixin {
  List<EmployeeLocationData> employees = [];
  bool isLoading = true;
  Timer? _refreshTimer;
  String selectedStatusFilter = 'All';
  String searchQuery = '';
  TabController? _mainTabController;
  TabController? _listTabController;
  
  // Animation controllers
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadEmployeesData();
    _startAutoRefresh();
  }

  void _initializeAnimations() {
    _mainTabController = TabController(length: 2, vsync: this);
    _listTabController = TabController(length: 4, vsync: this);
    
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController!,
      curve: Curves.easeInOut,
    ));
    
    _fadeController?.forward();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mainTabController?.dispose();
    _listTabController?.dispose();
    _fadeController?.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadEmployeesData();
      }
    });
  }

  Future<void> _loadEmployeesData() async {
    if (!mounted) return;
    
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('grade', isNotEqualTo: 'Owner')
          .orderBy('empName')
          .get();
      final filteredDocs = snapshot.docs.where(
        (doc) => doc['designation'] != 'Contractor',
      );
      List<EmployeeLocationData> loadedEmployees = [];
      
      for (var doc in filteredDocs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        String today = DateFormat('dd-MMM-yy').format(DateTime.now());
        QuerySnapshot attendanceQuery = await FirebaseFirestore.instance
            .collection('attendance')
            .where('userId', isEqualTo: doc.id)
            .where('date', isEqualTo: today)
            .limit(1)
            .get();
        
        Map<String, dynamic>? attendanceData;
        if (attendanceQuery.docs.isNotEmpty) {
          attendanceData = attendanceQuery.docs.first.data() as Map<String, dynamic>;
        }
        
        loadedEmployees.add(EmployeeLocationData.fromFirestore(doc.id, data, attendanceData));
      }

      if (mounted) {
        setState(() {
          employees = loadedEmployees;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showSnackBar('Error loading employee data: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<EmployeeLocationData> get workingEmployees => 
      employees.where((emp) => emp.workStatus == 'Working').toList();
  
  List<EmployeeLocationData> get onBreakEmployees => 
      employees.where((emp) => emp.workStatus == 'On Break').toList();
  
  List<EmployeeLocationData> get offlineEmployees => 
      employees.where((emp) => emp.workStatus == 'Offline').toList();

  Widget _buildMapView() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Employee Locations Map',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildMapLegend(),
            ],
          ),
        ),
        Expanded(
          child: isLoading 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading employee locations...'),
                  ],
                ),
              )
            : MapWidget(employees: employees),
        ),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMapStatCard('Working', workingEmployees.length, Colors.green),
              _buildMapStatCard('On Break', onBreakEmployees.length, Colors.orange),
              _buildMapStatCard('Offline', offlineEmployees.length, Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapLegend() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLegendItem(Colors.green, 'Working'),
          SizedBox(width: 8),
          _buildLegendItem(Colors.orange, 'Break'),
          SizedBox(width: 8),
          _buildLegendItem(Colors.red, 'Offline'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMapStatCard(String title, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
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

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total',
            employees.length.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Working',
            workingEmployees.length.toString(),
            Icons.work,
            Colors.green,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'On Break',
            onBreakEmployees.length.toString(),
            Icons.coffee,
            Colors.orange,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Offline',
            offlineEmployees.length.toString(),
            Icons.person_off,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or employee ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Filter by Status:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedStatusFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['All', 'Working', 'On Break', 'Offline']
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedStatusFilter = value!;
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                    });
                    _loadEmployeesData();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabView() {
    List<EmployeeLocationData> filteredList = employees;
    
    // Apply status filter
    if (selectedStatusFilter != 'All') {
      filteredList = filteredList.where((emp) => emp.workStatus == selectedStatusFilter).toList();
    }
    
    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filteredList = filteredList.where((emp) => 
        emp.empName.toLowerCase().contains(searchQuery.toLowerCase()) ||
        emp.empId.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }

    return Column(
      children: [
        TabBar(
          controller: _listTabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'All (${filteredList.length})'),
            Tab(text: 'Working (${workingEmployees.where((emp) => 
              (searchQuery.isEmpty || emp.empName.toLowerCase().contains(searchQuery.toLowerCase()) || emp.empId.toLowerCase().contains(searchQuery.toLowerCase()))
            ).length})'),
            Tab(text: 'On Break (${onBreakEmployees.where((emp) => 
              (searchQuery.isEmpty || emp.empName.toLowerCase().contains(searchQuery.toLowerCase()) || emp.empId.toLowerCase().contains(searchQuery.toLowerCase()))
            ).length})'),
            Tab(text: 'Offline (${offlineEmployees.where((emp) => 
              (searchQuery.isEmpty || emp.empName.toLowerCase().contains(searchQuery.toLowerCase()) || emp.empId.toLowerCase().contains(searchQuery.toLowerCase()))
            ).length})'),
          ],
        ),
        Container(
          height: 400,
          child: TabBarView(
            controller: _listTabController,
            children: [
              _buildEmployeeTabList(filteredList),
              _buildEmployeeTabList(workingEmployees.where((emp) => 
                (searchQuery.isEmpty || emp.empName.toLowerCase().contains(searchQuery.toLowerCase()) || emp.empId.toLowerCase().contains(searchQuery.toLowerCase()))
              ).toList()),
              _buildEmployeeTabList(onBreakEmployees.where((emp) => 
                (searchQuery.isEmpty || emp.empName.toLowerCase().contains(searchQuery.toLowerCase()) || emp.empId.toLowerCase().contains(searchQuery.toLowerCase()))
              ).toList()),
              _buildEmployeeTabList(offlineEmployees.where((emp) => 
                (searchQuery.isEmpty || emp.empName.toLowerCase().contains(searchQuery.toLowerCase()) || emp.empId.toLowerCase().contains(searchQuery.toLowerCase()))
              ).toList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeTabList(List<EmployeeLocationData> employeeList) {
    if (employeeList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No employees found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: employeeList.length,
      itemBuilder: (context, index) {
        return _buildEmployeeCard(employeeList[index]);
      },
    );
  }

  Widget _buildEmployeeCard(EmployeeLocationData employee) {
    Color statusColor = _getStatusColor(employee.workStatus);
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEmployeeDetails(employee),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    radius: 25,
                    child: Text(
                      employee.empName.isNotEmpty 
                          ? employee.empName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.empName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ID: ${employee.empId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        _buildStatusChip(employee.workStatus, statusColor),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (employee.lastLocationUpdate != null)
                        Text(
                          _formatTimestamp(employee.lastLocationUpdate!),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (employee.currentLocation != null)
                            IconButton(
                              icon: Icon(Icons.location_on, size: 20, color: Colors.blue),
                              onPressed: () => _openLocation(employee.currentLocation!),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                          IconButton(
                            icon: Icon(Icons.info_outline, size: 20, color: Colors.grey),
                            onPressed: () => _showEmployeeDetails(employee),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (employee.currentLocation != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          employee.currentLocation!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (employee.isCurrentlyWorking && employee.todayLoginTime != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildWorkTimeInfo(
                        'Login Time',
                        employee.todayLoginTime!,
                        Icons.login,
                        Colors.green,
                      ),
                    ),
                    SizedBox(width: 8),
                    if (employee.currentWorkDuration != null)
                      Expanded(
                        child: _buildWorkTimeInfo(
                          'Work Duration',
                          employee.currentWorkDuration!,
                          Icons.timer,
                          Colors.blue,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTimeInfo(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Working':
        return Colors.green;
      case 'On Break':
        return Colors.orange;
      case 'Offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    Duration difference = DateTime.now().difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    }
  }

  Future<void> _openLocation(String coordinates) async {
    try {
      List<String> coords = coordinates.split(', ');
      if (coords.length == 2) {
        double lat = double.parse(coords[0]);
        double lng = double.parse(coords[1]);
        
        String googleMapsUrl = 'https://www.google.com/maps?q=$lat,$lng';
        
        if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
          await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Could not open maps', Colors.red);
        }
      }
    } catch (e) {
      _showSnackBar('Invalid coordinates format', Colors.red);
    }
  }

  void _showEmployeeDetails(EmployeeLocationData employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getStatusColor(employee.workStatus).withOpacity(0.2),
              child: Text(
                employee.empName.isNotEmpty ? employee.empName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: _getStatusColor(employee.workStatus),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.empName),
                  Text(
                    'ID: ${employee.empId}',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Status', employee.workStatus, _getStatusColor(employee.workStatus)),
              if (employee.currentLocation != null)
                _buildDetailRow('Location', employee.currentLocation!, Colors.blue),
              if (employee.todayLoginTime != null)
                _buildDetailRow('Login Time', employee.todayLoginTime!, Colors.green),
              if (employee.currentWorkDuration != null)
                _buildDetailRow('Work Duration', employee.currentWorkDuration!, Colors.purple),
              if (employee.currentBreakDuration != null)
                _buildDetailRow('Break Duration', employee.currentBreakDuration!, Colors.orange),
              if (employee.lastLocationUpdate != null)
                _buildDetailRow('Last Update', _formatTimestamp(employee.lastLocationUpdate!), Colors.grey),
            ],
          ),
        ),
        actions: [
          if (employee.currentLocation != null)
            TextButton.icon(
              icon: Icon(Icons.map),
              label: Text('View on Map'),
              onPressed: () {
                Navigator.pop(context);
                _openLocation(employee.currentLocation!);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Location Monitor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 4,
        bottom: TabBar(
          controller: _mainTabController,
          tabs: [
            Tab(
              icon: Icon(Icons.list),
              text: 'Employee List',
            ),
            Tab(
              icon: Icon(Icons.map),
              text: 'Map View',
            ),
            
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _loadEmployeesData();
            },
          ),
          IconButton(
            icon: Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => AdminLocationMonitorPage(),
              ));
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation!,
        child: TabBarView(
          controller: _mainTabController,
          physics: NeverScrollableScrollPhysics(),
          children: [
            // Employee List Tab
            RefreshIndicator(
              onRefresh: _loadEmployeesData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Real-time Employee Monitoring',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Last updated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildStatsCards(),
                    SizedBox(height: 20),
                    _buildSearchAndFilter(),
                    SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: _buildTabView(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Map View Tab
            _buildMapView(),
          ],
        ),
      ),
    );
  }

}