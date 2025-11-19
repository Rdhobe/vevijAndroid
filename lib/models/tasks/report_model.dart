import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String generatedBy;
  final DateTime generatedAt;
  final Map<String, dynamic> filters;
  final Map<String, dynamic> summaryStats;
  final Map<String, dynamic> chartData;
  final String reportName;
  final String reportType;

  ReportModel({
    required this.id,
    required this.generatedBy,
    required this.generatedAt,
    required this.filters,
    required this.summaryStats,
    required this.chartData,
    required this.reportName,
    required this.reportType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'generatedBy': generatedBy,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'filters': filters,
      'summaryStats': summaryStats,
      'chartData': chartData,
      'reportName': reportName,
      'reportType': reportType,
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] ?? '',
      generatedBy: map['generatedBy'] ?? '',
      generatedAt: (map['generatedAt'] as Timestamp).toDate(),
      filters: Map<String, dynamic>.from(map['filters'] ?? {}),
      summaryStats: Map<String, dynamic>.from(map['summaryStats'] ?? {}),
      chartData: Map<String, dynamic>.from(map['chartData'] ?? {}),
      reportName: map['reportName'] ?? '',
      reportType: map['reportType'] ?? '',
    );
  }

  ReportModel copyWith({
    String? id,
    String? generatedBy,
    DateTime? generatedAt,
    Map<String, dynamic>? filters,
    Map<String, dynamic>? summaryStats,
    Map<String, dynamic>? chartData,
    String? reportName,
    String? reportType,
  }) {
    return ReportModel(
      id: id ?? this.id,
      generatedBy: generatedBy ?? this.generatedBy,
      generatedAt: generatedAt ?? this.generatedAt,
      filters: filters ?? this.filters,
      summaryStats: summaryStats ?? this.summaryStats,
      chartData: chartData ?? this.chartData,
      reportName: reportName ?? this.reportName,
      reportType: reportType ?? this.reportType,
    );
  }
}