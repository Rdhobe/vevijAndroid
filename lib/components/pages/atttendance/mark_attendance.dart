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
import 'dart:async';
import 'package:flutter/foundation.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // State Management
  AppState _state = AppState.initial();
  final StatePersistenceService _stateService = StatePersistenceService();
  
  // Controllers and Timers
  Timer? _timer;
  Timer? _syncTimer;
  Timer? _locationTimer;
  Timer? _saveStateDebounceTimer;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Services
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Location
  Position? _currentPosition;
  Position? _lastStoredPosition;
  bool _locationEnabled = false;
  bool _isGettingLocation = false;

  // Stream Subscriptions
  StreamSubscription? _approvalListener;
  StreamSubscription? _userDataListener;
  StreamSubscription? _approvalPollingSubscription;
  Timer? _approvalTimeoutTimer;
  // Flags
  bool _isDisposed = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _hasError = false;
  String? _errorMessage;

  // SnackBar dedupe
  String? _lastSnackMessage;
  DateTime? _lastSnackTime;
  final Duration _snackDebounce = const Duration(seconds: 4);
  
  // Performance optimization
  DateTime _lastLocationUpdate = DateTime.now();
  DateTime _lastLocationStore = DateTime.now();
  DateTime _lastNotificationUpdate = DateTime.now();
  static const Duration _locationUpdateInterval = Duration(seconds: 10);
  static const Duration _locationStoreInterval = Duration(seconds: 30);
  static const Duration _notificationUpdateInterval = Duration(seconds: 10);
  static const Duration _syncInterval = Duration(seconds: 60);

  // Timer debugging
  int _timerTickCount = 0;
  DateTime? _lastTimerTick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (_isDisposed) return;
    
    try {
      // Initialize state first
      _state = await _stateService.loadAppState();
      
      // Initialize animations
      _initializeAnimations();
      
      // Initialize services in sequence
      await _initializeNotifications();
      await _checkLocationPermission();
      await _initializeUserData();
      await _initializeBackgroundService();
      
      // Start periodic tasks
      _startPeriodicSync();
      _startPeriodicStateSave();

      // Recover approval state if needed
      await _recoverApprovalState();

      // Auto-start timer if user is logged in
      if (_state.isLoggedIn && _state.loginTime != null && !_state.isWaitingForApproval) {
        _startTimer();
        _startLocationTracking();
        _updateNotification();
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }

      _startInstructionsTimer();
      
    } catch (e, stackTrace) {
      _logError('Error initializing app', e, stackTrace);
      _handleError('Failed to initialize app. Please restart.');
    }
  }
  Future<void> _initializeUserData() async {
    if (_isDisposed) return;

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _updateState(_state.copyWith(
          userName: "Please Sign In",
          userId: "",
          empId: "",
          shift: "",  
        ));
        return;
      }

      // Try to load cached user data first
      final cachedUserData = await _stateService.loadUserData();
      if (cachedUserData['userName']!.isNotEmpty && 
          cachedUserData['empId']!.isNotEmpty) {
        _updateState(_state.copyWith(
          userName: cachedUserData['userName']!,
          empId: cachedUserData['empId']!,
          userId: currentUser.uid,
          shift: cachedUserData['shift']!,
        ));
      }

      // Fetch fresh data from Firestore
      final DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.exists) {
        final Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        final Employee employee = Employee.fromMap(data);
        
        _updateState(_state.copyWith(
          userName: employee.empName,
          empId: employee.empCode.isNotEmpty ? employee.empCode : employee.uid,
          userId: currentUser.uid,
          shift: employee.shift,
        ));

        await _stateService.saveUserData(employee.empName, employee.empCode, currentUser.uid , employee.shift);
        _setupUserDataListener(currentUser.uid);
      } else {
        _updateState(_state.copyWith(
          userName: "Employee Data Not Found",
          empId: "",

        ));
      }
    } catch (e, stackTrace) {
      _logError('Error initializing user data', e, stackTrace);
      _handleError('Failed to load employee data. Please check connection.');
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) async {
      if (!_isDisposed && !_isSyncing && _state.isLoggedIn) {
        await _syncWithFirestore();
      }
    });
  }

  void _startPeriodicStateSave() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!_isDisposed) {
        _stateService.saveAppState(_state);
      }
    });
  }

  void _setupUserDataListener(String userId) {
    _userDataListener?.cancel();
    _userDataListener = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted && !_isDisposed) {
            try {
              final Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
              final Employee employee = Employee.fromMap(data);
              _updateState(_state.copyWith(
                userName: employee.empName,
                empId: employee.empCode.isNotEmpty ? employee.empCode : userId,
                shift: employee.shift,
              ));
              _stateService.saveUserData(employee.empName, employee.empCode, userId , employee.shift);
            } catch (e, stackTrace) {
              _logError('Error in user data listener', e, stackTrace);
            }
          }
        }, onError: (error) {
          _logError('Error in user data listener', error, null);
        });
  }

  Future<void> _checkLocationPermission() async {
    if (_isDisposed) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && !_isDisposed) {
          _updateState(_state.copyWith(currentCoordinates: 'Location service disabled'));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && !_isDisposed) {
            _updateState(_state.copyWith(currentCoordinates: 'Location permission denied'));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && !_isDisposed) {
          _updateState(_state.copyWith(currentCoordinates: 'Location permission permanently denied'));
        }
        return;
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _locationEnabled = true;
        });
      }
    } catch (e, stackTrace) {
      _logError('Error checking location permission', e, stackTrace);
      if (mounted && !_isDisposed) {
        _updateState(_state.copyWith(currentCoordinates: 'Error checking location'));
      }
    }
  }

  Future<void> _recoverApprovalState() async {
    try {
      final approvalState = await _stateService.loadApprovalState();
      
      if (approvalState['isWaitingForApproval'] == true && 
          approvalState['pendingApprovalId'] != null) {
        
        final approvalId = approvalState['pendingApprovalId']!;
        final requestTime = approvalState['approvalRequestTime'];
        
        // Check if approval request is expired
        if (requestTime != null && 
            DateTime.now().difference(requestTime).inHours >= 24) {
          await _handleExpiredApproval(approvalId);
          return;
        }
        
        // Restore approval waiting state
        _updateState(_state.copyWith(
          isWaitingForApproval: true,
          pendingApprovalId: approvalId,
          approvalRequestTime: requestTime,
        ));
        
        // Re-establish listener
        _listenForApproval(approvalId);
      }
    } catch (e, stackTrace) {
      _logError('Error recovering approval state', e, stackTrace);
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
      _logError('Error marking approval as expired', e, null);
    }
    
    _updateState(_state.copyWith(
      isWaitingForApproval: false,
      loginTime: null,
      pendingApprovalId: null,
      approvalRequestTime: null,
    ));
    
    await _stateService.clearApprovalState();
    
    _safeShowSnackBar(
      '⏰ Approval request expired after 24 hours. Please login again.',
      backgroundColor: Colors.orange,
      icon: Icons.access_time,
      durationSeconds: 6,
    );
  }
  void _listenForApproval(String approvalId) {
    _approvalListener?.cancel();

    _approvalListener = FirebaseFirestore.instance
        .collection('loginApprovals')
        .doc(approvalId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists || _isDisposed) return;

          try {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
            String status = data['status'] ?? 'pending';

            if (status == 'approved') {
              _approvalListener?.cancel();
              if (mounted && !_isDisposed) {
                _updateState(_state.copyWith(isWaitingForApproval: false));
                _completeLogin();
                _safeShowSnackBar(
                  'Login approved by ${data['approvedBy'] ?? 'Admin'}',
                  backgroundColor: Colors.green,
                  icon: Icons.check_circle,
                );
              }
            } else if (status == 'rejected') {
              _approvalListener?.cancel();
              if (mounted && !_isDisposed) {
                _updateState(_state.copyWith(
                  isWaitingForApproval: false,
                  loginTime: null,
                ));
                _safeShowSnackBar(
                  'Login request rejected: ${data['rejectionReason'] ?? 'No reason provided'}',
                  backgroundColor: Colors.red,
                  icon: Icons.cancel,
                  durationSeconds: 5,
                );
              }
            }
          } catch (e, stackTrace) {
            _logError('Error in approval listener', e, stackTrace);
          }
        }, onError: (error) {
          _logError('Error in approval listener', error, null);
        });
  }
  Future<void> _updateNotification() async {
    if (!_state.isLoggedIn) {
      await _notificationsPlugin.cancel(1);
      return;
    }

    try {
      String dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());
      String title = 'Attendance Tracker - ${_state.userName}';
      String body;

      if (_state.isOnBreak) {
        Duration currentBreakDuration = _state.breakStartTime != null
            ? DateTime.now().difference(_state.breakStartTime!)
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
    } catch (e, stackTrace) {
      _logError('Error updating notification', e, stackTrace);
    }
  }
  void _startInstructionsTimer() {
    Timer(const Duration(seconds: 10), () {
      if (mounted && !_isDisposed && !_state.isLoggedIn) {
        _updateState(_state.copyWith(showInstructions: false));
      }
    });
  }

  void _handleError(String message) {
    if (mounted && !_isDisposed) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(initializationSettings);

      final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
      await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e, stackTrace) {
      _logError('Error initializing notifications', e, stackTrace);
    }
  }

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
    } catch (e, stackTrace) {
      _logError('Error initializing background service', e, stackTrace);
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
      final String? breakStartTimeStr = prefs.getString(PersistenceKeys.bgBreakStartTime);
      final int totalBreakSeconds = prefs.getInt(PersistenceKeys.bgTotalBreakDurationSeconds) ?? 0;
      final bool isOnBreak = prefs.getBool(PersistenceKeys.bgIsOnBreak) ?? false;
      final bool isLoggedIn = prefs.getBool(PersistenceKeys.bgIsLoggedIn) ?? false;

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
      final String body;

      if (isOnBreak) {
        body =
            '$dateStr\n🟠 On Break: ${_formatDurationStatic(currentBreakDuration)}\n⏰ Work: ${_formatDurationStatic(workDuration)}';
      } else {
        body =
            '$dateStr\n🔵 Working: ${_formatDurationStatic(workDuration)}\n☕ Break: ${_formatDurationStatic(totalBreakDuration)}';
      }

      service.invoke('update', {
        'title': title,
        'body': body,
        'workDuration': workDuration.inSeconds,
        'breakDuration': totalBreakDuration.inSeconds,
      });
    });
  }
  
  static String _formatDurationStatic(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
  void _initializeAnimations() {
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

    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    if (!_state.isLoggedIn) {
      _pulseController.repeat(reverse: true);
    }
    _slideController.forward();
  }

  // ... [Keep all your existing service initialization methods exactly as they are]
  // _initializeNotifications, _initializeBackgroundService, _initializeUserData, etc.

  // FIXED TIMER IMPLEMENTATION
  void _startTimer() {
    _timer?.cancel(); // Always cancel existing timer first
    
    if (_isDisposed || !_state.isLoggedIn || _state.loginTime == null) {
      if (kDebugMode) print('⏰ Timer not started: disposed=$_isDisposed, loggedIn=${_state.isLoggedIn}, loginTime=${_state.loginTime}');
      return;
    }

    if (kDebugMode) print('⏰ Starting work timer...');
    _timerTickCount = 0;
    _lastTimerTick = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timerTickCount++;
      _lastTimerTick = DateTime.now();
      
      if (!mounted || _isDisposed || !_state.isLoggedIn || _state.loginTime == null) {
        if (kDebugMode) print('⏰ Timer cancelled: mounted=$mounted, disposed=$_isDisposed, loggedIn=${_state.isLoggedIn}');
        timer.cancel();
        return;
      }
      
      try {
        _updateWorkDuration();
        
        // Throttle notification updates
        if (DateTime.now().difference(_lastNotificationUpdate) > _notificationUpdateInterval) {
          _updateNotification();
          _lastNotificationUpdate = DateTime.now();
        }

        // Debug logging every 30 seconds
        if (_timerTickCount % 30 == 0 && kDebugMode) {
          print('⏰ Timer active - ticks: $_timerTickCount, work: ${_formatDuration(_state.workDuration)}');
        }
      } catch (e, stackTrace) {
        _logError('Timer error', e, stackTrace);
        timer.cancel();
      }
    });
  }

  void _updateWorkDuration() {
    if (!_state.isLoggedIn || _state.loginTime == null) return;

    final now = DateTime.now();
    Duration newWorkDuration;
    Duration newRemainingShiftTime = _calculateRemainingTime();

    if (!_state.isOnBreak) {
      // Normal working time calculation
      newWorkDuration = now.difference(_state.loginTime!) - _state.totalBreakDurationToday;
    } else if (_state.breakStartTime != null) {
      // On break - subtract current break duration
      Duration currentBreak = now.difference(_state.breakStartTime!);
      newWorkDuration = now.difference(_state.loginTime!) - _state.totalBreakDurationToday - currentBreak;
    } else {
      // Fallback
      newWorkDuration = _state.workDuration;
    }

    // Ensure duration is not negative
    if (newWorkDuration.isNegative) {
      newWorkDuration = Duration.zero;
    }

    // Only update state if values actually changed
    if (newWorkDuration != _state.workDuration || newRemainingShiftTime != _state.remainingShiftTime) {
      _updateState(_state.copyWith(
        workDuration: newWorkDuration,
        remainingShiftTime: newRemainingShiftTime,
      ));
    }
  }

  void _stopTimer() {
    if (kDebugMode) print('⏰ Stopping work timer...');
    _timer?.cancel();
    _timer = null;
  }

  // ENHANCED LOCATION TRACKING
  void _startLocationTracking() {
    if (_isDisposed || !_state.isLoggedIn) return;

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(_locationUpdateInterval, (timer) async {
      if (!_state.isLoggedIn || _isDisposed) {
        timer.cancel();
        return;
      }
      try {
        await _getCurrentLocation();
      } catch (e) {
        _logError('Error in location timer', e, null);
      }
    });
    _getCurrentLocation(); // Get initial location immediately
  }

  Future<void> _getCurrentLocation() async {
    if (_isDisposed || _isGettingLocation) return;

    // Throttle location updates
    if (DateTime.now().difference(_lastLocationUpdate) < _locationUpdateInterval) {
      return;
    }

    _isGettingLocation = true;

    try {
      if (!_locationEnabled) {
        await _checkLocationPermission();
        if (!_locationEnabled) return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      ).timeout(const Duration(seconds: 15));

      if (_currentPosition != null && !_isDisposed) {
        String newCoordinates =
            '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';

        _updateState(_state.copyWith(currentCoordinates: newCoordinates));

        if (_state.isLoggedIn && _state.userId.isNotEmpty) {
          await _updateRealTimeLocation();
          String activityType = _state.isOnBreak ? 'on_break' : 'working';
          await _storeLocationInHistory(activityType);
        }

        _lastLocationUpdate = DateTime.now();
      }
    } on TimeoutException {
      _updateState(_state.copyWith(currentCoordinates: 'Location timeout'));
    } catch (e, stackTrace) {
      _logError('Error getting location', e, stackTrace);
      _updateState(_state.copyWith(currentCoordinates: 'Location unavailable'));
    } finally {
      _isGettingLocation = false;
    }
  }
  Future<void> _storeLocationInHistory(String activityType) async {
    // Rate limiting for Firestore writes - store every 30 seconds only
    if (DateTime.now().difference(_lastLocationStore) < _locationStoreInterval) {
      return;
    }

    if (_isDisposed ||
        !_state.isLoggedIn ||
        _state.currentCoordinates.isEmpty ||
        _state.todayAttendanceId == null) {
      return;
    }
    
    try {
      double distanceMoved = 0.0;
      if (_lastStoredPosition != null && _currentPosition != null) {
        distanceMoved = _calculateDistance(
          _lastStoredPosition!,
          _currentPosition!,
        );

        if (distanceMoved > 10) { // Only count significant movements (>10 meters)
          _updateState(_state.copyWith(
            totalDistanceTraveled: _state.totalDistanceTraveled + (distanceMoved / 1000)
          ));
        }
      }

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
            'distanceFromLast': distanceMoved / 1000,
            'totalDistance': _state.totalDistanceTraveled,
            'userName': _state.userName,
            'userId': _state.userId,
          });

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(_state.todayAttendanceId)
          .update({
            'totalDistanceTraveled': _state.totalDistanceTraveled,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          });

      _lastStoredPosition = _currentPosition;
      _lastLocationStore = DateTime.now(); // Update last store time
    } catch (e, stackTrace) {
      _logError('Error storing location history', e, stackTrace);
    }
  }
  double _calculateDistance(Position start, Position end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }
  Future<void> _updateRealTimeLocation() async {
    if (_isDisposed || !_state.isLoggedIn || _state.currentCoordinates.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_state.userId).update({
        'currentLocation': _state.currentCoordinates,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'isCurrentlyWorking': _state.isLoggedIn,
        'isOnBreak': _state.isOnBreak,
        'workStatus': _state.isOnBreak ? 'On Break' : 'Working',
        'todayLoginTime': _state.loginTime?.toIso8601String(),
        'currentWorkDuration': _formatDuration(_state.workDuration),
        'currentBreakDuration': _formatDuration(_state.totalBreakDurationToday),
        'totalDistanceTraveled': _state.totalDistanceTraveled,
      });
    } catch (e, stackTrace) {
      _logError('Error updating real-time location', e, stackTrace);
    }
  }
  // ENHANCED LOGIN WITH PROPER TIMER START
  Future<void> _completeLogin() async {
    if (_state.isLoggedIn) {
      if (kDebugMode) print('⚠️ _completeLogin aborted - already logged in');
      return;
    }

    final now = DateTime.now();

    _updateState(_state.copyWith(
      isLoggedIn: true,
      isOnBreak: false,
      isWaitingForApproval: false,
      loginTime: now,
      workDuration: Duration.zero,
      totalBreakDurationToday: Duration.zero,
      totalDistanceTraveled: 0.0,
      showInstructions: false,
      remainingShiftTime: _calculateRemainingTime(),
    ));

    // Persist keys used by the background service
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

    // CRITICAL: Start timers and services AFTER state is fully updated
    _startLocationTracking();
    _startTimer();
    await _updateNotification();
    await _startBackgroundService();

    _safeShowSnackBar(
      'Welcome back, ${_state.userName}! 🌟',
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
      durationSeconds: 4,
    );

    if (kDebugMode) print('✅ Login completed successfully - timers started');
  }
  Future<void> _startBackgroundService() async {
    try {
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();

      if (!isRunning && _state.isLoggedIn) {
        await service.startService();
      }
    } catch (e, stackTrace) {
      _logError('Error starting background service', e, stackTrace);
    }
  }
   Future<void> _createTodayAttendanceRecord() async {
    if (_isDisposed) return;

    try {
      DateTime today = DateTime.now();
      String dateKey = DateFormat('dd-MMM-yy').format(today);
      String dayName = DateFormat('EEE').format(today);

      QuerySnapshot existing = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _state.userId)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        DocumentReference docRef = await FirebaseFirestore.instance
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
        _updateState(_state.copyWith(todayAttendanceId: existing.docs.first.id));
      }
    } catch (e, stackTrace) {
      _logError('Error creating attendance record', e, stackTrace);
      _safeShowSnackBar(
        'Failed to create attendance record',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }

  Future<void> _updateAttendanceOnLogin() async {
    if (_isDisposed) return;

    if (_state.todayAttendanceId == null) {
      await _createTodayAttendanceRecord();
    }

    if (_state.todayAttendanceId != null && _state.loginTime != null) {
      try {
        String inTimeStr = DateFormat('h:mm a').format(_state.loginTime!);
        double lateHours = _calculateLateHours(_state.loginTime!);
        double lateMark = lateHours > 0 ? 1.0 : 0.0;

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
      } catch (e, stackTrace) {
        _logError('Error updating login time', e, stackTrace);
      }
    }
  }
  double _calculateLateHours(DateTime actualInTime) {
    DateTime now = actualInTime;
    DateTime standardInTime = DateTime(now.year, now.month, now.day, 9, 30);

    if (actualInTime.isAfter(standardInTime)) {
      Duration lateDuration = actualInTime.difference(standardInTime);
      return lateDuration.inMinutes / 60.0;
    }

    return 0.0;
  }

  // ENHANCED LOGOUT
  Future<void> _logout({String? reason}) async {
    if (_isDisposed) return;

    await _getCurrentLocation();
    await _storeLocationInHistory('logout');

    // Stop services FIRST
    _stopTimer();
    _stopLocationTracking();
    await _stopBackgroundService();

    // Then update attendance
    await _updateAttendanceOnLogout(reason: reason);

    // Then update UI and notifications
    await _notificationsPlugin.cancel(1);

    _updateState(AppState.initial().copyWith(
      userName: _state.userName,
      userId: _state.userId,
      empId: _state.empId,
    ));

    _pulseController.repeat(reverse: true);

    // Clear background-service prefs on logout
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PersistenceKeys.bgIsLoggedIn, false);
      await prefs.remove(PersistenceKeys.bgLoginTime);
      await prefs.remove(PersistenceKeys.bgBreakStartTime);
      await prefs.setBool(PersistenceKeys.bgIsOnBreak, false);
      await prefs.setInt(PersistenceKeys.bgTotalBreakDurationSeconds, _state.totalBreakDurationToday.inSeconds);
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

    if (kDebugMode) print('✅ Logout completed successfully - all timers stopped');
  }
  Future<void> _stopBackgroundService() async {
    try {
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('stop');
      }
    } catch (e, stackTrace) {
      _logError('Error stopping background service', e, stackTrace);
    }
  }
  Future<void> _updateAttendanceOnLogout({String? reason}) async {
    if (_isDisposed) return;

    if (_state.todayAttendanceId != null && _state.loginTime != null) {
      try {
        DateTime logoutTime = DateTime.now();
        String outTimeStr = DateFormat('h:mm a').format(logoutTime);

        Duration totalWork =
            logoutTime.difference(_state.loginTime!) - _state.totalBreakDurationToday;
        double totalHours = totalWork.inMinutes / 60.0;
        double shiftHours = _getShiftDuration().inMinutes / 60.0;
        double otHours = totalHours > shiftHours
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
      } catch (e, stackTrace) {
        _logError('Error updating logout time', e, stackTrace);
      }
    }
  }
  Duration _getShiftDuration() {
    return const Duration(hours: 9);
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
          .catchError((e) => _logError('Error updating offline status', e, null));
    }
  }
  // ENHANCED BREAK MANAGEMENT
  Future<void> _startBreak() async {
    if (_isDisposed) return;

    await _getCurrentLocation();

    _updateState(_state.copyWith(
      isOnBreak: true,
      breakStartTime: DateTime.now(),
    ));

    // Persist break start for background service
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PersistenceKeys.bgIsOnBreak, true);
      await prefs.setString(PersistenceKeys.bgBreakStartTime, DateTime.now().toIso8601String());
      await prefs.setInt(PersistenceKeys.bgTotalBreakDurationSeconds, _state.totalBreakDurationToday.inSeconds);
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

    Duration currentBreakDuration = _state.breakStartTime != null
        ? DateTime.now().difference(_state.breakStartTime!)
        : Duration.zero;

    _updateState(_state.copyWith(
      isOnBreak: false,
      totalBreakDurationToday: _state.totalBreakDurationToday + currentBreakDuration,
      breakStartTime: null,
    ));

    // Persist break end for background service
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PersistenceKeys.bgIsOnBreak, false);
      await prefs.remove(PersistenceKeys.bgBreakStartTime);
      await prefs.setInt(PersistenceKeys.bgTotalBreakDurationSeconds, _state.totalBreakDurationToday.inSeconds);
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

  // ENHANCED STATE MANAGEMENT
  void _updateState(AppState newState) {
    if (mounted && !_isDisposed && _state != newState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          setState(() {
            _state = newState;
          });
          
          _saveStateDebounceTimer?.cancel();
          _saveStateDebounceTimer = Timer(const Duration(milliseconds: 500), () {
            if (!_isDisposed) {
              _stateService.saveAppState(newState);
            }
          });
        }
      });
    }
  }

  // ENHANCED APP LIFECYCLE
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (kDebugMode) print('🔄 App lifecycle: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_state.isLoggedIn) {
          _startBackgroundService();
        }
        break;
      case AppLifecycleState.resumed:
        _syncWithFirestore();
        _stopBackgroundService();
        if (_state.isLoggedIn && _state.loginTime != null) {
          // Restart timer and update immediately when app resumes
          _startTimer();
          _updateWorkDuration();
          _updateNotification();
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
    }
  }

  // ENHANCED DISPOSE
  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel all timers in correct order
    _saveStateDebounceTimer?.cancel();
    _timer?.cancel();
    _syncTimer?.cancel();
    _locationTimer?.cancel();
    
    // Cancel all subscriptions
    _approvalListener?.cancel();
    _userDataListener?.cancel();
    
    // Dispose controllers
    _pulseController.dispose();
    _slideController.dispose();
    
    // Stop services
    _stopAllServices();
    
    // Save final state
    _stateService.saveAppState(_state);
    
    if (kDebugMode) print('🧹 MarkAttendancePage disposed properly');
    
    super.dispose();
  }

  void _stopAllServices() {
    _stopTimer();
    _stopLocationTracking();
    _stopBackgroundService();
    _notificationsPlugin.cancel(1);
  }

  // ENHANCED ERROR HANDLING
  void _logError(String message, dynamic error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('❌ $message: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  // ENHANCED SYNC WITH FIREBASE
  Future<void> _syncWithFirestore() async {
    if (_isDisposed || _isSyncing || _state.userId.isEmpty) return;

    _isSyncing = true;
    
    try {
      final String today = DateFormat('dd-MMM-yy').format(DateTime.now());
      
      final QuerySnapshot attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _state.userId)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        await _handleExistingAttendance(attendanceQuery.docs.first, today);
      } else {
        await _handleNoAttendanceRecord();
      }

      // Force UI update after sync
      if (_state.isLoggedIn) {
        _updateWorkDuration();
      }
    } catch (e, stackTrace) {
      _logError('Error syncing with Firestore', e, stackTrace);
      if (mounted && !_isDisposed) {
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
    if (_state.isLoggedIn) {
      await _createTodayAttendanceRecord();
      if (_state.loginTime != null) {
        await _updateAttendanceOnLogin();
      }
    }
  }
  Future<void> _handleExistingAttendance(DocumentSnapshot doc, String today) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final attendance = Attendance.fromFirestore(doc);

      if (attendance.inTime != null && attendance.outTime == null) {
        if (!_state.isLoggedIn) {
          await _restoreLoginState(attendance);
        } else {
          if (_state.isOnBreak != attendance.isOnBreak) {
            _updateState(_state.copyWith(isOnBreak: attendance.isOnBreak));
          }
        }
      } else if (attendance.outTime != null && _state.isLoggedIn) {
        // Server indicates this day's attendance has an outTime (user logged out remotely).
        // Do NOT perform an automatic logout — require user to tap Logout manually.
        if (kDebugMode) print('ℹ️ Remote outTime detected for attendance ${attendance.id}; not auto-logging out.');

        // Update stored todayAttendanceId so UI reflects server record, but keep user logged in.
        _updateState(_state.copyWith(todayAttendanceId: attendance.id));

        // Notify the user once about the remote record without forcing logout.
        _safeShowSnackBar(
          'Notice: Attendance shows you were logged out remotely. Please tap Logout to finish your day.',
          backgroundColor: Colors.orange,
          icon: Icons.info_outline,
          durationSeconds: 5,
        );
      }
    } catch (e, stackTrace) {
      _logError('Error handling existing attendance', e, stackTrace);
    }
  }
