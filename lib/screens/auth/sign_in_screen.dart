import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // State is held in ValueNotifiers rather than plain fields + setState().
  // Each sign-in widget only listens to the notifier(s) it actually
  // needs, so e.g. toggling password visibility no longer rebuilds the
  // logo, header, or sign-in button — only the password field repaints.
  final ValueNotifier<bool> _rememberMe = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _obscurePassword = ValueNotifier<bool>(true);

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
        _emailController.text = storedEmail;
        _rememberMe.value = true;
      }
    } catch (e) {
      debugPrint('Error loading credentials: $e');
    }
  }

  /// Handle email/password sign in
  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    _isLoading.value = true;

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
      HapticFeedback.selectionClick();
      _showErrorSnackBar(_authService.getAuthErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Unexpected error: $e');
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  /// Save or delete email based on "Remember Me" preference
  Future<void> _handleRememberMe() async {
    try {
      if (_rememberMe.value) {
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
    _isLoading.value = true;
    try {
      _showErrorSnackBar('Google sign-in not yet implemented');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Google sign-in failed: $e');
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  /// Navigation helpers
  /// Navigate to sign up screen
  void _navigateToSignUp() {
    if (!_isLoading.value) {
      Navigator.pushNamed(context, Routes.signUp);
    }
  }

  /// Navigate to forgot password screen
  void _navigateToForgotPassword() {
    if (!_isLoading.value) {
      Navigator.pushNamed(context, Routes.forgotPassword);
    }
  }

  /// Navigate to home screen
  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, Routes.home);
  }

  /// UI helpers
  void _togglePasswordVisibility() {
    _obscurePassword.value = !_obscurePassword.value;
  }

  void _updateRememberMe(bool? value) {
    _rememberMe.value = value ?? false;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _rememberMe.dispose();
    _isLoading.dispose();
    _obscurePassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double buttonHeight = (mediaQuery.size.height * 0.07).clamp(48.0, 58.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        backgroundColor: theme.primaryColor,
      ),
      body: Stack(
        children: <Widget>[
          _buildMainContent(buttonHeight),
          // Only the overlay rebuilds when isLoading flips — the rest of
          // the form tree (email/password/remember-me/etc.) is untouched.
          ValueListenableBuilder<bool>(
            valueListenable: _isLoading,
            builder: (context, loading, _) =>
                loading ? _buildLoadingOverlay() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Build main scrollable content
  Widget _buildMainContent(double buttonHeight) {
    return SingleChildScrollView(
      // Keeps the form usable when the keyboard opens on smaller screens.
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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