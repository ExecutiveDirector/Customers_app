import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/premium_dialogs.dart';

/// Smart Rate App Service
///
/// This service intelligently manages when to show the rate dialog
/// to maximize user engagement without being annoying.
///
/// Features:
/// - Shows after X successful orders
/// - Respects user dismissals (max 3 times)
/// - Cooldown period between prompts (7 days)
/// - Tracks if user already rated
/// - Easy to test and reset
class RateAppService {
  // SharedPreferences keys
  static const String _ordersKey = 'completed_orders_count';
  static const String _ratedKey = 'has_rated_app';
  static const String _dismissedKey = 'rate_dialog_dismissed_count';
  static const String _lastShownKey = 'rate_dialog_last_shown';
  static const String _firstOrderKey = 'first_order_timestamp';

  // Configuration - Adjust these to your needs
  static const int showAfterOrders = 3; // Show after 3 completed orders
  static const int maxDismissals = 3; // Stop asking after 3 dismissals
  static const int daysBetweenPrompts = 7; // Wait 7 days between prompts
  static const int minDaysSinceFirstOrder =
      3; // Wait at least 3 days since first order

  /// Call this after a successful order completion
  ///
  /// Example usage:
  /// ```dart
  /// // After order is successfully delivered
  /// await RateAppService.incrementOrders(context);
  /// ```
  static Future<void> incrementOrders(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Don't show if already rated
      if (prefs.getBool(_ratedKey) ?? false) {
        debugPrint('RateAppService: User already rated, skipping');
        return;
      }

      // Don't show if dismissed too many times
      final dismissCount = prefs.getInt(_dismissedKey) ?? 0;
      if (dismissCount >= maxDismissals) {
        debugPrint(
            'RateAppService: Max dismissals reached ($dismissCount/$maxDismissals)');
        return;
      }

      // Track first order timestamp
      final firstOrder = prefs.getInt(_firstOrderKey);
      if (firstOrder == null) {
        await prefs.setInt(
            _firstOrderKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('RateAppService: First order recorded');
      }

      // Check if enough time has passed since last shown
      final lastShown = prefs.getInt(_lastShownKey) ?? 0;
      if (lastShown > 0) {
        final daysSinceLastShown = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(lastShown))
            .inDays;

        if (daysSinceLastShown < daysBetweenPrompts) {
          debugPrint(
              'RateAppService: Too soon since last prompt ($daysSinceLastShown/$daysBetweenPrompts days)');
          return;
        }
      }

      // Check if enough days have passed since first order
      if (firstOrder != null) {
        final daysSinceFirstOrder = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(firstOrder))
            .inDays;

        if (daysSinceFirstOrder < minDaysSinceFirstOrder) {
          debugPrint(
              'RateAppService: Too early since first order ($daysSinceFirstOrder/$minDaysSinceFirstOrder days)');
          return;
        }
      }

      // Increment order count
      final count = (prefs.getInt(_ordersKey) ?? 0) + 1;
      await prefs.setInt(_ordersKey, count);
      debugPrint('RateAppService: Order count: $count');

