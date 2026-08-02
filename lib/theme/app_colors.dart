// lib/theme/app_colors.dart
//
// Shared palette + design tokens for AquaGas. Pulled from the existing
// live-tracking screen (track_order_screen.dart) so every newer screen —
// product detail, notifications, help & support, categories, the home
// page — shares one consistent "AquaGas teal" look instead of each screen
// inventing its own colors.
//
// If you ever restyle the tracking screen's palette, update it here too
// (or better: have track_order_screen.dart import these instead of
// defining its own copies).
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color brand = Color(0xFF1FB89A); // AquaGas teal
  static const Color brandDark = Color(0xFF0E8F77);
  static const Color brandLight = Color(0xFFB8EFE2);

  // ── Greens (legacy – kept for the rest of the app) ───────────────────────
  static const Color green500 = Color(0xFF10B981);
  static const Color green600 = Color(0xFF059669);
  static const Color green900 = Color(0xFF064E3B);
  static const Color green100 = Color(0xFFD1FAE5);
  static const Color green50 = Color(0xFFECFDF5);

  // ── Neutrals / slate ─────────────────────────────────────────────────────
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoSoft = Color(0xFFE0F2FE);

  // ── Surface / backgrounds ────────────────────────────────────────────────
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF7F9FB);

  // ── Aliases used elsewhere in the app ────────────────────────────────────
  static const Color amber500 = warning;
  static const Color red500 = danger;
  static const Color blue500 = info;

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient greenHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green600, green900],
  );

  static const LinearGradient brandHeader = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1FB89A), Color(0xFF0E8F77)],
  );

  // ── Shadows ──────────────────────────────────────────────────────────────
  static List<BoxShadow> softShadow({double opacity = 0.06}) => [
        BoxShadow(
          color: Colors.black.withOpacity(opacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> headerShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Design-system radii. Use these instead of magic numbers so every
/// card, chip, button and surface has the same corner language.
class AppRadius {
  AppRadius._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

/// Design-system spacing scale. Use these instead of raw padding values
/// so the page has a consistent vertical rhythm.
class AppSpacing {
  AppSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}
