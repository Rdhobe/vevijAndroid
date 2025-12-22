import 'package:vevij/components/imports.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controller for auth state changes
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();
  Stream<User?> get authStateChanges => _authStateController.stream;
  bool _initialized = false;
  StreamSubscription<User?>? _authSub;
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // Initialize auth state monitoring
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _authSub = _auth.authStateChanges().listen((User? user) {
      _authStateController.add(user);
      if (user != null) {
        unawaited(_saveUserSession(user));
      } else {
        unawaited(_clearUserSession());
      }
    });
  }

  String getCurrentUserId() {
    return _auth.currentUser?.uid ?? '';
  }

  // Save user session data
  Future<void> _saveUserSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.uid);
      await prefs.setString('user_email', user.email ?? '');
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('last_login', DateTime.now().toIso8601String());

      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        throw Exception('User profile missing in Firestore');
      }
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        await prefs.setString('user_name', userData['empName'] ?? '');
        await prefs.setString('user_role', userData['designation'] ?? '');
        await prefs.setString('emp_id', userData['empId'] ?? '');
      }
    } catch (e) {
      debugPrint('Error saving user session: $e');
    }
  }

  // Clear user session data
  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_role');
      await prefs.remove('emp_id');
      await prefs.setBool('is_logged_in', false);
    } catch (e) {
      debugPrint('Error clearing user session: $e');
    }
  }

  Future<bool> isSessionValid() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        await _clearUserSession();
        return false;
      }

      // Force token refresh check
      await user.getIdToken(true);

      return true;
    } catch (e) {
      await _clearUserSession();
      return false;
    }
  }

  // Get cached user data
  Future<Map<String, String>> getCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return {
        'userId': prefs.getString('user_id') ?? '',
        'userEmail': prefs.getString('user_email') ?? '',
        'userName': prefs.getString('user_name') ?? '',
        'userRole': prefs.getString('user_role') ?? '',
        'empId': prefs.getString('emp_id') ?? '',
      };
    } catch (e) {
      debugPrint('Error getting cached user data: $e');
      return {
        'userId': prefs.getString('user_id') ?? '',
        'userEmail': prefs.getString('user_email') ?? '',
        'userName': prefs.getString('user_name') ?? 'Unknown',
        'userRole': prefs.getString('user_role') ?? 'Employee',
        'empId': prefs.getString('emp_id') ?? '',
      };
    }
  }

  // Sign out and clear session
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _clearUserSession();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _authSub?.cancel();
    _authStateController.close();
  }
  bool get isReady => _initialized;
  User get requireUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('AUTH_REQUIRED');
    }
    return user;
  }

  Future<void> ensureAuthenticated() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Force token refresh to ensure Firestore permission validity
    await user.getIdToken(true);
  }
}
