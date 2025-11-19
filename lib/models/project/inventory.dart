import 'package:vevij/components/imports.dart';
import 'package:flutter/foundation.dart';
class Inventory {
  final int balIssueQty;
  final int balanceQty;
  final Map<String, int> categoryBreakdown;
  final DateTime createdAt;
  final String createdBy;
  final List<EditHistory> editHistory;
  final bool isCustomHardware;
  final List<IssuedEntry> issuedEntries;
  final List<ReceivedEntry> receivedEntries;
  final int requiredQty;
  final String source;
  final int totalIssuedQty;
  final int totalReceivedQty;
  final String uom;
  final DateTime updatedAt;
  final int usedQty;

  Inventory({
    required this.balIssueQty,
    required this.balanceQty,
    required this.categoryBreakdown,
    required this.createdAt,
    required this.createdBy,
    required this.editHistory,
    required this.isCustomHardware,
    required this.issuedEntries,
    required this.receivedEntries,
    required this.requiredQty,
    required this.source,
    required this.totalIssuedQty,
    required this.totalReceivedQty,
    required this.uom,
    required this.updatedAt,
    required this.usedQty,
  });

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      balIssueQty: (map['balIssueQty'] ?? 0).toInt(),
      balanceQty: (map['balanceQty'] ?? 0).toInt(),
      categoryBreakdown: Map<String, int>.from(map['categoryBreakdown'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
      editHistory: List<EditHistory>.from(
          (map['editHistory'] ?? []).map((x) => EditHistory.fromMap(x))),
      isCustomHardware: map['isCustomHardware'] ?? false,
      issuedEntries: List<IssuedEntry>.from(
          (map['issuedEntries'] ?? []).map((x) => IssuedEntry.fromMap(x))),
      receivedEntries: List<ReceivedEntry>.from(
          (map['receivedEntries'] ?? []).map((x) => ReceivedEntry.fromMap(x))),
      requiredQty: (map['requiredQty'] ?? 0).toInt(),
      source: map['source'] ?? '',
      totalIssuedQty: (map['totalIssuedQty'] ?? 0).toInt(),
      totalReceivedQty: (map['totalReceivedQty'] ?? 0).toInt(),
      uom: map['uom'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      usedQty: (map['usedQty'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'balIssueQty': balIssueQty,
      'balanceQty': balanceQty,
      'categoryBreakdown': categoryBreakdown,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'editHistory': editHistory.map((x) => x.toMap()).toList(),
      'isCustomHardware': isCustomHardware,
      'issuedEntries': issuedEntries.map((x) => x.toMap()).toList(),
      'receivedEntries': receivedEntries.map((x) => x.toMap()).toList(),
      'requiredQty': requiredQty,
      'source': source,
      'totalIssuedQty': totalIssuedQty,
      'totalReceivedQty': totalReceivedQty,
      'uom': uom,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'usedQty': usedQty,
    };
  }

  Inventory copyWith({
    int? balIssueQty,
    int? balanceQty,
    Map<String, int>? categoryBreakdown,
    DateTime? createdAt,
    String? createdBy,
    List<EditHistory>? editHistory,
    bool? isCustomHardware,
    List<IssuedEntry>? issuedEntries,
    List<ReceivedEntry>? receivedEntries,
    int? requiredQty,
    String? source,
    int? totalIssuedQty,
    int? totalReceivedQty,
    String? uom,
    DateTime? updatedAt,
    int? usedQty,
  }) {
    return Inventory(
      balIssueQty: balIssueQty ?? this.balIssueQty,
      balanceQty: balanceQty ?? this.balanceQty,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      editHistory: editHistory ?? this.editHistory,
      isCustomHardware: isCustomHardware ?? this.isCustomHardware,
      issuedEntries: issuedEntries ?? this.issuedEntries,
      receivedEntries: receivedEntries ?? this.receivedEntries,
      requiredQty: requiredQty ?? this.requiredQty,
      source: source ?? this.source,
      totalIssuedQty: totalIssuedQty ?? this.totalIssuedQty,
      totalReceivedQty: totalReceivedQty ?? this.totalReceivedQty,
      uom: uom ?? this.uom,
      updatedAt: updatedAt ?? this.updatedAt,
      usedQty: usedQty ?? this.usedQty,
    );
  }

  @override
  String toString() {
    return 'Inventory(balanceQty: $balanceQty, requiredQty: $requiredQty, uom: $uom)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Inventory &&
        other.balIssueQty == balIssueQty &&
        other.balanceQty == balanceQty &&
        mapEquals(other.categoryBreakdown, categoryBreakdown) &&
        other.createdAt == createdAt &&
        other.createdBy == createdBy &&
        listEquals(other.editHistory, editHistory) &&
        other.isCustomHardware == isCustomHardware &&
        listEquals(other.issuedEntries, issuedEntries) &&
        listEquals(other.receivedEntries, receivedEntries) &&
        other.requiredQty == requiredQty &&
        other.source == source &&
        other.totalIssuedQty == totalIssuedQty &&
        other.totalReceivedQty == totalReceivedQty &&
        other.uom == uom &&
        other.updatedAt == updatedAt &&
        other.usedQty == usedQty;
  }

  @override
  int get hashCode {
    return balIssueQty.hashCode ^
        balanceQty.hashCode ^
        categoryBreakdown.hashCode ^
        createdAt.hashCode ^
        createdBy.hashCode ^
        editHistory.hashCode ^
        isCustomHardware.hashCode ^
        issuedEntries.hashCode ^
        receivedEntries.hashCode ^
        requiredQty.hashCode ^
        source.hashCode ^
        totalIssuedQty.hashCode ^
        totalReceivedQty.hashCode ^
        uom.hashCode ^
        updatedAt.hashCode ^
        usedQty.hashCode;
  }
}

class EditHistory {
  final List<String> changes;
  final String editDate;
  final String editedBy;
  final String reason;
  final DateTime timestamp;

  EditHistory({
    required this.changes,
    required this.editDate,
    required this.editedBy,
    required this.reason,
    required this.timestamp,
  });

  factory EditHistory.fromMap(Map<String, dynamic> map) {
    return EditHistory(
      changes: List<String>.from(map['changes'] ?? []),
      editDate: map['editDate'] ?? '',
      editedBy: map['editedBy'] ?? '',
      reason: map['reason'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'changes': changes,
      'editDate': editDate,
      'editedBy': editedBy,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  EditHistory copyWith({
    List<String>? changes,
    String? editDate,
    String? editedBy,
    String? reason,
    DateTime? timestamp,
  }) {
    return EditHistory(
      changes: changes ?? this.changes,
      editDate: editDate ?? this.editDate,
      editedBy: editedBy ?? this.editedBy,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class IssuedEntry {
  final String materialName;
  final String projectId;

  IssuedEntry({
    required this.materialName,
    required this.projectId,
  });

  factory IssuedEntry.fromMap(Map<String, dynamic> map) {
    return IssuedEntry(
      materialName: map['materialName'] ?? '',
      projectId: map['projectId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'materialName': materialName,
      'projectId': projectId,
    };
  }

  IssuedEntry copyWith({
    String? materialName,
    String? projectId,
  }) {
    return IssuedEntry(
      materialName: materialName ?? this.materialName,
      projectId: projectId ?? this.projectId,
    );
  }
}

class ReceivedEntry {
  final String challanNo;
  final String date;
  final int qty;
  final int receivedQty;

  ReceivedEntry({
    required this.challanNo,
    required this.date,
    required this.qty,
    required this.receivedQty,
  });

  factory ReceivedEntry.fromMap(Map<String, dynamic> map) {
    return ReceivedEntry(
      challanNo: map['challanNo'] ?? '',
      date: map['date'] ?? '',
      qty: (map['qty'] ?? 0).toInt(),
      receivedQty: (map['receivedQty'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challanNo': challanNo,
      'date': date,
      'qty': qty,
      'receivedQty': receivedQty,
    };
  }

  ReceivedEntry copyWith({
    String? challanNo,
    String? date,
    int? qty,
    int? receivedQty,
  }) {
    return ReceivedEntry(
      challanNo: challanNo ?? this.challanNo,
      date: date ?? this.date,
      qty: qty ?? this.qty,
      receivedQty: receivedQty ?? this.receivedQty,
    );
  }
}