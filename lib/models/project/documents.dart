import 'package:vevij/components/imports.dart';

class Document {
  final String designation;
  final String name;
  final String storagePath;
  final DateTime timestamp;
  final String uploadedBy;
  final String url;

  Document({
    required this.designation,
    required this.name,
    required this.storagePath,
    required this.timestamp,
    required this.uploadedBy,
    required this.url,
  });

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      designation: map['designation'] ?? '',
      name: map['name'] ?? '',
      storagePath: map['storagePath'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      uploadedBy: map['uploadedBy'] ?? '',
      url: map['url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'designation': designation,
      'name': name,
      'storagePath': storagePath,
      'timestamp': Timestamp.fromDate(timestamp),
      'uploadedBy': uploadedBy,
      'url': url,
    };
  }

  Document copyWith({
    String? designation,
    String? name,
    String? storagePath,
    DateTime? timestamp,
    String? uploadedBy,
    String? url,
  }) {
    return Document(
      designation: designation ?? this.designation,
      name: name ?? this.name,
      storagePath: storagePath ?? this.storagePath,
      timestamp: timestamp ?? this.timestamp,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      url: url ?? this.url,
    );
  }

  @override
  String toString() {
    return 'Document(name: $name, designation: $designation, uploadedBy: $uploadedBy, url: $url)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Document &&
        other.designation == designation &&
        other.name == name &&
        other.storagePath == storagePath &&
        other.timestamp == timestamp &&
        other.uploadedBy == uploadedBy &&
        other.url == url;
  }

  @override
  int get hashCode {
    return designation.hashCode ^
        name.hashCode ^
        storagePath.hashCode ^
        timestamp.hashCode ^
        uploadedBy.hashCode ^
        url.hashCode;
  }
}