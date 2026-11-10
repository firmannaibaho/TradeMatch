import 'package:flutter/material.dart';
import 'package:trade_match/theme.dart';

class SearchFilterPage extends StatefulWidget {
  const SearchFilterPage({super.key});

  @override
  State<SearchFilterPage> createState() => _SearchFilterPageState();
}

class _SearchFilterPageState extends State<SearchFilterPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  RangeValues _priceRange = const RangeValues(0, 10000000);
  double _maxDistance = 50;
  final List<String> _selectedConditions = [];

  final List<String> _categories = [
    'All',
    'Electronics',
    'Fashion',
    'Books',
    'Sports',
    'Home & Living',
    'Gaming',
    'Others',
  ];

  final List<String> _conditions = ['New', 'Like New', 'Good', 'Fair', 'Poor'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          TextButton(onPressed: _resetFilters, child: const Text('Reset')),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),

          // Filters
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories
                  const Text('Category', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(category),
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            selectedColor: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.2),
                            checkmarkColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Price Range
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price Range', style: AppTextStyles.heading3),
                      Text(
                        'IDR ${_priceRange.start.round()} - ${_priceRange.end.round()}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 10000000,
                    divisions: 100,
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    onChanged: (values) {
                      setState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Distance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Maximum Distance',
                        style: AppTextStyles.heading3,
                      ),
                      Text(
                        '${_maxDistance.round()} km',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _maxDistance,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: Theme.of(context).colorScheme.primary,
                    inactiveColor: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    onChanged: (value) {
                      setState(() {
                        _maxDistance = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Condition
                  const Text('Condition', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _conditions.map((condition) {
                      final isSelected = _selectedConditions.contains(
                        condition,
                      );
                      return FilterChip(
                        selected: isSelected,
                        label: Text(condition),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedConditions.add(condition);
                            } else {
                              _selectedConditions.remove(condition);
                            }
                          });
                        },
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Apply Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              // Changed to Column to accommodate SizedBox and GradientButton
              children: [
                const SizedBox(
                  height: AppSpacing.xl,
                ), // Added SizedBox as per instruction
                // Apply Filters Button
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: 'Apply Filters',
                    onPressed: () =>
                        Navigator.pop(context), // Changed onPressed and text
                    icon: Icons.check,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = 'All';
      _priceRange = const RangeValues(0, 10000000);
      _maxDistance = 50;
      _selectedConditions.clear();
    });
  }

  void _applyFilters() {
    // TODO: Apply filters and navigate back with results
    Navigator.pop(context);
  }
}
