import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:aquagas/widgets/order_provider.dart' as provider;
import 'package:aquagas/src/core/theme_provider.dart';
import 'package:aquagas/app.dart'; // Contains MyApp
import 'package:aquagas/services/error_reporting_service.dart';

// ✅ Global navigator key for deep link navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Everything (including the errors WidgetsFlutterBinding itself might
  // throw) runs inside this zone so genuinely uncaught errors — the ones
  // that would otherwise just vanish into the device log on launch week —
  // still reach ErrorReportingService instead of going unreported.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // google-services.json is in place and matches applicationId
    // com.Aquagas.customer, so this should succeed — but it's still
    // wrapped defensively: nothing else in the app hangs off Firebase
    // actually initializing, and failing safe beats crashing on launch.
    bool firebaseReady = false;
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
    } catch (e) {
      debugPrint('⚠️ Firebase.initializeApp() failed (non-fatal): $e');
    }

    if (firebaseReady) {
      // Crash reporting. Two destinations on purpose: Crashlytics gives you
      // full stack traces / device info / breadcrumbs in the Firebase
      // console; the backend's client-error log (same endpoint
      // OrderService already used) surfaces the same errors right next to
      // your other system_events in the admin dashboard. Belt and
      // suspenders for launch week.
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        ErrorReportingService.logError(
          'flutter_framework',
          details.exception,
          stackTrace: details.stack,
          fatal: true,
        );
      };

      // Errors thrown outside the Flutter framework (e.g. in a Future that
      // nothing awaited) surface here instead of FlutterError.onError.
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        ErrorReportingService.logError(
          'platform_dispatcher',
          error,
          stackTrace: stack,
          fatal: true,
        );
        return true;
      };
    } else {
      // No Crashlytics without Firebase, but still report to the backend
      // so launch-week crashes don't go completely dark.
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        ErrorReportingService.logError(
          'flutter_framework',
          details.exception,
          stackTrace: details.stack,
          fatal: true,
        );
      };
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        ErrorReportingService.logError(
          'platform_dispatcher',
          error,
          stackTrace: stack,
          fatal: true,
        );
        return true;
      };
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
  }, (Object error, StackTrace stack) {
    // Last resort — anything that slips past the handlers above (e.g. an
    // error during the zone's own setup) still gets reported rather than
    // silently killing the app with nothing recorded anywhere.
    debugPrint('⚠️ Uncaught zone error: $error');
    ErrorReportingService.logError(
      'zone_uncaught',
      error,
      stackTrace: stack,
      fatal: true,
    );
  });
}