// lib/theme/app_colors.dart
//
// Shared palette, pulled from the existing live-tracking screen
// (track_order_screen.dart) so every newer screen — product detail,
// notifications, help & support, categories — shares one consistent
// "AquaGas green" look instead of each screen inventing its own colors.
//
// If you ever restyle the tracking screen's palette, update it here too
// (or better: have track_order_screen.dart import these instead of
// defining its own copies).
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color green500 = Color(0xFF10B981);
  static const Color green600 = Color(0xFF059669);
  static const Color green900 = Color(0xFF064E3B);
  static const Color green100 = Color(0xFFD1FAE5);
  static const Color green50 = Color(0xFFECFDF5);

  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate100 = Color(0xFFF1F5F9);

  static const Color amber500 = Color(0xFFF59E0B);
  static const Color red500 = Color(0xFFEF4444);
  static const Color blue500 = Color(0xFF0EA5E9);

  static const LinearGradient greenHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green600, green900],
  );

  static List<BoxShadow> softShadow({double opacity = 0.08}) => [
        BoxShadow(
          color: Colors.black.withOpacity(opacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}
