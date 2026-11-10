import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/services/permission_service.dart';
import 'package:trade_match/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const EditProfilePage({super.key, this.userData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();

  // Current photos from database
  String? _profilePictureUrl;
  String? _backgroundPictureUrl;

  // New photos selected by user (not yet uploaded)
  File? _newProfilePicture;
  File? _newBackgroundPicture;

  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _profilePictureUrl = widget.userData?['profile_picture_url'];
    _backgroundPictureUrl = widget.userData?['background_picture_url'];
  }

  Future<void> _pickProfilePicture() async {
    final hasPermission = await PermissionService.requestImagePermission(
      context,
      purpose: 'change your profile picture',
    );

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo permission required')),
        );
      }
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _newProfilePicture = File(image.path);
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickBackgroundPicture() async {
    final hasPermission = await PermissionService.requestImagePermission(
      context,
      purpose: 'change your background photo',
    );

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo permission required')),
        );
      }
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _newBackgroundPicture = File(image.path);
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload profile picture if changed
      if (_newProfilePicture != null) {
        await _supabaseService.uploadProfilePicture(_newProfilePicture!);
      }

      // Upload background picture if changed
      if (_newBackgroundPicture != null) {
        await _supabaseService.uploadBackgroundPicture(_newBackgroundPicture!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _hasChanges
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Background Photo Section
            _buildBackgroundPhotoSection(),

            const SizedBox(height: AppSpacing.lg),

            // Profile Picture Section
            _buildProfilePictureSection(),

            const SizedBox(height: AppSpacing.xl),

            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tap on the photos above to change them.\nYour photos will be visible to other users.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Background Photo', style: AppTextStyles.labelBold),
        ),
        GestureDetector(
          onTap: _pickBackgroundPicture,
          child: Container(
            height: 180,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show new image if selected, else existing URL, else placeholder
                  if (_newBackgroundPicture != null)
                    Image.file(_newBackgroundPicture!, fit: BoxFit.cover)
                  else if (_backgroundPictureUrl != null &&
                      _backgroundPictureUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: _backgroundPictureUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildPlaceholder(Icons.panorama),
                    )
                  else
                    _buildPlaceholder(Icons.panorama),

                  // Edit overlay
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Tap to change',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        Text('Profile Picture', style: AppTextStyles.labelBold),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: _pickProfilePicture,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  border: Border.all(color: AppColors.divider, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _newProfilePicture != null
                      ? Image.file(
                          _newProfilePicture!,
                          fit: BoxFit.cover,
                          width: 140,
                          height: 140,
                        )
                      : (_profilePictureUrl != null &&
                            _profilePictureUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: _profilePictureUrl!,
                          fit: BoxFit.cover,
                          width: 140,
                          height: 140,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildCirclePlaceholder(),
                        )
                      : _buildCirclePlaceholder(),
                ),
              ),
              // Camera icon overlay
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(IconData icon) {
    return Container(
      color: Colors.grey[200],
      child: Center(child: Icon(icon, size: 48, color: Colors.grey[400])),
    );
  }

  Widget _buildCirclePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.person, size: 64, color: Colors.grey[400]),
      ),
    );
  }
}
