import 'package:cloud_firestore/cloud_firestore.dart';
class LoginApproval {
  final String id;
  final String userId;
  final String userName;
  final String empId;
  final DateTime requestTime;
  final String requestTimeStr;
  final String date;
  final double lateBy;
  final String status;
  final String coordinates;
  final String? approvedBy;
  final DateTime? approvalTime;
  final String reason;
  final String? rejectionReason;

  LoginApproval({
    required this.id,
    required this.userId,
    required this.userName,
    required this.empId,
    required this.requestTime,
    required this.requestTimeStr,
    required this.date,
    required this.lateBy,
    required this.status,
    required this.coordinates,
    this.approvedBy,
    this.approvalTime,
    required this.reason,
    this.rejectionReason,
  });

  factory LoginApproval.fromMap(String id, Map<String, dynamic> map) {
    return LoginApproval(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      empId: map['empId'] ?? '',
      requestTime: (map['requestTime'] as Timestamp).toDate(),
      requestTimeStr: map['requestTimeStr'] ?? '',
      date: map['date'] ?? '',
      lateBy: (map['lateBy'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
      coordinates: map['coordinates'] ?? '',
      approvedBy: map['approvedBy'],
      approvalTime: map['approvalTime'] != null 
          ? (map['approvalTime'] as Timestamp).toDate() 
          : null,
      reason: map['reason'] ?? '',
      rejectionReason: map['rejectionReason'],
    );
  }
}