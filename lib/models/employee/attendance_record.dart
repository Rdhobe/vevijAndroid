import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String userId;
  final String userName;
  final String empId;
  final String date;
  final String day;
  final String shiftCode;
  final String shiftInTime;
  final String shiftOutTime;
  final String? inTime;
  final String? outTime;
  final double totHrs;
  final double lateHrs;
  final double lateMark;
  final double otHrs;
  final String type1;
  final double portion;
  final String type2;
  final String? coordinates;
  final double totalDistanceTraveled;
  final bool isOnBreak;
  final int totalBreakSeconds;
  final String? breakStartTime;
  final String? breakEndTime;
  final String? loginCoordinates;
  final String? logoutCoordinates;
  final String? breakInCoordinates;
  final String? breakOutCoordinates;
  final String? lastBreakDuration;
  final String? totalBreakTime;
  final String? earlyLogoutReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.empId,
    required this.date,
    required this.day,
    required this.shiftCode,
    required this.shiftInTime,
    required this.shiftOutTime,
    this.inTime,
    this.outTime,
    required this.totHrs,
    required this.lateHrs,
    required this.lateMark,
    required this.otHrs,
    required this.type1,
    required this.portion,
    required this.type2,
    this.coordinates,
    required this.totalDistanceTraveled,
    required this.isOnBreak,
    required this.totalBreakSeconds,
    this.breakStartTime,
    this.breakEndTime,
    this.loginCoordinates,
    this.logoutCoordinates,
    this.breakInCoordinates,
    this.breakOutCoordinates,
    this.lastBreakDuration,
    this.totalBreakTime,
    this.earlyLogoutReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceRecord(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      empId: map['empId'] ?? '',
      date: map['date'] ?? '',
      day: map['day'] ?? '',
      shiftCode: map['shiftCode'] ?? 'GN',
      shiftInTime: map['shiftInTime'] ?? '09:30 AM',
      shiftOutTime: map['shiftOutTime'] ?? '06:30 PM',
      inTime: map['inTime'],
      outTime: map['outTime'],
      totHrs: (map['totHrs'] ?? 0.0).toDouble(),
      lateHrs: (map['lateHrs'] ?? 0.0).toDouble(),
      lateMark: (map['lateMark'] ?? 0.0).toDouble(),
      otHrs: (map['otHrs'] ?? 0.0).toDouble(),
      type1: map['type1'] ?? 'ABS',
      portion: (map['portion'] ?? 0.0).toDouble(),
      type2: map['type2'] ?? '---',
      coordinates: map['coordinates'],
      totalDistanceTraveled: (map['totalDistanceTraveled'] ?? 0.0).toDouble(),
      isOnBreak: map['isOnBreak'] ?? false,
      totalBreakSeconds: map['totalBreakSeconds'] ?? 0,
      breakStartTime: map['breakStartTime'],
      breakEndTime: map['breakEndTime'],
      loginCoordinates: map['loginCoordinates'],
      logoutCoordinates: map['logoutCoordinates'],
      breakInCoordinates: map['breakInCoordinates'],
      breakOutCoordinates: map['breakOutCoordinates'],
      lastBreakDuration: map['lastBreakDuration'],
      totalBreakTime: map['totalBreakTime'],
      earlyLogoutReason: map['earlyLogoutReason'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'empId': empId,
      'date': date,
      'day': day,
      'shiftCode': shiftCode,
      'shiftInTime': shiftInTime,
      'shiftOutTime': shiftOutTime,
      'inTime': inTime,
      'outTime': outTime,
      'totHrs': totHrs,
      'lateHrs': lateHrs,
      'lateMark': lateMark,
      'otHrs': otHrs,
      'type1': type1,
      'portion': portion,
      'type2': type2,
      'coordinates': coordinates,
      'totalDistanceTraveled': totalDistanceTraveled,
      'isOnBreak': isOnBreak,
      'totalBreakSeconds': totalBreakSeconds,
      'breakStartTime': breakStartTime,
      'breakEndTime': breakEndTime,
      'loginCoordinates': loginCoordinates,
      'logoutCoordinates': logoutCoordinates,
      'breakInCoordinates': breakInCoordinates,
      'breakOutCoordinates': breakOutCoordinates,
      'lastBreakDuration': lastBreakDuration,
      'totalBreakTime': totalBreakTime,
      'earlyLogoutReason': earlyLogoutReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}