Future<void> _restoreLoginState(Attendance attendance) async {
    try {
      final parsedLoginTime = _parseTimeToToday(attendance.inTime!);
      DateTime? breakStartTime;
      
      if (attendance.isOnBreak && attendance.breakStartTime != null) {
        breakStartTime = _parseTimeToToday(attendance.breakStartTime!);
      }

      _updateState(_state.copyWith(
        isLoggedIn: true,
        isOnBreak: attendance.isOnBreak,
        loginTime: parsedLoginTime,
        breakStartTime: breakStartTime,
        todayAttendanceId: attendance.id,
        totalBreakDurationToday: Duration(seconds: attendance.totalBreakSeconds),
        totalDistanceTraveled: attendance.totalDistanceTraveled,
        showInstructions: false,
      ));

      _startTimer();
      _startLocationTracking();
      await _updateNotification();
      
      _safeShowSnackBar(
        'Session restored from server',
        backgroundColor: Colors.green,
        icon: Icons.cloud_done,
      );
    } catch (e, stackTrace) {
      _logError('Error restoring login state', e, stackTrace);
    }
  }

  // ENHANCED UI COMPONENTS

  DateTime _parseTimeToToday(String timeStr) {
    try {
      DateTime now = DateTime.now();
      DateFormat format = DateFormat('h:mm a');
      DateTime parsed = format.parse(timeStr);
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      return DateTime.now();
    }
  }
   Widget _buildLoadingWidget() {
    return Column(children: [
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
              offset: const Offset(0, 5)
            )
          ],
        ),
        child: Stack(
          alignment: Alignment.center, 
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), 
              strokeWidth: 3
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                const Icon(Icons.hourglass_empty, color: Colors.grey, size: 40), 
                const SizedBox(height: 8),
                const Text(
                  'LOADING', 
                  style: TextStyle(
                    color: Colors.grey, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ]
            ),
          ]
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Initializing...', 
        style: TextStyle(
          color: Colors.grey, 
          fontSize: 16, 
          fontWeight: FontWeight.w600
        ), 
        textAlign: TextAlign.center
      ),
    ]);
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
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_empty, color: Colors.white, size: 40),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _showCancelApprovalDialog(),
          child: const Text(
            'Cancel Request',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
  
  Future<void> _showCancelApprovalDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Cancel Approval Request'),
            ],
          ),
          content: const Text('Are you sure you want to cancel this login approval request?'),
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
        if (kDebugMode) print('❌ Error cancelling approval: $e');
      }
    }
    
    _cleanupApprovalListeners();
    _updateState(_state.copyWith(
      isWaitingForApproval: false,
      loginTime: null,
      pendingApprovalId: null,
      approvalRequestTime: null,
    ));
    
    await _stateService.clearApprovalState();
    
    _safeShowSnackBar(
      'Approval request cancelled',
      backgroundColor: Colors.grey,
      icon: Icons.cancel,
    );
  }

  void _cleanupApprovalListeners() {
    _approvalListener?.cancel();
    _approvalPollingSubscription?.cancel();
    _approvalTimeoutTimer?.cancel();
  }

  Future<void> _manualCheckApprovalStatus() async {
    if (_isDisposed || !mounted) {
      if (kDebugMode) print('⚠️ Manual check aborted - disposed or not mounted');
      return;
    }
    
    final approvalId = _state.pendingApprovalId;
    if (approvalId == null || !_state.isWaitingForApproval) {
      _safeShowSnackBar(
        '❌ No pending approval request found',
        backgroundColor: Colors.grey[600]!,
        icon: Icons.info_outline,
        durationSeconds: 3,
      );
      return;
    }
    
    // Show loading state
    _safeShowSnackBar(
      '🔍 Checking approval status...',
      backgroundColor: Colors.blue,
      icon: Icons.refresh,
      durationSeconds: 2,
    );
    
    try {
      // Add a small delay to show the loading state
      await Future.delayed(const Duration(milliseconds: 500));
      
      final result = await _performComprehensiveStatusCheck(approvalId);
      
      if (_isDisposed) return;
      
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
      if (kDebugMode) print('❌ Manual status check failed: $e');
      
      if (_isDisposed) return;
      
      _safeShowSnackBar(
        '🌐 Network error - Could not check status',
        backgroundColor: Colors.red,
        icon: Icons.wifi_off,
        durationSeconds: 4,
      );
      
      // Update retry count
      final newRetryCount = _state.approvalRetryCount + 1;
      _updateState(_state.copyWith(approvalRetryCount: newRetryCount));
    }
  }
  String _getFormattedWaitingTime() {
    final requestTime = _state.approvalRequestTime;
    if (requestTime == null) return 'Unknown time';
    
    final waitingDuration = DateTime.now().difference(requestTime);
    final hours = waitingDuration.inHours;
    final minutes = waitingDuration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
  Future<ApprovalCheckResult> _performComprehensiveStatusCheck(String approvalId) async {
    try {
      // 1. First attempt - direct document fetch
      final doc = await FirebaseFirestore.instance
          .collection('loginApprovals')
          .doc(approvalId)
          .get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Firestore query timeout');
          });
      
      if (!doc.exists) {
        return ApprovalCheckResult(
          status: 'missing',
          reason: 'Approval request not found in system',
        );
      }
      
      final data = doc.data();
      if (data == null) {
        return ApprovalCheckResult(
          status: 'corrupted',
          reason: 'Approval data is corrupted',
        );
      }
      
      final status = data['status']?.toString().toLowerCase() ?? 'pending';
      final reason = data['rejectionReason']?.toString() ?? 
                    data['notes']?.toString() ?? 
                    'No reason provided';
      
      // If approved or rejected, trigger the appropriate handler
      if (status == 'approved' && mounted && !_isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleApprovalUpdate(data);
        });
      } else if (status == 'rejected' && mounted && !_isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleApprovalUpdate(data);
        });
      }
      
      return ApprovalCheckResult(
        status: status,
        reason: reason,
        data: data,
      );
      
    } on TimeoutException catch (e) {
      if (kDebugMode) print('⏰ Status check timeout: $e');
      rethrow;
    } on FirebaseException catch (e) {
      if (kDebugMode) print('🔥 Firestore error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      if (kDebugMode) print('❌ Unexpected error in status check: $e');
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
      case 'pending':
        // Still waiting, update UI if needed
        _updateApprovalWaitingUI(data);
        break;
    }
  }
  
  void _updateApprovalWaitingUI(Map<String, dynamic> data) {
    if (_isDisposed || !mounted) return;
    
    try {
      final timestamp = data['updatedAt'] as Timestamp?;
      final lastUpdate = timestamp != null 
          ? DateFormat('h:mm a').format(timestamp.toDate())
          : 'Unknown';
      
      final requestedBy = data['approvedBy'] ?? 'Admin';
      final lateBy = data['lateBy'] ?? 0.0;
      final lateMinutes = (lateBy * 60).toInt();
      
      // Update any relevant state for UI refresh
      if (mounted) {
        setState(() {
          // Force UI refresh to show updated information
        });
      }
      
      // Log for debugging
      if (kDebugMode) {
        print('📊 Approval Status Update - '
            'Last Check: $lastUpdate, '
            'Late by: ${lateMinutes}min, '
            'Approver: $requestedBy');
      }
      
      // Show periodic status updates to user (every 10 minutes)
      final requestTime = _state.approvalRequestTime;
      if (requestTime != null) {
        final waitingDuration = DateTime.now().difference(requestTime);
        final waitingMinutes = waitingDuration.inMinutes;
        
        // Show status updates at specific intervals
        if (waitingMinutes == 5 || waitingMinutes == 15 || waitingMinutes == 30 || waitingMinutes % 60 == 0) {
          String statusMessage;
          Color backgroundColor;
          
          if (waitingMinutes <= 30) {
            statusMessage = 'Approval pending - ${waitingMinutes}m waiting '
                '(Late by ${lateMinutes}min)';
            backgroundColor = Colors.orange;
          } else if (waitingMinutes <= 120) {
            statusMessage = 'Still waiting for approval - ${waitingMinutes}m '
                'Consider following up with your manager';
            backgroundColor = Colors.orange[700]!;
          } else {
            statusMessage = 'Extended wait time - ${waitingMinutes}m '
                'Please contact admin/HR directly';
            backgroundColor = Colors.red;
          }
          
          _safeShowSnackBar(
            statusMessage,
            backgroundColor: backgroundColor,
            icon: Icons.access_time,
            durationSeconds: 5,
          );
        }
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Error in updateApprovalWaitingUI: $e');
      // Don't crash the app due to UI update errors
    }
  }

  void _handleApprovalApproved(Map<String, dynamic> data) {
    _cleanupApprovalListeners();
    
    _updateState(_state.copyWith(
      isWaitingForApproval: false,
      pendingApprovalId: null,
      approvalRequestTime: null,
      approvalRetryCount: 0,
    ));
    
    _stateService.clearApprovalState();
    _completeLogin();
    
    _safeShowSnackBar(
      '✅ Login approved by ${data['approvedBy'] ?? 'Admin'}',
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
      durationSeconds: 5,
    );
  }

  void _handleApprovalRejected(Map<String, dynamic> data) {
    _cleanupApprovalListeners();
    
    _updateState(_state.copyWith(
      isWaitingForApproval: false,
      loginTime: null,
      pendingApprovalId: null,
      approvalRequestTime: null,
      approvalRetryCount: 0,
    ));
    
    _stateService.clearApprovalState();
    
    _safeShowSnackBar(
      '❌ Login rejected: ${data['rejectionReason'] ?? 'No reason provided'}',
      backgroundColor: Colors.red,
      icon: Icons.cancel,
      durationSeconds: 6,
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
        Duration currentBreakDuration = _state.breakStartTime != null ? 
            DateTime.now().difference(_state.breakStartTime!) : Duration.zero;
        displayText = 'BREAK\n${_formatDuration(currentBreakDuration)}';
        circleColor = Colors.orange;
        instructionText = 'Long press to end break';
      } else {
        if (_state.remainingShiftTime.inSeconds > 0) {
          // FIXED: Show work duration instead of remaining shift time
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

    Widget circle = Container(
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
            offset: const Offset(0, 5)
          )
        ],
      ),
      child: Center(
        child: Text(
          displayText, 
          style: TextStyle(
            color: textColor, 
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            height: 1.2
          ), 
          textAlign: TextAlign.center
        )
      ),
    );

    return Column(children: [
      GestureDetector(
        onTap: () {
          if (!_state.isLoggedIn) {
            _login();
          } else if (!_state.isOnBreak && _state.remainingShiftTime.inSeconds <= 0) {
            _showLogoutConfirmationDialog();
          }
        },
        onLongPress: () {
          if (_state.isLoggedIn && !_state.isOnBreak && _state.remainingShiftTime.inSeconds > 0) {
            _startBreak();
          } else if (_state.isLoggedIn && _state.isOnBreak) {
            _endBreak();
          }
        },
        child: !_state.isLoggedIn ? AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(scale: _pulseAnimation.value, child: circle),
        ) : circle,
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
            fontWeight: FontWeight.w600
          ), 
          textAlign: TextAlign.center
        ),
      ),
      // Debug info in development
      if (kDebugMode && _state.isLoggedIn) ...[
        const SizedBox(height: 8),
        Text(
          'Timer: $_timerTickCount ticks',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    ]);
  }
  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String? logoutReason;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Future<void> _login() async {
    if (_isDisposed) return;

    _pulseController.stop();
    await _getCurrentLocation();

    final now = DateTime.now();

    final needsApproval = _needsLoginApproval();

    if (needsApproval) {
      final approvalId = await _requestLoginApproval();
      if (approvalId != null) {
        // Save approval state immediately
        await _stateService.saveApprovalState(
          isWaitingForApproval: true,
          pendingApprovalId: approvalId,
          approvalRequestTime: now,
        );
        
        _updateState(_state.copyWith(
          isWaitingForApproval: true,
          loginTime: now,
          pendingApprovalId: approvalId,
          approvalRequestTime: now,
          approvalRetryCount: 0,
        ));
        
        _listenForApproval(approvalId);
        
        _safeShowSnackBar(
          '⏳ Login after grace period. Waiting for admin/HR approval...',
          backgroundColor: Colors.orange,
          icon: Icons.access_time,
          durationSeconds: 5,
        );
      } else {
        _updateState(_state.copyWith(
          isWaitingForApproval: false,
          loginTime: null,
        ));
        await _stateService.clearApprovalState();
      }
    } else {
      await _completeLogin();
      await _stateService.clearApprovalState();
    }
  }
  Future<String?> _requestLoginApproval() async {
    if (_isDisposed) return null;

    try {
      DateTime now = DateTime.now();
      String dateKey = DateFormat('dd-MMM-yy').format(now);

      DocumentReference approvalRef = await FirebaseFirestore.instance
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

      await _notifyAdminAndHR(approvalRef.id);
      return approvalRef.id;
    } catch (e, stackTrace) {
      _logError('Error requesting login approval', e, stackTrace);
      return null;
    }
  }
  
  Future<void> _notifyAdminAndHR(String approvalId) async {
    try {
      QuerySnapshot adminUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'hr', 'superadmin'])
          .get();

      for (var doc in adminUsers.docs) {
        try {
          String? fcmToken = doc.get('fcmToken');
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
    } catch (e, stackTrace) {
      _logError('Error notifying admin/HR', e, stackTrace);
    }
  }

  bool _needsLoginApproval() {
  if (_state.userId.isEmpty || _state.empId.isEmpty) {
    // If user is not logged in, no approval needed for login
    return false;
  }

  DateTime now = DateTime.now();
  String employeeShift = _state.shift;

  // Parse shift string to get start time
  try {
    // Handle different shift formats
    DateTime shiftStartTime = _parseShiftStartTime(employeeShift);
    DateTime graceEndTime = shiftStartTime.add(const Duration(minutes: 15));

    // Check if current time is within grace period
    return now.isAfter(graceEndTime);
  } catch (e) {
    _logError('Error parsing shift time', e, null);
    // Default fallback: if shift can't be parsed, use standard 9:30 AM
    DateTime graceTime = DateTime(now.year, now.month, now.day, 9, 45);
    return now.isAfter(graceTime);
  }
}

