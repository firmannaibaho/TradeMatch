/// Form validation utilities for TradeMatch
/// Provides reusable validation functions for all input forms
class FormValidators {
  // ============================================================================
  // TEXT FIELD VALIDATORS
  // ============================================================================

  /// Validates item title
  /// Rules: 3-100 characters, allows letters, numbers, and basic punctuation
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < 3) {
      return 'Title must be at least 3 characters';
    }

    if (trimmed.length > 100) {
      return 'Title must not exceed 100 characters';
    }

    // Check for excessive special characters (allow basic punctuation)
    // Allows: letters, numbers, spaces, hyphens, periods, commas, exclamation, question marks, parentheses, brackets
    final invalidCharsRegex = RegExp(r'[^\w\s\-.,!?()\[\]]');
    if (invalidCharsRegex.hasMatch(trimmed)) {
      return 'Title contains invalid special characters';
    }

    return null;
  }

  /// Validates item description
  /// Rules: 10-2000 characters
  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < 10) {
      return 'Description must be at least 10 characters';
    }

    if (trimmed.length > 2000) {
      return 'Description must not exceed 2000 characters';
    }

    return null;
  }

  /// Validates estimated value
  /// Rules: Must be a positive number
  static String? validateEstimatedValue(String? value) {
    // Optional field
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }

    if (number <= 0) {
      return 'Value must be greater than 0';
    }

    if (number > 1000000000) {
      return 'Value seems unrealistic (max 1 billion)';
    }

    return null;
  }

  // ============================================================================
  // AUTHENTICATION VALIDATORS
  // ============================================================================

  /// Validates email address
  /// Rules: Must match standard email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validates password
  /// Rules: Min 8 characters, must contain at least one letter and one number
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Check for at least one letter
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Password must contain at least one letter';
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Validates user name
  /// Rules: 2-50 characters, letters and spaces only
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (trimmed.length > 50) {
      return 'Name must not exceed 50 characters';
    }

    // Allow letters, spaces, hyphens, and apostrophes (for names like O'Brien, Mary-Jane)
    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }

    return null;
  }

  // ============================================================================
  // LOCATION VALIDATORS
  // ============================================================================

  /// Validates GPS coordinates
  /// Rules: Latitude -90 to 90, Longitude -180 to 180
  static String? validateCoordinates(double? lat, double? lon) {
    if (lat == null || lon == null) {
      return 'Location coordinates are required';
    }

    if (lat < -90 || lat > 90) {
      return 'Invalid latitude (must be between -90 and 90)';
    }

    if (lon < -180 || lon > 180) {
      return 'Invalid longitude (must be between -180 and 180)';
    }

    return null;
  }

  /// Validates location name
  /// Rules: 1-255 characters
  static String? validateLocationName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Location name is required';
    }

    final trimmed = value.trim();

    if (trimmed.length > 255) {
      return 'Location name must not exceed 255 characters';
    }

    return null;
  }

  /// Validates location address
  /// Rules: Optional, max 500 characters
  static String? validateLocationAddress(String? value) {
    // Optional field
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    if (value.trim().length > 500) {
      return 'Address must not exceed 500 characters';
    }

    return null;
  }

  // ============================================================================
  // MESSAGE VALIDATORS
  // ============================================================================

  /// Validates chat message
  /// Rules: 1-1000 characters
  static String? validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Message cannot be empty';
    }

    final trimmed = value.trim();

    if (trimmed.length > 1000) {
      return 'Message must not exceed 1000 characters';
    }

    return null;
  }

  // ============================================================================
  // COLLECTION VALIDATORS
  // ============================================================================

  /// Validates wanted categories selection
  /// Rules: At least 1 category must be selected
  static String? validateWantedCategories(List<int> categoryIds) {
    if (categoryIds.isEmpty) {
      return 'Please select at least one category you want';
    }

    if (categoryIds.length > 10) {
      return 'You can select up to 10 categories';
    }

    return null;
  }

  /// Validates image count
  /// Rules: Optional (0-10 images allowed)
  /// Note: Per user request, images are now optional
  static String? validateImageCount(int count) {
    if (count > 10) {
      return 'You can upload up to 10 images';
    }

    // Images are optional, no minimum requirement
    return null;
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Checks if a required field is filled
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates a dropdown selection is made
  static String? validateDropdownSelection<T>(T? value, String fieldName) {
    if (value == null) {
      return 'Please select a $fieldName';
    }
    return null;
  }
}
