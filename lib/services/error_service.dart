import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ErrorService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _errorEndpoint = 'https://error-sentinel-backend.vercel.app/api/errors';
  Future<void> reportError({
    required String message,
    required String stackTrace,
    String errorType = 'Error',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      final payload = {
        'projectId': 'vevijerp',
        'message': message,
        'stackTrace': stackTrace,
        'errorType': errorType,
        'platform': kIsWeb ? 'web' : 'mobile',
        'appVersion': '14',
        'deviceInfo': {},
        'metadata': {...?metadata, if (userId != null) 'userId': userId},
      };

      final resp = await http.post(
        Uri.parse(_errorEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (kDebugMode) debugPrint('Error report sent: ${resp.statusCode}');
    } catch (_) {
      // Swallow reporting errors to avoid cascading failures
    }
  }

}