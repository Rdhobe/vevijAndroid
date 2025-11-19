// import 'package:flutter_test/flutter_test.dart';
// import 'package:vevij/models/employee/attendance_model.dart';

// void main() {
//   group('Attendance Model', () {
//     test('Attendance.initial() creates a valid initial instance', () {
//       final attendance = Attendance.initial();

//       expect(attendance.id, isNull);
//       expect(attendance.userId, isEmpty);
//       expect(attendance.userName, isEmpty);
//       expect(attendance.empId, isEmpty);
//       expect(attendance.date, isNotEmpty);
//       expect(attendance.inTime, isNull);
//       expect(attendance.outTime, isNull);
//       expect(attendance.isOnBreak, false);
//       expect(attendance.totalBreakSeconds, 0);
//     });

//     test('Attendance.fromFirestore() deserializes Firestore document correctly', () {
//       final firestoreData = {
//         'userId': 'user123',
//         'userName': 'John Doe',
//         'empId': 'E001',
//         'date': '18-Nov-25',
//         'day': 'Mon',
//         'inTime': '09:30 AM',
//         'outTime': '06:30 PM',
//         'totHrs': 8.5,
//         'lateHrs': 0.0,
//         'lateMark': 0.0,
//         'otHrs': 0.5,
//         'type1': 'DP',
//         'portion': 1.0,
//         'type2': '---',
//         'coordinates': '28.6,77.2',
//         'totalDistanceTraveled': 12.5,
//         'isOnBreak': false,
//         'totalBreakSeconds': 900,
//         'breakStartTime': '12:00 PM',
//         'totalBreakTime': '00:15:00',
//         'lastBreakDuration': '00:15:00',
//       };

//       final attendance = Attendance.fromFirestore(
//         firestoreData as Map<String, dynamic>,
//         'attendance_doc_123',
//       );

//       expect(attendance.id, 'attendance_doc_123');
//       expect(attendance.userId, 'user123');
//       expect(attendance.userName, 'John Doe');
//       expect(attendance.empId, 'E001');
//       expect(attendance.date, '18-Nov-25');
//       expect(attendance.day, 'Mon');
//       expect(attendance.inTime, '09:30 AM');
//       expect(attendance.outTime, '06:30 PM');
//       expect(attendance.totHrs, 8.5);
//       expect(attendance.isOnBreak, false);
//       expect(attendance.totalBreakSeconds, 900);
//     });

//     test('Attendance.toMap() serializes all fields correctly', () {
//       final attendance = Attendance(
//         id: 'att123',
//         userId: 'user456',
//         userName: 'Jane Doe',
//         empId: 'E002',
//         date: '19-Nov-25',
//         day: 'Tue',
//         inTime: '09:45 AM',
//         outTime: '06:45 PM',
//         totHrs: 8.0,
//         lateHrs: 0.25,
//         lateMark: 1.0,
//         otHrs: 0.0,
//         type1: 'DP',
//         portion: 1.0,
//         type2: '---',
//         coordinates: '28.7,77.3',
//         totalDistanceTraveled: 15.0,
//         isOnBreak: false,
//         totalBreakSeconds: 1800,
//         breakStartTime: '12:30 PM',
//         totalBreakTime: '00:30:00',
//       );

//       final map = attendance.toMap();

//       expect(map['userId'], 'user456');
//       expect(map['userName'], 'Jane Doe');
//       expect(map['empId'], 'E002');
//       expect(map['date'], '19-Nov-25');
//       expect(map['inTime'], '09:45 AM');
//       expect(map['outTime'], '06:45 PM');
//       expect(map['totHrs'], 8.0);
//       expect(map['lateHrs'], 0.25);
//       expect(map['lateMark'], 1.0);
//       expect(map['isOnBreak'], false);
//       expect(map['totalBreakSeconds'], 1800);
//       expect(map['totalDistanceTraveled'], 15.0);
//     });

//     test('Attendance round-trip (fromFirestore -> toMap) preserves data', () {
//       final originalData = {
//         'userId': 'user789',
//         'userName': 'Bob Smith',
//         'empId': 'E003',
//         'date': '20-Nov-25',
//         'day': 'Wed',
//         'inTime': '09:30 AM',
//         'outTime': '06:30 PM',
//         'totHrs': 9.0,
//         'lateHrs': 0.0,
//         'lateMark': 0.0,
//         'otHrs': 1.0,
//         'type1': 'DP',
//         'portion': 1.0,
//         'type2': '---',
//         'coordinates': '28.5,77.1',
//         'totalDistanceTraveled': 20.0,
//         'isOnBreak': false,
//         'totalBreakSeconds': 0,
//         'breakStartTime': null,
//         'totalBreakTime': '00:00:00',
//       };

//       // Deserialize from Firestore
//       final attendance = Attendance.fromFirestore(
//         originalData as Map<String, dynamic>,
//         'doc_789',
//       );

//       // Serialize to map
//       final serialized = attendance.toMap();

