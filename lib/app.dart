import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_links/app_links.dart';
import 'package:aquagas/src/core/theme_provider.dart';
import 'package:aquagas/screens/orderHistoryPage.dart';
import 'package:aquagas/screens/auth/sign_in_screen.dart';
import 'package:aquagas/screens/auth/sign_up_screen.dart';
import 'package:aquagas/screens/auth/reset_password_screen.dart';
import 'package:aquagas/screens/forgot_password.dart';
import 'package:aquagas/screens/update_password_screen.dart';
import 'package:aquagas/screens/complete_profile_screen.dart';
import 'package:aquagas/screens/home/home_page.dart';
import 'package:aquagas/screens/track_order_screen.dart';
import 'package:aquagas/screens/cart_screen.dart';
import 'package:aquagas/screens/payment_options_screen.dart';
import 'package:aquagas/screens/payment_confirmation_screen.dart';
import 'package:aquagas/screens/nearby_vendors_screen.dart';
import 'package:aquagas/screens/change_location_screen.dart';
import 'package:aquagas/screens/profile_screen.dart';
import 'package:aquagas/app_splash_screen.dart';
import 'package:aquagas/main.dart';
import 'package:aquagas/screens/account_screen.dart';
import 'package:aquagas/app_order.dart' as models;
import 'package:aquagas/screens/home/widgets/vendor_products_section.dart';
import 'package:aquagas/screens/notifications_screen.dart';
import 'package:aquagas/screens/help_support_screen.dart';

class Routes {
  Routes._();

  static const splash = '/splash';
  static const home = '/';
  static const signIn = '/sign_in';
  static const signUp = '/sign_up';
  static const resetPassword = '/reset_password';
  static const updatePassword = '/update_password';
  static const forgotPassword = '/forgot_password';
  static const completeProfile = '/complete_profile';
  static const profile = '/profile_screen';
  static const paymentConfirmation = '/payment_confirmation';
  static const paymentOptions = '/payment_options';
  static const cart = '/cart';
  static const account = '/account';
  static const nearby = '/nearby';
  static const trackOrder = '/track_order';
  static const changeLocation = '/change_location';
  static const orderHistory = '/order_history';
  static const outletProducts = '/outlet-products';
  static const notifications = '/notifications';
  static const helpSupport = '/help_support';
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  // Default coordinates (Nairobi)
  static const double defaultLatitude = -1.286389;
  static const double defaultLongitude = 36.817223;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  // ✅ Initialize Deep Link Listening
  Future<void> _initDeepLinks() async {
    try {
      final initialLink = await _appLinks.getInitialAppLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (Object err, StackTrace stack) {
        debugPrint('Deep link error: $err');
        debugPrint('Stack trace: $stack');
      },
    );
  }

