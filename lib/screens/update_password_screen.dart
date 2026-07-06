import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isCheckingStatus = true;
  bool _hasSetPassword = false; // Track if user has set password

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  static const String _baseUrl =
      'https://aquagas-backend.onrender.com/api/v1/auth';

  @override
  void initState() {
    super.initState();
    _checkPasswordStatus();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Check if user has previously set a password
  Future<void> _checkPasswordStatus() async {
    try {
      // First try local storage
      final passwordSet = await _storage.read(key: 'password_set');

      if (passwordSet != null) {
        setState(() {
          _hasSetPassword = passwordSet == 'true';
          _isCheckingStatus = false;
        });
        return;
      }

      // If not in storage, check with backend
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        setState(() => _isCheckingStatus = false);
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/check-password-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final hasPassword = data['hasSetPassword'] as bool? ?? false;

        // Cache the result
        await _storage.write(
            key: 'password_set', value: hasPassword.toString());

        setState(() {
          _hasSetPassword = hasPassword;
          _isCheckingStatus = false;
        });
      } else {
        setState(() => _isCheckingStatus = false);
      }
    } catch (e) {
      debugPrint('Error checking password status: $e');
      setState(() => _isCheckingStatus = false);
    }
  }

  /// Update or set password
  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final String? currentPassword =
        _hasSetPassword ? _currentPasswordController.text.trim() : null;
    final String newPassword = _newPasswordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      _showSnack('Passwords do not match', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final requestBody = <String, dynamic>{
        'newPassword': newPassword,
      };

      // Only include current password if user has set one before
      if (_hasSetPassword && currentPassword != null) {
        requestBody['currentPassword'] = currentPassword;
      }

      debugPrint('Updating password (hasSetPassword: $_hasSetPassword)');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Successfully updated password
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        // Update stored status
        await _storage.write(key: 'password_set', value: 'true');

        _showSnack(
          _hasSetPassword
              ? 'Password changed successfully!'
              : 'Password set successfully!',
          isError: false,
        );

        // Navigate back after short delay
        await Future<void>.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to update password');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to update password: ${e.toString()}', isError: true);
      }
      debugPrint('Update password error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Password'),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text('Checking password status...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _hasSetPassword ? 'Change Password' : 'Set Password',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 20.0),

                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _hasSetPassword
                            ? Colors.orange.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hasSetPassword
                              ? Colors.orange.shade200
                              : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            _hasSetPassword ? Icons.info : Icons.lock_open,
                            color: _hasSetPassword
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              _hasSetPassword
                                  ? 'Changing your password regularly helps secure your account.'
                                  : 'Set a password to enable login with your phone number or email.',
                              style: TextStyle(
                                color: _hasSetPassword
                                    ? Colors.orange.shade900
                                    : Colors.blue.shade900,
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Current Password Field (only if password exists)
                    if (_hasSetPassword) ...[
                      _buildPasswordField(
                        controller: _currentPasswordController,
                        labelText: 'Current Password',
                        icon: Icons.lock,
                        obscureText: _obscureCurrentPassword,
                        onToggleObscure: () => setState(() =>
                            _obscureCurrentPassword = !_obscureCurrentPassword),
                        validator: (String? value) {
                          if (_hasSetPassword &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Current password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20.0),
                    ],

                    // New Password Field
                    _buildPasswordField(
                      controller: _newPasswordController,
                      labelText: _hasSetPassword ? 'New Password' : 'Password',
                      icon: Icons.lock,
                      obscureText: _obscureNewPassword,
                      onToggleObscure: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password is required';
                        }
                        if (value.trim().length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (!RegExp(r'[A-Z]').hasMatch(value)) {
                          return 'Must contain at least one uppercase letter';
                        }
                        if (!RegExp(r'[a-z]').hasMatch(value)) {
                          return 'Must contain at least one lowercase letter';
                        }
                        if (!RegExp(r'\d').hasMatch(value)) {
                          return 'Must contain at least one number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20.0),

                    // Confirm Password Field
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      labelText: 'Confirm Password',
                      icon: Icons.lock,
                      obscureText: _obscureConfirmPassword,
                      onToggleObscure: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                      validator: (String? value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12.0),

                    // Password Requirements
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Password must be 8+ characters with uppercase, lowercase, and number',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40.0),

                    // Submit Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.orange.shade500,
                            Colors.orange.shade800,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updatePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50.0, vertical: 15.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          _hasSetPassword ? 'Change Password' : 'Set Password',
                          style: const TextStyle(
                              fontSize: 18.0, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Colors.orange,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _hasSetPassword
                            ? 'Updating password...'
                            : 'Setting password...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.green),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.green),
          borderRadius: BorderRadius.circular(8.0),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.green,
          ),
          onPressed: onToggleObscure,
        ),
      ),
      validator: validator,
    );
  }
}
