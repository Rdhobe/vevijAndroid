import 'package:vevij/components/imports.dart';

class HODHistory {
  final DateTime assignedAt;
  final String assignedBy;
  final String hodEmail;
  final String hodId;
  final String hodName;
  final String reason;

  HODHistory({
    required this.assignedAt,
    required this.assignedBy,
    required this.hodEmail,
    required this.hodId,
    required this.hodName,
    required this.reason,
  });

  factory HODHistory.fromMap(Map<String, dynamic> map) {
    return HODHistory(
      assignedAt: (map['assignedAt'] as Timestamp).toDate(),
      assignedBy: map['assignedBy'] ?? '',
      hodEmail: map['hodEmail'] ?? '',
      hodId: map['hodId'] ?? '',
      hodName: map['hodName'] ?? '',
      reason: map['reason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assignedAt': Timestamp.fromDate(assignedAt),
      'assignedBy': assignedBy,
      'hodEmail': hodEmail,
      'hodId': hodId,
      'hodName': hodName,
      'reason': reason,
    };
  }

  HODHistory copyWith({
    DateTime? assignedAt,
    String? assignedBy,
    String? hodEmail,
    String? hodId,
    String? hodName,
    String? reason,
  }) {
    return HODHistory(
      assignedAt: assignedAt ?? this.assignedAt,
      assignedBy: assignedBy ?? this.assignedBy,
      hodEmail: hodEmail ?? this.hodEmail,
      hodId: hodId ?? this.hodId,
      hodName: hodName ?? this.hodName,
      reason: reason ?? this.reason,
    );
  }

  @override
  String toString() {
    return 'HODHistory(hodName: $hodName, assignedBy: $assignedBy, assignedAt: $assignedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is HODHistory &&
        other.assignedAt == assignedAt &&
        other.assignedBy == assignedBy &&
        other.hodEmail == hodEmail &&
        other.hodId == hodId &&
        other.hodName == hodName &&
        other.reason == reason;
  }

  @override
  int get hashCode {
    return assignedAt.hashCode ^
        assignedBy.hashCode ^
        hodEmail.hashCode ^
        hodId.hashCode ^
        hodName.hashCode ^
        reason.hashCode;
  }
}
