/// Utility class for string formatting operations
class StringUtils {
  // Prevent instantiation
  StringUtils._();

  /// Convert snake_case, kebab-case, or space-separated strings to Title Case
  /// 
  /// Examples:
  /// - "chronic_disease_management" → "Chronic Disease Management"
  /// - "pediatric_care" → "Pediatric Care"
  /// - "home-health-care" → "Home Health Care"
  /// - "general care" → "General Care"
  static String toTitleCase(String text) {
    if (text.isEmpty) return text;

    // Replace underscores and hyphens with spaces
    final normalized = text.replaceAll('_', ' ').replaceAll('-', ' ');

    // Split by spaces and capitalize each word
    return normalized
        .split(' ')
        .where((word) => word.isNotEmpty) // Remove empty strings
        .map((word) => 
            word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  /// Format care type specifically (alias for toTitleCase for clarity)
  static String formatCareType(String careType) {
    return toTitleCase(careType);
  }

  /// Format specialization (alias for toTitleCase for clarity)
  static String formatSpecialization(String specialization) {
    return toTitleCase(specialization);
  }

  /// Truncate string to a maximum length with ellipsis
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}$ellipsis';
  }

  /// Capitalize first letter only
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Convert to sentence case (first letter capital, rest lowercase)
  static String toSentenceCase(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}