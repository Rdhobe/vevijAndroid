import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vevij/models/employee/employee.dart';
import 'package:vevij/models/employee/attendance_model.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vevij/services/attendance_service.dart';
import 'package:vevij/services/error_service.dart';
import 'package:provider/provider.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _loginLock = false;
  // Controllers and Timers
  Timer? _timer;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Services
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final error = ErrorService();

  // Location
  Position? _currentPosition;
  bool _locationEnabled = false;
  bool _isGettingLocation = false;

  // Stream Subscriptions
  StreamSubscription? _userDataListener;
  StreamSubscription? _attendanceListener;
  Timer? _instructionTimer;
  // Flags
  bool _isDisposed = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _hasError = false;
  String? _errorMessage;

  // Local state (no persistence)
  Employee? _employee;
  Attendance? _todayAttendance;
  DateTime? _loginTime;
  DateTime? _breakStartTime;
  Duration _workDuration = Duration.zero;
  Duration _totalBreakDurationToday = Duration.zero;
  
  // SnackBar dedupe
  String? _lastSnackMessage;
  DateTime? _lastSnackTime;
  final Duration _snackDebounce = const Duration(seconds: 4);

  // Performance optimization
  DateTime _lastNotificationUpdate = DateTime.now();
  static const Duration _notificationUpdateInterval = Duration(seconds: 10);

  // Office geofence settings
  static const double officeLat = 18.50954783069657;
  static const double officeLng = 73.87062867788329;
  static const double allowedRadiusMeters = 150;
  // maps 
  GoogleMapController? _mapController;
  Widget? _cachedMapWidget;
  LatLng? _lastMapCenter;
  // UI state
  bool _showInstructions = true;
  bool _isWaitingForApproval = false;
  String? _pendingApprovalId;
  DateTime? _approvalRequestTime;
  int _approvalRetryCount = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _fetchLocation();
  }

  // Getters for computed properties
  bool get _isLoggedIn => _loginTime != null && _todayAttendance?.outTime == null;
  bool get _isOnBreak => _breakStartTime != null;
  String get _userName => _employee?.empName ?? 'Loading...';
  String get _empId => _employee?.empCode ?? '';
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _shift => _employee?.shift ?? '9:30AM to 6:30 PM';
  String get _workLocation => _employee?.workLocation ?? 'office';
  String get _currentCoordinates => _currentPosition != null 
      ? '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}'
      : 'Unknown';
  String? get _todayAttendanceId => _todayAttendance?.id;

  Duration get _remainingShiftTime {
    if (_loginTime == null) return Duration.zero;
    
    DateTime shiftEnd = _getShiftEndTime();
    DateTime now = DateTime.now();
    
    if (now.isAfter(shiftEnd)) {
      return Duration.zero;
    }
    
    return shiftEnd.difference(now);
  }

  DateTime _getShiftEndTime() {
    DateTime now = DateTime.now();
    if (now.weekday == DateTime.saturday) {
      return DateTime(now.year, now.month, now.day, 16, 0);
    }
    return DateTime(now.year, now.month, now.day, 18, 30);
  }

  Future<void> _fetchLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = pos;
        _showInstructions = false;
      });
    } catch (e) {
      error.reportError(
        message: 'Failed to fetch location: $e',
        stackTrace: e.toString(),
        errorType: e.runtimeType.toString(),
      );
    }
  }

  Future<void> _initializeApp() async {
    if (_isDisposed) return;

    try {
      // Initialize animations and services
      _initializeAnimations();
      await _initializeNotifications();
      await _checkLocationPermission();
      await _initializeUserData();

      // One-time sync from Firestore
      await _syncWithFirestore();

      // Auto-start timer for UI if user is logged in
      if (_isLoggedIn && _loginTime != null) {
        _startTimer();
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
      error.reportError(
        message: 'App initialization failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
    } 
  }

  Future<void> _initializeUserData() async {
    if (_isDisposed) return;

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Fetch fresh data from Firestore
      final DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.exists) {
        final Map<String, dynamic> data =
            snapshot.data() as Map<String, dynamic>;
        final Employee employee = Employee.fromMap(data);
        
        setState(() {
          _employee = employee;
        });

        _setupUserDataListener(currentUser.uid);
        _setupAttendanceListener(currentUser.uid);
      } else {
        throw Exception('User document does not exist');
      }
    } catch (e, stackTrace) {
      _logError('Error initializing user data', e, stackTrace);
      _handleError('Failed to load employee data. Please check connection.');
      error.reportError(
        message: 'User data initialization failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
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
            if (snapshot.exists && mounted && !_isDisposed) {
              try {
                final Map<String, dynamic> data =
                    snapshot.data() as Map<String, dynamic>;
                final Employee employee = Employee.fromMap(data);
                
                setState(() {
                  _employee = employee;
                });
              } catch (e, stackTrace) {
                _logError('Error in user data listener', e, stackTrace);
                error.reportError(
                  message: 'User data listener error: $e',
                  stackTrace: stackTrace.toString(),
                  errorType: e.runtimeType.toString(),
                );
              }
            }
          },
          onError: (error) {
            _logError('Error in user data listener', error, null);
            error.reportError(
              message: 'User data listener error: $error',
              stackTrace: error.toString(),
              errorType: error.runtimeType.toString(),
            );
          },
        );
      _setupAttendanceListener(userId);
  }

  void _setupAttendanceListener(String userId) {
    try {
      _attendanceListener?.cancel();

      final String docId = '${userId}_${DateFormat('dd-MMM-yy').format(DateTime.now())}';
      final docRef = FirebaseFirestore.instance.collection('attendance').doc(docId);

      _attendanceListener = docRef.snapshots().listen((doc) {
        if (!mounted || _isDisposed) return;

        try {
          if (doc.exists) {
            final attendance = Attendance.fromFirestore(doc);
            
            setState(() {
              _todayAttendance = attendance;
              
              // Update login time from attendance
              if (attendance.inTime != null) {
                _loginTime = _parseTimeToToday(attendance.inTime!);
              }
              
              // Update break state
              if (attendance.isOnBreak && attendance.breakStartTime != null) {
                _breakStartTime = _parseTimeToToday(attendance.breakStartTime!);
              } else {
                _breakStartTime = null;
              }
              
              // Update break duration
              _totalBreakDurationToday = Duration(seconds: attendance.totalBreakSeconds);
              
              // Update work duration if logged in
              if (_isLoggedIn && _loginTime != null) {
                _updateWorkDuration();
              }
            });
          } else {
            setState(() {
              _todayAttendance = null;
              _loginTime = null;
              _breakStartTime = null;
              _workDuration = Duration.zero;
              _totalBreakDurationToday = Duration.zero;
            });
          }

          if (_isLoggedIn && _timer == null) {
            _startTimer();
          }
        } catch (e, st) {
          _logError('Attendance listener error', e, st);
          error.reportError(
            message: 'Attendance listener error: $e',
            stackTrace: st.toString(),
            errorType: e.runtimeType.toString(),
          );
        }
      }, onError: (err) {
        _logError('Attendance snapshot error', err, null);
        error.reportError(
          message: 'Attendance snapshot error: $err',
          stackTrace: err.toString(),
          errorType: err.runtimeType.toString(),
        );
      });
    } catch (e, st) {
      _logError('Failed to start attendance listener', e, st);
      error.reportError(
        message: 'Start attendance listener failed: $e',
        stackTrace: st.toString(),
        errorType: e.runtimeType.toString(),
      );
    }
  }

  DateTime _parseTimeToToday(String timeStr) {
    try {
      DateTime now = DateTime.now();
      DateFormat format = DateFormat('h:mm a');
      DateTime parsed = format.parse(timeStr);
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      error.reportError(
        message: 'Time parse failed: $e',
        stackTrace: e.toString(),
        errorType: e.runtimeType.toString(),
      );
      return DateTime.now();
    }
  }

  Future<void> _checkLocationPermission() async {
    if (_isDisposed) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && !_isDisposed) {
            _safeShowSnackBar(
              'Location permission denied. Please allow location access.',
              backgroundColor: Colors.red,
              icon: Icons.location_off,
              durationSeconds: 8,
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && !_isDisposed) {
          _safeShowSnackBar(
            'Location permission denied permanently. Please enable it from settings.',
            backgroundColor: Colors.red,
            icon: Icons.location_off,
            durationSeconds: 8,
          );
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
      error.reportError(
        message: 'Location permission check failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
    }
  }

  void _updateWorkDuration() {
    if (!_isLoggedIn || _loginTime == null) return;

    final now = DateTime.now();
    Duration newWorkDuration;

    if (!_isOnBreak) {
      newWorkDuration = now.difference(_loginTime!) - _totalBreakDurationToday;
    } else if (_breakStartTime != null) {
      Duration currentBreak = now.difference(_breakStartTime!);
      newWorkDuration = now.difference(_loginTime!) - _totalBreakDurationToday - currentBreak;
    } else {
      newWorkDuration = _workDuration;
    }

    if (newWorkDuration.isNegative) {
      newWorkDuration = Duration.zero;
    }

    if (newWorkDuration != _workDuration) {
      setState(() {
        _workDuration = newWorkDuration;
      });
    }
  }

  Future<void> _updateNotification() async {
    if (!_isLoggedIn) {
      await _notificationsPlugin.cancel(1);
      return;
    }

    try {
      String dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());
      String title = 'Attendance Tracker - $_userName';
      String body;

      if (_isOnBreak) {
        Duration currentBreakDuration = _breakStartTime != null
            ? DateTime.now().difference(_breakStartTime!)
            : Duration.zero;
        body =
            '$dateStr\n🟠 On Break: ${_formatDuration(currentBreakDuration)}\n⏰ Work: ${_formatDuration(_workDuration)}';
      } else {
        body =
            '$dateStr\n🔵 Working: ${_formatDuration(_workDuration)}\n☕ Break: ${_formatDuration(_totalBreakDurationToday)}';
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
      error.reportError(
        message: 'Notification update failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
    }
  }

  void _startInstructionsTimer() {
    try{
      _instructionTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && !_isDisposed && !_isLoggedIn) {
        setState(() {
          _showInstructions = false;
        });
      }
    });}catch(e){
      print(e);
    }
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

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(initializationSettings);

      final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
      await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e, stackTrace) {
      _logError('Error initializing notifications', e, stackTrace);
      error.reportError(
        message: 'Notification initialization failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
    }
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

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    if (!_isLoggedIn) {
      _pulseController.repeat(reverse: true);
    }
    _slideController.forward();
  }

  void _startTimer() {
    _timer?.cancel();

    if (_isDisposed || !_isLoggedIn || _loginTime == null) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposed || !_isLoggedIn || _loginTime == null) {
        timer.cancel();
        return;
      }

      try {
        _updateWorkDuration();

        if (DateTime.now().difference(_lastNotificationUpdate) >
            _notificationUpdateInterval) {
          _updateNotification();
          _lastNotificationUpdate = DateTime.now();
        }
      } catch (e, stackTrace) {
        _logError('Timer error', e, stackTrace);
        error.reportError(
          message: 'Timer error: $e',
          stackTrace: stackTrace.toString(),
          errorType: e.runtimeType.toString(),
        );
        timer.cancel();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _getCurrentLocation() async {
    if (_isDisposed || _isGettingLocation) return;

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
        // Location is now available for use
      }
    } on TimeoutException {
      // Handle timeout
    } catch (e, stackTrace) {
      _logError('Error getting location', e, stackTrace);
      error.reportError(
        message: 'Get location failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
    } finally {
      _isGettingLocation = false;
    }
  }

  Future<void> _completeLogin() async {
    if (_isLoggedIn) return;
    if (_loginLock) return;
    _loginLock = true;
    final attendanceService = context.read<AttendanceService>();

    try {
      await attendanceService.login(
        userName: _userName,
        empId: _empId,
        location: _currentCoordinates,
      );

      setState(() {
        _loginTime = DateTime.now();
        _isWaitingForApproval = false;
        _pendingApprovalId = null;
      });

      _startTimer();
      _safeShowSnackBar('Login successful ✅');
    } catch (e, st) {
      _loginLock = false;
      _reportAndShowError('Login failed', e, st);
    } finally {
      _loginLock = false;
    }
  }

  Future<void> _logout({String? reason}) async {
    final attendanceService = context.read<AttendanceService>();

    try {
      await attendanceService.logout(location: _currentCoordinates);
      
      setState(() {
        _loginTime = null;
        _breakStartTime = null;
        _workDuration = Duration.zero;
        _totalBreakDurationToday = Duration.zero;
      });
      
      _stopTimer();
      await _updateNotification();
      
      _safeShowSnackBar('Logout successful 👋');
    } catch (e) {
      error.reportError(
        message: 'Logout failed: $e',
        stackTrace: e.toString(),
        errorType: e.runtimeType.toString(),
      );
      _safeShowSnackBar(
        'Logout failed. Try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _startBreak() async {
    if (_isDisposed) return;

    await _getCurrentLocation();

    final attendanceService = context.read<AttendanceService>();
    await attendanceService.startBreak(location: _currentCoordinates);

    setState(() {
      _breakStartTime = DateTime.now();
    });

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

    final attendanceService = context.read<AttendanceService>();
    await attendanceService.endBreak(location: _currentCoordinates);

    setState(() {
      _breakStartTime = null;
    });

    _safeShowSnackBar(
      'Break ended',
      backgroundColor: Colors.blue,
      icon: Icons.work,
      durationSeconds: 3,
    );

    await _updateNotification();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
    _mapController?.dispose();
    _mapController = null;
    _cachedMapWidget = null;
  }
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _syncWithFirestore();
        if (_isLoggedIn && _loginTime != null) {
          _startTimer();
          _updateWorkDuration();
          _updateNotification();
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();
    _userDataListener?.cancel();
    _attendanceListener?.cancel();
    _instructionTimer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();

    _stopAllServices();

    super.dispose();
  }

  void _stopAllServices() {
    _stopTimer();
    _notificationsPlugin.cancel(1);
  }

  void _logError(String message, dynamic error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('❌ $message: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  void _reportAndShowError(String contextMessage, dynamic e, StackTrace? st) {
    try {
      error.reportError(
        message: '$contextMessage: $e',
        stackTrace: st?.toString() ?? e.toString(),
        errorType: e.runtimeType.toString(),
      );
    } catch (_) {}

    if (mounted && !_isDisposed) {
      _safeShowSnackBar(
        '$contextMessage: ${e.toString()}',
        backgroundColor: Colors.red,
        icon: Icons.error,
        durationSeconds: 5,
      );
    }
  }

  Future<void> _syncWithFirestore() async {
    if (_isDisposed || _isSyncing || _userId.isEmpty) return;

    _isSyncing = true;

    try {
      final String today = DateFormat('dd-MMM-yy').format(DateTime.now());

      final QuerySnapshot attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: _userId)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        final doc = attendanceQuery.docs.first;
        final attendance = Attendance.fromFirestore(doc);
        
        setState(() {
          _todayAttendance = attendance;
          
          if (attendance.inTime != null) {
            _loginTime = _parseTimeToToday(attendance.inTime!);
          }
          
          if (attendance.isOnBreak && attendance.breakStartTime != null) {
            _breakStartTime = _parseTimeToToday(attendance.breakStartTime!);
          } else {
            _breakStartTime = null;
          }
          
          _totalBreakDurationToday = Duration(seconds: attendance.totalBreakSeconds);
        });

        if (_isLoggedIn) {
          _updateWorkDuration();
        }
        
        if (attendance.outTime != null && _isLoggedIn) {
          _safeShowSnackBar(
            'Notice: Attendance shows you were logged out remotely. Please tap Logout to finish your day.',
            backgroundColor: Colors.orange,
            icon: Icons.info_outline,
            durationSeconds: 5,
          );
        }
      }
    } catch (e, stackTrace) {
      _logError('Error syncing with Firestore', e, stackTrace);
      error.reportError(
        message: 'Firestore sync failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
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

  Widget _buildAttendanceCircle() {
    if (_isLoading) return _buildLoadingWidget();
    if (_isWaitingForApproval) return _buildApprovalWaitingWidget();

    String displayText = 'TAP TO\nLOGIN';
    Color circleColor = Colors.green;
    Color textColor = Colors.white;
    String instructionText = '';

    if (_isLoggedIn) {
      if (_isOnBreak) {
        Duration currentBreakDuration = _breakStartTime != null
            ? DateTime.now().difference(_breakStartTime!)
            : Duration.zero;
        displayText = 'BREAK\n${_formatDuration(currentBreakDuration)}';
        circleColor = Colors.orange;
        instructionText = 'Long press to end break';
      } else {
        if (_remainingShiftTime.inSeconds > 0) {
          displayText = 'WORKING\n${_formatDuration(_workDuration)}';
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
            if (!_isLoggedIn) {
              _login();
            } else if (!_isOnBreak &&
                _remainingShiftTime.inSeconds <= 0) {
              _showLogoutConfirmationDialog();
            }
          },
          onLongPress: () {
            if (_isLoggedIn &&
                !_isOnBreak &&
                _remainingShiftTime.inSeconds > 0) {
              _startBreak();
            } else if (_isLoggedIn && _isOnBreak) {
              _endBreak();
            }
          },
          child: !_isLoggedIn
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

  Widget _buildGeoInfo() {
  if (_currentPosition == null) {
    return const SizedBox(
      height: 200,
      child: Center(child: Text("Fetching location...")),
    );
  }

  final userLocation =
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
  final officeLocation = const LatLng(officeLat, officeLng);

  // Build map ONLY once
  _cachedMapWidget ??= SizedBox(
    height: 200,
    child: GoogleMap(
      initialCameraPosition: CameraPosition(
        target: userLocation,
        zoom: 16,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      markers: {
        Marker(
          markerId: const MarkerId("user"),
          position: userLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
        Marker(
          markerId: const MarkerId("office"),
          position: officeLocation,
        ),
      },
      circles: {
        Circle(
          circleId: const CircleId("office_radius"),
          center: officeLocation,
          radius: allowedRadiusMeters,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      },
      myLocationEnabled: _locationEnabled,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
    ),
  );

  // Camera move WITHOUT rebuild
  if (_lastMapCenter == null ||
      _lastMapCenter != userLocation) {
    _lastMapCenter = userLocation;
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(userLocation),
    );
  }
  return _cachedMapWidget!;
}
  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String? logoutReason;

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

  bool _isInsideOffice(double lat, double lng) {
    double distance = Geolocator.distanceBetween(
      lat,
      lng,
      officeLat,
      officeLng,
    );

    return distance <= allowedRadiusMeters;
  }

  Future<void> _login() async {
    if (_isDisposed) return;

    _pulseController.stop();
    await _getCurrentLocation();

    if (_currentPosition == null) {
      _safeShowSnackBar(
        'Unable to detect location. Please:\n1. Enable GPS\n2. Grant location permission\n3. Ensure you have network connectivity',
        backgroundColor: Colors.red,
        icon: Icons.location_off,
        durationSeconds: 6,
      );
      _pulseController.repeat(reverse: true);
      return;
    }

    final workLocationStr = _workLocation;
    if (workLocationStr.isEmpty) {
      _safeShowSnackBar(
        'Work location is not set for your profile. Please contact HR or Admin.',
        backgroundColor: Colors.red,
        icon: Icons.error_outline,
      );
      _pulseController.repeat(reverse: true);
      return;
    }

    final workLoc = workLocationStr.toLowerCase().trim();

    if (workLoc == 'field') {
      bool needsApproval = _needsLoginApproval();
      if (needsApproval) {
        await _requestLoginApproval();
      } else {
        await _completeLogin();
      }
      return;
    }

    if (workLoc == 'office') {
      final pos = _currentPosition!;
      bool inside = _isInsideOffice(pos.latitude, pos.longitude);

      if (!inside) {
        _safeShowSnackBar(
          '❌ You must be at the office to login.\n'
          'Login blocked due to location restriction.',
          backgroundColor: Colors.red,
          icon: Icons.my_location,
          durationSeconds: 5,
        );
        return;
      }
    } else if (workLoc == 'site') {
      // SITE employees can login anywhere
    } else {
      _safeShowSnackBar(
        'Invalid work location "$workLocationStr". Contact Administrator.',
        backgroundColor: Colors.red,
        icon: Icons.warning_amber,
      );
      return;
    }

    final needsApproval = _needsLoginApproval();

    if (needsApproval) {
      final approvalId = await _requestLoginApproval();
      if (approvalId != null) {
        setState(() {
          _isWaitingForApproval = true;
          _pendingApprovalId = approvalId;
          _approvalRequestTime = DateTime.now();
        });
        _safeShowSnackBar(
          '⏳ Waiting for approval...',
          backgroundColor: Colors.orange,
          icon: Icons.access_time,
        );
      }
    } else {
      await _completeLogin();
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
            'userId': _userId,
            'userName': _userName,
            'empId': _empId,
            'requestTime': FieldValue.serverTimestamp(),
            'requestTimeStr': DateFormat('h:mm a').format(now),
            'date': dateKey,
            'lateBy': _calculateLateHours(now),
            'status': 'pending',
            'coordinates': _currentCoordinates,
            'approvedBy': null,
            'approvalTime': null,
            'reason': 'Late login - After grace period',
          });

      await _notifyAdminAndHR(approvalRef.id);
      return approvalRef.id;
    } catch (e, stackTrace) {
      _logError('Error requesting login approval', e, stackTrace);
      error.reportError(
        message: 'Login approval request failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
      return null;
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
              'message': '$_userName requesting login approval',
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
      error.reportError(
        message: 'Notification to admin/HR failed: $e',
        stackTrace: stackTrace.toString(),
        errorType: e.runtimeType.toString(),
      );
    }
  }

  bool _needsLoginApproval() {
    DateTime now = DateTime.now();
    try {
      DateTime shiftStartTime = _parseShiftStartTime(_shift);
      DateTime graceEndTime = shiftStartTime.add(const Duration(minutes: 15));
      return now.isAfter(graceEndTime);
    } catch (e) {
      _logError('Error parsing shift time', e, null);
      DateTime graceTime = DateTime(now.year, now.month, now.day, 9, 45);
      return now.isAfter(graceTime);
    }
  }

  DateTime _parseShiftStartTime(String shiftString) {
    DateTime now = DateTime.now();

    if (shiftString.toLowerCase().contains('9:30am') ||
        shiftString.toLowerCase().contains('9:30 am') ||
        shiftString == '9:30AM to 6:30 PM') {
      return DateTime(now.year, now.month, now.day, 9, 30);
    } else if (shiftString.toLowerCase().contains('9:50am') ||
        shiftString.toLowerCase().contains('9:50 am') ||
        shiftString == '9:50AM to 6:50 PM') {
      return DateTime(now.year, now.month, now.day, 9, 50);
    } else if (shiftString.toLowerCase().contains('10:00am') ||
        shiftString.toLowerCase().contains('10:00 am')) {
      return DateTime(now.year, now.month, now.day, 10, 0);
    } else if (shiftString.toLowerCase().contains('10:30am') ||
        shiftString.toLowerCase().contains('10:30 am')) {
      return DateTime(now.year, now.month, now.day, 10, 30);
    }

    try {
      final timeRegex = RegExp(
        r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)',
        caseSensitive: false,
      );
      final match = timeRegex.firstMatch(shiftString);

      if (match != null) {
        int hour = int.parse(match.group(1)!);
        int minute = int.parse(match.group(2)!);
        String period = match.group(3)!.toUpperCase();

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
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  radius: 25,
                  child: Icon(Icons.person, color: Colors.blue, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isLoggedIn
                            ? "Currently Working"
                            : "Not Logged In",
                        style: TextStyle(
                          color: _isLoggedIn ? Colors.green : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Employee ID: $_empId',
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
                    color: _isLoggedIn
                        ? Colors.green[100]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isLoggedIn ? "ACTIVE" : "OFFLINE",
                    style: TextStyle(
                      color: _isLoggedIn
                          ? Colors.green[700]
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoggedIn) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                    Icons.access_time,
                    'Work Time',
                    _formatDuration(_workDuration),
                  ),
                  _buildInfoItem(
                    Icons.coffee,
                    'Break Time',
                    _formatDuration(_totalBreakDurationToday),
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
                      _formatDuration(_remainingShiftTime),
                      style: TextStyle(
                        color: _remainingShiftTime.inHours < 1
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

  Widget _buildLoadingWidget() {
    return Column(
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
    final timeSinceRequest = _approvalRequestTime != null
        ? DateTime.now().difference(_approvalRequestTime!)
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
              const CircularProgressIndicator(
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
                    '$_approvalRetryCount/3',
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
          'Requested: ${DateFormat('h:mm a').format(_approvalRequestTime ?? DateTime.now())}',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Elapsed: ${timeSinceRequest.inHours}h ${timeSinceRequest.inMinutes.remainder(60)}m',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                  child: Icon(Icons.error_outline, color: Colors.red, size: 30),
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
          if (_isLoggedIn && !_isLoading)
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
              if (_isLoggedIn) {
                _updateWorkDuration();
              }
            },
            tooltip: 'Sync Now',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildGeoInfo(),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  if (_hasError) _buildErrorWidget(),
                  if (!_hasError) ...[
                    _buildInstructionsCard(),
                    const SizedBox(height: 16),
                    _buildLocationBanner(),
                    const SizedBox(height: 4),
                    _buildAttendanceCircle(),
                    const SizedBox(height: 4),
                    _buildRefreshButton(),
                    const SizedBox(height: 4),
                    _buildLogoutButton(),
                    const SizedBox(height: 4),
                    _buildUserInfo(),
                  ],
                ],
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
            if (_isLoggedIn) {
              _updateWorkDuration();
            }
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
    if (!_isLoggedIn ||
        _isOnBreak ||
        _remainingShiftTime.inSeconds <= 0 ||
        _isLoading) {
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _safeShowSnackBar(
    String message, {
    Color? backgroundColor,
    IconData? icon,
    int durationSeconds = 3,
  }) {
    if (!(mounted && !_isDisposed)) return;

    final now = DateTime.now();
    if (_lastSnackMessage == message &&
        _lastSnackTime != null &&
        now.difference(_lastSnackTime!) < _snackDebounce) {
      return;
    }

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

  Widget _buildInstructionsCard() {
    if (!_showInstructions || _isLoading) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _showInstructions ? 1.0 : 0.0,
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
                      onPressed: () => setState(() {
                        _showInstructions = false;
                      }),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _buildInstructionItem(
                  Icons.login,
                  'LOGIN/LOGOUT: $_shift',
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
