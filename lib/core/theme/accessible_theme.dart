import 'package:flutter/material.dart';

/// Shared accessible theme for Droobi.
///
/// Per Stage 2's accessibility architecture: large text, sufficient
/// contrast, and a minimum interactive touch target enforced at the
/// theme level so individual screens don't need to remember it.
class AccessibleTheme {
  AccessibleTheme._();

  static const double minTouchTargetSize = 48;

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.light,
    );

    return base.copyWith(
      textTheme: base.textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            minTouchTargetSize * 2,
            minTouchTargetSize,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            minTouchTargetSize,
            minTouchTargetSize,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}
