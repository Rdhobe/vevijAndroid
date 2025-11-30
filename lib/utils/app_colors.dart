import 'package:flutter/material.dart';

/// App color scheme with vibrant colors and gradients
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);

  // Secondary colors
  static const Color secondary = Color(0xFFEC4899); // Pink
  static const Color secondaryDark = Color(0xFFDB2777);
  static const Color secondaryLight = Color(0xFFF472B6);

  // Accent colors
  static const Color accent = Color(0xFF8B5CF6); // Purple
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Priority colors
  static const Color priorityLow = Color(0xFF34D399);
  static const Color priorityMedium = Color(0xFF60A5FA);
  static const Color priorityHigh = Color(0xFFFBBF24);
  static const Color priorityUrgent = Color(0xFFF87171);
  static const Color priorityCritical = Color(0xFFDC2626);

  // Task status colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusInProgress = Color(0xFF3B82F6);
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusCancelled = Color(0xFFEF4444);

  // Neutral colors (Light mode)
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color onBackground = Color(0xFF111827);
  static const Color onSurface = Color(0xFF374151);
  static const Color divider = Color(0xFFE5E7EB);

  // Dark mode colors
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color onBackgroundDark = Color(0xFFF1F5F9);
  static const Color onSurfaceDark = Color(0xFFCBD5E1);
  static const Color dividerDark = Color(0xFF475569);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Priority gradients
  static LinearGradient getPriorityGradient(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF6EE7B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'medium':
        return const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF93C5FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'high':
        return const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFFCD34D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'urgent':
        return const LinearGradient(
          colors: [Color(0xFFF87171), Color(0xFFFCA5A5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'critical':
        return const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return primaryGradient;
    }
  }

  // Glassmorphic overlay
  static Color glassmorphicOverlay(bool isDark) {
    return isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.7);
  }

  static Color glassmorphicBorder(bool isDark) {
    return isDark
        ? Colors.white.withOpacity(0.2)
        : Colors.white.withOpacity(0.3);
  }
}