  /// ✅ Handle incoming deep links
  void _handleDeepLink(Uri uri) {
    debugPrint('📱 Received deep link: $uri');

    if (uri.path.contains('reset-password')) {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        navigatorKey.currentState?.pushNamed(
          Routes.resetPassword,
          arguments: {'token': token},
        );
      }
    }
  }

  Future<Map<String, double>> _getUserLocation(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationSnackBar(
          context, 'Location services disabled. Using default.');
      return _getDefaultLocation();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationSnackBar(context, 'Location permission denied.');
        return _getDefaultLocation();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationSnackBar(context, 'Location permanently denied.');
      return _getDefaultLocation();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return {'latitude': position.latitude, 'longitude': position.longitude};
    } catch (e) {
      debugPrint('Location error: $e');
      _showLocationSnackBar(context, 'Unable to fetch location.');
      return _getDefaultLocation();
    }
  }

  Map<String, double> _getDefaultLocation() =>
      {'latitude': defaultLatitude, 'longitude': defaultLongitude};

  void _showLocationSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Wrap with Consumer to listen to theme changes
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'AquaGas',

          // ✅ Theme configuration with dynamic theme switching
          themeMode: themeProvider.themeMode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),

          initialRoute: Routes.splash,
          routes: _buildRoutes(),
          onUnknownRoute: _handleUnknownRoute,
        );
      },
    );
  }

  /// ✅ Light theme with AquaGas branding
  ThemeData _buildLightTheme() {
    const seedColor = Color(0xFF1FB89A); // Teal primary color
    const backgroundColor = Color(0xFFF7F3F1); // Warm light background

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      background: backgroundColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFF4A4A4A),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF6A6A6A),
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1A1A1A),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: seedColor, width: 1.5),
          foregroundColor: seedColor,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: seedColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: seedColor,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade300,
        thickness: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// ✅ Dark theme with AquaGas branding
  ThemeData _buildDarkTheme() {
    const seedColor = Color(0xFF1FB89A);
    const backgroundColor = Color(0xFF081229); // Deep blue background
    const surfaceColor = Color(0xFF1A1F2E); // Card color

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      background: backgroundColor,
      surface: surfaceColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFE0E0E0),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFFB0B0B0),
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: seedColor, width: 1.5),
          foregroundColor: seedColor,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: seedColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // Bottom navigation bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: seedColor,
        unselectedItemColor: Color(0xFF808080),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seedColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 1,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() => {
        Routes.splash: (_) => const SplashScreen(),
        Routes.signIn: (_) => const SignInScreen(),
        Routes.signUp: (_) => const SignUpScreen(),
        Routes.forgotPassword: (_) => const ForgotPasswordScreen(),
        Routes.updatePassword: (_) => const UpdatePasswordScreen(),
        Routes.completeProfile: (_) => const CompleteProfileScreen(),
        Routes.profile: (_) => ProfileScreen(),
        Routes.notifications: (_) => const NotificationsScreen(),
        Routes.helpSupport: (_) => const HelpSupportScreen(),
        Routes.cart: (_) => const CartScreen(),
        Routes.outletProducts: (context) => const OutletProductsScreen(),
        Routes.orderHistory: (_) => const OrderHistoryPage(),
        Routes.account: (_) => const AccountPage(),
        Routes.nearby: (_) => const NearbyVendorsScreen(),
        Routes.changeLocation: (_) => const ChangeLocationScreen(),
        Routes.resetPassword: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final token = args?['token'] as String?;
          if (token == null || token.isEmpty) {
            throw ArgumentError('Missing or invalid token');
          }
          return ResetPasswordScreen(token: token);
        },
        Routes.home: (context) => FutureBuilder<Map<String, double>>(
              future: _getUserLocation(context),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                final data = snapshot.data!;
                return HomePage(
                  userLat: data['latitude']!,
                  userLng: data['longitude']!,
                );
              },
            ),
        Routes.paymentOptions: (context) {
          final order =
              ModalRoute.of(context)?.settings.arguments as models.AppOrder?;
          return PaymentOptionsScreen(order: order ?? _getDefaultOrder());
        },
        Routes.paymentConfirmation: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;

          return PaymentConfirmationScreen(
            paymentOption: args?['paymentOption']?.toString() ?? 'Unknown',
            orderId: args?['orderId']?.toString() ?? '',
          );
        },
        Routes.trackOrder: (context) {
          final orderId = ModalRoute.of(context)?.settings.arguments as String?;
          return TrackOrderScreen(orderId: orderId ?? '');
        },
      };

  Route<Widget> _handleUnknownRoute(RouteSettings settings) =>
      MaterialPageRoute(builder: (_) {
        return const Scaffold(
          body: Center(child: Text('404 - Page not found')),
        );
      });

  models.AppOrder _getDefaultOrder() => models.AppOrder(
        id: '',
        userId: '',
        vendorName: '',
        status: 'Unknown',
        timestamp: DateTime.now(),
        items: [],
        totalPrice: 0.0,
        quantity: 1,
        deliveryLocation: null,
      );
}
