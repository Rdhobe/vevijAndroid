
// import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vevij/models/employee/appstate.dart';
import 'package:vevij/services/persistence_keys.dart';
import 'package:vevij/services/state_persistence_service.dart';
import 'package:vevij/models/employee/employee.dart';
import 'package:vevij/models/employee/attendance_model.dart';
import 'dart:async' show Timer, StreamSubscription, TimeoutException, unawaited;
// If your Attendance model does not have these fields, adapt accordingly:
// Attendance: id, inTime (String), outTime (String), isOnBreak (bool), totalBreakSeconds (int),
// totalDistanceTraveled (double), loginTimestamp (Timestamp?), breakStartTimestamp (Timestamp?)

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ----------------------------
  // State & Services
  // ----------------------------
  AppState _state = AppState.initial();
  final StatePersistenceService _stateService = StatePersistenceService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ----------------------------
  // Guards & Flags
  // ----------------------------
  bool _isDisposed = false;
  bool _isLoggingIn = false;
  bool _isLoggingOut = false;
  bool _isSyncing = false;
  bool _isGettingLocation = false;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  // ----------------------------
  // Timers
  // ----------------------------
  Timer? _workTimer;
  Timer? _syncTimer;
  Timer? _locationTimer;
  Timer? _saveStateDebounceTimer;
  Timer? _approvalTimeoutTimer;

  // ----------------------------
  // Animation controllers
  // ----------------------------
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // ----------------------------
  // Location & positioning
  // ----------------------------
  Position? _currentPosition;
  Position? _lastStoredPosition;
  bool _locationEnabled = false;

  // ----------------------------
  // Subscriptions
  // ----------------------------
  StreamSubscription<DocumentSnapshot>? _approvalListener;
  StreamSubscription<DocumentSnapshot>? _userDataListener;
  StreamSubscription<QuerySnapshot>? _approvalPollingSubscription;
  StreamSubscription<DocumentSnapshot>?
  _attendanceListener; // Realtime sync listener

  // ----------------------------
  // Perf & throttles
  // ----------------------------
  DateTime _lastLocationUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastLocationStore = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastNotificationUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  // DateTime? _lastTimerTick;

  static const Duration _locationUpdateInterval = Duration(seconds: 10);
  static const Duration _locationStoreInterval = Duration(seconds: 30);
  static const Duration _notificationUpdateInterval = Duration(seconds: 10);
  static const Duration _syncInterval = Duration(seconds: 60);
  static const Duration _workTimerInterval = Duration(seconds: 1);
  static const Duration _snackDebounce = Duration(seconds: 4);

  static const int _attendanceNotificationId = 1;

  // Snack dedupe
  String? _lastSnackMessage;
  DateTime? _lastSnackTime;

  // Server time cache (offset: serverUtc - deviceUtc)
  Duration? _serverTimeOffset;
  DateTime? _lastServerOffsetFetch;

  // ----------------------------
  // Lifecycle
  // ----------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  void _startInstructionsTimer() {
    Timer(const Duration(seconds: 10), () {
      if (mounted && !_isDisposed && !_state.isLoggedIn) {
        setState(() {
          _state = _state.copyWith(showInstructions: false);
        });
      }
    });
  }

  Future<void> _initializeApp() async {
    if (_isDisposed) return;
    try {
      // 1) Load persisted state
      try {
        _state = await _stateService.loadAppState();
      } catch (e, st) {
        _logError('Failed to load state', e, st);
      }

      // 2) Animations
      _pulseController = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      );
      _slideController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );

      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      );
      _slideAnimation =
          Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
            CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
          );

      if (!_state.isLoggedIn) _pulseController.repeat(reverse: true);
      _slideController.forward();

      // 3) Prefetch server time (best-effort)
      unawaited(_fetchAndCacheServerTime());

      // 4) Services init
      await _initializeNotifications();
      await _checkLocationPermission();
      await _initializeUserData();
      await _initializeBackgroundService();

      // 5) Start periodic tasks
      _startPeriodicSync();
      _startPeriodicStateSave();
      _startInstructionsTimer();

      // 6) Recover approval state
      await _recoverApprovalState();

      // 7) If user was logged in and not waiting for approval, restore session
      if (_state.isLoggedIn &&
          _state.loginTime != null &&
          !_state.isWaitingForApproval) {
        _startWorkTimer();
        _startLocationTracking();
        _startRealtimeAttendanceListener(); // Start realtime sync
        unawaited(_updateNotification());
      }

      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, st) {
      _logError('Error initializing app', e, st);
      _handleError('Failed to initialize app. Please restart.');
    }
  }

  // ----------------------------
  // Safe state helpers
  // ----------------------------
  bool _safeToUpdate() => mounted && !_isDisposed;

  bool _safeSetState(VoidCallback fn) {
    if (_safeToUpdate()) {
      setState(fn);
      return true;
    }
    return false;
  }

  void _updateState(AppState newState) {
    if (!_safeToUpdate()) return;
    if (newState == _state) return;
    _safeSetState(() {
      _state = newState;
    });

    _saveStateDebounceTimer?.cancel();
    _saveStateDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed) {
        try {
          _stateService.saveAppState(newState);
        } catch (e, st) {
          _logError('Error saving state', e, st);
        }
      }
    });
  }

  void _handleError(String message) {
    if (_safeToUpdate()) {
      _safeSetState(() {
        _hasError = true;
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  // ----------------------------
  // Server time helpers
  // ----------------------------
  Future<DateTime> _fetchAndCacheServerTime({
    Duration ttl = const Duration(minutes: 10),
  }) async {
    // Only refresh if stale
    if (_lastServerOffsetFetch != null &&
        DateTime.now().difference(_lastServerOffsetFetch!) < ttl &&
        _serverTimeOffset != null) {
      return DateTime.now().toUtc().add(_serverTimeOffset!).toLocal();
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('_server_time_tmp')
          .doc();
      await docRef.set({'ts': FieldValue.serverTimestamp()});
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data != null && data['ts'] is Timestamp) {
        final Timestamp ts = data['ts'] as Timestamp;
        final DateTime serverUtc = ts.toDate().toUtc();
        final DateTime deviceUtc = DateTime.now().toUtc();
        _serverTimeOffset = serverUtc.difference(deviceUtc);
        _lastServerOffsetFetch = DateTime.now();
        try {
          await docRef.delete();
        } catch (_) {}
        return DateTime.now().toUtc().add(_serverTimeOffset!).toLocal();
      }
    } catch (e, st) {
      _logError('Failed to fetch server time', e, st);
    }
    return DateTime.now();
  }

  DateTime _nowUsingServerOffset() {
    if (_serverTimeOffset != null) {
      return DateTime.now().toUtc().add(_serverTimeOffset!).toLocal();
    }
    return DateTime.now();
  }

  Future<DateTime> _nowAlignedToServer() async {
    if (_serverTimeOffset == null ||
        _lastServerOffsetFetch == null ||
        DateTime.now().difference(_lastServerOffsetFetch!) >
            const Duration(minutes: 10)) {
      await _fetchAndCacheServerTime();
    }
    return _nowUsingServerOffset();
  }

  // ----------------------------
  // Notifications
  // ----------------------------
  Future<void> _initializeNotifications() async {
    try {
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
      );
      await _notificationsPlugin.initialize(initSettings);

      try {
        final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
        await firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (e) {
        _logError('FCM permission request failed', e, null);
      }
    } catch (e, st) {
      _logError('Error initializing notifications', e, st);
    }
  }

  Future<void> _updateNotification() async {
    if (!_safeToUpdate()) return;
    try {
      if (!_state.isLoggedIn) {
        await _notificationsPlugin.cancel(_attendanceNotificationId);
        return;
      }

      final DateTime now = _nowUsingServerOffset();
      final String dateStr = DateFormat('dd MMM yyyy').format(now);
      final String title = 'Attendance Tracker - ${_state.userName}';
      final String body;
      if (_state.isOnBreak) {
        final Duration currentBreakDuration = _state.breakStartTime != null
            ? now.difference(_state.breakStartTime!)
            : Duration.zero;
        body =
            '$dateStr\n🟠 On Break: ${_formatDuration(currentBreakDuration)}\n⏰ Work: ${_formatDuration(_state.workDuration)}';
      } else {
        body =
            '$dateStr\n🔵 Working: ${_formatDuration(_state.workDuration)}\n☕ Break: ${_formatDuration(_state.totalBreakDurationToday)}\n📍 Distance: ${_state.totalDistanceTraveled.toStringAsFixed(2)} km';
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'attendance_tracker',
            'Attendance Tracker',
            channelDescription: 'Shows current work and break time',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            onlyAlertOnce: true,
            styleInformation: BigTextStyleInformation(''),
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );
      await _notificationsPlugin.show(1, title, body, notificationDetails);
    } catch (e, st) {
      _logError('Error updating notification', e, st);
    }
  }

  // ----------------------------
  // Location permission & tracking
  // ----------------------------
  Future<void> _checkLocationPermission() async {
    if (_isDisposed) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (_safeToUpdate())
          {_updateState(
            _state.copyWith(currentCoordinates: 'Location service disabled'),
          );}
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (_safeToUpdate())
           { _updateState(
              _state.copyWith(currentCoordinates: 'Location permission denied'),
            );}
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (_safeToUpdate())
          {_updateState(
            _state.copyWith(
              currentCoordinates: 'Location permission permanently denied',
            ),
          );}
        return;
      }
      if (_safeToUpdate()) {
        _safeSetState(() {
          _locationEnabled = true;
        });
      }
    } catch (e, st) {
      _logError('Error checking location permission', e, st);
      if (_safeToUpdate())
        {_updateState(
          _state.copyWith(currentCoordinates: 'Error checking location'),
        );}
    }
  }

  void _startLocationTracking() {
    if (!_safeToUpdate() || !_state.isLoggedIn) return;
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(_locationUpdateInterval, (timer) async {
      if (_isDisposed || !_state.isLoggedIn) {
        timer.cancel();
        _locationTimer = null;
        return;
      }
      try {
        await _getCurrentLocation();
      } catch (e, st) {
        _logError('Error in location timer', e, st);
      }
    });

    unawaited(_getCurrentLocation());
  }

  Future<void> _getCurrentLocation() async {
    if (_isDisposed) return;
    if (_isGettingLocation) return;
    if (DateTime.now().difference(_lastLocationUpdate) <
        _locationUpdateInterval)
      {return;}

    _isGettingLocation = true;
    try {
      if (!_locationEnabled) {
        await _checkLocationPermission();
        if (!_locationEnabled) return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      ).timeout(const Duration(seconds: 15));
      if (_isDisposed) return;

      _currentPosition = pos;
      final String coords =
          '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      _updateState(_state.copyWith(currentCoordinates: coords));

      double distanceMeters = 0.0;
      if (_lastStoredPosition != null) {
        distanceMeters = _calculateDistance(
          _lastStoredPosition!,
          _currentPosition!,
        ); // meters
      }

      // if significant movement, update local total
      if (distanceMeters > 10) {
        final double km = distanceMeters / 1000.0;
        _updateState(
          _state.copyWith(
            totalDistanceTraveled: _state.totalDistanceTraveled + km,
          ),
        );
      }

      // update users collection (throttle by store interval or significant movement)
      final DateTime now = _nowUsingServerOffset();
      if (now.difference(_lastLocationStore) >= _locationStoreInterval ||
          distanceMeters > 50) {
        if (_safeToUpdate() && _state.userId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_state.userId)
                .update({
                  'currentLocation': coords,
                  'lastLocationUpdate': FieldValue.serverTimestamp(),
                  'isCurrentlyWorking': _state.isLoggedIn,
                  'isOnBreak': _state.isOnBreak,
                  'workStatus': _state.isOnBreak ? 'On Break' : 'Working',
                  'todayLoginTime': _state.loginTime?.toIso8601String(),
                  'currentWorkDuration': _formatDuration(_state.workDuration),
                  'currentBreakDuration': _formatDuration(
                    _state.totalBreakDurationToday,
                  ),
                  'totalDistanceTraveled': _state.totalDistanceTraveled,
                });
          } catch (e) {
            _logError('Error updating user realtime location', e, null);
          }
        }
      }

      // store history (rate-limited)
      if (_state.isLoggedIn && _state.todayAttendanceId != null) {
        await _storeLocationInHistory(
          _state.isOnBreak ? 'on_break' : 'working',
        );
      }

      _lastLocationUpdate = DateTime.now();
    } on TimeoutException {
      _updateState(_state.copyWith(currentCoordinates: 'Location timeout'));
    } catch (e, st) {
      _logError('Error getting location', e, st);
      _updateState(_state.copyWith(currentCoordinates: 'Location unavailable'));
    } finally {
      _isGettingLocation = false;
    }
  }

  Future<void> _storeLocationInHistory(String activityType) async {
    if (DateTime.now().difference(_lastLocationStore) < _locationStoreInterval)
      {return;}
    if (_isDisposed ||
        !_state.isLoggedIn ||
        _state.currentCoordinates.isEmpty ||
        _state.todayAttendanceId == null)
      {return;}

    try {
      double distanceMeters = 0.0;
      if (_lastStoredPosition != null && _currentPosition != null) {
        distanceMeters = _calculateDistance(
          _lastStoredPosition!,
          _currentPosition!,
        );
      }

      final bool shouldWrite =
          distanceMeters > 5 ||
          activityType == 'login' ||
          activityType == 'logout' ||
          activityType == 'break_start' ||
          activityType == 'break_end';
      if (!shouldWrite) {
        _lastLocationStore = DateTime.now();
        return;
      }

      final double distanceKm = distanceMeters / 1000.0;
      final double totalKm = _state.totalDistanceTraveled;

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(_state.todayAttendanceId)
          .collection('locationHistory')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
            'coordinates': _state.currentCoordinates,
            'latitude': _currentPosition?.latitude,
            'longitude': _currentPosition?.longitude,
            'accuracy': _currentPosition?.accuracy,
            'activityType': activityType,
            'status': _state.isOnBreak ? 'on_break' : 'working',
            'distanceFromLast_m': distanceMeters,
            'distanceFromLast_km': distanceKm,
            'totalDistance_km': totalKm,
            'userName': _state.userName,
            'userId': _state.userId,
          });

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(_state.todayAttendanceId)
          .update({
            'totalDistanceTraveled': totalKm,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          });

      _lastStoredPosition = _currentPosition;
      _lastLocationStore = DateTime.now();
    } catch (e, st) {
      _logError('Error storing location history', e, st);
    }
  }

  double _calculateDistance(Position start, Position end) {
    try {
      return Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );
    } catch (e) {
      return 0.0;
    }
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (_state.userId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(_state.userId)
          .update({
            'isCurrentlyWorking': false,
            'workStatus': 'Offline',
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          })
          .catchError(
            (e) => _logError('Error updating offline status', e, null),
          );
    }
  }

  // ----------------------------
  // Timer & sync system
  // ----------------------------
  void _startWorkTimer() {
    if (_workTimer != null) return;
    if (!_safeToUpdate() || !_state.isLoggedIn || _state.loginTime == null)
      {return;}

    _workTimer = Timer.periodic(_workTimerInterval, (timer) {
      if (!_safeToUpdate() || !_state.isLoggedIn || _state.loginTime == null) {
        timer.cancel();
        _workTimer = null;
        {return;}
      }

      try {
        _updateWorkDuration();
        final now = _nowUsingServerOffset();
        if (now.difference(_lastNotificationUpdate) >
            _notificationUpdateInterval) {
          unawaited(_updateNotification());
          _lastNotificationUpdate = now;
        }
      } catch (e, st) {
        _logError('Work timer error', e, st);
        timer.cancel();
        _workTimer = null;
      }
    });
  }

  void _stopWorkTimer() {
    _workTimer?.cancel();
    _workTimer = null;
  }

  void _updateWorkDuration() {
    if (!_state.isLoggedIn || _state.loginTime == null) return;
    final DateTime now = _nowUsingServerOffset();
    Duration newWorkDuration;
    Duration newRemainingShiftTime = _calculateRemainingTimeUsing(now);

    if (!_state.isOnBreak) {
      newWorkDuration =
          now.difference(_state.loginTime!) - _state.totalBreakDurationToday;
    } else if (_state.breakStartTime != null) {
      final Duration currentBreak = now.difference(_state.breakStartTime!);
      newWorkDuration =
          now.difference(_state.loginTime!) -
          _state.totalBreakDurationToday -
          currentBreak;
    } else {
      newWorkDuration = _state.workDuration;
    }

    if (newWorkDuration.isNegative) newWorkDuration = Duration.zero;

    if (newWorkDuration != _state.workDuration ||
        newRemainingShiftTime != _state.remainingShiftTime) {
      _updateState(
        _state.copyWith(
          workDuration: newWorkDuration,
          remainingShiftTime: newRemainingShiftTime,
        ),
      );
    }
  }

  Duration _calculateRemainingTimeUsing(DateTime now) {
    if (_state.loginTime == null) return Duration.zero;
    final DateTime shiftEnd = DateTime(now.year, now.month, now.day, 18, 30);
    if (now.isAfter(shiftEnd)) return Duration.zero;
    return shiftEnd.difference(now);
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) async {
      if (_isDisposed || _isSyncing) return;
      if (!_state.isLoggedIn || _state.userId.isEmpty) return;
      await _syncWithFirestore();
    });
  }

  void _startPeriodicStateSave() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      try {
        _stateService.saveAppState(_state);
      } catch (e, st) {
        _logError('Periodic save failed', e, st);
      }
    });
  }

  Future<void> _syncWithFirestore() async {
    if (_isDisposed || _isSyncing || _state.userId.isEmpty) return;
    _isSyncing = true;
    try {
      final DateTime now = _nowUsingServerOffset();
      final String todayKey = DateFormat('dd-MMM-yy').format(now);

      final QuerySnapshot attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _state.userId)
          .where('date', isEqualTo: todayKey)
          .limit(1)
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        await _handleExistingAttendance(attendanceQuery.docs.first);
      } else {
        await _handleNoAttendanceRecord();
      }

      if (_state.isLoggedIn) _updateWorkDuration();
    } catch (e, st) {
      _logError('Error syncing with Firestore', e, st);
      if (_safeToUpdate()) {
        _safeShowSnackBar(
          'Sync failed. Please check connection.',
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _handleNoAttendanceRecord() async {
    if (!_state.isLoggedIn) return;
    try {
      await _createTodayAttendanceRecord();
      if (_state.loginTime != null) await _updateAttendanceOnLogin();
    } catch (e, st) {
      _logError('Error creating attendance record during sync', e, st);
    }
  }

  Future<void> _handleExistingAttendance(DocumentSnapshot doc) async {
    try {
      final attendance = Attendance.fromFirestore(doc);
      if (attendance.inTime != null && attendance.outTime == null) {
        if (!_state.isLoggedIn) {
          await _restoreLoginState(attendance);
        } else {
          if (_state.isOnBreak != attendance.isOnBreak) {
            _updateState(_state.copyWith(isOnBreak: attendance.isOnBreak));
          }
          if (_state.todayAttendanceId != attendance.id)
           { _updateState(_state.copyWith(todayAttendanceId: attendance.id));}
        }
      } else if (attendance.outTime != null) {
        if (_state.todayAttendanceId != attendance.id)
          {_updateState(_state.copyWith(todayAttendanceId: attendance.id));}
        if (_state.isLoggedIn) {
          // Remote logout detected - automatically log out on this device
          _safeShowSnackBar(
            'You were logged out from another device. Logging out...',
            backgroundColor: Colors.orange,
            icon: Icons.sync,
          );
          // Automatically log out the user
          await _logout(reason: 'Remote logout detected from another device');
        }
      } else {
        if (_state.todayAttendanceId != attendance.id)
          {_updateState(_state.copyWith(todayAttendanceId: attendance.id));}
      }
    } catch (e, st) {
      _logError('Error handling existing attendance', e, st);
    }
  }

  // ----------------------------
  // Realtime Attendance Sync
  // ----------------------------
  void _startRealtimeAttendanceListener() {
    if (_state.todayAttendanceId == null || _state.todayAttendanceId!.isEmpty) {
      return;
    }

    // Cancel existing listener if any
    _attendanceListener?.cancel();

    // Create realtime listener for today's attendance document
    _attendanceListener = FirebaseFirestore.instance
        .collection('attendance')
        .doc(_state.todayAttendanceId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) async {
            if (_isDisposed || !_safeToUpdate()) return;

            try {
              if (!snapshot.exists || snapshot.data() == null) return;

              final attendance = Attendance.fromFirestore(snapshot);

              // Check if remote logout detected
              if (attendance.outTime != null && _state.isLoggedIn) {
                // Remote logout detected - automatically log out on this device
                _safeShowSnackBar(
                  '🔄 Remote logout detected. Logging out...',
                  backgroundColor: Colors.orange,
                  icon: Icons.sync,
                );
                // Automatically log out the user
                await _logout(
                  reason: 'Remote logout detected from another device',
                );
              }
              // Sync break state in realtime
              else if (_state.isLoggedIn &&
                  attendance.isOnBreak != _state.isOnBreak) {
                _updateState(_state.copyWith(isOnBreak: attendance.isOnBreak));
                _safeShowSnackBar(
                  attendance.isOnBreak
                      ? '☕ Break started from another device'
                      : '✅ Break ended from another device',
                  backgroundColor: Colors.blue,
                  icon: Icons.sync,
                  durationSeconds: 2,
                );
              }
            } catch (e, st) {
              _logError('Error in realtime attendance listener', e, st);
            }
          },
          onError: (error) {
            _logError('Realtime attendance listener error', error, null);
          },
        );
  }

  void _stopRealtimeAttendanceListener() {
    _attendanceListener?.cancel();
    _attendanceListener = null;
  }

  Future<void> _restoreLoginState(Attendance attendance) async {
    try {
      DateTime loginTime;
      if (attendance.loginTimestamp != null) {
        loginTime = attendance.loginTimestamp!.toDate();
      } else if (attendance.inTime != null) {
        loginTime = _parseTimeToToday(attendance.inTime!);
      } else {
        loginTime = _nowUsingServerOffset();
      }

      DateTime? breakStart;
      if (attendance.isOnBreak) {
        if (attendance.breakStartTimestamp != null)
          {breakStart = attendance.breakStartTimestamp!.toDate();}
        else if (attendance.breakStartTime != null)
          {breakStart = _parseTimeToToday(attendance.breakStartTime!);}
      }

      _updateState(
        _state.copyWith(
          isLoggedIn: true,
          isOnBreak: attendance.isOnBreak,
          loginTime: loginTime,
          breakStartTime: breakStart,
          todayAttendanceId: attendance.id,
          totalBreakDurationToday: Duration(
            seconds: attendance.totalBreakSeconds,
          ),
          totalDistanceTraveled: attendance.totalDistanceTraveled,
          showInstructions: false,
        ),
      );

      _startWorkTimer();
      _startLocationTracking();
      _startRealtimeAttendanceListener(); // Start realtime sync on restore
      unawaited(_updateNotification());
      _safeShowSnackBar(
        'Session restored from server',
        backgroundColor: Colors.green,
        icon: Icons.cloud_done,
      );
    } catch (e, st) {
      _logError('Error restoring login state', e, st);
    }
  }

  // ----------------------------
  // Login/Logout & Approval flow
  // ----------------------------
  Future<void> _login() async {
    if (_isDisposed || _isLoggingIn) return;
    _isLoggingIn = true;

    try {
      _pulseController.stop();
      await _getCurrentLocation();

      final DateTime nowServer = await _nowAlignedToServer();
      final needsApproval = _needsLoginApproval(nowServer);

      if (needsApproval) {
        final approvalId = await _requestLoginApproval();
        if (approvalId != null) {
          await _stateService.saveApprovalState(
            isWaitingForApproval: true,
            pendingApprovalId: approvalId,
            approvalRequestTime: nowServer,
          );
          _updateState(
            _state.copyWith(
              isWaitingForApproval: true,
              loginTime: nowServer,
              pendingApprovalId: approvalId,
              approvalRequestTime: nowServer,
              approvalRetryCount: 0,
            ),
          );
          _listenForApproval(approvalId);
          _safeShowSnackBar(
            '⏳ Login after grace period. Waiting for admin/HR approval...',
            backgroundColor: Colors.orange,
            icon: Icons.access_time,
            durationSeconds: 5,
          );
        } else {
          _updateState(
            _state.copyWith(isWaitingForApproval: false, loginTime: null),
          );
          await _stateService.clearApprovalState();
        }
      } else {
        await _completeLogin(nowServer: nowServer);
        await _stateService.clearApprovalState();
      }
    } catch (e, st) {
      _logError('Error during login', e, st);
      _safeShowSnackBar(
        'Login failed. Please try again.',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      _isLoggingIn = false;
    }
  }

  Future<void> _completeLogin({DateTime? nowServer}) async {
    if (_state.isLoggedIn) return;
    final DateTime now = nowServer ?? await _nowAlignedToServer();

    _updateState(
      _state.copyWith(
        isLoggedIn: true,
        isOnBreak: false,
        isWaitingForApproval: false,
        loginTime: now,
        workDuration: Duration.zero,
        totalBreakDurationToday: Duration.zero,
        totalDistanceTraveled: 0.0,
        showInstructions: false,
        remainingShiftTime: _calculateRemainingTimeUsing(now),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PersistenceKeys.bgIsLoggedIn, true);
      await prefs.setString(PersistenceKeys.bgLoginTime, now.toIso8601String());
      await prefs.setBool(PersistenceKeys.bgIsOnBreak, false);
      await prefs.setInt(PersistenceKeys.bgTotalBreakDurationSeconds, 0);
      await prefs.setString(PersistenceKeys.userName, _state.userName);
    } catch (e) {
      _logError('Error persisting login prefs', e, null);
    }

    await _createTodayAttendanceRecord();
    await _updateAttendanceOnLogin();
    await _storeLocationInHistory('login');

    _startLocationTracking();
    _startWorkTimer();
    _startRealtimeAttendanceListener(); // Start realtime sync
    unawaited(_updateNotification());
    await _startBackgroundService();

    _safeShowSnackBar(
      'Welcome back, ${_state.userName}! 🌟',
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
      durationSeconds: 4,
    );
  }

  Future<void> _logout({String? reason}) async {
    if (_isDisposed || _isLoggingOut) return;
    _isLoggingOut = true;

    try {
      await _getCurrentLocation();
      await _storeLocationInHistory('logout');

      _stopWorkTimer();
      _stopLocationTracking();
      _stopRealtimeAttendanceListener(); // Stop realtime sync
      await _stopBackgroundService();

      await _updateAttendanceOnLogout(reason: reason);

      await _notificationsPlugin.cancel(1);

      _updateState(
        AppState.initial().copyWith(
          userName: _state.userName,
          userId: _state.userId,
          empId: _state.empId,
        ),
      );
      _pulseController.repeat(reverse: true);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(PersistenceKeys.bgIsLoggedIn, false);
        await prefs.remove(PersistenceKeys.bgLoginTime);
        await prefs.remove(PersistenceKeys.bgBreakStartTime);
        await prefs.setBool(PersistenceKeys.bgIsOnBreak, false);
        await prefs.setInt(
          PersistenceKeys.bgTotalBreakDurationSeconds,
          _state.totalBreakDurationToday.inSeconds,
        );
      } catch (e) {
        _logError('Error clearing login prefs', e, null);
      }

      String message = reason != null
          ? 'Early logout completed\nReason: $reason'
          : 'Good work, ${_state.userName}! 🌙\nLogged out successfully';
      _safeShowSnackBar(
        message,
        backgroundColor: Colors.deepPurple,
        icon: Icons.bedtime,
        durationSeconds: 4,
      );
    } catch (e, st) {
      _logError('Error during logout', e, st);
      _safeShowSnackBar(
        'Logout failed. Please try again.',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      _isLoggingOut = false;
    }
  }

  // ----------------------------
  // Attendance creation & updates
  // ----------------------------
  Future<void> _createTodayAttendanceRecord() async {
    if (_isDisposed) return;
    try {
      final DateTime now = _nowUsingServerOffset();
      final String dateKey = DateFormat('dd-MMM-yy').format(now);
      final String dayName = DateFormat('EEE').format(now);

      final QuerySnapshot existing = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _state.userId)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        final DocumentReference docRef = await FirebaseFirestore.instance
            .collection('attendance')
            .add({
              'userId': _state.userId,
              'userName': _state.userName,
              'empId': _state.empId,
              'date': dateKey,
              'day': dayName,
              'shiftCode': 'GN',
              'shiftInTime': '09:30 AM',
              'shiftOutTime': '06:30 PM',
              'inTime': null,
              'outTime': null,
              'totHrs': 0.0,
              'lateHrs': 0.0,
              'lateMark': 0.0,
              'otHrs': 0.0,
              'type1': 'ABS',
              'portion': 0.0,
              'type2': '---',
              'coordinates': _state.currentCoordinates,
              'totalDistanceTraveled': 0.0,
              'isOnBreak': false,
              'totalBreakSeconds': 0,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
        _updateState(_state.copyWith(todayAttendanceId: docRef.id));
      } else {
        _updateState(
          _state.copyWith(todayAttendanceId: existing.docs.first.id),
        );
      }
    } catch (e, st) {
      _logError('Error creating attendance record', e, st);
      _safeShowSnackBar(
        'Failed to create attendance record',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }

  Future<void> _updateAttendanceOnLogin() async {
    if (_isDisposed) return;
    if (_state.todayAttendanceId == null) await _createTodayAttendanceRecord();
    if (_state.todayAttendanceId != null && _state.loginTime != null) {
      try {
        final String inTimeStr = DateFormat('h:mm a').format(_state.loginTime!);
        final double lateHours = _calculateLateHours(_state.loginTime!);
        final double lateMark = lateHours > 0 ? 1.0 : 0.0;

        await FirebaseFirestore.instance
            .collection('attendance')
            .doc(_state.todayAttendanceId)
            .update({
              'inTime': inTimeStr,
              'lateHrs': lateHours,
              'lateMark': lateMark,
              'type1': 'DP',
              'portion': 1.0,
              'loginCoordinates': _state.currentCoordinates,
              'isOnBreak': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (e, st) {
        _logError('Error updating login time', e, st);
      }
    }
  }

  Future<void> _updateAttendanceOnLogout({String? reason}) async {
    if (_isDisposed) return;
    if (_state.todayAttendanceId != null && _state.loginTime != null) {
      try {
        final DateTime logoutTime = await _nowAlignedToServer();
        final String outTimeStr = DateFormat('h:mm a').format(logoutTime);
        final Duration totalWork =
            logoutTime.difference(_state.loginTime!) -
            _state.totalBreakDurationToday;
        final double totalHours = totalWork.inMinutes / 60.0;
        final double shiftHours = _getShiftDuration().inMinutes / 60.0;
        final double otHours = totalHours > shiftHours
            ? totalHours - shiftHours
            : 0.0;

        String type1 = 'DP';
        double portion = 1.0;
        if (totalHours < 4.0) {
          type1 = 'ABS';
          portion = 0.0;
        } else if (totalHours < shiftHours) {
          type1 = 'HD';
          portion = 0.5;
        }

        await FirebaseFirestore.instance
            .collection('attendance')
            .doc(_state.todayAttendanceId)
            .update({
              'outTime': outTimeStr,
              'totHrs': double.parse(totalHours.toStringAsFixed(2)),
              'otHrs': double.parse(otHours.toStringAsFixed(2)),
              'type1': type1,
              'portion': portion,
              'totalBreakTime': _formatDuration(_state.totalBreakDurationToday),
              'totalBreakSeconds': _state.totalBreakDurationToday.inSeconds,
              'logoutCoordinates': _state.currentCoordinates,
              'earlyLogoutReason': reason,
              'totalDistanceTraveled': _state.totalDistanceTraveled,
              'isOnBreak': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (e, st) {
        _logError('Error updating logout time', e, st);
      }
    }
  }

  // ----------------------------
  // Break management
  // ----------------------------
  Future<void> _startBreak() async {
    if (_isDisposed) return;
    await _getCurrentLocation();
    _updateState(
      _state.copyWith(isOnBreak: true, breakStartTime: DateTime.now()),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PersistenceKeys.bgIsOnBreak, true);
      await prefs.setString(
        PersistenceKeys.bgBreakStartTime,
        DateTime.now().toIso8601String(),
      );
      await prefs.setInt(
        PersistenceKeys.bgTotalBreakDurationSeconds,
        _state.totalBreakDurationToday.inSeconds,
      );
    } catch (e) {
      _logError('Error persisting break start prefs', e, null);
    }
    if (_state.todayAttendanceId != null) {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(_state.todayAttendanceId)
          .update({
            'isOnBreak': true,
            'breakStartTime': DateFormat('h:mm a').format(DateTime.now()),
            'breakInCoordinates': _state.currentCoordinates,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }
    await _storeLocationInHistory('break_start');
    _safeShowSnackBar(
      'Break started ☕',
      backgroundColor: Colors.orange,
      icon: Icons.coffee,
    );
    await _updateNotification();
  }

  Future<void> _endBreak() async {
    if (_isDisposed) return;
    await _getCurrentLocation();
    final Duration currentBreakDuration = _state.breakStartTime != null
        ? DateTime.now().difference(_state.breakStartTime!)
        : Duration.zero;
    _updateState(
      _state.copyWith(
        isOnBreak: false,
        totalBreakDurationToday:
            _state.totalBreakDurationToday + currentBreakDuration,
        breakStartTime: null,
      ),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PersistenceKeys.bgIsOnBreak, false);
      await prefs.remove(PersistenceKeys.bgBreakStartTime);
      await prefs.setInt(
        PersistenceKeys.bgTotalBreakDurationSeconds,
        _state.totalBreakDurationToday.inSeconds,
      );
    } catch (e) {
      _logError('Error persisting break end prefs', e, null);
    }
    if (_state.todayAttendanceId != null) {
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(_state.todayAttendanceId)
          .update({
            'isOnBreak': false,
            'totalBreakTime': _formatDuration(_state.totalBreakDurationToday),
            'totalBreakSeconds': _state.totalBreakDurationToday.inSeconds,
            'lastBreakDuration': _formatDuration(currentBreakDuration),
            'breakEndTime': DateFormat('h:mm a').format(DateTime.now()),
            'breakOutCoordinates': _state.currentCoordinates,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }
    await _storeLocationInHistory('break_end');
    _safeShowSnackBar(
      'Break ended - Duration: ${_formatDuration(currentBreakDuration)}',
      backgroundColor: Colors.blue,
      icon: Icons.work,
      durationSeconds: 3,
    );
    await _updateNotification();
  }

  // ----------------------------
  // Approval workflow
  // ----------------------------
  Future<void> _recoverApprovalState() async {
    try {
      final approvalState = await _stateService.loadApprovalState();
      if (approvalState['isWaitingForApproval'] == true &&
          approvalState['pendingApprovalId'] != null) {
        final String approvalId = approvalState['pendingApprovalId']!;
        final DateTime? requestTime = approvalState['approvalRequestTime'];
        if (requestTime != null &&
            DateTime.now().difference(requestTime).inHours >= 24) {
          await _handleExpiredApproval(approvalId);
          return;
        }
        _updateState(
          _state.copyWith(
            isWaitingForApproval: true,
            pendingApprovalId: approvalId,
            approvalRequestTime: requestTime,
          ),
        );
        _listenForApproval(approvalId);
      }
    } catch (e, st) {
      _logError('Error recovering approval state', e, st);
    }
  }

  Future<void> _handleExpiredApproval(String approvalId) async {
    try {
      await FirebaseFirestore.instance
          .collection('loginApprovals')
          .doc(approvalId)
          .update({
            'status': 'expired',
            'expiredAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      _logError('Error marking approval expired', e, null);
    }
    _updateState(
      _state.copyWith(
        isWaitingForApproval: false,
        loginTime: null,
        pendingApprovalId: null,
        approvalRequestTime: null,
      ),
    );
    await _stateService.clearApprovalState();
    _safeShowSnackBar(
      '⏰ Approval request expired after 24 hours. Please login again.',
      backgroundColor: Colors.orange,
      icon: Icons.access_time,
      durationSeconds: 6,
    );
  }

  Future<String?> _requestLoginApproval() async {
    if (_isDisposed) return null;
    try {
      final DateTime now = await _nowAlignedToServer();
      final String dateKey = DateFormat('dd-MMM-yy').format(now);
      final docRef = await FirebaseFirestore.instance
          .collection('loginApprovals')
          .add({
            'userId': _state.userId,
            'userName': _state.userName,
            'empId': _state.empId,
            'requestTime': FieldValue.serverTimestamp(),
            'requestTimeStr': DateFormat('h:mm a').format(now),
            'date': dateKey,
            'lateBy': _calculateLateHours(now),
            'status': 'pending',
            'coordinates': _state.currentCoordinates,
            'approvedBy': null,
            'approvalTime': null,
            'reason': 'Late login - After grace period',
          });
      await _notifyAdminAndHR(docRef.id);
      return docRef.id;
    } catch (e, st) {
      _logError('Error requesting login approval', e, st);
      return null;
    }
  }

  Future<void> _notifyAdminAndHR(String approvalId) async {
    try {
      final QuerySnapshot adminUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'hr', 'superadmin'])
          .get();
      for (var doc in adminUsers.docs) {
        try {
          final String? fcmToken = doc.get('fcmToken');
          if (fcmToken != null) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': doc.id,
              'type': 'login_approval_request',
              'title': 'Late Login Request',
              'message': '${_state.userName} requesting login approval',
              'approvalId': approvalId,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
        } catch (e) {
          _logError('Error notifying user ${doc.id}', e, null);
        }
      }
    } catch (e, st) {
      _logError('Error notifying admin/HR', e, st);
    }
  }

  void _listenForApproval(String approvalId) {
    _approvalListener?.cancel();
    _approvalListener = FirebaseFirestore.instance
        .collection('loginApprovals')
        .doc(approvalId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists || _isDisposed) return;
            try {
              final data = snapshot.data() as Map<String, dynamic>;
              final String status = (data['status'] ?? 'pending')
                  .toString()
                  .toLowerCase();
              if (status == 'approved') {
                _cleanupApprovalListeners();
                if (_safeToUpdate()) {
                  _updateState(_state.copyWith(isWaitingForApproval: false));
                  _handleApprovalApproved(data);
                }
              } else if (status == 'rejected') {
                _cleanupApprovalListeners();
                if (_safeToUpdate()) {
                  _updateState(
                    _state.copyWith(
                      isWaitingForApproval: false,
                      loginTime: null,
                    ),
                  );
                  _handleApprovalRejected(data);
                }
              } else {
                // pending - optionally handle periodic UI update
                _updateApprovalWaitingUI(data);
              }
            } catch (e, st) {
              _logError('Error in approval listener', e, st);
            }
          },
          onError: (err) {
            _logError('Approval listener error', err, null);
          },
        );
  }

  void _cleanupApprovalListeners() {
    _approvalListener?.cancel();
    _approvalListener = null;
    _approvalPollingSubscription?.cancel();
    _approvalPollingSubscription = null;
    _approvalTimeoutTimer?.cancel();
    _approvalTimeoutTimer = null;
  }

  Future<void> _manualCheckApprovalStatus() async {
    if (_isDisposed || !mounted) return;
    final String? approvalId = _state.pendingApprovalId;
    if (approvalId == null || !_state.isWaitingForApproval) {
      _safeShowSnackBar(
        '❌ No pending approval request found',
        backgroundColor: Colors.grey[600]!,
        icon: Icons.info_outline,
        durationSeconds: 3,
      );
      return;
    }

    _safeShowSnackBar(
      '🔍 Checking approval status...',
      backgroundColor: Colors.blue,
      icon: Icons.refresh,
      durationSeconds: 2,
    );
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final result = await _performComprehensiveStatusCheck(approvalId);
      if (!mounted) return;
      switch (result.status) {
        case 'approved':
          _safeShowSnackBar(
            '✅ Approval granted! Completing login...',
            backgroundColor: Colors.green,
            icon: Icons.check_circle,
            durationSeconds: 3,
          );
          break;
        case 'rejected':
          _safeShowSnackBar(
            '❌ Request rejected: ${result.reason}',
            backgroundColor: Colors.red,
            icon: Icons.cancel,
            durationSeconds: 5,
          );
          break;
        case 'pending':
          final waitingTime = _getFormattedWaitingTime();
          _safeShowSnackBar(
            '⏳ Still pending... $waitingTime',
            backgroundColor: Colors.orange,
            icon: Icons.access_time,
            durationSeconds: 4,
          );
          break;
        case 'expired':
          _safeShowSnackBar(
            '⏰ Approval request expired',
            backgroundColor: Colors.orange[800]!,
            icon: Icons.timer_off,
            durationSeconds: 4,
          );
          break;
        case 'cancelled':
          _safeShowSnackBar(
            '🚫 Approval request was cancelled',
            backgroundColor: Colors.grey,
            icon: Icons.not_interested,
            durationSeconds: 4,
          );
          break;
        default:
          _safeShowSnackBar(
            '❓ Unknown status: ${result.status}',
            backgroundColor: Colors.grey,
            icon: Icons.help_outline,
            durationSeconds: 4,
          );
      }
    } catch (e) {
      _logError('Manual check failed', e, null);
      if (_isDisposed) return;
      _safeShowSnackBar(
        '🌐 Network error - Could not check status',
        backgroundColor: Colors.red,
        icon: Icons.wifi_off,
        durationSeconds: 4,
      );
      final newRetry = _state.approvalRetryCount + 1;
      _updateState(_state.copyWith(approvalRetryCount: newRetry));
    }
  }

  Future<ApprovalCheckResult> _performComprehensiveStatusCheck(
    String approvalId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('loginApprovals')
          .doc(approvalId)
          .get()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Firestore query timeout');
            },
          );
      if (!doc.exists)
        {return ApprovalCheckResult(
          status: 'missing',
          reason: 'Approval request not found in system',
        );}
      final data = doc.data();
      if (data == null)
        {return ApprovalCheckResult(
          status: 'corrupted',
          reason: 'Approval data is corrupted',
        );}
      final String status =
          (data['status']?.toString().toLowerCase() ?? 'pending');
      final String reason =
          (data['rejectionReason']?.toString() ??
          data['notes']?.toString() ??
          'No reason provided');
      if ((status == 'approved' || status == 'rejected') &&
          mounted &&
          !_isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleApprovalUpdate(data);
        });
      }
      return ApprovalCheckResult(status: status, reason: reason, data: data);
    } on TimeoutException catch (e) {
      _logError('Status check timeout', e, null);
      rethrow;
    } on FirebaseException catch (e) {
      _logError('Firestore error', e, null);
      rethrow;
    } catch (e) {
      _logError('Unexpected error in status check', e, null);
      rethrow;
    }
  }

  void _handleApprovalUpdate(Map<String, dynamic> data) {
    if (_isDisposed) return;
    final status = data['status'] ?? 'pending';
    switch (status) {
      case 'approved':
        _handleApprovalApproved(data);
        break;
      case 'rejected':
        _handleApprovalRejected(data);
        break;
      default:
        _updateApprovalWaitingUI(data);
    }
  }

  void _updateApprovalWaitingUI(Map<String, dynamic> data) {
    if (_isDisposed || !mounted) return;
    try {
      final Timestamp? timestamp = data['updatedAt'] as Timestamp?;
      final String lastUpdate = timestamp != null
          ? DateFormat('h:mm a').format(timestamp.toDate())
          : 'Unknown';
      final requestedBy = data['approvedBy'] ?? 'Admin';
      final lateBy = (data['lateBy'] ?? 0.0) as double;
      final lateMinutes = (lateBy * 60).toInt();
      if (kDebugMode)
        {print(
          'Approval Update - Last Check: $lastUpdate, Late by: ${lateMinutes}min, Approver: $requestedBy',
        );}
      final requestTime = _state.approvalRequestTime;
      if (requestTime != null) {
        final waitingMinutes = DateTime.now().difference(requestTime).inMinutes;
        if (waitingMinutes == 5 ||
            waitingMinutes == 15 ||
            waitingMinutes == 30 ||
            waitingMinutes % 60 == 0) {
          String statusMsg;
          Color bg;
          if (waitingMinutes <= 30) {
            statusMsg =
                'Approval pending - ${waitingMinutes}m waiting (Late by ${lateMinutes}min)';
            bg = Colors.orange;
          } else if (waitingMinutes <= 120) {
            statusMsg =
                'Still waiting for approval - ${waitingMinutes}m Consider following up with your manager';
            bg = Colors.orange[700]!;
          } else {
            statusMsg =
                'Extended wait time - ${waitingMinutes}m Please contact admin/HR directly';
            bg = Colors.red;
          }
          _safeShowSnackBar(
            statusMsg,
            backgroundColor: bg,
            icon: Icons.access_time,
            durationSeconds: 5,
          );
        }
      }
    } catch (e) {
      _logError('Error in updateApprovalWaitingUI', e, null);
    }
  }

  void _handleApprovalApproved(Map<String, dynamic> data) async {
    _cleanupApprovalListeners();
    _updateState(
      _state.copyWith(
        isWaitingForApproval: false,
        pendingApprovalId: null,
        approvalRequestTime: null,
        approvalRetryCount: 0,
      ),
    );
    _stateService.clearApprovalState();
    await _completeLogin();
    _safeShowSnackBar(
      '✅ Login approved by ${data['approvedBy'] ?? 'Admin'}',
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
      durationSeconds: 5,
    );
  }

  void _handleApprovalRejected(Map<String, dynamic> data) {
    _cleanupApprovalListeners();
    _updateState(
      _state.copyWith(
        isWaitingForApproval: false,
        loginTime: null,
        pendingApprovalId: null,
        approvalRequestTime: null,
        approvalRetryCount: 0,
      ),
    );
    _stateService.clearApprovalState();
    _safeShowSnackBar(
      '❌ Login rejected: ${data['rejectionReason'] ?? 'No reason provided'}',
      backgroundColor: Colors.red,
      icon: Icons.cancel,
      durationSeconds: 6,
    );
  }

  Future<void> _cancelApprovalRequest() async {
    if (_state.pendingApprovalId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('loginApprovals')
            .doc(_state.pendingApprovalId!)
            .update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        _logError('Error cancelling approval', e, null);
      }
    }
    _cleanupApprovalListeners();
    _updateState(
      _state.copyWith(
        isWaitingForApproval: false,
        loginTime: null,
        pendingApprovalId: null,
        approvalRequestTime: null,
      ),
    );
    await _stateService.clearApprovalState();
    _safeShowSnackBar(
      'Approval request cancelled',
      backgroundColor: Colors.grey,
      icon: Icons.cancel,
    );
  }

  String _getFormattedWaitingTime() {
    final requestTime = _state.approvalRequestTime;
    if (requestTime == null) return 'Unknown time';
    final waitingDuration = DateTime.now().difference(requestTime);
    final hours = waitingDuration.inHours;
    final minutes = waitingDuration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  bool _needsLoginApproval(DateTime now) {
    final DateTime graceTime = DateTime(now.year, now.month, now.day, 9, 45);
    return now.isAfter(graceTime);
  }

  // ----------------------------
  // Background service
  // ----------------------------
  Future<void> _initializeBackgroundService() async {
    try {
      final service = FlutterBackgroundService();
      await service.configure(
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'attendance_tracker',
          initialNotificationTitle: 'Attendance Tracker',
          initialNotificationContent: 'Tracking your work time',
          foregroundServiceNotificationId: 888,
        ),
      );
    } catch (e, st) {
      _logError('Error initializing background service', e, st);
    }
  }

  @pragma('vm:entry-point')
  static bool _onIosBackground(ServiceInstance service) {
    return true;
  }

  static Future<void> _onStart(ServiceInstance service) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is! AndroidServiceInstance) {
        timer.cancel();
        return;
      }

      service.setForegroundNotificationInfo(
        title: "Attendance Tracker",
        content: "Tracking your work time",
      );

      final String? loginTimeStr = prefs.getString(PersistenceKeys.bgLoginTime);
      final String? breakStartTimeStr = prefs.getString(
        PersistenceKeys.bgBreakStartTime,
      );
      final int totalBreakSeconds =
          prefs.getInt(PersistenceKeys.bgTotalBreakDurationSeconds) ?? 0;
      final bool isOnBreak =
          prefs.getBool(PersistenceKeys.bgIsOnBreak) ?? false;
      final bool isLoggedIn =
          prefs.getBool(PersistenceKeys.bgIsLoggedIn) ?? false;

      if (!isLoggedIn || loginTimeStr == null) {
        timer.cancel();
        return;
      }

      final DateTime loginTime = DateTime.parse(loginTimeStr);
      final DateTime now = DateTime.now();
      Duration totalBreakDuration = Duration(seconds: totalBreakSeconds);
      Duration currentBreakDuration = Duration.zero;
      if (isOnBreak && breakStartTimeStr != null) {
        final DateTime breakStartTime = DateTime.parse(breakStartTimeStr);
        currentBreakDuration = now.difference(breakStartTime);
      }

      final Duration workDuration =
          now.difference(loginTime) - totalBreakDuration - currentBreakDuration;

      await prefs.setInt('workDurationSeconds', workDuration.inSeconds);
      await prefs.setInt(
        'currentBreakDurationSeconds',
        currentBreakDuration.inSeconds,
      );

      final String userName = prefs.getString('userName') ?? 'User';
      final String dateStr = DateFormat('dd MMM yyyy').format(now);

      final String title = 'Attendance Tracker - $userName';
      final String body = isOnBreak
          ? '$dateStr\n🟠 On Break: ${_formatDurationStatic(currentBreakDuration)}\n⏰ Work: ${_formatDurationStatic(workDuration)}'
          : '$dateStr\n🔵 Working: ${_formatDurationStatic(workDuration)}\n☕ Break: ${_formatDurationStatic(totalBreakDuration)}';

      service.invoke('update', {
        'title': title,
        'body': body,
        'workDuration': workDuration.inSeconds,
        'breakDuration': totalBreakDuration.inSeconds,
      });
    });
  }

  Future<void> _startBackgroundService() async {
    try {
      final service = FlutterBackgroundService();
      bool running = await service.isRunning();
      if (!running && _state.isLoggedIn) await service.startService();
    } catch (e, st) {
      _logError('Error starting background service', e, st);
    }
  }

  Future<void> _stopBackgroundService() async {
    try {
      final service = FlutterBackgroundService();
      bool running = await service.isRunning();
      if (running) service.invoke('stop');
    } catch (e, st) {
      _logError('Error stopping background service', e, st);
    }
  }

  // ----------------------------
  // Helpers, parsing, UI helpers
  // ----------------------------
  DateTime _parseTimeToToday(String timeStr) {
    try {
      final DateTime now = DateTime.now();
      final DateFormat fmt = DateFormat('h:mm a');
      final DateTime parsed = fmt.parse(timeStr);
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      return DateTime.now();
    }
  }

  double _calculateLateHours(DateTime actualInTime) {
    final DateTime now = actualInTime;
    final DateTime standardIn = DateTime(now.year, now.month, now.day, 9, 30);
    if (actualInTime.isAfter(standardIn)) {
      final late = actualInTime.difference(standardIn);
      return late.inMinutes / 60.0;
    }
    return 0.0;
  }

  Duration _getShiftDuration() => const Duration(hours: 9);

  // Snack helper
  void _safeShowSnackBar(
    String message, {
    Color? backgroundColor,
    IconData? icon,
    int durationSeconds = 3,
  }) {
    if (!_safeToUpdate()) return;
    final now = DateTime.now();
    if (_lastSnackMessage == message &&
        _lastSnackTime != null &&
        now.difference(_lastSnackTime!) < _snackDebounce)
      {return;}
    _lastSnackMessage = message;
    _lastSnackTime = now;
    final snackBar = SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: backgroundColor ?? Colors.blue,
      duration: Duration(seconds: durationSeconds),
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  static String _formatDurationStatic(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _logError(String message, dynamic error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('❌ $message: $error');
      if (stackTrace != null) print(stackTrace);
    }
  }

  // ----------------------------
  // UI: simplified but feature-complete
  // ----------------------------
  Widget _buildLoadingWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[300],
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 8,
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                strokeWidth: 3,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    color: Colors.grey,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'LOADING',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Initializing...',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildApprovalWaitingWidget() {
    final requestTime = _state.approvalRequestTime;
    final timeSinceRequest = requestTime != null
        ? DateTime.now().difference(requestTime)
        : Duration.zero;
    return Column(
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange,
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                spreadRadius: 8,
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'WAITING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_state.approvalRetryCount}/3',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Waiting for Admin/HR approval...',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Requested: ${DateFormat('h:mm a').format(requestTime ?? DateTime.now())}',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Elapsed: ${timeSinceRequest.inHours}h ${timeSinceRequest.inMinutes.remainder(60)}m',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _manualCheckApprovalStatus,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Check Status Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _showCancelApprovalDialog,
          child: const Text(
            'Cancel Request',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCircle() {
    if (_isLoading) return _buildLoadingWidget();
    if (_state.isWaitingForApproval) return _buildApprovalWaitingWidget();

    String displayText = 'TAP TO\nLOGIN';
    Color circleColor = Colors.green;
    Color textColor = Colors.white;
    String instructionText = '';

    if (_state.isLoggedIn) {
      if (_state.isOnBreak) {
        final Duration currentBreakDuration = _state.breakStartTime != null
            ? DateTime.now().difference(_state.breakStartTime!)
            : Duration.zero;
        displayText = 'BREAK\n${_formatDuration(currentBreakDuration)}';
        circleColor = Colors.orange;
        instructionText = 'Long press to end break';
      } else {
        if (_state.remainingShiftTime.inSeconds > 0) {
          displayText = 'WORKING\n${_formatDuration(_state.workDuration)}';
          circleColor = Colors.blue;
          instructionText = 'Long press for break';
        } else {
          displayText = 'SHIFT\nCOMPLETE';
          circleColor = Colors.green;
          instructionText = 'Tap to logout';
        }
      }
    } else {
      instructionText = 'Tap to start your day';
    }

    final Widget circle = Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: circleColor,
        boxShadow: [
          BoxShadow(
            color: circleColor.withOpacity(0.3),
            spreadRadius: 8,
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (!_state.isLoggedIn) {
              _login();
            } else if (!_state.isOnBreak &&
                _state.remainingShiftTime.inSeconds <= 0) {
              _showLogoutConfirmationDialog();
            }
          },
          onLongPress: () {
            if (_state.isLoggedIn &&
                !_state.isOnBreak &&
                _state.remainingShiftTime.inSeconds > 0) {
              _startBreak();
            } else if (_state.isLoggedIn && _state.isOnBreak) {
              _endBreak();
            }
          },
          child: !_state.isLoggedIn
              ? AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: circle,
                  ),
                )
              : circle,
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            instructionText,
            key: ValueKey(instructionText),
            style: TextStyle(
              color: circleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    if (_isLoading) return _buildLoadingUserInfo();
    if (_hasError) return _buildErrorUserInfo();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  radius: 25,
                  child: const Icon(Icons.person, color: Colors.blue, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _state.userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _state.isLoggedIn
                            ? "Currently Working"
                            : "Not Logged In",
                        style: TextStyle(
                          color: _state.isLoggedIn ? Colors.green : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Employee ID: ${_state.empId}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy - EEEE').format(DateTime.now()),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _state.isLoggedIn
                        ? Colors.green[100]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _state.isLoggedIn ? "ACTIVE" : "OFFLINE",
                    style: TextStyle(
                      color: _state.isLoggedIn
                          ? Colors.green[700]
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_state.isLoggedIn) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                    Icons.access_time,
                    'Work Time',
                    _formatDuration(_state.workDuration),
                  ),
                  _buildInfoItem(
                    Icons.coffee,
                    'Break Time',
                    _formatDuration(_state.totalBreakDurationToday),
                  ),
                  _buildInfoItem(
                    Icons.route,
                    'Distance',
                    '${_state.totalDistanceTraveled.toStringAsFixed(1)} km',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shift ends:',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Text(
                      _formatDuration(_state.remainingShiftTime),
                      style: TextStyle(
                        color: _state.remainingShiftTime.inHours < 1
                            ? Colors.orange
                            : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingUserInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              radius: 25,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "LOADING",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUserInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red[100],
                  radius: 25,
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Error Loading User",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        _errorMessage ?? 'Unknown error occurred',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _initializeUserData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Loading'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Colors.blue),
          ),
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: () async {
            _safeShowSnackBar(
              'Refreshing...',
              backgroundColor: Colors.blue,
              icon: Icons.refresh,
              durationSeconds: 2,
            );
            await _syncWithFirestore();
            if (_state.isLoggedIn) _updateWorkDuration();
          },
          label: const Text(
            'REFRESH DATA',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    if (!_state.isLoggedIn ||
        _state.isOnBreak ||
        _state.remainingShiftTime.inSeconds <= 0 ||
        _isLoading)
      {return const SizedBox.shrink();}
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.logout),
          onPressed: _showLogoutConfirmationDialog,
          label: const Text(
            'EARLY LOGOUT',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBanner() {
    if (_locationEnabled || _isLoading) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[100]!, Colors.orange[50]!],
        ),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Enable location for accurate attendance tracking',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(60, 30),
            ),
            onPressed: _checkLocationPermission,
            child: const Text('Enable', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initializeApp,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    String? logoutReason;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Confirm Logout'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to logout?'),
              const SizedBox(height: 16),
              const Text(
                'Early logout reason (optional):',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'e.g., Doctor appointment, Personal work...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) {
                  logoutReason = value.isEmpty ? null : value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _logout(reason: logoutReason);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCancelApprovalDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 8),
              Text('Cancel Approval Request'),
            ],
          ),
          content: const Text(
            'Are you sure you want to cancel this login approval request?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No, Keep Waiting'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _cancelApprovalRequest();
              },
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeUserData() async {
    if (_isDisposed) return;
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _updateState(
          _state.copyWith(userName: "Please Sign In", userId: "", empId: ""),
        );
        return;
      }
      final cached = await _stateService.loadUserData();
      if (cached['userName']!.isNotEmpty && cached['empId']!.isNotEmpty) {
        _updateState(
          _state.copyWith(
            userName: cached['userName']!,
            empId: cached['empId']!,
            userId: currentUser.uid,
          ),
        );
      }

      final DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final Employee emp = Employee.fromMap(data);
        _updateState(
          _state.copyWith(
            userName: emp.empName,
            empId: emp.empCode.isNotEmpty ? emp.empCode : emp.uid,
            userId: currentUser.uid,
          ),
        );
        await _stateService.saveUserData(
          emp.empName,
          emp.empCode,
          currentUser.uid,
        );
        _setupUserDataListener(currentUser.uid);
      } else {
        _updateState(
          _state.copyWith(userName: "Employee Data Not Found", empId: ""),
        );
      }
    } catch (e, st) {
      _logError('Error initializing user data', e, st);
      _handleError('Failed to load employee data. Please check connection.');
    } finally {
      if (_safeToUpdate())
        {_safeSetState(() {
          _isLoading = false;
        });}
    }
  }

  void _setupUserDataListener(String userId) {
    _userDataListener?.cancel();
    _userDataListener = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && _safeToUpdate()) {
              try {
                final Map<String, dynamic> data =
                    snapshot.data() as Map<String, dynamic>;
                final Employee emp = Employee.fromMap(data);
                _updateState(
                  _state.copyWith(
                    userName: emp.empName,
                    empId: emp.empCode.isNotEmpty ? emp.empCode : userId,
                  ),
                );
                _stateService.saveUserData(emp.empName, emp.empCode, userId);
              } catch (e, st) {
                _logError('Error in user data listener', e, st);
              }
            }
          },
          onError: (err) {
            _logError('Error in user data listener', err, null);
          },
        );
  }

  // ----------------------------
  // Lifecycle
  // ----------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isDisposed) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_state.isLoggedIn) _startBackgroundService();
        break;
      case AppLifecycleState.resumed:
        unawaited(_syncWithFirestore());
        _stopBackgroundService();
        if (_state.isLoggedIn && _state.loginTime != null) {
          _startWorkTimer();
          _updateWorkDuration();
          unawaited(_updateNotification());
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _saveStateDebounceTimer?.cancel();
    _workTimer?.cancel();
    _syncTimer?.cancel();
    _locationTimer?.cancel();
    _approvalTimeoutTimer?.cancel();
    _approvalListener?.cancel();
    _userDataListener?.cancel();
    _approvalPollingSubscription?.cancel();
    _attendanceListener?.cancel(); // Cancel realtime sync listener
    try {
      _pulseController.dispose();
      _slideController.dispose();
    } catch (_) {}
    _stopAllServices();
    try {
      _stateService.saveAppState(_state);
    } catch (_) {}
    super.dispose();
  }

  void _stopAllServices() {
    _stopWorkTimer();
    _stopLocationTracking();
    _stopBackgroundService();
    try {
      _notificationsPlugin.cancel(1);
    } catch (_) {}
  }

  // ----------------------------
  // Build
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Attendance Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
        actions: [
          if (_state.isLoggedIn && !_isLoading)
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: _updateNotification,
              tooltip: 'Update Notification',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              _safeShowSnackBar(
                'Syncing...',
                backgroundColor: Colors.blue,
                icon: Icons.sync,
                durationSeconds: 2,
              );
              await _syncWithFirestore();
              if (_state.isLoggedIn) _updateWorkDuration();
            },
            tooltip: 'Sync Now',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_hasError) _buildErrorWidget(),
              if (!_hasError) ...[
                _buildInstructionsCard(),
                const SizedBox(height: 16),
                _buildLocationBanner(),
                const SizedBox(height: 24),
                _buildAttendanceCircle(),
                const SizedBox(height: 24),
                _buildRefreshButton(),
                const SizedBox(height: 8),
                _buildLogoutButton(),
                const SizedBox(height: 24),
                _buildUserInfo(),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    if (!_state.showInstructions || _isLoading) return const SizedBox.shrink();
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _state.showInstructions ? 1.0 : 0.0,
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'How to Use Attendance System',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => _updateState(
                        _state.copyWith(showInstructions: false),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildInstructionItem(
                  Icons.login,
                  'LOGIN (9:30 AM)',
                  'Tap to start. 15 min grace period. After 9:45 AM requires approval',
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildInstructionItem(
                  Icons.coffee,
                  'BREAK',
                  'Long press during work to take a break',
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildInstructionItem(
                  Icons.work,
                  'RESUME',
                  'Long press again to end your break',
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildInstructionItem(
                  Icons.logout,
                  'LOGOUT (6:30 PM)',
                  'Tap when shift ends or provide early logout reason',
                  Colors.red,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.gps_fixed, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📍 Location tracked every 10 sec. Distance calculated automatically',
                          style: TextStyle(
                            color: Colors.amber[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 12,
                ),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------
  // Minor helpers left for completeness (some methods may be used above)
  // ----------------------------
  // (Already implemented earlier in the file)
}

// ApprovalCheckResult class
class ApprovalCheckResult {
  final String status;
  final String reason;
  final Map<String, dynamic>? data;
  const ApprovalCheckResult({
    required this.status,
    required this.reason,
    this.data,
  });
}
