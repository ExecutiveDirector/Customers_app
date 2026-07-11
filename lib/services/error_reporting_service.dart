// lib/services/error_reporting_service.dart
//
// Central place to report client-side errors to the backend's
// POST /api/v1/logs/client-error endpoint (controllers/clientLogController.js),
// so they show up as system_events alongside backend events in the admin
// dashboard instead of only living in a device's debug console.
//
// This is deliberately a top-level static service (not tied to any widget
// or other service instance) so it can be wired into main.dart's global
// error handlers (runZonedGuarded / FlutterError.onError /
// PlatformDispatcher.instance.onError), which run before most of the app's
// object graph exists.
//
// OrderService.logError() previously had its own private copy of this same
// POST call — it now delegates here so there's a single implementation.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aquagas/services/auth_service.dart';

class ErrorReportingService {
  ErrorReportingService._();

  static const String _baseUrl = 'https://aquagas-backend.onrender.com/api/v1';
  static final AuthService _authService = AuthService();

  /// Logs an error locally and (best-effort, fire-and-forget) reports it to
  /// the backend. This intentionally never throws — a failure to log must
  /// never break the calling code path, and must never itself trigger
  /// another error report (which could recurse).
  static void logError(
    String context,
    Object error, {
    StackTrace? stackTrace,
    String? orderId,
    String severity = 'error',
    bool fatal = false,
  }) {
    debugPrint('[$context]${fatal ? ' FATAL' : ''} Error: $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }

    unawaited(_report(
      context: context,
      error: error,
      severity: fatal ? 'critical' : severity,
      orderId: orderId,
    ));
  }

  static Future<void> _report({
    required String context,
    required Object error,
    required String severity,
    String? orderId,
  }) async {
    try {
      final String? token = await _authService.getToken();

      await http
          .post(
            Uri.parse('$_baseUrl/logs/client-error'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, dynamic>{
              'context': context,
              'message': error.toString(),
              'severity': severity,
              'platform': 'flutter',
              if (orderId != null) 'orderId': orderId,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Swallow silently — logging the failure of logging would recurse.
    }
  }
}