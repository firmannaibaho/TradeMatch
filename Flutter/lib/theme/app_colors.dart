import 'package:flutter/material.dart';

/// Complete color palette following 2025 modern design standards.
/// Includes primary colors, semantics, neutrals, and glassmorphism effects.
class AppColors {
  // Primary (keeping existing orange for consistency)
  static const Color primary = Color(0xFFFD7E14);
  static const Color primaryDark = Color(0xFFE8590C);
  static const Color primaryLight = Color(0xFFFF9847);

  // Accent
  static const Color accent = Color(0xFFF59E0B); // Amber for highlights

  // Semantics
  static const Color success = Color(0xFF10B981); // Green
  static const Color error = Color(0xFFEF4444); // Red
  static const Color warning = Color(0xFFF59E0B); // Amber

  // Neutrals (Light mode - Dark mode ready)
  static const Color background = Color(0xFFFAFAFA); // Light background
  static const Color backgroundDark = Color(0xFF0F172A); // Dark background
  static const Color surface = Color(0xFFFFFFFF); // Cards
  static const Color surfaceDark = Color(0xFF1E293B);

  // Text hierarchy
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Glassmorphism overlays
  static const Color glassFill = Color(0x33FFFFFF); // White with 20% opacity
  static const Color glassStroke = Color(0x1AFFFFFF); // Border

  // Utility colors
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shadow = Color(0x1A000000);
}