//       // Verify key fields
//       expect(serialized['userId'], originalData['userId']);
//       expect(serialized['userName'], originalData['userName']);
//       expect(serialized['date'], originalData['date']);
//       expect(serialized['inTime'], originalData['inTime']);
//       expect(serialized['outTime'], originalData['outTime']);
//       expect(serialized['totHrs'], originalData['totHrs']);
//       expect(serialized['totalDistanceTraveled'], originalData['totalDistanceTraveled']);
//     });

//     test('Attendance handles null values correctly', () {
//       final firestoreData = {
//         'userId': 'user_null_test',
//         'userName': 'Null Tester',
//         'empId': 'E999',
//         'date': '21-Nov-25',
//         'inTime': null,
//         'outTime': null,
//         'breakStartTime': null,
//         'coordinates': null,
//         'totalDistanceTraveled': 0.0,
//         'isOnBreak': false,
//         'totalBreakSeconds': 0,
//       };

//       final attendance = Attendance.fromFirestore(
//         firestoreData as Map<String, dynamic>,
//         'null_test_doc',
//       );

//       expect(attendance.inTime, isNull);
//       expect(attendance.outTime, isNull);
//       expect(attendance.breakStartTime, isNull);
//       expect(attendance.coordinates, isNull);
//       expect(attendance.totalDistanceTraveled, 0.0);
//     });

//     test('Attendance equality works correctly', () {
//       final att1 = Attendance(
//         id: 'att_eq_1',
//         userId: 'eq_user_1',
//         userName: 'Equality Test 1',
//         empId: 'EQ001',
//         date: '22-Nov-25',
//         inTime: '09:30 AM',
//         outTime: '06:30 PM',
//         totHrs: 9.0,
//         lateHrs: 0.0,
//         lateMark: 0.0,
//         otHrs: 0.0,
//         type1: 'DP',
//         portion: 1.0,
//         isOnBreak: false,
//         totalBreakSeconds: 0,
//       );

//       final att2 = Attendance(
//         id: 'att_eq_1',
//         userId: 'eq_user_1',
//         userName: 'Equality Test 1',
//         empId: 'EQ001',
//         date: '22-Nov-25',
//         inTime: '09:30 AM',
//         outTime: '06:30 PM',
//         totHrs: 9.0,
//         lateHrs: 0.0,
//         lateMark: 0.0,
//         otHrs: 0.0,
//         type1: 'DP',
//         portion: 1.0,
//         isOnBreak: false,
//         totalBreakSeconds: 0,
//       );

//       final att3 = att1.copyWith(userName: 'Different Name');

//       expect(att1, att2);
//       expect(att1, isNot(att3));
//     });

//     test('Attendance copyWith() creates new instance with updated fields', () {
//       final original = Attendance.initial();

//       final updated = original.copyWith(
//         userId: 'copy_user_1',
//         userName: 'Copy Test User',
//         inTime: '09:30 AM',
//       );

//       // Original should be unchanged
//       expect(original.userId, isEmpty);
//       expect(original.userName, isEmpty);
//       expect(original.inTime, isNull);

//       // New instance should have updated values
//       expect(updated.userId, 'copy_user_1');
//       expect(updated.userName, 'Copy Test User');
//       expect(updated.inTime, '09:30 AM');

//       // Other fields should be preserved
//       expect(updated.date, original.date);
//       expect(updated.isOnBreak, original.isOnBreak);
//     });

//     test('Attendance calculations: late hours and marks', () {
//       final att = Attendance(
//         id: 'calc_test_1',
//         userId: 'calc_user',
//         userName: 'Calculator',
//         empId: 'CALC01',
//         date: '23-Nov-25',
//         inTime: '09:45 AM',
//         lateHrs: 0.25, // 15 minutes late
//         lateMark: 1.0, // Marked as late
//         totHrs: 8.5,
//         type1: 'DP',
//         portion: 1.0,
//         isOnBreak: false,
//         totalBreakSeconds: 1200, // 20 minutes
//       );

//       expect(att.lateHrs, 0.25);
//       expect(att.lateMark, 1.0);
//       expect(att.totalBreakSeconds, 1200);
//       expect(att.totHrs, 8.5);
//     });

//     test('Attendance handles break tracking', () {
//       final attWithBreak = Attendance(
//         id: 'break_test_1',
//         userId: 'break_user',
//         userName: 'Break Tracker',
//         empId: 'BRK01',
//         date: '24-Nov-25',
//         inTime: '09:30 AM',
//         outTime: '06:30 PM',
//         isOnBreak: false,
//         breakStartTime: '12:00 PM',
//         totalBreakSeconds: 1800, // 30 minutes
//         totalBreakTime: '00:30:00',
//         lastBreakDuration: '00:30:00',
//       );

//       expect(attWithBreak.isOnBreak, false);
//       expect(attWithBreak.breakStartTime, '12:00 PM');
//       expect(attWithBreak.totalBreakSeconds, 1800);
//       expect(attWithBreak.totalBreakTime, '00:30:00');
//     });
//   });
// }
