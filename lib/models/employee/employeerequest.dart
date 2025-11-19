import 'package:vevij/components/imports.dart';

class EmployeeRequest {
  final String requestType; // 'leave', 'mis_punch', 'profile_update'
  final String appliedDate;
  final DateTime createdAt;
  final String employeeName;
  final String userId;
  final String status; // 'pending', 'approved', 'rejected'
  final String? processedBy;
  final DateTime? processedAt;
  final DateTime updatedAt;
  final String? reason;
  
  // Leave specific fields
  final String? leaveType;
  final String? subType;
  final int? duration;
  final String? startDate;
  final String? endDate;
  final String? contactNumber;
  
  // Mispunch specific fields
  final String? date;
  final String? punchType;
  final String? punchTypeLabel;
  final String? correctInTime;
  final String? correctOutTime;
  
  // Profile update specific fields
  final String? updateType;
  final String? updateTypeLabel;
  final Map<String, dynamic>? updateData;
  final String? adminComment;

  EmployeeRequest({
    required this.requestType,
    required this.appliedDate,
    required this.createdAt,
    required this.employeeName,
    required this.userId,
    required this.status,
    this.processedBy,
    this.processedAt,
    required this.updatedAt,
    this.reason,
    
    // Leave
    this.leaveType,
    this.subType,
    this.duration,
    this.startDate,
    this.endDate,
    this.contactNumber,
    
    // Mispunch
    this.date,
    this.punchType,
    this.punchTypeLabel,
    this.correctInTime,
    this.correctOutTime,
    
    // Profile update
    this.updateType,
    this.updateTypeLabel,
    this.updateData,
    this.adminComment,
  });

  factory EmployeeRequest.fromMap(Map<String, dynamic> map) {
    return EmployeeRequest(
      requestType: map['requestType'] ?? '',
      appliedDate: map['appliedDate'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      employeeName: map['employeeName'] ?? '',
      userId: map['userId'] ?? '',
      status: map['status'] ?? 'pending',
      processedBy: map['processedBy'],
      processedAt: map['processedAt'] != null ? (map['processedAt'] as Timestamp).toDate() : null,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      reason: map['reason'],
      
      // Leave fields
      leaveType: map['leaveType'],
      subType: map['subType'],
      duration: (map['duration'] ?? 0).toInt(),
      startDate: map['startDate'],
      endDate: map['endDate'],
      contactNumber: map['contactNumber'],
      
      // Mispunch fields
      date: map['date'],
      punchType: map['punchType'],
      punchTypeLabel: map['punchTypeLabel'],
      correctInTime: map['correctInTime'],
      correctOutTime: map['correctOutTime'],
      
      // Profile update fields
      updateType: map['updateType'],
      updateTypeLabel: map['updateTypeLabel'],
      updateData: Map<String, dynamic>.from(map['updateData'] ?? {}),
      adminComment: map['adminComment'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestType': requestType,
      'appliedDate': appliedDate,
      'createdAt': Timestamp.fromDate(createdAt),
      'employeeName': employeeName,
      'userId': userId,
      'status': status,
      'processedBy': processedBy,
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'reason': reason,
      
      // Leave fields
      if (leaveType != null) 'leaveType': leaveType,
      if (subType != null) 'subType': subType,
      if (duration != null) 'duration': duration,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
      if (contactNumber != null) 'contactNumber': contactNumber,
      
      // Mispunch fields
      if (date != null) 'date': date,
      if (punchType != null) 'punchType': punchType,
      if (punchTypeLabel != null) 'punchTypeLabel': punchTypeLabel,
      if (correctInTime != null) 'correctInTime': correctInTime,
      if (correctOutTime != null) 'correctOutTime': correctOutTime,
      
      // Profile update fields
      if (updateType != null) 'updateType': updateType,
      if (updateTypeLabel != null) 'updateTypeLabel': updateTypeLabel,
      if (updateData != null) 'updateData': updateData,
      if (adminComment != null) 'adminComment': adminComment,
    };
  }

  EmployeeRequest copyWith({
    String? requestType,
    String? appliedDate,
    DateTime? createdAt,
    String? employeeName,
    String? userId,
    String? status,
    String? processedBy,
    DateTime? processedAt,
    DateTime? updatedAt,
    String? reason,
    
    // Leave
    String? leaveType,
    String? subType,
    int? duration,
    String? startDate,
    String? endDate,
    String? contactNumber,
    
    // Mispunch
    String? date,
    String? punchType,
    String? punchTypeLabel,
    String? correctInTime,
    String? correctOutTime,
    
    // Profile update
    String? updateType,
    String? updateTypeLabel,
    Map<String, dynamic>? updateData,
    String? adminComment,
  }) {
    return EmployeeRequest(
      requestType: requestType ?? this.requestType,
      appliedDate: appliedDate ?? this.appliedDate,
      createdAt: createdAt ?? this.createdAt,
      employeeName: employeeName ?? this.employeeName,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      processedBy: processedBy ?? this.processedBy,
      processedAt: processedAt ?? this.processedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reason: reason ?? this.reason,
      
      leaveType: leaveType ?? this.leaveType,
      subType: subType ?? this.subType,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      contactNumber: contactNumber ?? this.contactNumber,
      
      date: date ?? this.date,
      punchType: punchType ?? this.punchType,
      punchTypeLabel: punchTypeLabel ?? this.punchTypeLabel,
      correctInTime: correctInTime ?? this.correctInTime,
      correctOutTime: correctOutTime ?? this.correctOutTime,
      
      updateType: updateType ?? this.updateType,
      updateTypeLabel: updateTypeLabel ?? this.updateTypeLabel,
      updateData: updateData ?? this.updateData,
      adminComment: adminComment ?? this.adminComment,
    );
  }
}

// Helper class for Profile Update Data
class ProfileUpdateData {
  final String? address;
  final String? email;
  final String? phoneNumber;

  ProfileUpdateData({
    this.address,
    this.email,
    this.phoneNumber,
  });

  factory ProfileUpdateData.fromMap(Map<String, dynamic> map) {
    return ProfileUpdateData(
      address: map['Address'],
      email: map['Email'],
      phoneNumber: map['Phone Number'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (address != null) 'Address': address,
      if (email != null) 'Email': email,
      if (phoneNumber != null) 'Phone Number': phoneNumber,
    };
  }
}