DateTime _parseShiftStartTime(String shiftString) {
  DateTime now = DateTime.now();
  
  // Handle various shift formats
  if (shiftString.toLowerCase().contains('9:30am') || 
      shiftString.toLowerCase().contains('9:30 am') ||
      shiftString == '9:30AM to 6:30 PM') {
    return DateTime(now.year, now.month, now.day, 9, 30);
  } else if (shiftString.toLowerCase().contains('9:50am') || 
             shiftString.toLowerCase().contains('9:50 am') ||
             shiftString == '9:50AM to 6:50 PM') {
    return DateTime(now.year, now.month, now.day, 9, 50);
  } 
  // Add more shift patterns as needed
  else if (shiftString.toLowerCase().contains('10:00am') || 
           shiftString.toLowerCase().contains('10:00 am')) {
    return DateTime(now.year, now.month, now.day, 10, 0);
  } else if (shiftString.toLowerCase().contains('10:30am') || 
             shiftString.toLowerCase().contains('10:30 am')) {
    return DateTime(now.year, now.month, now.day, 10, 30);
  }
  
  // Default fallback - try to extract time from string
  try {
    // Try to extract time like "9:30AM" or "09:30 AM"
    final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)', caseSensitive: false);
    final match = timeRegex.firstMatch(shiftString);
    
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      int minute = int.parse(match.group(2)!);
      String period = match.group(3)!.toUpperCase();
      
      // Convert to 24-hour format
      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
  } catch (e) {
    _logError('Error parsing shift from string: $shiftString', e, null);
  }
  
  // If all parsing fails, return default 9:30 AM
  return DateTime(now.year, now.month, now.day, 9, 30);
}
  Widget _buildUserInfo() {
    if (_isLoading) return _buildLoadingUserInfo();
    if (_hasError) return _buildErrorUserInfo();

    return Card(
      elevation: 4, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0), 
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: Colors.blue[100], 
              radius: 25, 
              child: Icon(Icons.person, color: Colors.blue, size: 30)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(_state.userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(
                    _state.isLoggedIn ? "Currently Working" : "Not Logged In", 
                    style: TextStyle(
                      color: _state.isLoggedIn ? Colors.green : Colors.grey, 
                      fontSize: 14
                    )
                  ),
                  Text(
                    'Employee ID: ${_state.empId}', 
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)
                  ),
                  Text(
                    DateFormat('dd MMM yyyy - EEEE').format(DateTime.now()), 
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)
                  ),
                ]
              )
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _state.isLoggedIn ? Colors.green[100] : Colors.grey[200], 
                borderRadius: BorderRadius.circular(20)
              ),
              child: Text(
                _state.isLoggedIn ? "ACTIVE" : "OFFLINE", 
                style: TextStyle(
                  color: _state.isLoggedIn ? Colors.green[700] : Colors.grey[600], 
                  fontWeight: FontWeight.bold, 
                  fontSize: 12
                )
              ),
            ),
          ]),
          if (_state.isLoggedIn) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, 
              children: [
                _buildInfoItem(Icons.access_time, 'Work Time', _formatDuration(_state.workDuration)),
                _buildInfoItem(Icons.coffee, 'Break Time', _formatDuration(_state.totalBreakDurationToday)),
                _buildInfoItem(Icons.route, 'Distance', '${_state.totalDistanceTraveled.toStringAsFixed(1)} km'),
              ]
            ),
            // Shift info
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
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatDuration(_state.remainingShiftTime),
                    style: TextStyle(
                      color: _state.remainingShiftTime.inHours < 1 ? Colors.orange : Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ])
      ),
    );
  }
  Widget _buildErrorUserInfo() {
    return Card(
      elevation: 4, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0), 
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: Colors.red[100], 
              radius: 25, 
              child: Icon(Icons.error_outline, color: Colors.red, size: 30)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  const Text(
                    "Error Loading User", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)
                  ),
                  Text(
                    _errorMessage ?? 'Unknown error occurred', 
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)
                  ),
                ]
              )
            ),
          ]),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _initializeUserData, 
            icon: const Icon(Icons.refresh), 
            label: const Text('Retry Loading'), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white
            )
          ),
        ])
      ),
    );
  }
  Widget _buildLoadingUserInfo() {
    return Card(
      elevation: 4, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0), 
        child: Row(children: [
          CircleAvatar(
            backgroundColor: Colors.grey[300], 
            radius: 25, 
            child: CircularProgressIndicator(
              strokeWidth: 3, 
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue)
            )
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
                    borderRadius: BorderRadius.circular(4)
                  )
                ),
                const SizedBox(height: 8), 
                Container(
                  width: 100, 
                  height: 16, 
                  decoration: BoxDecoration(
                    color: Colors.grey[200], 
                    borderRadius: BorderRadius.circular(4)
                  )
                ),
                const SizedBox(height: 4), 
                Container(
                  width: 120, 
                  height: 14, 
                  decoration: BoxDecoration(
                    color: Colors.grey[200], 
                    borderRadius: BorderRadius.circular(4)
                  )
                ),
              ]
            )
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
            decoration: BoxDecoration(
              color: Colors.grey[200], 
              borderRadius: BorderRadius.circular(20)
            ),
            child: const Text(
              "LOADING", 
              style: TextStyle(
                color: Colors.grey, 
                fontWeight: FontWeight.bold, 
                fontSize: 12
              )
            ),
          ),
        ])
      ),
    );
  }
  // MANUAL REFRESH BUTTON
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
            if (_state.isLoggedIn) {
              _updateWorkDuration();
            }
          },
          label: const Text('REFRESH DATA', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
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
              if (_state.isLoggedIn) {
                _updateWorkDuration();
              }
            },
            tooltip: 'Sync Now',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (_hasError) _buildErrorWidget(),
            if (!_hasError) ...[
              _buildInstructionsCard(),
              const SizedBox(height: 16),
              _buildLocationBanner(),
              const SizedBox(height: 24),
              _buildAttendanceCircle(),
              const SizedBox(height: 24),
              _buildRefreshButton(), // Add refresh button
              const SizedBox(height: 8),
              _buildLogoutButton(),
              const SizedBox(height: 24),
              _buildUserInfo(),
              const SizedBox(height: 24),
            ],
          ]),
        ),
      ),
    );
  }
  Widget _buildLogoutButton() {
    if (!_state.isLoggedIn || _state.isOnBreak || _state.remainingShiftTime.inSeconds <= 0 || _isLoading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity, 
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red, 
            foregroundColor: Colors.white, 
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.logout), 
          onPressed: _showLogoutConfirmationDialog,
          label: const Text(
            'EARLY LOGOUT', 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
          ),
        )
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
        gradient: LinearGradient(colors: [Colors.orange[100]!, Colors.orange[50]!]), 
        borderRadius: BorderRadius.circular(12.0), 
        border: Border.all(color: Colors.orange),
      ),
      child: Row(children: [
        Icon(Icons.location_off, color: Colors.orange), 
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Enable location for accurate attendance tracking', 
            style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w500)
          )
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange, 
            foregroundColor: Colors.white, 
            minimumSize: const Size(60, 30)
          ),
          onPressed: _checkLocationPermission, 
          child: const Text('Enable', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
  Widget _buildErrorWidget() {
    return Card(
      elevation: 4, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0), 
        child: Column(children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red), 
          const SizedBox(height: 16),
          const Text(
            'Something went wrong', 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)
          ),
          const SizedBox(height: 8), 
          Text(
            _errorMessage ?? 'Unknown error occurred', 
            style:  TextStyle(color: Colors.grey[600]), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initializeApp, 
            icon: const Icon(Icons.refresh), 
            label: const Text('Retry'), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white
            )
          ),
        ])
      ),
    );
  }

  // Keep all your existing helper methods (formatDuration, calculateRemainingTime, etc.)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Duration _calculateRemainingTime() {
    if (_state.loginTime == null) return Duration.zero;

    DateTime shiftEnd = _getShiftEndTime();
    DateTime now = DateTime.now();

    if (now.isAfter(shiftEnd)) {
      return Duration.zero;
    }

    return shiftEnd.difference(now);
  }

  DateTime _getShiftEndTime() {
    DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 18, 30);
  }
  void _safeShowSnackBar(String message, {
    Color? backgroundColor, 
    IconData? icon, 
    int durationSeconds = 3
  }) {
    if (!(mounted && !_isDisposed)) return;

    final now = DateTime.now();
    // Suppress duplicate messages within a short debounce window
    if (_lastSnackMessage == message && _lastSnackTime != null && now.difference(_lastSnackTime!) < _snackDebounce) {
      if (kDebugMode) print('⚠️ Snack suppressed (duplicate): $message');
      return;
    }

    _lastSnackMessage = message;
    _lastSnackTime = now;

    final snackBar = SnackBar(
      content: Row(children: [
        if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 8)],
        Expanded(child: Text(message)),
      ]),
      backgroundColor: backgroundColor ?? Colors.blue,
      duration: Duration(seconds: durationSeconds),
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'How to Use Attendance System', 
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.blue[800]
                      )
                    )
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey), 
                    onPressed: () => _updateState(_state.copyWith(showInstructions: false))
                  ),
                ]),
                const Divider(), 
                const SizedBox(height: 8),
                _buildInstructionItem(Icons.login, 'LOGIN (9:30 AM)', 'Tap to start. 15 min grace period. After 9:45 AM requires approval', Colors.green),
                const SizedBox(height: 12),
                _buildInstructionItem(Icons.coffee, 'BREAK', 'Long press during work to take a break', Colors.orange),
                const SizedBox(height: 12),
                _buildInstructionItem(Icons.work, 'RESUME', 'Long press again to end your break', Colors.blue),
                const SizedBox(height: 12),
                _buildInstructionItem(Icons.logout, 'LOGOUT (6:30 PM)', 'Tap when shift ends or provide early logout reason', Colors.red),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12), 
                  decoration: BoxDecoration(
                    color: Colors.amber[100], 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Row(children: [
                    Icon(Icons.gps_fixed, color: Colors.amber[700]), 
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📍 Location tracked every 10 sec. Distance calculated automatically', 
                        style: TextStyle(
                          color: Colors.amber[700], 
                          fontWeight: FontWeight.w500, 
                          fontSize: 12
                        )
                      )
                    ),
                  ]),
                ),
              ]
            )
          ),
        ),
      ),
    );
  }
  Widget _buildInstructionItem(IconData icon, String title, String description, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8), 
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(8)
        ), 
        child: Icon(icon, color: color, size: 20)
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
                fontSize: 12
              )
            ),
            Text(
              description, 
              style: TextStyle(
                color: Colors.grey[700], 
                fontSize: 11
              )
            ),
          ]
        )
      ),
    ]);
  }
  Widget _buildInfoItem(IconData icon, String title, String value) {
    return Column(children: [
      Icon(icon, color: Colors.blue, size: 20), 
      const SizedBox(height: 4),
      Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])), 
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[800])),
    ]);
  }
}

// Keep your ApprovalCheckResult class
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