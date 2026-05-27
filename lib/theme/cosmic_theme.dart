import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cosmic Harmony color palette and typography for BHR1GU.
class CosmicColors {
  CosmicColors._();

  // Primary palette.
  static const Color midnightBlue = Color(0xFF0D0A20);
  static const Color starGold = Color(0xFF876118);
  static const Color agedParchment = Color(0xFFC3A372);
  static const Color dustyPlum = Color(0xFF292B3A);
  static const Color forestMoss = Color(0xFF242D32);

  // Accent palette.
  static const Color celestialSilver = Color(0xFF444D56);
  static const Color starlightLilac = Color(0xFF383F4F);
  static const Color oxidizedBronze = Color(0xFF3D5728);

  // Text and utility colors.
  static const Color bodyText = Color(0xFFF0ECF8);
  static const Color mutedText = Color(0xFF8A8FA0);
  static const Color softGold = Color(0xFFE0C48F);
  static const Color brightParchment = Color(0xFFFFD88A);
}

class CosmicTypography {
  CosmicTypography._();

  static const String amandineFamily = 'Amandine';
  static const List<String> serifFallback = [
    'Cormorant Garamond',
    'Cinzel',
    'Georgia',
    'Times New Roman',
    'serif',
  ];

  static TextTheme textTheme(TextTheme base) {
    return GoogleFonts.cormorantGaramondTextTheme(base).apply(
      fontFamily: amandineFamily,
      fontFamilyFallback: serifFallback,
      bodyColor: CosmicColors.bodyText,
      displayColor: CosmicColors.agedParchment,
    );
  }
}

class CosmicTheme {
  CosmicTheme._();

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = CosmicTypography.textTheme(base.textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CosmicColors.midnightBlue,
      fontFamily: CosmicTypography.amandineFamily,
      fontFamilyFallback: CosmicTypography.serifFallback,
      textTheme: textTheme,
      primaryTextTheme: CosmicTypography.textTheme(base.primaryTextTheme),
      colorScheme: const ColorScheme.dark(
        primary: CosmicColors.agedParchment,
        onPrimary: CosmicColors.midnightBlue,
        secondary: CosmicColors.starGold,
        onSecondary: CosmicColors.midnightBlue,
        tertiary: CosmicColors.oxidizedBronze,
        surface: CosmicColors.dustyPlum,
        onSurface: CosmicColors.bodyText,
        error: Color(0xFFFFB4AB),
        onError: CosmicColors.midnightBlue,
      ),
      cardTheme: CardThemeData(
        color: CosmicColors.dustyPlum,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(
            color: CosmicColors.celestialSilver,
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CosmicColors.midnightBlue,
        foregroundColor: CosmicColors.agedParchment,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: CosmicColors.agedParchment,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
        iconTheme: const IconThemeData(color: CosmicColors.agedParchment),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CosmicColors.dustyPlum,
        selectedItemColor: CosmicColors.starGold,
        unselectedItemColor: CosmicColors.starlightLilac,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CosmicColors.dustyPlum,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: CosmicColors.agedParchment,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: CosmicColors.bodyText,
          height: 1.4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: CosmicColors.celestialSilver),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CosmicColors.celestialSilver,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CosmicColors.dustyPlum,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: CosmicColors.mutedText,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CosmicColors.celestialSilver),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CosmicColors.celestialSilver),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: CosmicColors.agedParchment,
            width: 1.4,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CosmicColors.agedParchment,
          foregroundColor: CosmicColors.midnightBlue,
          disabledBackgroundColor: CosmicColors.celestialSilver,
          disabledForegroundColor: CosmicColors.mutedText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CosmicColors.agedParchment,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CosmicColors.dustyPlum,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: CosmicColors.bodyText,
        ),
        actionTextColor: CosmicColors.agedParchment,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CosmicColors.starGold,
        linearTrackColor: CosmicColors.starlightLilac,
        circularTrackColor: CosmicColors.starlightLilac,
      ),
    );
  }
}