      // Show dialog after X orders
      if (count >= showAfterOrders && context.mounted) {
        debugPrint(
            'RateAppService: Showing rate dialog (threshold: $showAfterOrders)');
        await _showRateDialog(context);
      }
    } catch (e) {
      debugPrint('RateAppService: Error incrementing orders: $e');
    }
  }

  /// Internal method to show the rate dialog
  static Future<void> _showRateDialog(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Record when we showed it
      await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);

      if (!context.mounted) return;

      // Show dialog and wait for result
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // Force user to make a choice
        builder: (_) => const PremiumRateDialog(),
      );

      // If user dismissed (clicked "Maybe Later" or back button)
      if (result != true) {
        final dismissCount = (prefs.getInt(_dismissedKey) ?? 0) + 1;
        await prefs.setInt(_dismissedKey, dismissCount);
        debugPrint('RateAppService: Dialog dismissed (count: $dismissCount)');
      }
    } catch (e) {
      debugPrint('RateAppService: Error showing dialog: $e');
    }
  }

  /// Call this when user actually rates the app
  ///
  /// Example usage:
  /// ```dart
  /// // In your premium_dialogs.dart, after opening store:
  /// await RateAppService.markAsRated();
  /// ```
  static Future<void> markAsRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_ratedKey, true);
      debugPrint('RateAppService: User marked as rated');
    } catch (e) {
      debugPrint('RateAppService: Error marking as rated: $e');
    }
  }

  /// Check if user has already rated
  static Future<bool> hasRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_ratedKey) ?? false;
    } catch (e) {
      debugPrint('RateAppService: Error checking rated status: $e');
      return false;
    }
  }

  /// Get current order count
  static Future<int> getOrderCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_ordersKey) ?? 0;
    } catch (e) {
      debugPrint('RateAppService: Error getting order count: $e');
      return 0;
    }
  }

  /// Get dismiss count
  static Future<int> getDismissCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_dismissedKey) ?? 0;
    } catch (e) {
      debugPrint('RateAppService: Error getting dismiss count: $e');
      return 0;
    }
  }

  /// Get status information for debugging
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getInt(_lastShownKey);
      final firstOrder = prefs.getInt(_firstOrderKey);

      return <String, dynamic>{
        'orderCount': prefs.getInt(_ordersKey) ?? 0,
        'hasRated': prefs.getBool(_ratedKey) ?? false,
        'dismissCount': prefs.getInt(_dismissedKey) ?? 0,
        'lastShown': lastShown != null
            ? DateTime.fromMillisecondsSinceEpoch(lastShown)
            : null,
        'firstOrder': firstOrder != null
            ? DateTime.fromMillisecondsSinceEpoch(firstOrder)
            : null,
        'daysSinceLastShown': lastShown != null
            ? DateTime.now()
                .difference(
                  DateTime.fromMillisecondsSinceEpoch(lastShown),
                )
                .inDays
            : null,
        'daysSinceFirstOrder': firstOrder != null
            ? DateTime.now()
                .difference(
                  DateTime.fromMillisecondsSinceEpoch(firstOrder),
                )
                .inDays
            : null,
      };
    } catch (e) {
      debugPrint('RateAppService: Error getting status: $e');
      return <String, dynamic>{};
    }
  }

  /// Force show the dialog (for testing only)
  ///
  /// Example usage:
  /// ```dart
  /// // In debug mode only:
  /// await RateAppService.forceShow(context);
  /// ```
  static Future<void> forceShow(BuildContext context) async {
    if (!context.mounted) return;

    debugPrint('RateAppService: Force showing dialog');
    await showDialog<void>(
      context: context,
      builder: (BuildContext _) => const PremiumRateDialog(),
    );
  }

  /// Reset all counters and flags (for testing)
  ///
  /// Example usage:
  /// ```dart
  /// // Add this as a debug button in settings:
  /// await RateAppService.reset();
  /// ```
  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ordersKey);
      await prefs.remove(_ratedKey);
      await prefs.remove(_dismissedKey);
      await prefs.remove(_lastShownKey);
      await prefs.remove(_firstOrderKey);
      debugPrint('RateAppService: All data reset');
    } catch (e) {
      debugPrint('RateAppService: Error resetting: $e');
    }
  }

  /// Print current status to console (for debugging)
  static Future<void> printStatus() async {
    final status = await getStatus();
    debugPrint('=== RateAppService Status ===');
    debugPrint('Order Count: ${status['orderCount']}');
    debugPrint('Has Rated: ${status['hasRated']}');
    debugPrint('Dismiss Count: ${status['dismissCount']}');
    debugPrint('Last Shown: ${status['lastShown']}');
    debugPrint('First Order: ${status['firstOrder']}');
    debugPrint('Days Since Last Shown: ${status['daysSinceLastShown']}');
    debugPrint('Days Since First Order: ${status['daysSinceFirstOrder']}');
    debugPrint('============================');
  }
}

/// Extension to make it easier to call from anywhere
extension RateAppContextExtension on BuildContext {
  /// Quick way to increment orders
  /// Usage: context.incrementOrders();
  Future<void> incrementOrders() => RateAppService.incrementOrders(this);

  /// Quick way to force show (testing)
  /// Usage: context.forceShowRateDialog();
  Future<void> forceShowRateDialog() => RateAppService.forceShow(this);
}
