import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF1565C0); // deep blue — lab feel
  static const Color secondary = Color(0xFF00897B); // teal
  static const Color warning = Color(0xFFF57C00); // amber
  static const Color danger = Color(0xFFC62828); // red
  static const Color success = Color(0xFF2E7D32); // green
  static const Color surface = Color(0xFFF5F5F5);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          secondary: secondary,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          secondary: secondary,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      );
}
