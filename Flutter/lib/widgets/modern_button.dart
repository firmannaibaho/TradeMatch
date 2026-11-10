import 'package:flutter/material.dart';
import 'package:trade_match/theme.dart';

enum ModernButtonStyle { primary, secondary, outline, text }

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ModernButtonStyle style;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;

  const ModernButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style = ModernButtonStyle.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 56,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // Base decoration
    final borderRadius = BorderRadius.circular(AppRadius.button);

    // Style logic
    Color? backgroundColor;
    Color foregroundColor;
    Border?
    border; // Use Border instead of BorderSide for Container decoration compatibility if manually drawing,
    // but for standard buttons, we configure ButtonStyle.

    switch (style) {
      case ModernButtonStyle.primary:
        backgroundColor = AppColors.primary;
        foregroundColor = Colors.white;
        break;
      case ModernButtonStyle.secondary:
        backgroundColor = AppColors.primary.withOpacity(0.1);
        foregroundColor = AppColors.primary;
        break;
      case ModernButtonStyle.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.primary;
        border = Border.all(color: AppColors.primary, width: 2);
        break;
      case ModernButtonStyle.text:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.textSecondary;
        break;
    }

    // If it's a primary button, we might want a gradient (optional)
    // For now, simple consistent style.

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 20, color: foregroundColor),
          const SizedBox(width: 8),
        ],
        if (!isLoading)
          Text(
            text,
            style: AppTextStyles.labelBold.copyWith(
              color: foregroundColor,
              fontSize: 16,
            ),
          ),
      ],
    );

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: borderRadius,
          child: Ink(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius,
              border: border,
            ),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
