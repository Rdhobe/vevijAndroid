import 'package:intl/intl.dart';
import 'package:vevij/components/imports.dart';
import 'persistence_keys.dart';

class AttendanceStateService {
  static final AttendanceStateService _instance =
      AttendanceStateService._internal();
  factory AttendanceStateService() => _instance;
  AttendanceStateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save attendance state
  Future<void> saveAttendanceState({
    required bool isLoggedIn,
    required bool isOnBreak,
    DateTime? loginTime,
    DateTime? breakStartTime,
    required Duration workDuration,
    required Duration totalBreakDurationToday,
    String? todayAttendanceId,
    String? currentCoordinates,
    required double totalDistanceTraveled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await prefs.setBool(PersistenceKeys.attendanceIsLoggedIn, isLoggedIn);
      await prefs.setBool(PersistenceKeys.attendanceIsOnBreak, isOnBreak);
      await prefs.setString(PersistenceKeys.attendanceSavedDate, today);

      if (loginTime != null) {
        await prefs.setString(
          PersistenceKeys.attendanceLoginTime,
          loginTime.toIso8601String(),
        );
      } else {
        await prefs.remove(PersistenceKeys.attendanceLoginTime);
      }

      if (breakStartTime != null) {
        await prefs.setString(
          PersistenceKeys.attendanceBreakStartTime,
          breakStartTime.toIso8601String(),
        );
      } else {
        await prefs.remove(PersistenceKeys.attendanceBreakStartTime);
      }

      await prefs.setInt(
        PersistenceKeys.attendanceWorkDurationSeconds,
        workDuration.inSeconds,
      );
      await prefs.setInt(
        PersistenceKeys.attendanceTotalBreakSeconds,
        totalBreakDurationToday.inSeconds,
      );

      if (todayAttendanceId != null) {
        await prefs.setString(PersistenceKeys.attendanceTodayId, todayAttendanceId);
      } else {
        await prefs.remove(PersistenceKeys.attendanceTodayId);
      }

      if (currentCoordinates != null) {
        await prefs.setString(
          PersistenceKeys.attendanceCurrentCoordinates,
          currentCoordinates,
        );
      } else {
        await prefs.remove(PersistenceKeys.attendanceCurrentCoordinates);
      }

      await prefs.setDouble(PersistenceKeys.attendanceTotalDistance, totalDistanceTraveled);

      // ALSO write the simple background keys to keep compatibility with the background service
      await prefs.setBool(PersistenceKeys.bgIsLoggedIn, isLoggedIn);
      if (loginTime != null) await prefs.setString(PersistenceKeys.bgLoginTime, loginTime.toIso8601String());
      await prefs.setBool(PersistenceKeys.bgIsOnBreak, isOnBreak);
      if (breakStartTime != null) await prefs.setString(PersistenceKeys.bgBreakStartTime, breakStartTime.toIso8601String());
      await prefs.setInt(PersistenceKeys.bgTotalBreakDurationSeconds, totalBreakDurationToday.inSeconds);

      debugPrint('Attendance state saved successfully');
    } catch (e) {
      debugPrint('Error saving attendance state: $e');
    }
  }

  // Load attendance state
  Future<Map<String, dynamic>> loadAttendanceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final savedDate = prefs.getString('attendance_saved_date');

      // Clear state if it's from a different day
      if (savedDate != today) {
        await clearAttendanceState();
        return _getDefaultState();
      }

      final isLoggedIn = prefs.getBool(PersistenceKeys.attendanceIsLoggedIn) ?? false;
      if (!isLoggedIn) {
        return _getDefaultState();
      }

      DateTime? loginTime;
      final loginTimeStr = prefs.getString(PersistenceKeys.attendanceLoginTime);
      if (loginTimeStr != null) {
        loginTime = DateTime.parse(loginTimeStr);
      }

      DateTime? breakStartTime;
      final breakStartTimeStr = prefs.getString(PersistenceKeys.attendanceBreakStartTime);
      if (breakStartTimeStr != null) {
        breakStartTime = DateTime.parse(breakStartTimeStr);
      }

