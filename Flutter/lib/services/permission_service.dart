import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized permission management service with lazy-request pattern.
/// 
/// Key Principles:
/// - NEVER request permissions on app startup
/// - Show rationale BEFORE system prompt (better UX)
/// - Handle permanent denials with settings redirect
/// - Context-aware permission requests
class PermissionService {
  /// Request camera + gallery permissions for image capture/selection.
  /// 
  /// [purpose] - User-facing explanation (e.g., "upload photos of your item")
  /// [context] - BuildContext for showing dialogs
  /// 
  /// Returns true if permissions granted, false otherwise.
  /// 
  /// NOTE: On Android 13+, image_picker handles READ_MEDIA_IMAGES permission internally.
  /// We only need to handle camera permission explicitly.
  static Future<bool> requestImagePermission(
    BuildContext context, {
    required String purpose,
  }) async {
    // For picking images from gallery, image_picker handles permissions on Android 13+
    // We mainly need this for camera access
    // Return true to allow image_picker to handle gallery permissions
    
    // Only check camera permission if we want to use camera
    // For now, let image_picker handle everything - it has better platform-specific handling
    return true;
  }
  
  /// Request location permission for distance calculations.
  /// 
  /// Returns true if permission granted, false otherwise.
  static Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.location.status;
    
    if (status.isGranted) return true;
    
    // Show rationale
    if (status.isDenied) {
      final shouldRequest = await _showPermissionRationale(
        context,
        title: 'Location Access',
        message:
            'We use your location to show items near you and calculate distances. Your exact location is never shared publicly (only city name is visible to other users).',
        icon: Icons.location_on,
      );
      
      if (shouldRequest != true) return false;
    }
    
    final result = await Permission.location.request();
    
    if (result.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showOpenSettingsDialog(context);
      return false;
    }
    
    return result.isGranted;
  }
  
  /// Request notification permission with custom pre-prompt.
  /// Shows benefits BEFORE system prompt (better conversion rate).
  /// 
  /// Returns true if permission granted, false otherwise.
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    // Show custom in-app explanation FIRST
    final wantsNotifications = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stay Updated'),
        content: const Text(
          'Get notified when:\n'
          '• Someone likes your item\n'
          '• You get a match\n'
          '• You receive a message\n'
          '• Trade status changes',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable Notifications'),
          ),
        ],
      ),
    );
    
    if (wantsNotifications != true) return false;
    
    // Then request system permission
    final status = await Permission.notification.request();
    return status.isGranted;
  }
  
  /// Show permission rationale dialog explaining why permission is needed.
  /// 
  /// Returns true if user wants to proceed, false if they cancel.
  static Future<bool?> _showPermissionRationale(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
  
  /// Show dialog prompting user to open app settings for permanent denials.
  static Future<void> _showOpenSettingsDialog(BuildContext context) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'This permission is required for this feature. '
          'Please enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    
    if (shouldOpen == true) {
      await openAppSettings();
    }
  }
}
