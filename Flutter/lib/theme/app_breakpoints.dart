import 'package:flutter/material.dart';

/// Screen size breakpoints for responsive design
class AppBreakpoints {
  // Breakpoint values (in logical pixels)
  static const double mobile = 600;    // 0-600: Mobile phones
  static const double tablet = 1024;   // 600-1024: Tablets
  static const double desktop = 1200;  // 1024+: Desktop/large tablets
  
  const AppBreakpoints._();
}

/// Device type based on screen width
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// Extension on BuildContext for responsive helpers
extension ResponsiveContext on BuildContext {
  /// Get current device type based on screen width
  DeviceType get deviceType {
    final width = MediaQuery.of(this).size.width;
    if (width < AppBreakpoints.mobile) {
      return DeviceType.mobile;
    } else if (width < AppBreakpoints.tablet) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  /// Check if current device is mobile
  bool get isMobile => deviceType == DeviceType.mobile;
  
  /// Check if current device is tablet
  bool get isTablet => deviceType == DeviceType.tablet;
  
  /// Check if current device is desktop
  bool get isDesktop => deviceType == DeviceType.desktop;
  
  /// Get screen width
  double get screenWidth => MediaQuery.of(this).size.width;
  
  /// Get screen height
  double get screenHeight => MediaQuery.of(this).size.height;
  
  /// Check if device is in landscape orientation
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
  
  /// Check if device is in portrait orientation
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;
}
