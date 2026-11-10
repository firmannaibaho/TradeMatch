import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trade_match/theme/app_colors.dart';

// Export all design system classes for easy access
export 'theme/app_colors.dart';
export 'theme/app_text_styles.dart';
export 'theme/app_spacing.dart';
export 'theme/app_radius.dart';
export 'theme/app_elevation.dart';
export 'theme/app_breakpoints.dart';
export 'utils/responsive_utils.dart';
export 'utils/animation_utils.dart';
export 'widgets/glass_effects.dart';
export 'widgets/gradient_widgets.dart';
export 'widgets/modern_button.dart';
export 'widgets/modern_card.dart';

// AppColors class removed to avoid conflict with 'theme/app_colors.dart'

class AppTheme {
  static ThemeData lightTheme() {
    // Start from a generated color scheme but enforce the exact primary color
    final generated = ColorScheme.fromSeed(seedColor: AppColors.primary);
    final colorScheme = generated.copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
    );

    return ThemeData(
      colorScheme: colorScheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: Colors.grey[50],
      // Use Google Fonts Inter for the entire app (falls back if needed)
      textTheme: GoogleFonts.interTextTheme(),
      // Buttons: show a subtle tint and ripple on interaction without darkening
      // overlayColor is resolved per state so pressed/hover get a light tint of primary
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(AppColors.primary),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed))
              return AppColors.primary.withOpacity(0.12);
            if (states.contains(WidgetState.hovered))
              return AppColors.primary.withOpacity(0.08);
            if (states.contains(WidgetState.focused))
              return AppColors.primary.withOpacity(0.06);
            return null;
          }),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppColors.primary),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed))
              return AppColors.primary.withOpacity(0.12);
            if (states.contains(WidgetState.hovered))
              return AppColors.primary.withOpacity(0.08);
            if (states.contains(WidgetState.focused))
              return AppColors.primary.withOpacity(0.06);
            return null;
          }),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(AppColors.primary),
          side: WidgetStateProperty.all(BorderSide(color: AppColors.primary)),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed))
              return AppColors.primary.withOpacity(0.12);
            if (states.contains(WidgetState.hovered))
              return AppColors.primary.withOpacity(0.08);
            if (states.contains(WidgetState.focused))
              return AppColors.primary.withOpacity(0.06);
            return null;
          }),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        splashColor: AppColors.primary.withOpacity(0.12),
        hoverColor: AppColors.primary.withOpacity(0.08),
        focusColor: AppColors.primary.withOpacity(0.06),
      ),
    );
  }
}
