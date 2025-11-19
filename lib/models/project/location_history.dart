import 'package:vevij/components/imports.dart';
class LocationHistory {
  final double accuracy;
  final String activityType;
  final String coordinates;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime timestamp;
  final String userId;
  final String userName;

  LocationHistory({
    required this.accuracy,
    required this.activityType,
    required this.coordinates,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.timestamp,
    required this.userId,
    required this.userName,
  });

  factory LocationHistory.fromMap(Map<String, dynamic> map) {
    return LocationHistory(
      accuracy: (map['accuracy'] ?? 0.0).toDouble(),
      activityType: map['activityType'] ?? '',
      coordinates: map['coordinates'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      status: map['status'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accuracy': accuracy,
      'activityType': activityType,
      'coordinates': coordinates,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'userName': userName,
    };
  }

  LocationHistory copyWith({
    double? accuracy,
    String? activityType,
    String? coordinates,
    double? latitude,
    double? longitude,
    String? status,
    DateTime? timestamp,
    String? userId,
    String? userName,
  }) {
    return LocationHistory(
      accuracy: accuracy ?? this.accuracy,
      activityType: activityType ?? this.activityType,
      coordinates: coordinates ?? this.coordinates,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
    );
  }

  @override
  String toString() {
    return 'LocationHistory(accuracy: $accuracy, activityType: $activityType, coordinates: $coordinates, latitude: $latitude, longitude: $longitude, status: $status, timestamp: $timestamp, userId: $userId, userName: $userName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is LocationHistory &&
      other.accuracy == accuracy &&
      other.activityType == activityType &&
      other.coordinates == coordinates &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.status == status &&
      other.timestamp == timestamp &&
      other.userId == userId &&
      other.userName == userName;
  }

  @override
  int get hashCode {
    return accuracy.hashCode ^
      activityType.hashCode ^
      coordinates.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      status.hashCode ^
      timestamp.hashCode ^
      userId.hashCode ^
      userName.hashCode;
  }
}