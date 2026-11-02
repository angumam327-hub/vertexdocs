import 'package:flutter/material.dart';

/// AppColors defines the complete premium modern pink color palette for VertexDocs.
class AppColors {
  AppColors._();

  // Primary Pink Palette
  static const Color primary = Color(0xFFF23882);
  static const Color primaryDark = Color(0xFFD61E68);
  static const Color primaryLight = Color(0xFFFF5E9E);
  static const Color primarySoft = Color(0xFFFF85B8);

  // Secondary & Accents
  static const Color secondary = Color(0xFFFFE5EF);
  static const Color secondaryLight = Color(0xFFFFF0F6);
  static const Color secondaryBorder = Color(0xFFFCD5E5);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFFFF7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAFAFC);
  static const Color cardBorder = Color(0xFFF3E4EB);

  // Typography Colors
  static const Color textPrimary = Color(0xFF1E1F2A);
  static const Color textSecondary = Color(0xFF6B6C7E);
  static const Color textTertiary = Color(0xFF9E9EA8);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textWhiteSubtle = Color(0xFFFFF0F5);

  // Status & Utility Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFE8FDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);

  // Gradients
  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFFF23882),
      Color(0xFFFF4D94),
      Color(0xFFFF6B9F),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [
      Color(0xFFF23882),
      Color(0xFFFF529A),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradient = buttonGradient;

  static const LinearGradient buttonGradientPressed = LinearGradient(
    colors: [
      Color(0xFFD61E68),
      Color(0xFFE62E78),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient softCardGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFFF3F8),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient aiBadgeGradient = LinearGradient(
    colors: [
      Color(0xFF9333EA),
      Color(0xFFF23882),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFFF23882).withValues(alpha: 0.06),
          offset: const Offset(0, 4),
          blurRadius: 16,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          offset: const Offset(0, 1),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: const Color(0xFFF23882).withValues(alpha: 0.35),
          offset: const Offset(0, 6),
          blurRadius: 16,
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get headerShadow => [
        BoxShadow(
          color: const Color(0xFFF23882).withValues(alpha: 0.25),
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: 0,
        ),
      ];
}
