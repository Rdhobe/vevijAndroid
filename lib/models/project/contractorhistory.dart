import 'package:vevij/components/imports.dart';

class ContractorHistory {
  final DateTime assignedAt;
  final String assignedBy;
  final String contractorEmail;
  final String contractorId;
  final String contractorName;
  final String reason;

  ContractorHistory({
    required this.assignedAt,
    required this.assignedBy,
    required this.contractorEmail,
    required this.contractorId,
    required this.contractorName,
    required this.reason,
  });

  factory ContractorHistory.fromMap(Map<String, dynamic> map) {
    return ContractorHistory(
      assignedAt: (map['assignedAt'] as Timestamp).toDate(),
      assignedBy: map['assignedBy'] ?? '',
      contractorEmail: map['contractorEmail'] ?? '',
      contractorId: map['contractorId'] ?? '',
      contractorName: map['contractorName'] ?? '',
      reason: map['reason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assignedAt': Timestamp.fromDate(assignedAt),
      'assignedBy': assignedBy,
      'contractorEmail': contractorEmail,
      'contractorId': contractorId,
      'contractorName': contractorName,
      'reason': reason,
    };
  }

  ContractorHistory copyWith({
    DateTime? assignedAt,
    String? assignedBy,
    String? contractorEmail,
    String? contractorId,
    String? contractorName,
    String? reason,
  }) {
    return ContractorHistory(
      assignedAt: assignedAt ?? this.assignedAt,
      assignedBy: assignedBy ?? this.assignedBy,
      contractorEmail: contractorEmail ?? this.contractorEmail,
      contractorId: contractorId ?? this.contractorId,
      contractorName: contractorName ?? this.contractorName,
      reason: reason ?? this.reason,
    );
  }

  @override
  String toString() {
    return 'ContractorHistory(contractorName: $contractorName, assignedBy: $assignedBy, assignedAt: $assignedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is ContractorHistory &&
        other.assignedAt == assignedAt &&
        other.assignedBy == assignedBy &&
        other.contractorEmail == contractorEmail &&
        other.contractorId == contractorId &&
        other.contractorName == contractorName &&
        other.reason == reason;
  }

  @override
  int get hashCode {
    return assignedAt.hashCode ^
        assignedBy.hashCode ^
        contractorEmail.hashCode ^
        contractorId.hashCode ^
        contractorName.hashCode ^
        reason.hashCode;
  }
}