import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeLocationData {
  final String userId;
  final String empId;
  final String empName;
  final String? currentLocation;
  final Timestamp? lastLocationUpdate;
  final bool isCurrentlyWorking;
  final bool isOnBreak;
  final String workStatus;
  final String? todayLoginTime;
  final String? currentWorkDuration;
  final String? currentBreakDuration;

  EmployeeLocationData({
    required this.userId,
    required this.empId,
    required this.empName,
    this.currentLocation,
    this.lastLocationUpdate,
    required this.isCurrentlyWorking,
    required this.isOnBreak,
    required this.workStatus,
    this.todayLoginTime,
    this.currentWorkDuration,
    this.currentBreakDuration,
  });

  factory EmployeeLocationData.fromFirestore(
    String userId,
    Map<String, dynamic> userData,
    Map<String, dynamic>? attendanceData,
  ) {
    String workStatus = 'Offline';
    if (userData['isCurrentlyWorking'] == true) {
      workStatus = userData['isOnBreak'] == true ? 'On Break' : 'Working';
    }

    return EmployeeLocationData(
      userId: userId,
      empId: userData['empId'] ?? 'N/A',
      empName: userData['empName'] ?? 'Unknown',
      currentLocation: userData['currentLocation'],
      lastLocationUpdate: userData['lastLocationUpdate'],
      isCurrentlyWorking: userData['isCurrentlyWorking'] ?? false,
      isOnBreak: userData['isOnBreak'] ?? false,
      workStatus: workStatus,
      todayLoginTime: userData['todayLoginTime'] != null 
          ? DateTime.parse(userData['todayLoginTime']).toString().split(' ')[1].substring(0, 5)
          : attendanceData?['inTime'],
      currentWorkDuration: userData['currentWorkDuration'],
      currentBreakDuration: userData['currentBreakDuration'],
    );
  }
}