class PersistenceKeys {
  // AppState
  static const String appState = 'appState';
  static const String userName = 'userName';
  static const String empId = 'empId';
  static const String userId = 'userId';

  // Approval state
  static const String isWaitingForApproval = 'isWaitingForApproval';
  static const String pendingApprovalId = 'pendingApprovalId';
  static const String approvalRequestTime = 'approvalRequestTime';

  // Background service / simple keys used by background worker
  static const String bgIsLoggedIn = 'isLoggedIn';
  static const String bgLoginTime = 'loginTime';
  static const String bgIsOnBreak = 'isOnBreak';
  static const String bgBreakStartTime = 'breakStartTime';
  static const String bgTotalBreakDurationSeconds = 'totalBreakDurationToday';

  // Attendance state service keys (legacy prefix)
  static const String attendanceIsLoggedIn = 'attendance_is_logged_in';
  static const String attendanceIsOnBreak = 'attendance_is_on_break';
  static const String attendanceSavedDate = 'attendance_saved_date';
  static const String attendanceLoginTime = 'attendance_login_time';
  static const String attendanceBreakStartTime = 'attendance_break_start_time';
  static const String attendanceWorkDurationSeconds = 'attendance_work_duration_seconds';
  static const String attendanceTotalBreakSeconds = 'attendance_total_break_seconds';
  static const String attendanceTodayId = 'attendance_today_id';
  static const String attendanceCurrentCoordinates = 'attendance_current_coordinates';
  static const String attendanceTotalDistance = 'attendance_total_distance';
}
