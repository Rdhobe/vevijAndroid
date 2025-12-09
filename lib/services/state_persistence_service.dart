import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vevij/models/employee/appstate.dart';
import 'persistence_keys.dart';

class StatePersistenceService {
  static final StatePersistenceService _instance = StatePersistenceService._internal();
  factory StatePersistenceService() => _instance;
  StatePersistenceService._internal();

  static const String _appStateKey = PersistenceKeys.appState;
  static const String _userNameKey = PersistenceKeys.userName;
  static const String _empIdKey = PersistenceKeys.empId;
  static const String _userIdKey = PersistenceKeys.userId;
  // New: explicit shift key so load/save always use same key
  static const String _shiftKey = PersistenceKeys.shift;
  static const String _workLocationKey = PersistenceKeys.workLocation;
  static const String _isWaitingForApprovalKey = PersistenceKeys.isWaitingForApproval;
  static const String _pendingApprovalIdKey = PersistenceKeys.pendingApprovalId;
  static const String _approvalRequestTimeKey = PersistenceKeys.approvalRequestTime;

  Future<void> saveAppState(AppState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateMap = state.toMap();
      
      final stateJson = json.encode(stateMap);
      await prefs.setString(_appStateKey, stateJson);
      
      if (!kReleaseMode) {
        print('✅ App state saved successfully');
      }
    } catch (e) {
      print('❌ Error saving app state: $e');
      rethrow;
    }
  }

  Future<AppState> loadAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString(_appStateKey);
      
      if (stateJson != null) {
        final stateMap = json.decode(stateJson) as Map<String, dynamic>;
        return AppState.fromMap(stateMap);
      }
    } catch (e) {
      print('❌ Error loading app state: $e');
    }
    
    return AppState.initial();
  }

  Future<void> clearAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_appStateKey);
      if (!kReleaseMode) {
        print('✅ App state cleared');
      }
    } catch (e) {
      print('❌ Error clearing app state: $e');
      rethrow;
    }
  }

  Future<void> saveUserData(String userName, String empId, String userId, String shift, String workLocation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userNameKey, userName);
      await prefs.setString(_empIdKey, empId);
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_shiftKey, shift);
      await prefs.setString(_workLocationKey, '');
      if (!kReleaseMode) {
        print('✅ User data saved to cache');
      }
    } catch (e) {
      print('❌ Error saving user data: $e');
      rethrow;
    }
  }

  /// Returns a consistent map with non-null String values.
  /// Keys: 'userName', 'empId', 'userId', 'shift'
  Future<Map<String, String>> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString(_userNameKey) ?? '';
      final empId = prefs.getString(_empIdKey) ?? '';
      final userId = prefs.getString(_userIdKey) ?? '';
      final shift = prefs.getString(_shiftKey) ?? '';
      final workLocation = prefs.getString(_workLocationKey) ?? '';
      return {
        'userName': userName,
        'empId': empId,
        'userId': userId,
        'shift': shift,
        'workLocation': workLocation
      };
    } catch (e) {
      print('❌ Error loading user data: $e');
      return {'userName': '', 'empId': '', 'userId': '', 'shift': '' , 'workLocation': ''};
    }
  }

  Future<void> saveApprovalState({
    required bool isWaitingForApproval,
    required String? pendingApprovalId,
    required DateTime? approvalRequestTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isWaitingForApprovalKey, isWaitingForApproval);
      
      if (pendingApprovalId != null) {
        await prefs.setString(_pendingApprovalIdKey, pendingApprovalId);
      } else {
        await prefs.remove(_pendingApprovalIdKey);
      }
      
      if (approvalRequestTime != null) {
        await prefs.setString(_approvalRequestTimeKey, approvalRequestTime.toIso8601String());
      } else {
        await prefs.remove(_approvalRequestTimeKey);
      }
      
      if (!kReleaseMode) {
        print('✅ Approval state saved');
      }
    } catch (e) {
      print('❌ Error saving approval state: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loadApprovalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isWaitingForApproval = prefs.getBool(_isWaitingForApprovalKey) ?? false;
      final pendingApprovalId = prefs.getString(_pendingApprovalIdKey);
      final approvalRequestTimeStr = prefs.getString(_approvalRequestTimeKey);
      
      DateTime? approvalRequestTime;
      if (approvalRequestTimeStr != null) {
        approvalRequestTime = DateTime.parse(approvalRequestTimeStr);
      }

      return {
        'isWaitingForApproval': isWaitingForApproval,
        'pendingApprovalId': pendingApprovalId,
        'approvalRequestTime': approvalRequestTime,
      };
    } catch (e) {
      print('❌ Error loading approval state: $e');
      return {
        'isWaitingForApproval': false,
        'pendingApprovalId': null,
        'approvalRequestTime': null,
      };
    }
  }

  Future<void> clearApprovalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isWaitingForApprovalKey);
      await prefs.remove(_pendingApprovalIdKey);
      await prefs.remove(_approvalRequestTimeKey);
      
      if (!kReleaseMode) {
        print('✅ Approval state cleared');
      }
    } catch (e) {
      print('❌ Error clearing approval state: $e');
      rethrow;
    }
  }

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!kReleaseMode) {
        print('✅ All data cleared');
      }
    } catch (e) {
      print('❌ Error clearing all data: $e');
      rethrow;
    }
  }
}
