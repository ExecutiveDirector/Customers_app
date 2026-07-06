import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service class for handling user authentication with custom backend
class AuthService {
  static const String _baseUrl =
      'https://aquagas-backend.onrender.com/api/v1/auth';

  static const String _hostUrl = 'https://aquagas-backend.onrender.com';

  /// Turns a relative path like "/uploads/avatars/xyz.jpg" into a full URL.
  /// Already-absolute URLs pass through unchanged. Returns null for empty input.
  static String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$_hostUrl${path.startsWith('/') ? path : '/$path'}';
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys for secure storage
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  /// Normalize email to match backend format
  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  /// Get stored authentication token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

// In lib/services/auth_service.dart
  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id');
    } catch (e) {
      debugPrint('Error getting user ID: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final String? token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current user data from storage
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final String? userJson = await _storage.read(key: _userKey);
    if (userJson == null) return null;
    return jsonDecode(userJson) as Map<String, dynamic>;
  }

  /// Get current user data (getter for UpdatePasswordScreen)
  Future<Map<String, dynamic>?> get currentUser async => await getCurrentUser();

  /// Sign in with email and password
  Future<Map<String, dynamic>> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      // 🔧 CRITICAL  Normalize email to match backend
      final String normalizedEmail = _normalizeEmail(email);

      print('🔵 Attempting login to: $_baseUrl/login');
      print('📧 Original email: $email');
      print('📧 Normalized email: $normalizedEmail');
      print('🔐 Password length: ${password.length}');

      // 🔧 CRITICAL: Send exact payload that backend expects
      final requestBody = {
        'email': normalizedEmail, // Use normalized email
        'password': password, // Send password as-is (no trimming!)
      };

      print('📤 Request payload: ${jsonEncode({
            'email': normalizedEmail,
            'password': '[HIDDEN - length: ${password.length}]',
          })}');

      final http.Response response = await http
          .post(
        Uri.parse('$_baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw AuthException('Connection timeout. Please try again.');
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        // Your backend returns: token, role, account, roleData
        final String? token = data['token'] as String?;
        final Map<String, dynamic>? account =
            data['account'] as Map<String, dynamic>?;
        final Map<String, dynamic>? roleData =
            data['roleData'] as Map<String, dynamic>?;

        if (token == null || account == null) {
          throw AuthException('Invalid response from server');
        }

        // Merge account and roleData for storage
        final Map<String, dynamic> userData = <String, dynamic>{
          ...account,
          if (roleData != null) ...roleData,
        };

        // Store authentication data
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _userKey, value: jsonEncode(userData));

        print('✅ Login successful');
        return <String, dynamic>{
          'success': true,
          'token': token,
          'user': userData,
          'role': data['role'],
          'message': data['message'] ?? 'Login successful',
        };
      } else if (response.statusCode == 401) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
            error['error'] as String? ?? 'Invalid email or password');
      } else if (response.statusCode == 403) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
            error['error'] as String? ?? 'Account is locked or deactivated');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(error['error'] as String? ?? 'Login failed');
      }
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw AuthException('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw AuthException('Could not connect to server. Please try again.');
    } on FormatException catch (e) {
      print('❌ Format Exception: $e');
      throw AuthException('Invalid response from server.');
    } catch (e) {
      print('❌ General Exception: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Sign up as a user
  Future<Map<String, dynamic>> signUpWithPhone({
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    String? password,
  }) async {
    try {
      // Normalize email if provided
      final String? normalizedEmail =
          email != null && email.isNotEmpty ? _normalizeEmail(email) : null;

      print('🔵 Attempting phone registration to: $_baseUrl/register/phone');
      print('📱 Phone: $phone');
      if (normalizedEmail != null) {
        print('📧 Email: $normalizedEmail');
      }
      if (password != null && password.isNotEmpty) {
        print('🔐 Password: provided');
      }

      final Map<String, dynamic> requestBody = <String, dynamic>{
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
      };

      // Add optional fields
      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        requestBody['email'] = normalizedEmail;
      }
      if (password != null && password.isNotEmpty) {
        requestBody['password'] = password; // Don't trim password!
      }

      final Map<String, dynamic> debugPayload = <String, dynamic>{
        ...requestBody,
        if (password != null) 'password': '[HIDDEN]',
      };

      print(
        '📤 Registration payload: ${jsonEncode(debugPayload)}',
      );

      final http.Response response = await http
          .post(
        Uri.parse('$_baseUrl/register/phone'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw AuthException('Connection timeout. Please try again.');
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final String? token = data['token'] as String?;
        final Map<String, dynamic>? user =
            data['user'] as Map<String, dynamic>?;
        final String? role = data['role'] as String?;

        // ✅ Capture backend flags
        final bool passwordSet = data['password_set'] as bool? ?? false;
        final bool profileCompleted =
            data['profile_completed'] as bool? ?? false;

        if (token == null || user == null) {
          throw AuthException('Invalid response from server');
        }

        // Store authentication data
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(
            key: _userKey, value: jsonEncode(data)); // Store complete response

        // ✅ Store important flags separately for easy access
        await _storage.write(
          key: 'password_set',
          value: passwordSet.toString(),
        );
        await _storage.write(
          key: 'profile_completed',
          value: profileCompleted.toString(),
        );
        await _storage.write(
          key: 'user_role',
          value: role ?? 'user',
        );

        print('✅ Registration successful');
        if (!profileCompleted) {
          print('⚠️ Profile incomplete - user should add email/password');
        }

        return <String, dynamic>{
          'success': true,
          'token': token,
          'user': user,
          'role': role,
          'password_set': passwordSet,
          'profile_completed': profileCompleted,
          'message': data['message'] ?? 'Registration successful',
        };
      } else if (response.statusCode == 409) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ??
              'Phone number or email already registered',
        );
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Invalid input data',
        );
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Registration failed',
        );
      }
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw AuthException('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw AuthException('Could not connect to server. Please try again.');
    } on FormatException catch (e) {
      print('❌ Format Exception: $e');
      throw AuthException('Invalid response from server.');
    } on TimeoutException catch (e) {
      print('❌ Timeout Exception: $e');
      throw AuthException('Connection timeout. Please try again.');
    } catch (e) {
      print('❌ General Exception: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Sign up as a vendor
  Future<Map<String, dynamic>> signUpVendor({
    required String businessName,
    required String contactPerson,
    required String email,
    required String phone,
    required String password,
    String? location,
  }) async {
    try {
      final String normalizedEmail = _normalizeEmail(email);

      print('🔵 Attempting vendor registration to: $_baseUrl/register/vendor');
      print('📧 Normalized email: $normalizedEmail');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/register/vendor'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'businessName': businessName.trim(),
              'contactPerson': contactPerson.trim(),
              'email': normalizedEmail,
              'phone': phone.trim(),
              'password': password,
              if (location != null) 'location': location,
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final String? token = data['token'] as String?;
        final Map<String, dynamic>? vendor =
            data['vendor'] as Map<String, dynamic>?;

        if (token == null || vendor == null) {
          throw AuthException('Invalid response from server');
        }

        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _userKey, value: jsonEncode(vendor));

        return <String, dynamic>{
          'success': true,
          'token': token,
          'user': vendor,
          'role': data['role'],
          'message': data['message'] ?? 'Vendor registration successful',
        };
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(error['error'] as String? ?? 'Registration failed');
      }
    } on SocketException {
      throw AuthException('No internet connection. Please check your network.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Sign up as a rider
  Future<Map<String, dynamic>> signUpRider({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? vehicleType,
    int? vendorId,
  }) async {
    try {
      final String normalizedEmail = _normalizeEmail(email);

      print('🔵 Attempting rider registration to: $_baseUrl/register/rider');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/register/rider'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'name': name.trim(),
              'email': normalizedEmail,
              'phone': phone.trim(),
              'password': password,
              if (vehicleType != null) 'vehicleType': vehicleType,
              if (vendorId != null) 'vendorId': vendorId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final String? token = data['token'] as String?;
        final Map<String, dynamic>? rider =
            data['rider'] as Map<String, dynamic>?;

        if (token == null || rider == null) {
          throw AuthException('Invalid response from server');
        }

        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _userKey, value: jsonEncode(rider));

        return <String, dynamic>{
          'success': true,
          'token': token,
          'user': rider,
          'role': data['role'],
          'message': data['message'] ?? 'Rider registration successful',
        };
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(error['error'] as String? ?? 'Registration failed');
      }
    } on SocketException {
      throw AuthException('No internet connection. Please check your network.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Check if user's profile is complete
  Future<bool> isProfileComplete() async {
    final String? completed = await _storage.read(key: 'profile_completed');
    return completed == 'true';
  }

  /// Check if user has set a password
  Future<bool> hasPasswordSet() async {
    final String? passwordSet = await _storage.read(key: 'password_set');
    return passwordSet == 'true';
  }

  /// Get user role
  Future<String?> getUserRole() async {
    return await _storage.read(key: 'user_role');
  }

  /// Get stored user data
  Future<Map<String, dynamic>?> getStoredUserData() async {
    final String? data = await _storage.read(key: _userKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  /// Clear all stored auth data
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: 'profile_completed');
    await _storage.delete(key: 'password_set');
    await _storage.delete(key: 'user_role');
    print('✅ Logged out successfully');
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      final String? token = await getToken();
      if (token != null) {
        // Call logout endpoint to blacklist token
        await http.post(
          Uri.parse('$_baseUrl/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      print('⚠️ Logout API call failed: $e');
      // Continue with local cleanup even if API fails
    } finally {
      // Always clear local storage
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    }
  }

  /// Update user password
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final String? token = await getToken();
      if (token == null) throw AuthException('Not authenticated');

      final http.Response response = await http
          .post(
            Uri.parse('$_baseUrl/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
            error['error'] as String? ?? 'Password update failed');
      }
    } on SocketException {
      throw AuthException('No internet connection. Please check your network.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Request password reset (forgot password)
  /// This sends a reset email with a token
  Future<void> requestPasswordReset(String email) async {
    try {
      final String normalizedEmail = _normalizeEmail(email);

      print('🔵 Requesting password reset for: $normalizedEmail');

      final http.Response response = await http
          .post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': normalizedEmail}),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw AuthException('Connection timeout. Please try again.');
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Success - email sent (backend returns 200)
        print('✅ Password reset email sent');
        return;
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Invalid email address',
        );
      } else if (response.statusCode == 429) {
        throw AuthException(
          'Too many reset attempts. Please try again later.',
        );
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Failed to process password reset',
        );
      }
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw AuthException('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw AuthException('Could not connect to server. Please try again.');
    } on FormatException catch (e) {
      print('❌ Format Exception: $e');
      throw AuthException('Invalid response from server.');
    } catch (e) {
      print('❌ General Exception: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Complete password reset with token from email
  Future<void> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    try {
      print('🔵 Resetting password with token');
      print('🔐 New password length: ${newPassword.length}');

      final http.Response response = await http
          .post(
        Uri.parse('$_baseUrl/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'newPassword': newPassword,
        }),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw AuthException('Connection timeout. Please try again.');
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Password reset successful');
        return;
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        final String errorMsg = error['error'] as String? ?? 'Invalid request';

        // Handle expired/invalid token
        if (errorMsg.toLowerCase().contains('expired') ||
            errorMsg.toLowerCase().contains('invalid')) {
          throw AuthException(
            'Reset link has expired or is invalid. Please request a new one.',
          );
        }

        throw AuthException(errorMsg);
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Failed to reset password',
        );
      }
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw AuthException('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw AuthException('Could not connect to server. Please try again.');
    } on FormatException catch (e) {
      print('❌ Format Exception: $e');
      throw AuthException('Invalid response from server.');
    } catch (e) {
      print('❌ General Exception: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Change password for authenticated user
  /// Handles both setting initial password and updating existing password
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    try {
      final String? token = await getToken();
      if (token == null) {
        throw AuthException('Not authenticated. Please log in.');
      }

      print('🔵 Changing password');
      print('🔐 Has current password: ${currentPassword != null}');

      final Map<String, dynamic> requestBody = <String, dynamic>{
        'newPassword': newPassword,
      };

      // Only include currentPassword if provided
      if (currentPassword != null && currentPassword.isNotEmpty) {
        requestBody['currentPassword'] = currentPassword;
      }

      final http.Response response = await http
          .post(
        Uri.parse('$_baseUrl/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw AuthException('Connection timeout. Please try again.');
        },
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Password changed successfully');
        return;
      } else if (response.statusCode == 401) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Current password is incorrect',
        );
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Invalid password format',
        );
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Failed to change password',
        );
      }
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw AuthException('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw AuthException('Could not connect to server. Please try again.');
    } on FormatException catch (e) {
      print('❌ Format Exception: $e');
      throw AuthException('Invalid response from server.');
    } catch (e) {
      print('❌ General Exception: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Check if user has set their password (for phone-only accounts)
  Future<Map<String, dynamic>> checkPasswordStatus() async {
    try {
      final String? token = await getToken();
      if (token == null) {
        throw AuthException('Not authenticated. Please log in.');
      }

      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/check-password-status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw AuthException('Failed to check password status');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final String? token = await getToken();
      if (token == null) throw AuthException('Not authenticated');

      print('🔵 Fetching profile from: $_baseUrl/profile');

      final http.Response response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw AuthException('Connection timeout. Please try again.');
        },
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        // Backend returns: { account, profile, role, profile_completed, password_set }
        final Map<String, dynamic>? account =
            data['account'] as Map<String, dynamic>?;
        final Map<String, dynamic>? profile =
            data['profile'] as Map<String, dynamic>?;
        final String? role = data['role'] as String?;
        final bool profileCompleted =
            data['profile_completed'] as bool? ?? true;
        final bool passwordSet = data['password_set'] as bool? ?? true;

        if (account == null || profile == null) {
          throw AuthException('Invalid profile data received');
        }

        // ✅ Update local storage with complete data
        await _storage.write(key: _userKey, value: jsonEncode(data));

        // ✅ Store flags separately for easy access
        await _storage.write(
          key: 'profile_completed',
          value: profileCompleted.toString(),
        );
        await _storage.write(
          key: 'password_set',
          value: passwordSet.toString(),
        );
        if (role != null) {
          await _storage.write(key: 'user_role', value: role);
        }

        print('✅ Profile fetched successfully');
        if (!profileCompleted) {
          print('⚠️ Profile incomplete');
        }

        return data;
      } else if (response.statusCode == 404) {
        throw AuthException('Profile not found. Please contact support.');
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _userKey);
        throw AuthException('Session expired. Please login again.');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
            error['error'] as String? ?? 'Failed to fetch profile');
      }
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw AuthException('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw AuthException('Could not connect to server. Please try again.');
    } on FormatException catch (e) {
      print('❌ Format Exception: $e');
      throw AuthException('Invalid response from server.');
    } on TimeoutException catch (e) {
      print('❌ Timeout Exception: $e');
      throw AuthException('Connection timeout. Please try again.');
    } catch (e) {
      print('❌ General Exception: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Update user profile

  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> updates) async {
    try {
      final String? token = await getToken();
      if (token == null) throw AuthException('Not authenticated');

      // ✅ Normalize email if being updated
      if (updates.containsKey('email') && updates['email'] != null) {
        updates['email'] = _normalizeEmail(updates['email'] as String);
      }

      print('🔵 Updating profile at: $_baseUrl/profile');
      print('📤 Update fields: ${updates.keys.join(', ')}');

      final http.Response response = await http
          .put(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updates),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw AuthException('Connection timeout. Please try again.');
        },
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        // Backend returns: { message, profile, email_updated? }
        final Map<String, dynamic>? profile =
            data['profile'] as Map<String, dynamic>?;
        final bool emailUpdated = data['email_updated'] as bool? ?? false;

        if (profile == null) {
          throw AuthException('Invalid response from server');
        }

        // ✅ Update stored user data with new profile
        final String? storedData = await _storage.read(key: _userKey);
        if (storedData != null) {
          final Map<String, dynamic> currentData =
              jsonDecode(storedData) as Map<String, dynamic>;
          currentData['profile'] = profile;

          // Update account email if it was changed
          if (emailUpdated && currentData.containsKey('account')) {
            currentData['account']['email'] = profile['email'];
          }

          await _storage.write(key: _userKey, value: jsonEncode(currentData));
        } else {
          // Fallback: store just the profile
          await _storage.write(key: _userKey, value: jsonEncode(data));
        }

        print('✅ Profile updated successfully');
        if (emailUpdated) {
          print('📧 Email was updated - verification may be required');
        }

        return <String, dynamic>{
          'success': true,
          'message': data['message'] ?? 'Profile updated successfully',
          'profile': profile,
          'email_updated': emailUpdated,
        };
      } else if (response.statusCode == 409) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ??
              'Email or phone number already registered to another account',
        );
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
          error['error'] as String? ?? 'Invalid input data',
        );
      } else if (response.statusCode == 404) {
        throw AuthException('Profile not found. Please contact support.');
      } else if (response.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _userKey);
        throw AuthException('Session expired. Please login again.');
      } else {
        final Map<String, dynamic> error =
            jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
            error['error'] as String? ?? 'Failed to update profile');
      }
    } on SocketException catch (e) {
      print('❌ Socket Exception: $e');
      throw AuthException('No internet connection. Please check your network.');
    } on HttpException catch (e) {
      print('❌ HTTP Exception: $e');
      throw AuthException('Could not connect to server. Please try again.');
    } on FormatException catch (e) {
      print('❌ Format Exception: $e');
      throw AuthException('Invalid response from server.');
    } on TimeoutException catch (e) {
      print('❌ Timeout Exception: $e');
      throw AuthException('Connection timeout. Please try again.');
    } catch (e) {
      print('❌ General Exception: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Upload a new profile avatar. Returns the server-relative avatar_url on success.
  Future<String> uploadAvatar(File imageFile) async {
    try {
      final String? token = await getToken();
      if (token == null) throw AuthException('Not authenticated');

      final request =
          http.MultipartRequest('POST', Uri.parse('$_baseUrl/profile/avatar'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files
          .add(await http.MultipartFile.fromPath('avatar', imageFile.path));

      final streamed = await request.send().timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw AuthException('Upload timed out. Please try again.'),
          );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String? avatarUrl = data['avatar_url'] as String?;
        if (avatarUrl == null)
          throw AuthException('Invalid response from server');

        // Keep local cache in sync — avatar shows immediately without a refetch.
        final String? stored = await _storage.read(key: _userKey);
        if (stored != null) {
          final current = jsonDecode(stored) as Map<String, dynamic>;
          if (current['profile'] is Map<String, dynamic>) {
            (current['profile'] as Map<String, dynamic>)['avatar_url'] =
                avatarUrl;
          }
          await _storage.write(key: _userKey, value: jsonEncode(current));
        }
        return avatarUrl;
      } else if (response.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _userKey);
        throw AuthException('Session expired. Please login again.');
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(
            error['error'] as String? ?? 'Failed to upload avatar');
      }
    } on SocketException {
      throw AuthException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw AuthException('Connection timeout. Please try again.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: ${e.toString()}');
    }
  }

  /// Get user-friendly error messages
  String getAuthErrorMessage(dynamic error) {
    if (error is AuthException) {
      final String message = error.message.toLowerCase();

      if (message.contains('invalid') && message.contains('credentials')) {
        return 'Invalid email or password';
      } else if (message.contains('invalid') && message.contains('password')) {
        return 'Invalid email or password';
      } else if (message.contains('not found')) {
        return 'No account found with this email';
      } else if (message.contains('already')) {
        return 'An account with this email already exists';
      } else if (message.contains('network') || message.contains('internet')) {
        return 'Network error. Please check your connection';
      } else if (message.contains('timeout')) {
        return 'Connection timeout. Please try again';
      } else if (message.contains('deactivated') ||
          message.contains('locked')) {
        return 'Your account has been deactivated or locked';
      }

      return error.message;
    }

    return 'An unexpected error occurred';
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}
