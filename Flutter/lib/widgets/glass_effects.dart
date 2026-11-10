import 'package:flutter/material.dart';
import 'dart:ui';

/// Glassmorphism effect utilities and widgets
class GlassEffect {
  /// Creates a frosted glass backdrop filter
  static ImageFilter createBlur({double sigma = 10.0}) {
    return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  }
  
  /// Standard glassmorphism decoration
  static BoxDecoration glassDecoration({
    Color? color,
    double borderRadius = 16,
    double blurSigma = 10,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1.5,
      ),
    );
  }
  
  const GlassEffect._();
}

/// Glassmorphism container widget
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? color;
  final Border? border;
  
  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.blurSigma = 10,
    this.color,
    this.border,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: GlassEffect.createBlur(sigma: blurSigma),
          child: Container(
            padding: padding,
            decoration: GlassEffect.glassDecoration(
              color: color,
              borderRadius: borderRadius,
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism card widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  
  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final container = GlassContainer(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      child: child,
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

/// Glassmorphism app bar
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;
  final double blurSigma;
  
  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.height = 56,
    this.blurSigma = 10,
  });
  
  @override
  Size get preferredSize => Size.fromHeight(height);
  
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: GlassEffect.createBlur(sigma: blurSigma),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (leading != null) leading! else const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
