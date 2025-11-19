import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class AdminLocationMonitorPage extends StatefulWidget {
  const AdminLocationMonitorPage({super.key});

  @override
  State<AdminLocationMonitorPage> createState() => _AdminLocationMonitorPageState();
}

class _AdminLocationMonitorPageState extends State<AdminLocationMonitorPage> 
    with SingleTickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  String? selectedUserId;
  String? selectedUserName;
  List<Map<String, dynamic>> employeesList = [];
  List<Map<String, dynamic>> employeesWithAttendance = [];
  List<Map<String, dynamic>> locationHistory = [];
  bool isLoading = false;
  bool isLoadingAttendance = false;
  String? selectedAttendanceId;
  
  int totalLocations = 0;
  Duration totalWorkDuration = Duration.zero;
  Duration totalBreakDuration = Duration.zero;
  String? loginTime;
  String? logoutTime;

  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    print('curretnt tab index $_currentTabIndex');
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _loadEmployees();
    _loadEmployeesWithAttendance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet => MediaQuery.of(context).size.width >= 600 && 
                       MediaQuery.of(context).size.width < 1024;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1024;

  Future<void> _loadEmployees() async {
    setState(() => isLoading = true);

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('designation', isEqualTo: 'Supervisor')
          .orderBy('empName')
          .get();

      employeesList = snapshot.docs.map((doc) {
        return {
          'userId': doc.id,
          'userName': doc['empName'] ?? 'Unknown',
          'empId': doc['empCode'] ?? '',
        };
      }).toList();

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error loading employees', isError: true);
    }
  }

  Future<void> _loadEmployeesWithAttendance() async {
    setState(() => isLoadingAttendance = true);

    try {
      String dateKey = DateFormat('dd-MMM-yy').format(selectedDate);

      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: dateKey)
          .get();

      List<Map<String, dynamic>> tempList = [];

      for (var doc in attendanceSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String userId = data['userId'] ?? '';
        
        if (userId.isNotEmpty) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (userDoc.exists && 
              (userDoc.data() as Map<String, dynamic>)['designation'] == 'Supervisor') {
            var userData = userDoc.data() as Map<String, dynamic>;
            
            QuerySnapshot locationSnapshot = await FirebaseFirestore.instance
                .collection('attendance')
                .doc(doc.id)
                .collection('locationHistory')
                .get();
            
            tempList.add({
              'userId': userId,
              'userName': userData['empName'] ?? 'Unknown',
              'empId': userData['empCode'] ?? '',
              'inTime': data['inTime'] ?? 'N/A',
              'outTime': data['outTime'] ?? 'N/A',
              'locationCount': locationSnapshot.docs.length,
              'status': data['outTime'] != null ? 'Completed' : 'Active',
            });
          }
        }
      }

      tempList.sort((a, b) => 
          (a['userName'] as String).compareTo(b['userName'] as String));

      setState(() {
        employeesWithAttendance = tempList;
        isLoadingAttendance = false;
      });
    } catch (e) {
      setState(() => isLoadingAttendance = false);
    }
  }

  Future<void> _loadLocationHistory() async {
    if (selectedUserId == null) {
      _showSnackBar('Please select an employee', isError: true);
      return;
    }

    setState(() {
      isLoading = true;
      locationHistory.clear();
      totalLocations = 0;
      selectedAttendanceId = null;
      markers.clear();
      polylines.clear();
    });

    try {
      String dateKey = DateFormat('dd-MMM-yy').format(selectedDate);

      QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: selectedUserId)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();

      if (attendanceSnapshot.docs.isEmpty) {
        setState(() => isLoading = false);
        _showSnackBar('No attendance record found', isError: true);
        return;
      }

      selectedAttendanceId = attendanceSnapshot.docs.first.id;
      var attendanceData = 
          attendanceSnapshot.docs.first.data() as Map<String, dynamic>;

      loginTime = attendanceData['inTime'];
      logoutTime = attendanceData['outTime'];
      
      double totHrs = attendanceData['totHrs']?.toDouble() ?? 0.0;
      totalWorkDuration = Duration(minutes: (totHrs * 60).toInt());

      QuerySnapshot locationSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(selectedAttendanceId)
          .collection('locationHistory')
          .orderBy('timestamp', descending: false)
          .get();

      locationHistory = locationSnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'timestamp': data['timestamp'],
          'coordinates': data['coordinates'] ?? 'Unknown',
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'accuracy': data['accuracy'],
          'activityType': data['activityType'] ?? 'working',
          'status': data['status'] ?? 'working',
        };
      }).toList();

      _calculateStatistics();
      _buildMapData();

      setState(() {
        totalLocations = locationHistory.length;
        isLoading = false;
      });

      // Auto-switch to map view after loading
      if (locationHistory.isNotEmpty) {
        _tabController.animateTo(1);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error loading data', isError: true);
    }
  }

  void _calculateStatistics() {
    if (locationHistory.isEmpty) return;

    Duration breakTime = Duration.zero;
    DateTime? lastBreakStart;

    for (var location in locationHistory) {
      if (location['activityType'] == 'break_start') {
        lastBreakStart = (location['timestamp'] as Timestamp).toDate();
      } else if (location['activityType'] == 'break_end' && lastBreakStart != null) {
        DateTime breakEnd = (location['timestamp'] as Timestamp).toDate();
        breakTime += breakEnd.difference(lastBreakStart);
        lastBreakStart = null;
      }
    }

    totalBreakDuration = breakTime;
  }

  void _buildMapData() {
    if (locationHistory.isEmpty) return;

    markers.clear();
    polylines.clear();
    List<LatLng> pathPoints = [];

    for (int i = 0; i < locationHistory.length; i++) {
      var location = locationHistory[i];
      
      if (location['latitude'] != null && location['longitude'] != null) {
        double lat = (location['latitude'] as num).toDouble();
        double lng = (location['longitude'] as num).toDouble();
        LatLng position = LatLng(lat, lng);
        pathPoints.add(position);

        DateTime timestamp = (location['timestamp'] as Timestamp).toDate();
        String activityType = location['activityType'] ?? 'working';
        
        markers.add(
          Marker(
            markerId: MarkerId('marker_$i'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerHue(activityType)),
            infoWindow: InfoWindow(
              title: '#${i + 1} - ${_formatActivityType(activityType)}',
              snippet: DateFormat('hh:mm:ss a').format(timestamp),
            ),
            onTap: () => _showLocationDetails(location, i),
          ),
        );
      }
    }

    if (pathPoints.length > 1) {
      polylines.add(
        Polyline(
          polylineId: PolylineId('journey_path'),
          points: pathPoints,
          color: Colors.blue.shade600,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          geodesic: true,
        ),
      );
    }
  }

  void _showLocationDetails(Map<String, dynamic> location, int index) {
    DateTime timestamp = (location['timestamp'] as Timestamp).toDate();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getActivityColor(location['activityType'])
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getActivityIcon(location['activityType']),
                    color: _getActivityColor(location['activityType']),
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location #${index + 1}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatActivityType(location['activityType']),
                        style: TextStyle(
                          color: _getActivityColor(location['activityType']),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildDetailRow(Icons.access_time, 'Time', 
                DateFormat('hh:mm:ss a').format(timestamp)),
            _buildDetailRow(Icons.location_on, 'Address', 
                location['coordinates'] ?? 'Unknown'),
            _buildDetailRow(Icons.gps_fixed, 'Coordinates', 
                '${location['latitude']?.toStringAsFixed(6)}, ${location['longitude']?.toStringAsFixed(6)}'),
            _buildDetailRow(Icons.gps_not_fixed, 'Accuracy', 
                '${location['accuracy']?.toStringAsFixed(2) ?? 'N/A'} meters'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getMarkerHue(String activityType) {
    switch (activityType) {
      case 'login': return BitmapDescriptor.hueGreen;
      case 'logout': return BitmapDescriptor.hueRed;
      case 'break_start': return BitmapDescriptor.hueOrange;
      case 'break_end': return BitmapDescriptor.hueBlue;
      case 'working': return BitmapDescriptor.hueAzure;
      case 'on_break': return BitmapDescriptor.hueYellow;
      default: return BitmapDescriptor.hueViolet;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    
    if (locationHistory.isNotEmpty && locationHistory[0]['latitude'] != null) {
      double lat = (locationHistory[0]['latitude'] as num).toDouble();
      double lng = (locationHistory[0]['longitude'] as num).toDouble();
      
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 13),
      );
    }
  }

  Future<void> _showReportTypeDialog() async {
    if (selectedUserId == null) {
      _showSnackBar('Please select an employee first', isError: true);
      return;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.file_download_outlined, 
                      size: 48, color: Colors.white),
                ),
                SizedBox(height: 24),
                Text(
                  'Export Report',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Choose the report period you want to export',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),
                _buildReportOption(
                  icon: Icons.today_outlined,
                  title: 'Daily Report',
                  subtitle: DateFormat('dd MMMM yyyy').format(selectedDate),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadReport('daily');
                  },
                ),
                SizedBox(height: 16),
                _buildReportOption(
                  icon: Icons.calendar_view_week_outlined,
                  title: 'Weekly Report',
                  subtitle: _getWeekRangeText(selectedDate),
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadReport('weekly');
                  },
                ),
                SizedBox(height: 16),
                _buildReportOption(
                  icon: Icons.calendar_month_outlined,
                  title: 'Monthly Report',
                  subtitle: DateFormat('MMMM yyyy').format(selectedDate),
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadReport('monthly');
                  },
                ),
                SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeekRangeText(DateTime date) {
    DateTime startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(Duration(days: 6));
    return '${DateFormat('dd MMM').format(startOfWeek)} - ${DateFormat('dd MMM yyyy').format(endOfWeek)}';
  }

  Future<void> _downloadReport(String reportType) async {
    if (selectedUserId == null) {
      _showSnackBar('Please select an employee', isError: true);
      return;
    }

    try {
      _showSnackBar('Generating $reportType report...', isError: false);
      
      List<List<dynamic>> rows = [];
      DateTime startDate, endDate;
      String reportTitle;

      switch (reportType) {
        case 'daily':
          startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          endDate = startDate.add(Duration(days: 1));
          reportTitle = 'Daily Location Report - ${DateFormat('dd MMM yyyy').format(selectedDate)}';
          break;
        case 'weekly':
          startDate = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
          endDate = startDate.add(Duration(days: 7));
          reportTitle = 'Weekly Location Report - ${_getWeekRangeText(selectedDate)}';
          break;
        case 'monthly':
          startDate = DateTime(selectedDate.year, selectedDate.month, 1);
          endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
          reportTitle = 'Monthly Location Report - ${DateFormat('MMMM yyyy').format(selectedDate)}';
          break;
        default:
          startDate = selectedDate;
          endDate = selectedDate.add(Duration(days: 1));
          reportTitle = 'Location Report';
      }

      // Report Header
      rows.add([reportTitle]);
      rows.add(['']);
      rows.add(['Employee Information']);
      rows.add(['Name', selectedUserName ?? 'Unknown']);
      rows.add(['Employee ID', selectedUserId ?? '']);
      rows.add(['Report Period''$reportType'.toUpperCase()]);
      rows.add(['Generated On', DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())]);
      rows.add(['']);

      // Fetch data for date range
      List<Map<String, dynamic>> allLocationData = [];
      
      for (DateTime date = startDate; date.isBefore(endDate); 
           date = date.add(Duration(days: 1))) {
        String dateKey = DateFormat('dd-MMM-yy').format(date);
        
        QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('userId', isEqualTo: selectedUserId)
            .where('date', isEqualTo: dateKey)
            .limit(1)
            .get();

        if (attendanceSnapshot.docs.isNotEmpty) {
          var attendanceDoc = attendanceSnapshot.docs.first;
          var attendanceData = attendanceDoc.data() as Map<String, dynamic>;
          
          QuerySnapshot locationSnapshot = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(attendanceDoc.id)
              .collection('locationHistory')
              .orderBy('timestamp', descending: false)
              .get();

          if (locationSnapshot.docs.isNotEmpty) {
            allLocationData.add({
              'date': date,
              'dateKey': dateKey,
              'inTime': attendanceData['inTime'] ?? 'N/A',
              'outTime': attendanceData['outTime'] ?? 'N/A',
              'totHrs': attendanceData['totHrs']?.toDouble() ?? 0.0,
              'locations': locationSnapshot.docs,
            });
          }
        }
      }

      if (allLocationData.isEmpty) {
        _showSnackBar('No data available for $reportType report', isError: true);
        return;
      }

      // Executive Summary
      rows.add(['EXECUTIVE SUMMARY']);
      rows.add(['']);
      rows.add(['Metric', 'Value']);
      
      int totalDays = allLocationData.length;
      int totalLocationsTracked = 0;
      double totalHours = 0;
      
      for (var dayData in allLocationData) {
        int locationCount = (dayData['locations'] as List).length;
        totalLocationsTracked += locationCount;
        totalHours += dayData['totHrs'] as double;
      }
      
      rows.add(['Total Working Days', totalDays.toString()]);
      rows.add(['Total Work Hours', _formatDuration(Duration(minutes: (totalHours * 60).toInt()))]);
      rows.add(['Total Locations Tracked', totalLocationsTracked.toString()]);
      rows.add(['Average Locations Per Day', 
                (totalLocationsTracked / totalDays).toStringAsFixed(1)]);
      rows.add(['']);

      // Daily Summary
      rows.add(['DAILY ATTENDANCE SUMMARY']);
      rows.add(['']);
      rows.add(['Date', 'Day', 'Login Time', 'Logout Time', 'Work Hours', 
                'Locations Tracked', 'Status']);
      
      for (var dayData in allLocationData) {
        int locationCount = (dayData['locations'] as List).length;
        String dayName = DateFormat('EEEE').format(dayData['date']);
        String status = dayData['outTime'] != 'N/A' ? 'Completed' : 'In Progress';
        
        rows.add([
          DateFormat('dd MMM yyyy').format(dayData['date']),
          dayName,
          dayData['inTime'],
          dayData['outTime'],
          _formatDuration(Duration(minutes: ((dayData['totHrs'] as double) * 60).toInt())),
          locationCount.toString(),
          status,
        ]);
      }
      rows.add(['']);

      // Detailed Location History
      rows.add(['DETAILED LOCATION TRACKING']);
      rows.add(['']);
      rows.add(['#', 'Date', 'Day', 'Time', 'Full Timestamp', 'Activity Type', 
                'Status', 'Address', 'Latitude', 'Longitude', 'Accuracy (m)']);

      int locationNumber = 1;
      for (var dayData in allLocationData) {
        for (var locationDoc in (dayData['locations'] as List<QueryDocumentSnapshot>)) {
          var location = locationDoc.data() as Map<String, dynamic>;
          DateTime timestamp = (location['timestamp'] as Timestamp).toDate();
          String dayName = DateFormat('EEE').format(timestamp);
          
          rows.add([
            locationNumber.toString(),
            DateFormat('dd MMM yyyy').format(timestamp),
            dayName,
            DateFormat('hh:mm:ss a').format(timestamp),
            DateFormat('dd MMM yyyy HH:mm:ss').format(timestamp),
            _formatActivityType(location['activityType']),
            _formatStatus(location['status']),
            location['coordinates'] ?? 'Unknown',
            location['latitude']?.toStringAsFixed(6) ?? 'N/A',
            location['longitude']?.toStringAsFixed(6) ?? 'N/A',
            location['accuracy']?.toStringAsFixed(2) ?? 'N/A',
          ]);
          locationNumber++;
        }
      }

      rows.add(['']);
      rows.add(['Report End']);
      rows.add(['']);
      rows.add(['Note: This is an automated report generated by the Location Monitoring System']);

      String csv = const ListToCsvConverter().convert(rows);
      final String fileName = 
          'Location_${reportType}_${selectedUserName?.replaceAll(' ', '_')}_${DateFormat('ddMMMyyyy').format(selectedDate)}.csv';
      
      final Directory? directory = await getExternalStorageDirectory();
      final String path = '${directory?.path}/$fileName';
      final File file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(path)], 
        text: '$reportTitle for $selectedUserName',
        subject: reportTitle,
      );

      _showSnackBar('Report exported successfully!');
    } catch (e) {
      print('Error generating report: $e');
      _showSnackBar('Error generating report', isError: true);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}";
  }

  String _formatActivityType(String? type) {
    switch (type) {
      case 'login': return 'Login';
      case 'logout': return 'Logout';
      case 'break_start': return 'Break Start';
      case 'break_end': return 'Break End';
      case 'working': return 'Working';
      case 'on_break': return 'On Break';
      default: return type ?? 'Unknown';
    }
  }

  String _formatStatus(String? status) {
    return status?.replaceAll('_', ' ').toUpperCase() ?? 'UNKNOWN';
  }

  Color _getActivityColor(String? activityType) {
    switch (activityType) {
      case 'login': return Colors.green.shade600;
      case 'logout': return Colors.red.shade600;
      case 'break_start': return Colors.orange.shade600;
      case 'break_end': return Colors.blue.shade600;
      case 'working': return Colors.blue.shade700;
      case 'on_break': return Colors.amber.shade700;
      default: return Colors.grey.shade600;
    }
  }

  IconData _getActivityIcon(String? activityType) {
    switch (activityType) {
      case 'login': return Icons.login;
      case 'logout': return Icons.logout;
      case 'break_start': return Icons.coffee;
      case 'break_end': return Icons.work;
      case 'working': return Icons.work_outline;
      case 'on_break': return Icons.pause_circle_outline;
      default: return Icons.location_on;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      await _loadEmployeesWithAttendance();
      if (selectedUserId != null) {
        await _loadLocationHistory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Monitor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 18 : 22,
            ),
          ),
          if (selectedUserName != null)
            Text(
              selectedUserName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(onPressed: _showReportTypeDialog, icon: Icon(Icons.download)),
        if (selectedUserId != null && isDesktop)
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: Icon(Icons.download_rounded, size: 20),
              label: Text('Export Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _showReportTypeDialog,
            ),
          ),
        if (!isDesktop)
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadEmployeesWithAttendance();
              if (selectedUserId != null) {
                _loadLocationHistory();
              }
            },
          ),
      ],
      bottom: !isDesktop
          ? TabBar(
              controller: _tabController,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  icon: Icon(Icons.people_alt_outlined),
                  text: 'Employees',
                ),
                Tab(
                  icon: Icon(Icons.map_outlined),
                  text: 'Map',
                ),
                Tab(
                  icon: Icon(Icons.timeline),
                  text: 'Timeline',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Sidebar - Employee List
        Container(
          width: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDateSelector(),
              Divider(height: 1),
              Expanded(child: _buildEmployeeList()),
            ],
          ),
        ),
        // Main Content Area
        Expanded(
          child: Column(
            children: [
              if (selectedUserId != null) ...[
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(24),
                  child: _buildStatisticsRow(),
                ),
                Divider(height: 1),
              ],
              Expanded(
                child: Row(
                  children: [
                    // Map View
                    Expanded(
                      flex: 3,
                      child: _buildMapSection(),
                    ),
                    // Timeline View
                    Container(
                      width: 420,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(-2, 0),
                          ),
                        ],
                      ),
                      child: _buildTimelineSection(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildEmployeeListMobile(),
        _buildMapSection(),
        _buildTimelineSection(),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(selectedDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMMM yyyy').format(selectedDate),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    if (isLoadingAttendance) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              'Loading employees...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (employeesWithAttendance.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No Employees Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'No attendance records for\n${DateFormat('dd MMM yyyy').format(selectedDate)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 12),
      itemCount: employeesWithAttendance.length,
      itemBuilder: (context, index) {
        var employee = employeesWithAttendance[index];
        bool isSelected = employee['userId'] == selectedUserId;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: isSelected
                ? Colors.blue.shade50
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedUserId = employee['userId'];
                  selectedUserName = employee['userName'];
                });
                _loadLocationHistory();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue.shade300
                        : Colors.grey.shade200,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: 'avatar_${employee['userId']}',
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isSelected
                                ? [Colors.blue.shade400, Colors.blue.shade700]
                                : [Colors.grey.shade400, Colors.grey.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isSelected
                                      ? Colors.blue
                                      : Colors.grey)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            employee['userName']
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee['userName'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSelected
                                  ? Colors.blue.shade900
                                  : Colors.grey[900],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.badge_outlined,
                                  size: 14, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                employee['empId'],
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                '${employee['inTime']} - ${employee['outTime']}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: employee['status'] == 'Active'
                                  ? [Colors.green.shade400, Colors.green.shade600]
                                  : [Colors.grey.shade300, Colors.grey.shade400],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (employee['status'] == 'Active'
                                        ? Colors.green
                                        : Colors.grey)
                                    .withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                employee['status'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.purple.shade200, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on,
                                  size: 14, color: Colors.purple.shade700),
                              SizedBox(width: 4),
                              Text(
                                '${employee['locationCount']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmployeeListMobile() {
    return Column(
      children: [
        _buildDateSelector(),
        if (locationHistory.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: _buildStatisticsGrid(),
          ),
          Divider(height: 1),
        ],
        Expanded(child: _buildEmployeeList()),
      ],
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Locations',
            totalLocations.toString(),
            Icons.location_on_outlined,
            Colors.purple,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Work Duration',
            _formatDuration(totalWorkDuration),
            Icons.work_outline,
            Colors.blue,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Break Time',
            _formatDuration(totalBreakDuration),
            Icons.coffee_outlined,
            Colors.orange,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Login Time',
            loginTime ?? 'N/A',
            Icons.login,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Statistics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Locations',
                totalLocations.toString(),
                Icons.location_on_outlined,
                Colors.purple,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Work Time',
                _formatDuration(totalWorkDuration),
                Icons.work_outline,
                Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Break Time',
                _formatDuration(totalBreakDuration),
                Icons.coffee_outlined,
                Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Login',
                loginTime ?? 'N/A',
                Icons.login,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isDesktop ? 20 : 18,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    if (isLoading) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(strokeWidth: 3),
              SizedBox(height: 20),
              Text(
                'Loading location history...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (locationHistory.isEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timeline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'No Timeline Data',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Select an employee to view\ntheir location timeline',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(bottom: BorderSide(color: Colors.teal.shade100)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.teal.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.timeline, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Timeline',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900,
                        ),
                      ),
                      Text(
                        '${locationHistory.length} tracking points recorded',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: locationHistory.length,
              itemBuilder: (context, index) =>
                  _buildLocationCard(locationHistory[index], index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location, int index) {
    DateTime timestamp = (location['timestamp'] as Timestamp).toDate();
    Color activityColor = _getActivityColor(location['activityType']);
    bool isLastItem = index == locationHistory.length - 1;

    return Container(
      margin: EdgeInsets.only(bottom: isLastItem ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      activityColor.withOpacity(0.3),
                      activityColor.withOpacity(0.1)
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: activityColor, width: 3),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: activityColor,
                    ),
                  ),
                ),
              ),
              if (!isLastItem)
                Container(
                  width: 3,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [activityColor.withOpacity(0.3), Colors.grey.shade200],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 16),
          // Card content
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: activityColor.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: activityColor.withOpacity(0.15),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              activityColor.withOpacity(0.2),
                              activityColor.withOpacity(0.1)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getActivityIcon(location['activityType']),
                          color: activityColor,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatActivityType(location['activityType']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: activityColor,
                              ),
                            ),
                            Text(
                              DateFormat('hh:mm:ss a').format(timestamp),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: activityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatStatus(location['status']),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: activityColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.place_outlined,
                          location['coordinates'] ?? 'Unknown',
                          Colors.grey[700]!,
                        ),
                        if (location['latitude'] != null &&
                            location['longitude'] != null) ...[
                          SizedBox(height: 10),
                          _buildInfoRow(
                            Icons.gps_fixed,
                            '${location['latitude'].toStringAsFixed(6)}, ${location['longitude'].toStringAsFixed(6)}',
                            Colors.grey[700]!,
                          ),
                        ],
                        if (location['accuracy'] != null) ...[
                          SizedBox(height: 10),
                          _buildInfoRow(
                            Icons.gps_not_fixed,
                            'Accuracy: ${location['accuracy'].toStringAsFixed(2)}m',
                            Colors.grey[700]!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
  if (isLoading) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Loading map data...',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  if (locationHistory.isEmpty || markers.isEmpty) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.map_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No Map Data Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Select an employee to view\ntheir journey on the map',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double lat = (locationHistory[0]['latitude'] as num).toDouble();
  double lng = (locationHistory[0]['longitude'] as num).toDouble();

  return Container(
    color: Colors.white,
    child: Column(
      children: [
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(bottom: BorderSide(color: Colors.indigo.shade100)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.map, color: Colors.white, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Journey Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                    Text(
                      '${markers.length} locations plotted on map',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.indigo.shade200, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.route, size: 16, color: Colors.indigo.shade700),
                      SizedBox(width: 6),
                      Text(
                        'Route Tracking',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _buildNativeMap(lat, lng),
        ),
      ],
    ),
  );
}

Widget _buildNativeMap(double lat, double lng) {
  return Stack(
    children: [
      GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(lat, lng),
          zoom: 13,
        ),
        markers: markers,
        polylines: polylines,
        mapType: MapType.normal,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
        rotateGesturesEnabled: true,
        scrollGesturesEnabled: true,
        tiltGesturesEnabled: true,
        zoomGesturesEnabled: true,
      ),
      Positioned(
        bottom: 16,
        left: 16,
        child: _buildMapLegend(),
      ),
    ],
  );
}
Widget _buildWebMapPlaceholder() {
  return Stack(
    children: [
      Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.map,
                size: 80,
                color: Colors.grey[400],
              ),
              SizedBox(height: 20),
              Text(
                'Map View',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Google Maps is not fully supported in web version',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 30),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Location Data Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'View the Timeline tab for detailed location tracking',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        bottom: 16,
        left: 16,
        child: _buildMapLegend(),
      ),
    ],
  );
}

Widget _buildMapLegend() {
  return Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Map Legend',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        _buildLegendItem(Colors.green.shade600, 'Login', Icons.login),
        _buildLegendItem(Colors.red.shade600, 'Logout', Icons.logout),
        _buildLegendItem(Colors.orange.shade600, 'Break Start', Icons.coffee),
        _buildLegendItem(Colors.blue.shade600, 'Break End', Icons.work),
        _buildLegendItem(Colors.blue.shade700, 'Working', Icons.work_outline),
      ],
    ),
  );
}
  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}