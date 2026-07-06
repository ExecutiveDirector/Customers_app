import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:aquagas/screens/complete_profile_screen.dart';
import 'package:aquagas/widgets/sign_up_widgets.dart';
import 'package:aquagas/services/phone_auth_service.dart';

/// Sign-Up Screen — phone OTP flow.
///
/// Flow mirrors the web (register.tsx):
///   Step 1 → phone entry   (PhoneInputSection)
///   Step 2 → OTP verify    (OTPInputSection)
///   Step 3a → existing user → navigate to Home (already authenticated)
///   Step 3b → new user     → navigate to CompleteProfileScreen
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  // ── Services ─────────────────────────────────────────────────────
  final PhoneAuthService _authService = PhoneAuthService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ── Controllers / focus ──────────────────────────────────────────
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  // ── Animations ───────────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  // ── State ────────────────────────────────────────────────────────
  String? _completePhoneNumber;
  bool _showOTPSection = false;
  bool _isLoading = false;
  bool _isOTPValid = true;
  bool _isPhoneValid = true;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;
  String _initialCountryCode = 'KE';
  bool _isDisposed = false;

  static const int _otpLength = 6;
  static const int _resendTimeout = 60;

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSavedCountryCode();
    _initAnimations();
    _otpController.addListener(_onOtpChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _resendTimer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // ── Init helpers ─────────────────────────────────────────────────

  Future<void> _loadSavedCountryCode() async {
    try {
      final code = await _storage.read(key: 'country_code');
      if (code != null && code.isNotEmpty && !_isDisposed && mounted) {
        setState(() => _initialCountryCode = code);
      }
    } catch (e) {
      debugPrint('Failed to load country code: $e');
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
  }

  // ── OTP validation ───────────────────────────────────────────────

  void _onOtpChanged() {
    if (_isDisposed) return;
    final otp = _otpController.text;
    final isValid = otp.length <= _otpLength && RegExp(r'^\d*$').hasMatch(otp);
    if (isValid != _isOTPValid && mounted) {
      setState(() => _isOTPValid = isValid);
    }
  }

  // ── Resend timer ─────────────────────────────────────────────────

  void _startResendTimer() {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendSecondsLeft = _resendTimeout);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 0) {
        timer.cancel();
        if (mounted) setState(() => _resendSecondsLeft = 0);
      } else {
        if (mounted) setState(() => _resendSecondsLeft--);
      }
    });
  }

  // ── STEP 1 — Send OTP ────────────────────────────────────────────

  Future<void> _sendOTP() async {
    if (!mounted) return;

    FocusScope.of(context).unfocus();
    final phone = _completePhoneNumber?.trim();

    if (phone == null || phone.isEmpty) {
      if (mounted) {
        setState(() => _isPhoneValid = false);
        _showSnackBar('Please enter a valid phone number');
      }
      return;
    }

    if (!RegExp(r'^\+\d{10,15}$').hasMatch(phone)) {
      if (mounted) {
        setState(() => _isPhoneValid = false);
        _showSnackBar('Invalid phone number format (e.g., +2547XXXXXXXX)');
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      await _authService.sendOTP(phone);

      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
          _showOTPSection = true;
          _isOTPValid = true;
        });
        _otpController.clear();

        await _fadeController.forward();
        await _scaleController.forward();
        _startResendTimer();

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) FocusScope.of(context).requestFocus(_otpFocusNode);
        });
      }
    } on AuthException catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(_authService.getAuthErrorMessage(e));
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Unexpected error: $e');
      }
    }
  }

  // ── STEP 2 — Verify OTP ──────────────────────────────────────────

  Future<void> _verifyOTP() async {
    if (!mounted) return;

    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();

    if (otp.length != _otpLength || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      if (mounted) {
        setState(() => _isOTPValid = false);
        _showSnackBar('Enter a valid 6-digit OTP');
      }
      return;
    }

    if (_completePhoneNumber == null || _completePhoneNumber!.isEmpty) {
      _showSnackBar('Phone number missing. Please restart the sign-up process.');
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final result = await _authService.verifyOTP(_completePhoneNumber!, otp);

      debugPrint('🎯 [SignUpScreen] verifyOTP result → verified=${result.verified}, '
          'token=${result.token != null ? "[SET]" : "null"}, '
          'needsRegistration=${result.needsRegistration}');

      if (!_isDisposed && mounted) {
        if (!result.verified) {
          setState(() {
            _isLoading = false;
            _isOTPValid = false;
          });
          _showSnackBar('Invalid OTP. Please try again.');
          return;
        }

        // ── Existing user: token stored in PhoneAuthService, go Home ──
        if (!result.needsRegistration && result.token != null) {
          _showSnackBar('Welcome back!', isSuccess: true);
          _navigateToHome();
          return;
        }

        // ── New user: complete profile ─────────────────────────────────
        _navigateToCompleteProfile();
      }
    } on AuthException catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
          _isOTPValid = false;
        });
        _showSnackBar(_authService.getAuthErrorMessage(e));
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
          _isOTPValid = false;
        });
        _showSnackBar('Unexpected error: $e');
      }
    }
  }

  // ── Navigation ───────────────────────────────────────────────────

  void _navigateToCompleteProfile() {
    if (!mounted) return;
    _resendTimer?.cancel();
    _otpController.removeListener(_onOtpChanged);
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const CompleteProfileScreen()),
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    _resendTimer?.cancel();
    _otpController.removeListener(_onOtpChanged);
    Navigator.pushReplacementNamed(context, '/');
  }

  // ── Misc ─────────────────────────────────────────────────────────

  void _resetToPhoneInput() {
    if (!mounted) return;
    _resendTimer?.cancel();
    _fadeController.reset();
    _scaleController.reset();
    _otpController.clear();
    setState(() {
      _showOTPSection = false;
      _isOTPValid = true;
      _isLoading = false;
      _resendSecondsLeft = 0;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) FocusScope.of(context).requestFocus(_phoneFocusNode);
    });
  }

  Future<void> _pasteFromClipboard() async {
    if (!mounted) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.length == _otpLength && RegExp(r'^\d{6}$').hasMatch(text)) {
        if (mounted) {
          _otpController.text = text;
          await _verifyOTP();
        }
      } else {
        if (mounted) _showSnackBar('Clipboard does not contain a valid 6-digit OTP');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to read clipboard');
      debugPrint('Clipboard error: $e');
    }
  }

  Future<void> _saveCountryCode(String code) async {
    try {
      await _storage.write(key: 'country_code', value: code);
    } catch (e) {
      debugPrint('Failed to save country code: $e');
    }
  }

  void _onPhoneChanged(String completeNumber) {
    _completePhoneNumber = completeNumber;
    final isValid = RegExp(r'^\+\d{10,15}$').hasMatch(completeNumber);
    if (isValid != _isPhoneValid && mounted) {
      setState(() => _isPhoneValid = isValid);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonHeight = MediaQuery.of(context).size.height * 0.07;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Step 1: Phone entry ──────────────────────────
                  if (!_showOTPSection)
                    PhoneInputSection(
                      theme: theme,
                      buttonHeight: buttonHeight,
                      phoneController: _phoneController,
                      phoneFocusNode: _phoneFocusNode,
                      initialCountryCode: _initialCountryCode,
                      isPhoneValid: _isPhoneValid,
                      isLoading: _isLoading,
                      onCountryChanged: _saveCountryCode,
                      onPhoneChanged: _onPhoneChanged,
                      onPhoneSubmitted: _sendOTP,
                      onSendOTP: _sendOTP,
                    ),

                  // ── Step 2: OTP entry ────────────────────────────
                  if (_showOTPSection)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: OTPInputSection(
                          theme: theme,
                          buttonHeight: buttonHeight,
                          otpController: _otpController,
                          otpFocusNode: _otpFocusNode,
                          otpLength: _otpLength,
                          isOTPValid: _isOTPValid,
                          isLoading: _isLoading,
                          resendSecondsLeft: _resendSecondsLeft,
                          onOTPChanged: (value) {
                            if (!_isOTPValid && mounted) {
                              setState(() => _isOTPValid = true);
                            }
                          },
                          onOTPCompleted: (_) {
                            if (mounted) _verifyOTP();
                          },
                          onPasteOTP: _pasteFromClipboard,
                          onResendOTP: _sendOTP,
                          onChangeNumber: _resetToPhoneInput,
                          onVerifyOTP: _verifyOTP,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}