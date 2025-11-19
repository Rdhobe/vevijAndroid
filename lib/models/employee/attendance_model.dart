// attendance_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
class Attendance {
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
  final String coordinates;
  final String? loginCoordinates;
  final String? logoutCoordinates;
  final double totalDistanceTraveled;
  final bool isOnBreak;
  final String? breakStartTime;
  final String? breakEndTime;
  final String? breakInCoordinates;
  final String? breakOutCoordinates;
  final String totalBreakTime;
  final int totalBreakSeconds;
  final String? lastBreakDuration;
  final String? earlyLogoutReason;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  Attendance({
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
    this.totHrs = 0.0,
    this.lateHrs = 0.0,
    this.lateMark = 0.0,
    this.otHrs = 0.0,
    this.type1 = 'ABS',
    this.portion = 0.0,
    this.type2 = '---',
    this.coordinates = 'Unknown',
    this.loginCoordinates,
    this.logoutCoordinates,
    this.totalDistanceTraveled = 0.0,
    this.isOnBreak = false,
    this.breakStartTime,
    this.breakEndTime,
    this.breakInCoordinates,
    this.breakOutCoordinates,
    this.totalBreakTime = '00:00:00',
    this.totalBreakSeconds = 0,
    this.lastBreakDuration,
    this.earlyLogoutReason,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for Firestore
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
      'loginCoordinates': loginCoordinates,
      'logoutCoordinates': logoutCoordinates,
      'totalDistanceTraveled': totalDistanceTraveled,
      'isOnBreak': isOnBreak,
      'breakStartTime': breakStartTime,
      'breakEndTime': breakEndTime,
      'breakInCoordinates': breakInCoordinates,
      'breakOutCoordinates': breakOutCoordinates,
      'totalBreakTime': totalBreakTime,
      'totalBreakSeconds': totalBreakSeconds,
      'lastBreakDuration': lastBreakDuration,
      'earlyLogoutReason': earlyLogoutReason,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create from Firestore Document
  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Attendance(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      empId: data['empId'] ?? '',
      date: data['date'] ?? '',
      day: data['day'] ?? '',
      shiftCode: data['shiftCode'] ?? 'GN',
      shiftInTime: data['shiftInTime'] ?? '09:30 AM',
      shiftOutTime: data['shiftOutTime'] ?? '06:30 PM',
      inTime: data['inTime'],
      outTime: data['outTime'],
      totHrs: (data['totHrs'] ?? 0.0).toDouble(),
      lateHrs: (data['lateHrs'] ?? 0.0).toDouble(),
      lateMark: (data['lateMark'] ?? 0.0).toDouble(),
      otHrs: (data['otHrs'] ?? 0.0).toDouble(),
      type1: data['type1'] ?? 'ABS',
      portion: (data['portion'] ?? 0.0).toDouble(),
      type2: data['type2'] ?? '---',
      coordinates: data['coordinates'] ?? 'Unknown',
      loginCoordinates: data['loginCoordinates'],
      logoutCoordinates: data['logoutCoordinates'],
      totalDistanceTraveled: (data['totalDistanceTraveled'] ?? 0.0).toDouble(),
      isOnBreak: data['isOnBreak'] ?? false,
      breakStartTime: data['breakStartTime'],
      breakEndTime: data['breakEndTime'],
      breakInCoordinates: data['breakInCoordinates'],
      breakOutCoordinates: data['breakOutCoordinates'],
      totalBreakTime: data['totalBreakTime'] ?? '00:00:00',
      totalBreakSeconds: data['totalBreakSeconds'] ?? 0,
      lastBreakDuration: data['lastBreakDuration'],
      earlyLogoutReason: data['earlyLogoutReason'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  // Create empty attendance
  factory Attendance.empty() {
    return Attendance(
      id: '',
      userId: '',
      userName: '',
      empId: '',
      date: DateFormat('dd-MMM-yy').format(DateTime.now()),
      day: DateFormat('EEE').format(DateTime.now()),
      shiftCode: 'GN',
      shiftInTime: '09:30 AM',
      shiftOutTime: '06:30 PM',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  // Create for new login
  factory Attendance.forLogin({
    required String userId,
    required String userName,
    required String empId,
    required String coordinates,
  }) {
    DateTime now = DateTime.now();
    return Attendance(
      id: '',
      userId: userId,
      userName: userName,
      empId: empId,
      date: DateFormat('dd-MMM-yy').format(now),
      day: DateFormat('EEE').format(now),
      shiftCode: 'GN',
      shiftInTime: '09:30 AM',
      shiftOutTime: '06:30 PM',
      inTime: DateFormat('h:mm a').format(now),
      coordinates: coordinates,
      loginCoordinates: coordinates,
      type1: 'DP',
      portion: 1.0,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  // Copy with method for updates
  Attendance copyWith({
    String? id,
    String? userId,
    String? userName,
    String? empId,
    String? date,
    String? day,
    String? shiftCode,
    String? shiftInTime,
    String? shiftOutTime,
    String? inTime,
    String? outTime,
    double? totHrs,
    double? lateHrs,
    double? lateMark,
    double? otHrs,
    String? type1,
    double? portion,
    String? type2,
    String? coordinates,
    String? loginCoordinates,
    String? logoutCoordinates,
    double? totalDistanceTraveled,
    bool? isOnBreak,
    String? breakStartTime,
    String? breakEndTime,
    String? breakInCoordinates,
    String? breakOutCoordinates,
    String? totalBreakTime,
    int? totalBreakSeconds,
    String? lastBreakDuration,
    String? earlyLogoutReason,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return Attendance(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      empId: empId ?? this.empId,
      date: date ?? this.date,
      day: day ?? this.day,
      shiftCode: shiftCode ?? this.shiftCode,
      shiftInTime: shiftInTime ?? this.shiftInTime,
      shiftOutTime: shiftOutTime ?? this.shiftOutTime,
      inTime: inTime ?? this.inTime,
      outTime: outTime ?? this.outTime,
      totHrs: totHrs ?? this.totHrs,
      lateHrs: lateHrs ?? this.lateHrs,
      lateMark: lateMark ?? this.lateMark,
      otHrs: otHrs ?? this.otHrs,
      type1: type1 ?? this.type1,
      portion: portion ?? this.portion,
      type2: type2 ?? this.type2,
      coordinates: coordinates ?? this.coordinates,
      loginCoordinates: loginCoordinates ?? this.loginCoordinates,
      logoutCoordinates: logoutCoordinates ?? this.logoutCoordinates,
      totalDistanceTraveled: totalDistanceTraveled ?? this.totalDistanceTraveled,
      isOnBreak: isOnBreak ?? this.isOnBreak,
      breakStartTime: breakStartTime ?? this.breakStartTime,
      breakEndTime: breakEndTime ?? this.breakEndTime,
      breakInCoordinates: breakInCoordinates ?? this.breakInCoordinates,
      breakOutCoordinates: breakOutCoordinates ?? this.breakOutCoordinates,
      totalBreakTime: totalBreakTime ?? this.totalBreakTime,
      totalBreakSeconds: totalBreakSeconds ?? this.totalBreakSeconds,
      lastBreakDuration: lastBreakDuration ?? this.lastBreakDuration,
      earlyLogoutReason: earlyLogoutReason ?? this.earlyLogoutReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? Timestamp.now(),
    );
  }

  // Getters for computed properties
  bool get isLoggedIn => inTime != null && outTime == null;
  bool get isLoggedOut => outTime != null;
  bool get isPresent => type1 == 'DP' || type1 == 'HD';
  bool get isAbsent => type1 == 'ABS';
  bool get isHalfDay => type1 == 'HD';

  // Calculate work status
  String get workStatus {
    if (!isLoggedIn) return 'Not Logged In';
    if (isOnBreak) return 'On Break';
    return 'Working';
  }

  // Get login time as DateTime
  DateTime? get loginDateTime {
    if (inTime == null) return null;
    try {
      DateTime now = DateTime.now();
      DateFormat format = DateFormat('h:mm a');
      DateTime parsed = format.parse(inTime!);
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      return null;
    }
  }

  // Get logout time as DateTime
  DateTime? get logoutDateTime {
    if (outTime == null) return null;
    try {
      DateTime now = DateTime.now();
      DateFormat format = DateFormat('h:mm a');
      DateTime parsed = format.parse(outTime!);
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'Attendance{id: $id, userName: $userName, date: $date, inTime: $inTime, outTime: $outTime, status: $type1}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Attendance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}