      return {
        'isLoggedIn': isLoggedIn,
        'isOnBreak': prefs.getBool(PersistenceKeys.attendanceIsOnBreak) ?? false,
        'loginTime': loginTime,
        'breakStartTime': breakStartTime,
        'workDuration': Duration(
          seconds: prefs.getInt(PersistenceKeys.attendanceWorkDurationSeconds) ?? 0,
        ),
        'totalBreakDurationToday': Duration(
          seconds: prefs.getInt(PersistenceKeys.attendanceTotalBreakSeconds) ?? 0,
        ),
        'todayAttendanceId': prefs.getString(PersistenceKeys.attendanceTodayId),
        'currentCoordinates': prefs.getString(PersistenceKeys.attendanceCurrentCoordinates),
        'totalDistanceTraveled':
            prefs.getDouble(PersistenceKeys.attendanceTotalDistance) ?? 0.0,
      };
    } catch (e) {
      debugPrint('Error loading attendance state: $e');
      return _getDefaultState();
    }
  }

  // Clear attendance state
  Future<void> clearAttendanceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        PersistenceKeys.attendanceIsLoggedIn,
        PersistenceKeys.attendanceIsOnBreak,
        PersistenceKeys.attendanceLoginTime,
        PersistenceKeys.attendanceBreakStartTime,
        PersistenceKeys.attendanceWorkDurationSeconds,
        PersistenceKeys.attendanceTotalBreakSeconds,
        PersistenceKeys.attendanceTodayId,
        PersistenceKeys.attendanceCurrentCoordinates,
        PersistenceKeys.attendanceTotalDistance,
        PersistenceKeys.attendanceSavedDate,
      ];

      for (final key in keys) {
        await prefs.remove(key);
      }

      debugPrint('Attendance state cleared successfully');
    } catch (e) {
      debugPrint('Error clearing attendance state: $e');
    }
  }

  // Sync with Firestore
  Future<Map<String, dynamic>?> syncWithFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final today = DateFormat('dd-MMM-yy').format(DateTime.now());

      final querySnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      final inTime = data['inTime'];
      final outTime = data['outTime'];
      final isCurrentlyOnBreak = data['isOnBreak'] ?? false;

      if (inTime != null && outTime == null) {
        // User is logged in
        final loginTime = _parseTimeToToday(inTime);
        final totalBreakSeconds = data['totalBreakSeconds'] ?? 0;
        final totalBreakDurationToday = Duration(seconds: totalBreakSeconds);

        DateTime? breakStartTime;
        if (isCurrentlyOnBreak && data['breakStartTime'] != null) {
          breakStartTime = _parseTimeToToday(data['breakStartTime']);
        }

        // Calculate work duration
        final totalWork = DateTime.now().difference(loginTime);
        Duration workDuration;

        if (isCurrentlyOnBreak && breakStartTime != null) {
          final currentBreak = DateTime.now().difference(breakStartTime);
          workDuration = totalWork - totalBreakDurationToday - currentBreak;
        } else {
          workDuration = totalWork - totalBreakDurationToday;
        }

        return {
          'isLoggedIn': true,
          'isOnBreak': isCurrentlyOnBreak,
          'loginTime': loginTime,
          'breakStartTime': breakStartTime,
          'workDuration': workDuration,
          'totalBreakDurationToday': totalBreakDurationToday,
          'todayAttendanceId': doc.id,
          'currentCoordinates': data['coordinates'],
          'totalDistanceTraveled': (data['totalDistanceTraveled'] ?? 0.0)
              .toDouble(),
        };
      } else if (outTime != null) {
        // User has logged out
        return _getDefaultState();
      }

      return null;
    } catch (e) {
      debugPrint('Error syncing with Firestore: $e');
      return null;
    }
  }

  // Parse time string to today's DateTime
  DateTime _parseTimeToToday(String timeStr) {
    try {
      final now = DateTime.now();
      final format = DateFormat('h:mm a');
      final parsed = format.parse(timeStr);
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      debugPrint('Error parsing time: $timeStr - $e');
      return DateTime.now();
    }
  }

  // Get default state
  Map<String, dynamic> _getDefaultState() {
    return {
      'isLoggedIn': false,
      'isOnBreak': false,
      'loginTime': null,
      'breakStartTime': null,
      'workDuration': Duration.zero,
      'totalBreakDurationToday': Duration.zero,
      'todayAttendanceId': null,
      'currentCoordinates': null,
      'totalDistanceTraveled': 0.0,
    };
  }
}
