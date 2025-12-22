import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:vevij/services/error_service.dart';
class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final error = ErrorService();
  // Use the app-wide date key format for document IDs and queries.
  String _todayKey() => DateFormat('dd-MMM-yy').format(DateTime.now());
  String _docId(String uid) => '${uid}_${_todayKey()}';

  String _todayDayName() => DateFormat('EEE').format(DateTime.now());

  /// ===============================
  /// FETCH TODAY ATTENDANCE
  /// ===============================
  String _todayKeyForApp() {
  return DateFormat('dd-MMM-yy').format(DateTime.now());
  }
  Future<DocumentSnapshot?> fetchToday() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // The app uses a date string like `dd-MMM-yy` and usually queries by
      // `userId` + `date`. Querying keeps behavior aligned with rest of app.
      final dateKey = _todayKey();
      final q = await _db
          .collection('attendance')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();

      if (q.docs.isEmpty) return null;
      return q.docs.first;
    } catch (e, st) {
      await error.reportError(
        message: 'fetchToday failed: $e',
        stackTrace: st.toString(),
        errorType: e.runtimeType.toString(),
      );
      return null;
    }
  }

  /// ===============================
  /// LOGIN (WRITE ONCE)
  /// ===============================
  Future<void> login({
    required String userName,
    required String empId,
    required String location,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('NOT_AUTHENTICATED');

    // Create attendance record compatible with the rest of the app UI.
    final ref = _db.collection('attendance').doc(_docId(user.uid));

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);

        if (snap.exists) {
          throw Exception('ALREADY_LOGGED_IN');
        }

        final now = DateTime.now();
        final inTimeStr = DateFormat('h:mm a').format(now);
        tx.set(ref, {
          'userId': user.uid,
          'userName': userName,
          'empId': empId,
          // use app-wide date format so admin queries match
          'date': _todayKey(),
          'day': _todayDayName(),
          'inTime': inTimeStr,
          'outTime': null,
          'loginCoordinates': location,
          'logoutCoordinates': null,
          'totHrs': 0.0,
          'lateHrs': 0.0,
          'lateMark': 0.0,
          'otHrs': 0.0,
          'type1': 'DP',
          'type2': '---',
          'portion': 1.0,
          'isOnBreak': false,
          'totalBreakSeconds': 0,
          'breaks': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      await error.reportError(
        message: 'login failed: $e',
        stackTrace: st.toString(),
        errorType: e.runtimeType.toString(),
        metadata: {'userName': userName, 'empId': empId},
      );
      rethrow;
    }
  }

  /// ===============================
  /// START BREAK (APPEND ONLY)
  /// ===============================
  Future<void> startBreak({required String location}) async {
    final user = _auth.currentUser!;
    final ref = _db.collection('attendance').doc(_docId(user.uid));

    try {
      await ref.update({
        'breaks': FieldValue.arrayUnion([
          {
            'start': FieldValue.serverTimestamp(),
            'end': null,
            'startLocation': location,
            'endLocation': null,
          }
        ]),
        'isOnBreak': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      await error.reportError(
        message: 'startBreak failed: $e',
        stackTrace: st.toString(),
        errorType: e.runtimeType.toString(),
        metadata: {'location': location},
      );
      rethrow;
    }
  }

  /// ===============================
  /// END BREAK (SAFE TRANSACTION)
  /// ===============================
  Future<void> endBreak({required String location}) async {
    final user = _auth.currentUser!;
    final ref = _db.collection('attendance').doc(_docId(user.uid));

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        final List breaks = List.from(data['breaks'] ?? []);

        if (breaks.isEmpty) return;

        final lastBreak = breaks.last;
        if (lastBreak['end'] != null) return;

        breaks[breaks.length - 1] = {
          ...lastBreak,
          'end': FieldValue.serverTimestamp(),
          'endLocation': location,
        };

        tx.update(ref, {
          'breaks': breaks,
          'isOnBreak': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      await error.reportError(
        message: 'endBreak failed: $e',
        stackTrace: st.toString(),
        errorType: e.runtimeType.toString(),
        metadata: {'location': location},
      );
      rethrow;
    }
  }

  /// ===============================
  /// LOGOUT (NO DATA LOSS)
  /// ===============================
  Future<void> logout({required String location}) async {
    final user = _auth.currentUser!;
    final ref = _db.collection('attendance').doc(_docId(user.uid));

    try {
      await ref.update({
        // write fields used by the rest of the app
        'outTime': DateFormat('h:mm a').format(DateTime.now()),
        'logoutCoordinates': location,
        'isOnBreak': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      await error.reportError(
        message: 'logout failed: $e',
        stackTrace: st.toString(),
        errorType: e.runtimeType.toString(),
        metadata: {'location': location},
      );
      rethrow;
    }
  }
}
