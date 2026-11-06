import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Application-wide cream and brown theme with shared Arabic typography.
class AccessibleTheme {
  AccessibleTheme._();

  static const double minTouchTargetSize = 48;

  static ThemeData get theme {
    const scheme = ColorScheme.light(
      primary: AppColors.brown,
      onPrimary: AppColors.cream,
      primaryContainer: AppColors.cream,
      onPrimaryContainer: AppColors.brown,
      secondary: AppColors.brown,
      onSecondary: AppColors.cream,
      secondaryContainer: AppColors.cream,
      onSecondaryContainer: AppColors.brown,
      tertiary: AppColors.brown,
      onTertiary: AppColors.cream,
      tertiaryContainer: AppColors.cream,
      onTertiaryContainer: AppColors.brown,
      error: AppColors.brown,
      onError: AppColors.cream,
      errorContainer: AppColors.cream,
      onErrorContainer: AppColors.brown,
      surface: AppColors.cream,
      onSurface: AppColors.brown,
      surfaceDim: AppColors.cream,
      surfaceBright: AppColors.cream,
      surfaceContainerLowest: AppColors.cream,
      surfaceContainerLow: AppColors.cream,
      surfaceContainer: AppColors.cream,
      surfaceContainerHigh: AppColors.cream,
      surfaceContainerHighest: AppColors.cream,
      onSurfaceVariant: AppColors.brown,
      outline: AppColors.brown,
      outlineVariant: AppColors.brown,
      shadow: AppColors.brown,
      scrim: AppColors.brown,
      inverseSurface: AppColors.brown,
      onInverseSurface: AppColors.cream,
      inversePrimary: AppColors.cream,
      surfaceTint: AppColors.cream,
    );

    const headline = TextStyle(
      fontFamily: 'LyonArabic',
      fontWeight: FontWeight.w900,
      color: AppColors.brown,
      fontFamilyFallback: ['IBMPlexSansArabic'],
    );
    const body = TextStyle(
      fontFamily: 'IBMPlexSansArabic',
      color: AppColors.brown,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.cream,
      cardColor: AppColors.cream,
      dialogBackgroundColor: AppColors.cream,
      fontFamily: 'IBMPlexSansArabic',
      textTheme: TextTheme(
        displayLarge: headline.copyWith(fontSize: 48, height: 1.25),
        displayMedium: headline.copyWith(fontSize: 40, height: 1.2),
        displaySmall: headline.copyWith(fontSize: 36, height: 1.2),
        headlineLarge: headline.copyWith(fontSize: 32, height: 1.2),
        headlineMedium: headline.copyWith(fontSize: 28, height: 1.2),
        headlineSmall: headline.copyWith(fontSize: 24, height: 1.25),
        titleLarge: headline.copyWith(fontSize: 24, height: 1.25),
        titleMedium: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w500, color: AppColors.brown),
        titleSmall: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w500, color: AppColors.brown),
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: body,
        labelLarge: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w700, color: AppColors.brown),
        labelMedium: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w500, color: AppColors.brown),
        labelSmall: body,
      ),
    );

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.brown.withValues(alpha: 0.6), width: 1.5),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.brown,
        surfaceTintColor: AppColors.cream,
        titleTextStyle: headline.copyWith(fontSize: 28, height: 1.2),
      ),
      iconTheme: const IconThemeData(color: AppColors.brown),
      primaryIconTheme: const IconThemeData(color: AppColors.brown),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTargetSize * 2, minTouchTargetSize),
          backgroundColor: AppColors.brown,
          foregroundColor: AppColors.cream,
          disabledBackgroundColor: AppColors.brown,
          disabledForegroundColor: AppColors.cream,
          textStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(minTouchTargetSize * 2, minTouchTargetSize),
          backgroundColor: AppColors.brown,
          foregroundColor: AppColors.cream,
          textStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.brown, textStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brown,
          side: const BorderSide(color: AppColors.brown),
          textStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(minTouchTargetSize, minTouchTargetSize), foregroundColor: AppColors.brown),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brown,
        foregroundColor: AppColors.cream,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cream,
        labelStyle: const TextStyle(color: AppColors.brown, fontFamily: 'IBMPlexSansArabic'),
        hintStyle: TextStyle(color: AppColors.brown.withValues(alpha: 0.6), fontFamily: 'IBMPlexSansArabic'),
        prefixIconColor: AppColors.brown,
        suffixIconColor: AppColors.brown,
        border: outline,
        enabledBorder: outline,
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: AppColors.brown, width: 2)),
        errorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: AppColors.brown, width: 2)),
        focusedErrorBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: AppColors.brown, width: 2)),
        disabledBorder: outline,
        errorStyle: const TextStyle(color: AppColors.brown, fontFamily: 'IBMPlexSansArabic'),
      ),
      cardTheme: const CardThemeData(color: AppColors.cream, surfaceTintColor: AppColors.cream),
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.cream, surfaceTintColor: AppColors.cream),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.cream, surfaceTintColor: AppColors.cream),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cream,
        selectedItemColor: AppColors.brown,
        unselectedItemColor: AppColors.brown,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.cream,
        indicatorColor: AppColors.cream,
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: AppColors.brown)),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: AppColors.brown, fontFamily: 'IBMPlexSansArabic')),
      ),
      tabBarTheme: const TabBarThemeData(labelColor: AppColors.brown, unselectedLabelColor: AppColors.brown, indicatorColor: AppColors.brown),
      switchTheme: const SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(AppColors.brown),
        trackColor: WidgetStatePropertyAll(AppColors.cream),
        trackOutlineColor: WidgetStatePropertyAll(AppColors.brown),
      ),
      checkboxTheme: const CheckboxThemeData(
        fillColor: WidgetStatePropertyAll(AppColors.brown),
        checkColor: WidgetStatePropertyAll(AppColors.cream),
        side: BorderSide(color: AppColors.brown),
      ),
      radioTheme: const RadioThemeData(fillColor: WidgetStatePropertyAll(AppColors.brown)),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.brown,
        inactiveTrackColor: AppColors.cream,
        thumbColor: AppColors.brown,
        overlayColor: AppColors.cream,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brown,
        linearTrackColor: AppColors.cream,
        circularTrackColor: AppColors.cream,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.brown,
        contentTextStyle: TextStyle(color: AppColors.cream, fontFamily: 'IBMPlexSansArabic'),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.brown),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.brown, textColor: AppColors.brown),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.brown,
        selectionColor: AppColors.cream,
        selectionHandleColor: AppColors.brown,
      ),
    );
  }
}
