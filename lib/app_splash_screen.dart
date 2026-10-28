import 'package:flutter/material.dart';
import 'package:aquagas/app.dart';
import 'package:aquagas/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _minSplash = Duration(milliseconds: 1900);

  final AuthService _authService = AuthService();

  // One-shot entrance (logo pops in, text and loader stagger up).
  late final AnimationController _intro;
  // Gentle idle float / glow while we check the session.
  late final AnimationController _idle;
  // Sign in / guest buttons slide up once we know the user is signed out.
  late final AnimationController _actions;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _tagline;
  late final Animation<double> _loader;

  final Stopwatch _clock = Stopwatch()..start();
  bool _isCheckingAuth = true;
  bool _showButtons = false;

  Animation<double> _interval(double a, double b, [Curve c = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(a, b, curve: c));

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _actions = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _logoScale = Tween<double>(begin: 0.55, end: 1.0)
        .animate(_interval(0.0, 0.5, Curves.easeOutBack));
    _logoFade = _interval(0.0, 0.3, Curves.easeOut);
    _tagline = _interval(0.4, 0.75);
    _loader = _interval(0.65, 1.0);

    _intro.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    var authenticated = false;
    try {
      authenticated = await _authService.isAuthenticated();
    } catch (e, stackTrace) {
      // Fall back to showing the sign in / guest buttons.
      debugPrint("❌ App initialization failed: $e");
      debugPrint("Stack trace: $stackTrace");
    }

    // Let the entrance animation finish so the splash never just flashes.
    final remaining = _minSplash - _clock.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;

    if (authenticated) {
      Navigator.pushReplacementNamed(context, Routes.home);
    } else {
      setState(() {
        _isCheckingAuth = false;
        _showButtons = true;
      });
      _actions.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    _actions.dispose();
    super.dispose();
  }

  void _goToSignIn() => Navigator.pushReplacementNamed(context, Routes.signIn);
  void _continueAsGuest() => Navigator.pushReplacementNamed(context, Routes.home);

  Widget _rise(Animation<double> t, Widget child) => Opacity(
        opacity: t.value,
        child: Transform.translate(
            offset: Offset(0, 16 * (1 - t.value)), child: child),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0a7d0a), Color(0xff1fb81f), Color(0xff3de03d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft decorative glow orbs.
            const Positioned(top: -80, right: -70, child: _GlowOrb(size: 240)),
            const Positioned(bottom: -100, left: -80, child: _GlowOrb(size: 280)),
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _idle, _actions]),
                  builder: (context, _) {
                    final float =
                        Curves.easeInOut.transform(_idle.value) * 6 - 3;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: _logoFade.value,
                          child: Transform.translate(
                            offset: Offset(0, float),
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white
                                          .withOpacity(0.18 + 0.18 * _idle.value),
                                      blurRadius: 30 + 16 * _idle.value,
                                      spreadRadius: 2 + 4 * _idle.value,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/assets/images/logo.png',
                                  width: 210,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint('❌ Failed to load logo: $error');
                                    return Icon(Icons.water_drop,
                                        size: 70, color: Colors.green.shade700);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _rise(
                          _tagline,
                          const Text(
                            'Fast. Safe. Reliable.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 56),
                        SizedBox(
                          height: 190,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _isCheckingAuth
                                ? _buildLoadingIndicator()
                                : _showButtons
                                    ? _buildActionButtons()
                                    : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Opacity(
      key: const ValueKey('loading'),
      opacity: _loader.value,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 120,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final t = CurvedAnimation(parent: _actions, curve: Curves.easeOutCubic);
    return Opacity(
      key: const ValueKey('buttons'),
      opacity: t.value,
      child: Transform.translate(
        offset: Offset(0, 24 * (1 - t.value)),
        child: Column(
          children: [
            SizedBox(
              width: 260,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign In',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 6,
                ),
                onPressed: _goToSignIn,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 260,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_outline),
                label: const Text('Continue as Guest'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _continueAsGuest,
              ),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Sign in for order tracking and faster checkout',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft radial glow used as decorative background texture.
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.0)],
        ),
      ),
    );
  }
}

// =========================================================================
// Error Screen (if initialization fails)
// =========================================================================
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffef5350), Color(0xffe57373)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.cloud_off_rounded,
                      size: 60,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Error Title
                  const Text(
                    "Unable to Connect",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Error Message
                  const Text(
                    "Please check your internet connection and try again.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Retry Button
                  SizedBox(
                    width: 250,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        "Retry",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 6,
                      ),
                      onPressed: () {
                        Navigator.pushReplacement<void, void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const SplashScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Continue to Sign In
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, Routes.signIn);
                    },
                    child: const Text(
                      "Continue to Sign In",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Continue as Guest
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, Routes.home);
                    },
                    child: const Text(
                      "Continue as Guest",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}