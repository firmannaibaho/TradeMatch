import 'package:flutter/material.dart';
import 'package:trade_match/theme.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final double? elevation;
  final Border? border;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.width,
    this.height,
    this.elevation,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = backgroundColor ?? theme.colorScheme.surface;

    // Default shadow if not flat
    final List<BoxShadow>? boxShadow = (elevation ?? 2) > 0
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
        : null;

    Widget content = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow:
              boxShadow, // Apply shadow to wrapper to avoid clipping issues if inkwell clips
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Ink(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: border,
              ),
              child: Container(
                width: width,
                height: height,
                padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return Container(margin: margin, child: content);
  }
}
