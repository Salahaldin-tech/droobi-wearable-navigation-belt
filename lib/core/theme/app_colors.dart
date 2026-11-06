import 'package:flutter/material.dart';

/// The application's cream and brown brand colors.
/// Brown is a MaterialColor so legacy shade references remain valid;
/// every shade is derived from the single #896E5F brand color.
abstract final class AppColors {
  static const Color cream = Color(0xFFF9F2E0);

  static const MaterialColor brown = MaterialColor(
    0xFF896E5F,
    <int, Color>{
      50: Color(0xFFF7F3F0),
      100: Color(0xFFEDE4DE),
      200: Color(0xFFDCCBC0),
      300: Color(0xFFC8AE9E),
      400: Color(0xFFA98A76),
      500: Color(0xFF896E5F),
      600: Color(0xFF755D50),
      700: Color(0xFF624D42),
      800: Color(0xFF4E3E35),
      900: Color(0xFF3B2F28),
    },
  );
}
