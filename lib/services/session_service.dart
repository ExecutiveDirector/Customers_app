import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// What happened when we tried to renew the customer's session.
enum RefreshOutcome {
  /// New tokens were saved.
  renewed,

  /// The server says the session is over (signed out elsewhere, password
  /// reset, account disabled) or there is nothing to renew with.
  rejected,

  /// Offline, timeout or server trouble. The session is probably still fine,
  /// so callers keep using the current token instead of signing out.
  unavailable,
}

/// Keeps customers signed in.
///
/// The access token is short-lived; the refresh token lasts months and is
/// replaced every time it is used, so a customer who opens the app at least
/// once in that window is never asked to sign in again. Every part of the app
/// gets its token through [validToken], which renews it in the background when
/// it has expired or is about to, so no individual screen needs to handle
/// expiry itself.
class SessionService {
  SessionService._();

  static const String _tokenKey = 'auth_token';
  static const String _refreshKey = 'refresh_token';

  /// Renew this long before the access token actually expires.
  static const Duration _margin = Duration(minutes: 2);

  // Test hooks.
  static FlutterSecureStorage storage = const FlutterSecureStorage();
  static http.Client Function() clientFactory = () => http.Client();
  static String refreshUrl =
      'https://aquagas-backend.onrender.com/api/v1/auth/refresh';
  static DateTime Function() now = DateTime.now;

  static Future<RefreshOutcome>? _inFlight;

  /// Store the refresh token returned by any login/registration response.
  static Future<void> saveRefreshToken(Object? value) async {
    if (value is String && value.isNotEmpty) {
      await storage.write(key: _refreshKey, value: value);
    }
  }

  static Future<String?> getRefreshToken() => storage.read(key: _refreshKey);

  static Future<void> clearRefreshToken() => storage.delete(key: _refreshKey);

  /// The access token to send with a request, renewed first if needed.
  /// Never throws and never signs anyone out: if renewal is not possible
  /// right now the current token is returned and the server decides.
  static Future<String?> validToken() async {
    final token = await storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return token;
    if (!_expiresSoon(token)) return token;
    if (await getRefreshToken() == null) return token;
    final outcome = await refresh();
    if (outcome == RefreshOutcome.renewed) {
      return await storage.read(key: _tokenKey);
    }
    return token;
  }

  static Future<RefreshOutcome> refresh() {
    return _inFlight ??= _renew().whenComplete(() => _inFlight = null);
  }

  static Future<RefreshOutcome> _renew() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return RefreshOutcome.rejected;
    }
    final client = clientFactory();
    try {
      final res = await client
          .post(
            Uri.parse(refreshUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 401 || res.statusCode == 403) {
        return RefreshOutcome.rejected;
      }
      if (res.statusCode != 200) return RefreshOutcome.unavailable;
      final data = jsonDecode(res.body);
      final token = data is Map ? data['token'] : null;
      if (token is! String || token.isEmpty) return RefreshOutcome.unavailable;
      await storage.write(key: _tokenKey, value: token);
      await saveRefreshToken(data['refreshToken']);
      return RefreshOutcome.renewed;
    } catch (e) {
      debugPrint('Session renewal unavailable: $e');
      return RefreshOutcome.unavailable;
    } finally {
      client.close();
    }
  }

  static bool _expiresSoon(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload is Map ? payload['exp'] : null;
      if (exp is! num) return false;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
      return !now().toUtc().add(_margin).isBefore(expiry);
    } catch (_) {
      return false;
    }
  }
}
