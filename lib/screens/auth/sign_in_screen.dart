import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aquagas/app.dart';
import 'package:aquagas/widgets/sign_in_widgets.dart';
import 'package:aquagas/services/auth_service.dart';

/// Sign In Screen
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // Form and Controllers
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Services
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  // State
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _checkAuthentication();
  }

  /// Check if user is already authenticated
  Future<void> _checkAuthentication() async {
    final isAuthenticated = await _authService.isAuthenticated();
    if (isAuthenticated && mounted) {
      _navigateToHome();
    }
  }

  /// Load saved email if "Remember Me" was previously checked
  Future<void> _loadCredentials() async {
    try {
      final String? storedEmail = await _storage.read(key: 'email');
      if (storedEmail != null && storedEmail.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = storedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading credentials: $e');
    }
  }

  // /// Navigate to home
  // void _navigateToHome() {
  //   Navigator.pushReplacementNamed(context, Routes.home);
  // }

  /// Handle email/password sign in
  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Handle "Remember Me"
      await _handleRememberMe();

      if (!mounted) return;

      // Success
      _showSuccessSnackBar(
          (result['message'] ?? 'Login successful').toString());
      _navigateToHome();
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(_authService.getAuthErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Save or delete email based on "Remember Me" preference
  Future<void> _handleRememberMe() async {
    try {
      if (_rememberMe) {
        await _storage.write(key: 'email', value: _emailController.text.trim());
      } else {
        await _storage.delete(key: 'email');
      }
      await _storage.delete(key: 'password');
    } catch (e) {
      debugPrint('Error handling remember me: $e');
    }
  }

  /// Handle Google OAuth sign in (optional)
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      _showErrorSnackBar('Google sign-in not yet implemented');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Navigation helpers
  /// Navigate to sign up screen
  void _navigateToSignUp() {
    if (!_isLoading) {
      Navigator.pushNamed(context, Routes.signUp);
    }
  }

  /// Navigate to forgot password screen
  void _navigateToForgotPassword() {
    if (!_isLoading) {
      Navigator.pushNamed(context, Routes.forgotPassword);
    }
  }

  /// Navigate to home screen
  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, Routes.home);
  }

  /// UI helpers
  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  void _updateRememberMe(bool? value) {
    setState(() => _rememberMe = value ?? false);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double buttonHeight = mediaQuery.size.height * 0.07;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        backgroundColor: theme.primaryColor,
      ),
      body: Stack(
        children: <Widget>[
          _buildMainContent(buttonHeight),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  /// Build main scrollable content
  Widget _buildMainContent(double buttonHeight) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 20),
            const SignInLogo(),
            const SizedBox(height: 20),
            const SignInHeader(),
            const SizedBox(height: 20),
            SignInEmailField(controller: _emailController),
            const SizedBox(height: 20),
            SignInPasswordField(
              controller: _passwordController,
              obscurePassword: _obscurePassword,
              onToggleVisibility: _togglePasswordVisibility,
              onSubmit: _handleSignIn,
            ),
            const SizedBox(height: 10),
            SignInRememberMeRow(
              rememberMe: _rememberMe,
              isLoading: _isLoading,
              onRememberMeChanged: _updateRememberMe,
              onForgotPassword: _navigateToForgotPassword,
            ),
            const SizedBox(height: 20),
            SignInButton(
              height: buttonHeight,
              isLoading: _isLoading,
              onPressed: _handleSignIn,
            ),
            const SizedBox(height: 20),
            const SignInDivider(),
            const SizedBox(height: 10),
            GoogleSignInButton(
              height: buttonHeight,
              isLoading: _isLoading,
              onPressed: _handleGoogleSignIn,
            ),
            const SizedBox(height: 20),
            SignUpLink(
              isLoading: _isLoading,
              onPressed: _navigateToSignUp,
            ),
          ],
        ),
      ),
    );
  }

  /// Build loading overlay
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}
