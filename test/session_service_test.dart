import 'dart:convert';

import 'package:aquagas/services/session_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _jwt(DateTime expiry) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${enc({'alg': 'HS256'})}.'
      '${enc({'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixedNow = DateTime.utc(2026, 10, 22, 12);
  late int requests;

  void respondWith(http.Response Function(http.Request) handler) {
    SessionService.clientFactory = () => MockClient((req) async {
          requests++;
          return handler(req);
        });
  }

  setUp(() {
    requests = 0;
    FlutterSecureStorage.setMockInitialValues({});
    SessionService.storage = const FlutterSecureStorage();
    SessionService.now = () => fixedNow;
  });

  Future<void> signedIn(String token, {String? refresh = 'r1'}) async {
    await SessionService.storage.write(key: 'auth_token', value: token);
    if (refresh != null) {
      await SessionService.storage.write(key: 'refresh_token', value: refresh);
    }
  }

  test('a token with plenty of life left is used as is', () async {
    final t = _jwt(fixedNow.add(const Duration(hours: 5)));
    await signedIn(t);
    respondWith((_) => http.Response('{}', 500));
    expect(await SessionService.validToken(), t);
    expect(requests, 0);
  });

  test('an expired token is renewed and the refresh token is replaced', () async {
    await signedIn(_jwt(fixedNow.subtract(const Duration(hours: 1))));
    respondWith((req) {
      expect(jsonDecode(req.body)['refreshToken'], 'r1');
      return http.Response(jsonEncode({'token': 'fresh', 'refreshToken': 'r2'}), 200);
    });
    expect(await SessionService.validToken(), 'fresh');
    expect(await SessionService.getRefreshToken(), 'r2');
  });

  test('a token expiring within two minutes is renewed early', () async {
    await signedIn(_jwt(fixedNow.add(const Duration(seconds: 60))));
    respondWith((_) => http.Response(jsonEncode({'token': 'fresh'}), 200));
    expect(await SessionService.validToken(), 'fresh');
  });

  test('offline: keeps the old token and the session', () async {
    final old = _jwt(fixedNow.subtract(const Duration(hours: 1)));
    await signedIn(old);
    SessionService.clientFactory =
        () => MockClient((_) async => throw http.ClientException('no network'));
    expect(await SessionService.validToken(), old);
    expect(await SessionService.getRefreshToken(), 'r1');
  });

  test('server error: keeps the old token and the session', () async {
    final old = _jwt(fixedNow.subtract(const Duration(hours: 1)));
    await signedIn(old);
    respondWith((_) => http.Response('oops', 503));
    expect(await SessionService.validToken(), old);
    expect(await SessionService.getRefreshToken(), 'r1');
  });

  test('refresh rejected: returns the old token so the caller sees the 401', () async {
    final old = _jwt(fixedNow.subtract(const Duration(hours: 1)));
    await signedIn(old);
    respondWith((_) => http.Response('{"error":"Session has ended"}', 401));
    expect(await SessionService.validToken(), old);
  });

  test('no refresh token (older login): no network call, token unchanged', () async {
    final old = _jwt(fixedNow.subtract(const Duration(hours: 1)));
    await signedIn(old, refresh: null);
    respondWith((_) => http.Response('{}', 500));
    expect(await SessionService.validToken(), old);
    expect(requests, 0);
  });

  test('signed out (no token) stays signed out', () async {
    respondWith((_) => http.Response('{}', 500));
    expect(await SessionService.validToken(), isNull);
    expect(requests, 0);
  });

  test('simultaneous callers share one renewal', () async {
    await signedIn(_jwt(fixedNow.subtract(const Duration(hours: 1))));
    SessionService.clientFactory = () => MockClient((req) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response(jsonEncode({'token': 'fresh', 'refreshToken': 'r2'}), 200);
        });
    final results = await Future.wait([
      SessionService.validToken(),
      SessionService.validToken(),
      SessionService.validToken(),
    ]);
    expect(results, everyElement('fresh'));
    expect(requests, 1);
  });

  test('a token that is not a JWT is left alone', () async {
    await signedIn('opaque-token');
    respondWith((_) => http.Response('{}', 500));
    expect(await SessionService.validToken(), 'opaque-token');
    expect(requests, 0);
  });
}
