import 'package:flutter/material.dart';
import 'package:trade_match/theme/app_breakpoints.dart';

/// Responsive utility functions and widgets
class ResponsiveUtils {
  const ResponsiveUtils._();
  
  /// Get a value based on current device type
  static T responsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = context.deviceType;
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
  
  /// Get responsive grid columns based on screen size
  static int getGridColumns(BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    return responsiveValue(
      context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context, {
    EdgeInsets? mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    return responsiveValue(
      context,
      mobile: mobile ?? const EdgeInsets.all(16),
      tablet: tablet ?? const EdgeInsets.all(24),
      desktop: desktop ?? const EdgeInsets.all(32),
    );
  }
  
  /// Get responsive font size with scaling
  static double getResponsiveFontSize(
    BuildContext context,
    double baseSize, {
    double mobileScale = 1.0,
    double tabletScale = 1.1,
    double desktopScale = 1.2,
  }) {
    final scale = responsiveValue(
      context,
      mobile: mobileScale,
      tablet: tabletScale,
      desktop: desktopScale,
    );
    return baseSize * scale;
  }
  
  /// Get responsive card width
  static double getCardWidth(BuildContext context, {
    double mobilePercentage = 0.9,
    double tabletPercentage = 0.7,
    double desktopPercentage = 0.5,
  }) {
    final percentage = responsiveValue(
      context,
      mobile: mobilePercentage,
      tablet: tabletPercentage,
      desktop: desktopPercentage,
    );
    return context.screenWidth * percentage;
  }
  
  /// Get responsive max width for content
  static double getMaxContentWidth(BuildContext context) {
    return responsiveValue(
      context,
      mobile: double.infinity,
      tablet: 600,
      desktop: 800,
    );
  }
}

/// Widget that builds different layouts for different screen sizes
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;
  
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  })  : mobile = null,
        tablet = null,
        desktop = null;
  
  const ResponsiveBuilder.withWidgets({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : builder = _defaultBuilder;
  
  static Widget _defaultBuilder(BuildContext context, DeviceType deviceType) {
    throw UnimplementedError('Use ResponsiveBuilder.withWidgets constructor');
  }
  
  @override
  Widget build(BuildContext context) {
    final deviceType = context.deviceType;
    
    if (mobile != null || tablet != null || desktop != null) {
      // Use specific widgets based on device type
      switch (deviceType) {
        case DeviceType.mobile:
          return mobile!;
        case DeviceType.tablet:
          return tablet ?? mobile!;
        case DeviceType.desktop:
          return desktop ?? tablet ?? mobile!;
      }
    }
    
    return builder(context, deviceType);
  }
}

/// Responsive grid widget that automatically adjusts columns
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;
  
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 2,
    this.tabletColumns = 3,
    this.desktopColumns = 4,
    this.spacing = 12,
    this.runSpacing = 12,
    this.childAspectRatio = 1.0,
  });
  
  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveUtils.getGridColumns(
      context,
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );
    
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: runSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
