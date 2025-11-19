import 'package:flutter/material.dart';
class AppTheme {
  static const primaryPurple = Color(0xFF7C3AED);
  static const deepPurple = Color(0xFF6D28D9);
  static const lightPurple = Color(0xFF9F7AEA);
  static const palePurple = Color(0xFFF3E8FF);
  static const accentPink = Color(0xFFEC4899);
  static const darkBg = Color(0xFF1E1B4B);
  static const cardBg = Color(0xFFFFFFFF);
  
  static ThemeData get theme => ThemeData(
    primaryColor: primaryPurple,
    scaffoldBackgroundColor: Color(0xFFF9FAFB),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryPurple,
      primary: primaryPurple,
      secondary: accentPink,
    ),
  );
}
