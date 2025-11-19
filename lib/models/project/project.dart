import 'package:vevij/components/imports.dart';
import 'package:flutter/foundation.dart';
class Project {
  final int architrave;
  final List<String> assignedContractorIds;
  final String assignedHODId;
  final String assignedHODName;
  final List<String> assignedSupervisorIds;
  final String contractorName;
  final DateTime createdAt;
  final String? createdBy;
  final String customerName;
  final String description;
  final int doorFrameHardware;
  final DateTime endDate;
  final String groupId;
  final int handover;
  final bool isSetupComplete;
  final DateTime lastUpdated;
  final String name;
  final String priority;
  final int progress;
  final String projectAddress;
  final String projectType;
  final DateTime startDate;
  final String status;
  final int totalTasks;

  Project({
    required this.architrave,
    required this.assignedContractorIds,
    required this.assignedHODId,
    required this.assignedHODName,
    required this.assignedSupervisorIds,
    required this.contractorName,
    required this.createdAt,
    this.createdBy,
    required this.customerName,
    required this.description,
    required this.doorFrameHardware,
    required this.endDate,
    required this.groupId,
    required this.handover,
    required this.isSetupComplete,
    required this.lastUpdated,
    required this.name,
    required this.priority,
    required this.progress,
    required this.projectAddress,
    required this.projectType,
    required this.startDate,
    required this.status,
    required this.totalTasks,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      architrave: (map['architrave'] ?? 0).toInt(),
      assignedContractorIds: List<String>.from(map['assignedContractorIds'] ?? []),
      assignedHODId: map['assignedHODId'] ?? '',
      assignedHODName: map['assignedHODName'] ?? '',
      assignedSupervisorIds: List<String>.from(map['assignedSupervisorIds'] ?? []),
      contractorName: map['contractorName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'],
      customerName: map['customerName'] ?? '',
      description: map['description'] ?? '',
      doorFrameHardware: (map['doorFrameHardware'] ?? 0).toInt(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      groupId: map['groupId'] ?? '',
      handover: (map['handover'] ?? 0).toInt(),
      isSetupComplete: map['isSetupComplete'] ?? false,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      name: map['name'] ?? '',
      priority: map['priority'] ?? 'Medium',
      progress: (map['progress'] ?? 0).toInt(),
      projectAddress: map['projectAddress'] ?? '',
      projectType: map['projectType'] ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'Active',
      totalTasks: (map['totalTasks'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'architrave': architrave,
      'assignedContractorIds': assignedContractorIds,
      'assignedHODId': assignedHODId,
      'assignedHODName': assignedHODName,
      'assignedSupervisorIds': assignedSupervisorIds,
      'contractorName': contractorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'customerName': customerName,
      'description': description,
      'doorFrameHardware': doorFrameHardware,
      'endDate': Timestamp.fromDate(endDate),
      'groupId': groupId,
      'handover': handover,
      'isSetupComplete': isSetupComplete,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'name': name,
      'priority': priority,
      'progress': progress,
      'projectAddress': projectAddress,
      'projectType': projectType,
      'startDate': Timestamp.fromDate(startDate),
      'status': status,
      'totalTasks': totalTasks,
    };
  }

  Project copyWith({
    int? architrave,
    List<String>? assignedContractorIds,
    String? assignedHODId,
    String? assignedHODName,
    List<String>? assignedSupervisorIds,
    String? contractorName,
    DateTime? createdAt,
    String? createdBy,
    String? customerName,
    String? description,
    int? doorFrameHardware,
    DateTime? endDate,
    String? groupId,
    int? handover,
    bool? isSetupComplete,
    DateTime? lastUpdated,
    String? name,
    String? priority,
    int? progress,
    String? projectAddress,
    String? projectType,
    DateTime? startDate,
    String? status,
    int? totalTasks,
  }) {
    return Project(
      architrave: architrave ?? this.architrave,
      assignedContractorIds: assignedContractorIds ?? this.assignedContractorIds,
      assignedHODId: assignedHODId ?? this.assignedHODId,
      assignedHODName: assignedHODName ?? this.assignedHODName,
      assignedSupervisorIds: assignedSupervisorIds ?? this.assignedSupervisorIds,
      contractorName: contractorName ?? this.contractorName,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      customerName: customerName ?? this.customerName,
      description: description ?? this.description,
      doorFrameHardware: doorFrameHardware ?? this.doorFrameHardware,
      endDate: endDate ?? this.endDate,
      groupId: groupId ?? this.groupId,
      handover: handover ?? this.handover,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      name: name ?? this.name,
      priority: priority ?? this.priority,
      progress: progress ?? this.progress,
      projectAddress: projectAddress ?? this.projectAddress,
      projectType: projectType ?? this.projectType,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      totalTasks: totalTasks ?? this.totalTasks,
    );
  }

  @override
  String toString() {
    return 'Project(name: $name, customer: $customerName, progress: $progress%, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Project &&
        other.architrave == architrave &&
        listEquals(other.assignedContractorIds, assignedContractorIds) &&
        other.assignedHODId == assignedHODId &&
        other.assignedHODName == assignedHODName &&
        listEquals(other.assignedSupervisorIds, assignedSupervisorIds) &&
        other.contractorName == contractorName &&
        other.createdAt == createdAt &&
        other.createdBy == createdBy &&
        other.customerName == customerName &&
        other.description == description &&
        other.doorFrameHardware == doorFrameHardware &&
        other.endDate == endDate &&
        other.groupId == groupId &&
        other.handover == handover &&
        other.isSetupComplete == isSetupComplete &&
        other.lastUpdated == lastUpdated &&
        other.name == name &&
        other.priority == priority &&
        other.progress == progress &&
        other.projectAddress == projectAddress &&
        other.projectType == projectType &&
        other.startDate == startDate &&
        other.status == status &&
        other.totalTasks == totalTasks;
  }

  @override
  int get hashCode {
    return architrave.hashCode ^
        assignedContractorIds.hashCode ^
        assignedHODId.hashCode ^
        assignedHODName.hashCode ^
        assignedSupervisorIds.hashCode ^
        contractorName.hashCode ^
        createdAt.hashCode ^
        createdBy.hashCode ^
        customerName.hashCode ^
        description.hashCode ^
        doorFrameHardware.hashCode ^
        endDate.hashCode ^
        groupId.hashCode ^
        handover.hashCode ^
        isSetupComplete.hashCode ^
        lastUpdated.hashCode ^
        name.hashCode ^
        priority.hashCode ^
        progress.hashCode ^
        projectAddress.hashCode ^
        projectType.hashCode ^
        startDate.hashCode ^
        status.hashCode ^
        totalTasks.hashCode;
  }
}