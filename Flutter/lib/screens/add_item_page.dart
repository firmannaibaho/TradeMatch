import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trade_match/models/category.dart';
import 'package:trade_match/models/item.dart';
import 'package:trade_match/services/supabase_service.dart';
import 'package:trade_match/services/permission_service.dart'; // Technical Implementation: Permissions
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Phase 3: Performance
import 'package:trade_match/theme.dart';
import 'package:trade_match/utils/form_validators.dart'; // Form validation utility

class AddItemPage extends StatefulWidget {
  final Item? item; // If provided, we are in Edit mode
  const AddItemPage({super.key, this.item});

  @override
  _AddItemPageState createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  // Form values
  String _title = '';
  String _description = '';
  double? _estimatedValue;
  String _condition = 'new';
  int? _categoryId;
  String _locationCity = '';
  double _locationLat = 0.0;
  double _locationLon = 0.0;
  String? _wantsDescription;
  final List<String> _imageUrls = [];
  final List<int> _wantedCategoryIds = [];

  // Image picking
  final ImagePicker _picker = ImagePicker();
  List<XFile> _imageFiles = [];

  // Edit mode flags
  bool get _isEditing => widget.item != null;
  bool _isLoading = false;

  // Categories
  List<Category> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    if (_isEditing) {
      _initializeEditMode();
    } else {
      _getCurrentLocation();
    }
  }

  void _initializeEditMode() {
    final item = widget.item!;
    _title = item.title;
    _description = item.description;
    _estimatedValue = item.estimatedValue;
    _condition = item.condition;
    _categoryId = item.categoryId;
    _locationCity = item.locationCity;
    _locationLat = item.locationLat;
    _locationLon = item.locationLon;
    _wantsDescription = item.wantsDescription;

    // Existing images
    if (item.images != null) {
      _imageUrls.addAll(item.images!.map((e) => e.imageUrl));
    }

    // Existing wants (categories)
    if (item.wants != null) {
      _wantedCategoryIds.addAll(item.wants!.map((e) => e.categoryId));
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final categoriesData = await _supabaseService.getCategories();
      final categories = categoriesData
          .map((data) => Category.fromJson(data))
          .toList();
      setState(() {
        _categories = List<Category>.from(categories);
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable GPS.'),
          ),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Please enable in settings.',
            ),
          ),
        );
      }
      return;
    }

    try {
      // Use HIGH accuracy for better location precision
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _locationLat = position.latitude;
        _locationLon = position.longitude;
        // Try multiple fields for better city name
        _locationCity =
            placemarks.first.locality ??
            placemarks.first.subAdministrativeArea ??
            placemarks.first.administrativeArea ??
            'Unknown';
      });

      print('📍 Location: $_locationCity ($_locationLat, $_locationLon)');
    } catch (e) {
      print('❌ Location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    }
  }

  Future<void> _pickImages() async {
    // PHASE 1: Request image permissions with rationale
    final hasPermission = await PermissionService.requestImagePermission(
      context,
      purpose: 'upload photos of your item',
    );

    // Graceful degradation: Exit if permission denied
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo permission required to add images'),
          ),
        );
      }
      return;
    }

    // Permission granted, proceed with image picking
    final List<XFile> selectedImages = await _picker.pickMultiImage();
    if (selectedImages.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(selectedImages);
      });
    }
  }

  Future<void> _submitForm() async {
    // Validate wanted categories before form submission
    final categoriesError = FormValidators.validateWantedCategories(
      _wantedCategoryIds,
    );
    if (categoriesError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(categoriesError), backgroundColor: Colors.red),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      try {
        // Upload NEW images and get URLs
        for (var imageFile in _imageFiles) {
          final imageUrl = await _supabaseService.uploadImage(
            File(imageFile.path),
          );
          _imageUrls.add(imageUrl);
        }

        // Build update data - only include actual columns from items table
        final itemData = {
          'title': _title,
          'description': _description,
          'category_id': _categoryId,
          'condition': _condition,
          'estimated_value': _estimatedValue,
          'currency': 'USD',
          'location_city': _locationCity,
          'location_lat': _locationLat,
          'location_lon': _locationLon,
          'wants_description': _wantsDescription,
        };

        if (_isEditing) {
          await _supabaseService.updateItem(widget.item!.id, itemData);

          // Handle new images separately if any were added
          for (final imageFile in _imageFiles) {
            await _supabaseService.uploadItemImage(
              widget.item!.id,
              File(imageFile.path),
              _imageUrls.length,
            );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Item updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          await _supabaseService.createItem(
            title: _title,
            description: _description,
            categoryId: _categoryId!,
            condition: _condition,
            estimatedValue: _estimatedValue,
            locationCity: _locationCity,
            locationLat: _locationLat,
            locationLon: _locationLon,
            wantsDescription: _wantsDescription,
            wantedCategoryIds: _wantedCategoryIds,
            imageUrls: _imageUrls,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Item created successfully')),
            );
          }
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${_isEditing ? 'update' : 'create'} item: $e',
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Item' : 'Add New Item')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveUtils.getMaxContentWidth(context),
                  ),
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      // Changed from ListView to Column to avoid layout issues
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image uploader
                        _buildImageUploader(),
                        const SizedBox(height: AppSpacing.md),
                        // Title
                        TextFormField(
                          initialValue: _title,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            hintText: '3-100 characters',
                            helperText:
                                'Brief, descriptive title for your item',
                          ),
                          maxLength: 100,
                          validator: FormValidators.validateTitle,
                          onSaved: (value) => _title = value!.trim(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Description
                        TextFormField(
                          initialValue: _description,
                          decoration: const InputDecoration(
                            labelText: 'Description *',
                            hintText: '10-2000 characters',
                            helperText: 'Detailed description of your item',
                          ),
                          maxLines: 5,
                          maxLength: 2000,
                          validator: FormValidators.validateDescription,
                          onSaved: (value) => _description = value!.trim(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Estimated Value
                        TextFormField(
                          initialValue: _estimatedValue?.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Estimated Value (USD)',
                            hintText: 'Optional - e.g., 50',
                            helperText: 'Approximate value of your item',
                            prefixText: '\$ ',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: FormValidators.validateEstimatedValue,
                          onSaved: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              _estimatedValue = double.tryParse(value.trim());
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Condition
                        _buildConditionSelector(),
                        const SizedBox(height: AppSpacing.md),
                        // Category
                        _buildCategorySelector(),
                        const SizedBox(height: AppSpacing.md),
                        // Location
                        _buildLocationPicker(),
                        const SizedBox(height: AppSpacing.md),
                        // Wants Description
                        TextFormField(
                          initialValue: _wantsDescription,
                          decoration: const InputDecoration(
                            labelText: 'What I Want (Description)',
                            hintText:
                                'Optional - Describe what you\'re looking for',
                            helperText: 'Be specific about your preferences',
                          ),
                          maxLines: 3,
                          maxLength: 500,
                          onSaved: (value) => _wantsDescription = value?.trim(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Wanted Categories
                        _buildWantedCategoriesSelector(),
                        const SizedBox(height: AppSpacing.xl),
                        const SizedBox(height: AppSpacing.lg),
                        // Submit button with gradient
                        SizedBox(
                          width: double.infinity,
                          child: GradientButton(
                            text: _isEditing ? 'Update Item' : 'Add Item',
                            onPressed: _submitForm,
                            icon: _isEditing ? Icons.check : Icons.add,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildImageUploader() {
    final totalImages = _imageUrls.length + _imageFiles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Images', style: AppTextStyles.labelBold),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: totalImages + 1,
          itemBuilder: (context, index) {
            if (index == totalImages) {
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.add_a_photo),
                ),
              );
            }

            // Display existing remote images first, then new local images
            if (index < _imageUrls.length) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _imageUrls[index],
                    fit: BoxFit.cover,
                    memCacheWidth: 600, // Medium-sized preview
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        const Center(child: Icon(Icons.broken_image)),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _imageUrls.removeAt(index);
                        });
                      },
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              final localIndex = index - _imageUrls.length;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(_imageFiles[localIndex].path),
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _imageFiles.removeAt(localIndex);
                        });
                      },
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildConditionSelector() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Condition'),
      value: _condition,
      items: ['new', 'like_new', 'good', 'fair']
          .map(
            (condition) => DropdownMenuItem(
              value: condition,
              child: Text(condition.replaceAll('_', ' ').toUpperCase()),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _condition = value!),
    );
  }

  Widget _buildCategorySelector() {
    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(labelText: 'Category'),
      value: _categoryId,
      items: _categories
          .map(
            (category) => DropdownMenuItem(
              value: category.id,
              child: Text(category.name),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _categoryId = value),
      validator: (value) => value == null ? 'Please select a category' : null,
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Location', style: AppTextStyles.labelBold),
        const SizedBox(height: AppSpacing.sm),
        Text('$_locationCity ($_locationLat, $_locationLon)'),
        TextButton.icon(
          onPressed: _getCurrentLocation,
          icon: const Icon(Icons.location_on),
          label: const Text('Update Location'),
        ),
      ],
    );
  }

  Widget _buildWantedCategoriesSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What I Want (Categories)', style: AppTextStyles.labelBold),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          children: _categories
              .map(
                (category) => FilterChip(
                  label: Text(category.name),
                  selected: _wantedCategoryIds.contains(category.id),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _wantedCategoryIds.add(category.id);
                      } else {
                        _wantedCategoryIds.remove(category.id);
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
