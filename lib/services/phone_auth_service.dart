import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Result model for OTP verification.
class OtpVerifyResult {
  final bool verified;
  final String? token;
  final bool needsRegistration;

  const OtpVerifyResult({
    required this.verified,
    this.token,
    required this.needsRegistration,
  });

  @override
  String toString() =>
      'OtpVerifyResult(verified=$verified, token=${token != null ? "[SET]" : "null"}, needsRegistration=$needsRegistration)';
}

class PhoneAuthService {
  static const String _baseUrl =
      'https://aquagas-backend.onrender.com/api/v1/auth';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _phoneKey = 'temp_phone';

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final json = await _storage.read(key: _userKey);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _phoneKey);
  }

  // ── Send OTP ────────────────────────────────────────────────────────

  Future<void> sendOTP(String phone) async {
    _assertPhone(phone);

    try {
      print('🔵 [sendOTP] Sending to: $phone');

      final res = await http
          .post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: _jsonHeaders,
        body: jsonEncode({'phone': phone}),
      )
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw AuthException('Connection timeout. Please try again.');
      });

      print('📡 [sendOTP] status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 200) {
        await _storage.write(key: _phoneKey, value: phone);
        print('✅ [sendOTP] OTP sent, phone stored in temp_phone');
      } else {
        throw AuthException(_parseError(res));
      }
    } on SocketException {
      throw AuthException('No internet connection.');
    } on HttpException {
      throw AuthException('Could not connect to server.');
    } on FormatException {
      throw AuthException('Invalid response from server.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  // ── Verify OTP ──────────────────────────────────────────────────────

  /// Posts to /verify-otp and inspects every field the backend can return.
  ///
  /// The web register.tsx checks:
  ///   if (data.token && !data.needsRegistration) → existing user, go Home
  ///   else                                        → new user, go CompleteProfile
  ///
  /// We mirror that exactly, plus handle the `accountExists` flag as a
  /// fallback in case `needsRegistration` is absent.
  Future<OtpVerifyResult> verifyOTP(String phone, String otp) async {
    _assertPhone(phone);
    _assertOtp(otp);

    try {
      print('🔵 [verifyOTP] phone=$phone otp=$otp');

      final res = await http
          .post(
        Uri.parse('$_baseUrl/verify-otp'),
        headers: _jsonHeaders,
        body: jsonEncode({'phone': phone, 'otp': otp}),
      )
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw AuthException('Connection timeout. Please try again.');
      });

      // ── Log the FULL raw response so we can see exactly what backend sends ──
      print('📡 [verifyOTP] status=${res.statusCode}');
      print('📡 [verifyOTP] raw body=${res.body}');

      if (res.statusCode != 200) {
        throw AuthException(_parseError(res));
      }

      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;

      print('📋 [verifyOTP] parsed keys: ${data.keys.toList()}');

      for (final MapEntry<String, dynamic> entry in data.entries) {
        print(
          '   ${entry.key} → ${entry.value} (${entry.value.runtimeType})',
        );
      }

      // ── Pull fields ──────────────────────────────────────────────
      final verified = data['verified'] as bool? ?? false;

      if (!verified) {
        print('❌ [verifyOTP] verified=false → invalid OTP');
        return const OtpVerifyResult(verified: false, needsRegistration: true);
      }

      final token = data['token'] as String?;

      print(
          '🔍 [verifyOTP] verified=$verified token=${token != null ? "[present]" : "null"}');

      // ── Decision ────────────────────────────────────────────────────
      // The backend returns `token` only for existing (already-registered)
      // users. New users get {verified:true} with no token — they still
      // need to complete their profile.
      //
      // We deliberately do NOT rely on `needsRegistration` or `accountExists`
      // because this backend omits both fields entirely.
      if (token != null) {
        await _storage.write(key: _tokenKey, value: token);

        final user = data['user'] as Map<String, dynamic>?;
        if (user != null) {
          await _storage.write(key: _userKey, value: jsonEncode(user));
        }

        print('✅ [verifyOTP] EXISTING USER — token stored → navigate Home');
        return OtpVerifyResult(
          verified: true,
          token: token,
          needsRegistration: false,
        );
      }

      print('✅ [verifyOTP] NEW USER — navigate to CompleteProfileScreen');
      return const OtpVerifyResult(verified: true, needsRegistration: true);
    } on SocketException {
      throw AuthException('No internet connection.');
    } on HttpException {
      throw AuthException('Could not connect to server.');
    } on FormatException {
      throw AuthException('Invalid response from server.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<void> resendOTP(String phone) => sendOTP(phone);

  // ── Error helpers ────────────────────────────────────────────────────

  String getAuthErrorMessage(dynamic e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') && msg.contains('phone'))
        return 'Invalid phone number format.';
      if (msg.contains('rate limit') || msg.contains('too many'))
        return 'Too many requests. Please try again later.';
      if (msg.contains('incorrect') ||
          (msg.contains('invalid') && msg.contains('otp')))
        return 'Incorrect OTP. Please check and try again.';
      if (msg.contains('already exists') || msg.contains('already registered'))
        return 'Phone already registered. Please sign in instead.';
      if (msg.contains('expired'))
        return 'OTP has expired. Please request a new code.';
      if (msg.contains('network') || msg.contains('internet'))
        return 'Network error. Please check your connection.';
      if (msg.contains('timeout'))
        return 'Connection timeout. Please try again.';
      return e.message;
    }
    return 'Authentication failed. Please try again.';
  }

  // ── Private ──────────────────────────────────────────────────────────

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  bool _validPhone(String p) => RegExp(r'^\+\d{10,15}$').hasMatch(p);

  void _assertPhone(String p) {
    if (!_validPhone(p))
      throw AuthException(
          'Invalid phone number format. Use E.164 (e.g. +254712345678)');
  }

  void _assertOtp(String o) {
    if (!RegExp(r'^\d{6}$').hasMatch(o))
      throw AuthException('Invalid OTP format. Must be 6 digits.');
  }

  String _parseError(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['error'] as String? ?? 'Request failed (${res.statusCode})';
    } catch (_) {
      return 'Request failed (${res.statusCode})';
    }
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
