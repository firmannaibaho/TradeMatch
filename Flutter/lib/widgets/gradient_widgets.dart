import 'package:flutter/material.dart';

/// Gradient utilities for buttons, cards, and UI elements
class AppGradients {
  /// Primary gradient (using existing orange color)
  static LinearGradient get primary => const LinearGradient(
    colors: [Color(0xFFFD7E14), Color(0xFFE8590C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Primary gradient - vertical
  static LinearGradient get primaryVertical => const LinearGradient(
    colors: [Color(0xFFFD7E14), Color(0xFFE8590C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  /// Success gradient
  static LinearGradient get success => const LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Error gradient
  static LinearGradient get error => const LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Info gradient
  static LinearGradient get info => const LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Warning gradient
  static LinearGradient get warning => const LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Subtle overlay gradient for cards
  static LinearGradient get cardOverlay => LinearGradient(
    colors: [
      Colors.black.withOpacity(0.0),
      Colors.black.withOpacity(0.3),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  /// Create custom gradient from color
  static LinearGradient fromColor(Color color, {double darkenAmount = 0.1}) {
    final hslColor = HSLColor.fromColor(color);
    final darkerColor = hslColor.withLightness(
      (hslColor.lightness - darkenAmount).clamp(0.0, 1.0),
    ).toColor();
    
    return LinearGradient(
      colors: [color, darkerColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  const AppGradients._();
}

/// Gradient button widget
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final LinearGradient? gradient;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double elevation;
  final IconData? icon;
  final bool isLoading;
  
  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradient,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius = 12,
    this.elevation = 4,
    this.icon,
    this.isLoading = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: onPressed != null ? elevation : 0,
      borderRadius: BorderRadius.circular(borderRadius),
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: onPressed != null 
              ? (gradient ?? AppGradients.primary)
              : LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: onPressed != null ? [
            BoxShadow(
              color: (gradient?.colors.first ?? const Color(0xFFFD7E14)).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient card with overlay
class GradientCard extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  
  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.borderRadius = 16,
    this.padding,
    this.margin,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final container = Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient ?? AppGradients.primary,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: padding,
        child: child,
      ),
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: container,
      );
    }
    
    return container;
  }
}
