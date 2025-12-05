import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

@immutable
class AppState extends Equatable {
  final String userName;
  final String userId;
  final String empId;
  final String shift;
  final bool isLoggedIn;
  final bool isOnBreak;
  final DateTime? loginTime;
  final DateTime? breakStartTime;
  final Duration workDuration;
  final Duration totalBreakDurationToday;
  final Duration remainingShiftTime;
  final double totalDistanceTraveled;
  final String currentCoordinates;
  final String? todayAttendanceId;
  final bool showInstructions;
  
  // Enhanced approval fields
  final bool isWaitingForApproval;
  final String? pendingApprovalId;
  final DateTime? approvalRequestTime;
  final int approvalRetryCount;
  final String? approvalStatus;

  const AppState({
    required this.userName,
    required this.userId,
    required this.empId,
    required this.shift,
    required this.isLoggedIn,
    required this.isOnBreak,
    this.loginTime,
    this.breakStartTime,
    required this.workDuration,
    required this.totalBreakDurationToday,
    required this.remainingShiftTime,
    required this.totalDistanceTraveled,
    required this.currentCoordinates,
    this.todayAttendanceId,
    required this.showInstructions,
    required this.isWaitingForApproval,
    this.pendingApprovalId,
    this.approvalRequestTime,
    required this.approvalRetryCount,
    this.approvalStatus,
  });

  factory AppState.initial() => const AppState(
        userName: "Please Sign In",
        userId: "",
        empId: "",
        shift: "",
        isLoggedIn: false,
        isOnBreak: false,
        loginTime: null,
        breakStartTime: null,
        workDuration: Duration.zero,
        totalBreakDurationToday: Duration.zero,
        remainingShiftTime: Duration.zero,
        totalDistanceTraveled: 0.0,
        currentCoordinates: "Getting location...",
        todayAttendanceId: null,
        showInstructions: true,
        isWaitingForApproval: false,
        pendingApprovalId: null,
        approvalRequestTime: null,
        approvalRetryCount: 0,
        approvalStatus: null,
      );

  AppState copyWith({
    String? userName,
    String? userId,
    String? empId,
    String? shift,
    bool? isLoggedIn,
    bool? isOnBreak,
    DateTime? loginTime,
    DateTime? breakStartTime,
    Duration? workDuration,
    Duration? totalBreakDurationToday,
    Duration? remainingShiftTime,
    double? totalDistanceTraveled,
    String? currentCoordinates,
    String? todayAttendanceId,
    bool? showInstructions,
    bool? isWaitingForApproval,
    String? pendingApprovalId,
    DateTime? approvalRequestTime,
    int? approvalRetryCount,
    String? approvalStatus,
  }) {
    return AppState(
      userName: userName ?? this.userName,
      userId: userId ?? this.userId,
      empId: empId ?? this.empId,
      shift: shift ?? this.shift,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isOnBreak: isOnBreak ?? this.isOnBreak,
      loginTime: loginTime ?? this.loginTime,
      breakStartTime: breakStartTime ?? this.breakStartTime,
      workDuration: workDuration ?? this.workDuration,
      totalBreakDurationToday: totalBreakDurationToday ?? this.totalBreakDurationToday,
      remainingShiftTime: remainingShiftTime ?? this.remainingShiftTime,
      totalDistanceTraveled: totalDistanceTraveled ?? this.totalDistanceTraveled,
      currentCoordinates: currentCoordinates ?? this.currentCoordinates,
      todayAttendanceId: todayAttendanceId ?? this.todayAttendanceId,
      showInstructions: showInstructions ?? this.showInstructions,
      isWaitingForApproval: isWaitingForApproval ?? this.isWaitingForApproval,
      pendingApprovalId: pendingApprovalId ?? this.pendingApprovalId,
      approvalRequestTime: approvalRequestTime ?? this.approvalRequestTime,
      approvalRetryCount: approvalRetryCount ?? this.approvalRetryCount,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'userId': userId,
      'empId': empId,
      'shift': shift,
      'isLoggedIn': isLoggedIn,
      'isOnBreak': isOnBreak,
      'loginTime': loginTime?.toIso8601String(),
      'breakStartTime': breakStartTime?.toIso8601String(),
      'workDuration': workDuration.inSeconds,
      'totalBreakDurationToday': totalBreakDurationToday.inSeconds,
      'remainingShiftTime': remainingShiftTime.inSeconds,
      'totalDistanceTraveled': totalDistanceTraveled,
      'currentCoordinates': currentCoordinates,
      'todayAttendanceId': todayAttendanceId,
      'showInstructions': showInstructions,
      'isWaitingForApproval': isWaitingForApproval,
      'pendingApprovalId': pendingApprovalId,
      'approvalRequestTime': approvalRequestTime?.toIso8601String(),
      'approvalRetryCount': approvalRetryCount,
      'approvalStatus': approvalStatus,
    };
  }

  factory AppState.fromMap(Map<String, dynamic> map) {
    return AppState(
      userName: map['userName'] ?? "Please Sign In",
      userId: map['userId'] ?? "",
      empId: map['empId'] ?? "",
      shift: map['shift'] ?? "",
      isLoggedIn: map['isLoggedIn'] ?? false,
      isOnBreak: map['isOnBreak'] ?? false,
      loginTime: map['loginTime'] != null ? DateTime.parse(map['loginTime']) : null,
      breakStartTime: map['breakStartTime'] != null ? DateTime.parse(map['breakStartTime']) : null,
      workDuration: Duration(seconds: map['workDuration'] ?? 0),
      totalBreakDurationToday: Duration(seconds: map['totalBreakDurationToday'] ?? 0),
      remainingShiftTime: Duration(seconds: map['remainingShiftTime'] ?? 0),
      totalDistanceTraveled: map['totalDistanceTraveled'] ?? 0.0,
      currentCoordinates: map['currentCoordinates'] ?? "Getting location...",
      todayAttendanceId: map['todayAttendanceId'],
      showInstructions: map['showInstructions'] ?? true,
      isWaitingForApproval: map['isWaitingForApproval'] ?? false,
      pendingApprovalId: map['pendingApprovalId'],
      approvalRequestTime: map['approvalRequestTime'] != null ? DateTime.parse(map['approvalRequestTime']) : null,
      approvalRetryCount: map['approvalRetryCount'] ?? 0,
      approvalStatus: map['approvalStatus'],
    );
  }

  // Helper methods for approval system
  bool get isApprovalExpired {
    if (approvalRequestTime == null) return false;
    final now = DateTime.now();
    return now.difference(approvalRequestTime!).inHours >= 24;
  }

  bool get shouldRetryApprovalCheck {
    return approvalRetryCount < 3;
  }

  Duration get waitingDuration {
    if (approvalRequestTime == null) return Duration.zero;
    return DateTime.now().difference(approvalRequestTime!);
  }

  @override
  List<Object?> get props => [
        userName,
        userId,
        empId,
        shift,
        isLoggedIn,
        isOnBreak,
        loginTime,
        breakStartTime,
        workDuration,
        totalBreakDurationToday,
        remainingShiftTime,
        totalDistanceTraveled,
        currentCoordinates,
        todayAttendanceId,
        showInstructions,
        isWaitingForApproval,
        pendingApprovalId,
        approvalRequestTime,
        approvalRetryCount,
        approvalStatus,
      ];
}