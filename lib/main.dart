import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:aquagas/widgets/order_provider.dart' as provider;
import 'package:aquagas/src/core/theme_provider.dart'; 
import 'package:aquagas/app.dart'; // Contains MyApp

// ✅ Global navigator key for deep link navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wrapped: until android/app/google-services.json (matching a real,
  // non-placeholder applicationId) is in place, this will throw — and the
  // rest of the app has nothing depending on Firebase actually succeeding
  // here, so failing safe beats crashing on launch. Push notifications
  // just won't be available until that config is added (see
  // push_notification_manager.dart for exactly what's needed).
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('⚠️ Firebase.initializeApp() failed (non-fatal): $e');
  }

  // Optional: Set system UI overlay style for better appearance
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  //  Run app with BOTH providers
  runApp(
    MultiProvider(
      providers: [
        //  existing provider order provider
        ChangeNotifierProvider<provider.OrderProvider>(
          create: (context) => provider.OrderProvider(),
        ),
        // Theme provider for settings
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) => ThemeProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
