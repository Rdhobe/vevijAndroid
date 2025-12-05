import 'package:flutter_test/flutter_test.dart';
import 'package:vevij/models/employee/appstate.dart';

void main() {
  group('AppState', () {
    test('AppState.initial() creates a valid initial state', () {
      final state = AppState.initial();

      expect(state.isLoggedIn, false);
      expect(state.isOnBreak, false);
      expect(state.loginTime, null);
      expect(state.breakStartTime, null);
      expect(state.workDuration, Duration.zero);
      expect(state.totalBreakDurationToday, Duration.zero);
      expect(state.totalDistanceTraveled, 0.0);
      expect(state.showInstructions, true);
      expect(state.userName, 'Unknown');
      expect(state.userId, '');
      expect(state.empId, '');
      expect(state.currentCoordinates, '');
      expect(state.isWaitingForApproval, false);
    });

    test('AppState toMap() serializes all fields correctly', () {
      final loginTime = DateTime(2025, 11, 18, 9, 30);
      final breakStartTime = DateTime(2025, 11, 18, 12, 0);

      final state = AppState(
        isLoggedIn: true,
        isOnBreak: true,
        shift: '9:30 AM - 6:30 PM',
        loginTime: loginTime,
        breakStartTime: breakStartTime,
        workDuration: const Duration(hours: 2),
        totalBreakDurationToday: const Duration(minutes: 15),
        totalDistanceTraveled: 5.5,
        showInstructions: false,
        userName: 'John Doe',
        userId: 'user123',
        empId: 'E001',
        currentCoordinates: '12.34,56.78',
        isWaitingForApproval: false,
        approvalRetryCount: 0,
        todayAttendanceId: 'att123',
        remainingShiftTime: const Duration(hours: 6),
      );

      final map = state.toMap();

      expect(map['isLoggedIn'], true);
      expect(map['isOnBreak'], true);
      expect(map['loginTime'], loginTime.toIso8601String());
      expect(map['breakStartTime'], breakStartTime.toIso8601String());
      expect(map['userName'], 'John Doe');
      expect(map['userId'], 'user123');
      expect(map['empId'], 'E001');
      expect(map['currentCoordinates'], '12.34,56.78');
      expect(map['totalDistanceTraveled'], 5.5);
      expect(map['showInstructions'], false);
      expect(map['isWaitingForApproval'], false);
      expect(map['todayAttendanceId'], 'att123');
    });

    test('AppState.fromMap() deserializes correctly', () {
      final loginTime = DateTime(2025, 11, 18, 9, 30);
      final breakStartTime = DateTime(2025, 11, 18, 12, 0);

      final map = {
        'isLoggedIn': true,
        'isOnBreak': true,
        'loginTime': loginTime.toIso8601String(),
        'breakStartTime': breakStartTime.toIso8601String(),
        'userName': 'Jane Doe',
        'userId': 'user456',
        'empId': 'E002',
        'currentCoordinates': '23.45,67.89',
        'totalDistanceTraveled': 8.25,
        'showInstructions': false,
        'isWaitingForApproval': true,
        'todayAttendanceId': 'att456',
      };

      final state = AppState.fromMap(map);

      expect(state.isLoggedIn, true);
      expect(state.isOnBreak, true);
      expect(state.loginTime, loginTime);
      expect(state.breakStartTime, breakStartTime);
      expect(state.userName, 'Jane Doe');
      expect(state.userId, 'user456');
      expect(state.empId, 'E002');
      expect(state.currentCoordinates, '23.45,67.89');
      expect(state.totalDistanceTraveled, 8.25);
      expect(state.showInstructions, false);
      expect(state.isWaitingForApproval, true);
      expect(state.todayAttendanceId, 'att456');
    });

    test('AppState round-trip serialization preserves data', () {
      final original = AppState(
        isLoggedIn: true,
        isOnBreak: false,
        shift: '9:30 AM - 6:30 PM',
        loginTime: DateTime(2025, 11, 18, 9, 15),
        breakStartTime: null,
        workDuration: const Duration(hours: 3, minutes: 30),
        totalBreakDurationToday: const Duration(minutes: 30),
        totalDistanceTraveled: 12.75,
        showInstructions: false,
        userName: 'Test User',
        userId: 'test_user_123',
        empId: 'E123',
        currentCoordinates: '28.6,77.2',
        isWaitingForApproval: false,
        approvalRetryCount: 0,
        todayAttendanceId: 'att789',
        remainingShiftTime: const Duration(hours: 5, minutes: 15),
      );

      // Serialize
      final map = original.toMap();

      // Deserialize
      final restored = AppState.fromMap(map);

      // Verify all fields match
      expect(restored.isLoggedIn, original.isLoggedIn);
      expect(restored.isOnBreak, original.isOnBreak);
      expect(restored.loginTime, original.loginTime);
      expect(restored.breakStartTime, original.breakStartTime);
      expect(restored.userName, original.userName);
      expect(restored.userId, original.userId);
      expect(restored.empId, original.empId);
      expect(restored.currentCoordinates, original.currentCoordinates);
      expect(restored.totalDistanceTraveled, original.totalDistanceTraveled);
      expect(restored.showInstructions, original.showInstructions);
      expect(restored.isWaitingForApproval, original.isWaitingForApproval);
      expect(restored.todayAttendanceId, original.todayAttendanceId);
    });

    test('AppState copyWith() creates new instance with updated fields', () {
      final original = AppState.initial();
      final now = DateTime.now();

      final updated = original.copyWith(
        isLoggedIn: true,
        loginTime: now,
        userName: 'Updated User',
      );

      // Original should be unchanged
      expect(original.isLoggedIn, false);
      expect(original.loginTime, null);
      expect(original.userName, 'Unknown');

      // New instance should have updated values
      expect(updated.isLoggedIn, true);
      expect(updated.loginTime, now);
      expect(updated.userName, 'Updated User');

      // Other fields should be the same
      expect(updated.isOnBreak, original.isOnBreak);
      expect(updated.workDuration, original.workDuration);
    });

    test('AppState equality works correctly', () {
      final state1 = AppState(
        isLoggedIn: true,
        isOnBreak: false,
        shift: '9:30 AM - 6:30 PM',
        loginTime: DateTime(2025, 11, 18, 9, 30),
        userName: 'Test',
        userId: 'uid1',
        empId: 'E001',
        breakStartTime: null,
        workDuration: const Duration(hours: 2),
        totalBreakDurationToday: Duration.zero,
        totalDistanceTraveled: 0.0,
        showInstructions: false,
        currentCoordinates: '',
        isWaitingForApproval: false,
        approvalRetryCount: 0,
        remainingShiftTime: const Duration(hours: 7),
      );

      final state2 = AppState(
        isLoggedIn: true,
        isOnBreak: false,
        shift: '9:30 AM - 6:30 PM',
        loginTime: DateTime(2025, 11, 18, 9, 30),
        userName: 'Test',
        userId: 'uid1',
        empId: 'E001',
        breakStartTime: null,
        workDuration: const Duration(hours: 2),
        totalBreakDurationToday: Duration.zero,
        totalDistanceTraveled: 0.0,
        showInstructions: false,
        currentCoordinates: '',
        isWaitingForApproval: false,
        approvalRetryCount: 0,
        remainingShiftTime: const Duration(hours: 7),
      );

      final state3 = state1.copyWith(userName: 'Different');

      expect(state1, state2);
      expect(state1, isNot(state3));
    });

    test('AppState handles null values correctly', () {
      final map = {
        'isLoggedIn': false,
        'isOnBreak': false,
        'loginTime': null,
        'breakStartTime': null,
        'userName': '',
        'userId': '',
        'empId': '',
        'currentCoordinates': '',
        'totalDistanceTraveled': 0.0,
        'showInstructions': true,
        'isWaitingForApproval': false,
        'todayAttendanceId': null,
      };

      final state = AppState.fromMap(map);

      expect(state.isLoggedIn, false);
      expect(state.loginTime, null);
      expect(state.breakStartTime, null);
      expect(state.todayAttendanceId, null);
      expect(state.userName.isEmpty, true);
    });
  });
}
