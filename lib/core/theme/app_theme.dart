import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.softPink,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brown,
      onPrimary: AppColors.white,
      secondary: AppColors.softPink,
      onSecondary: AppColors.charcoal,
      surface: AppColors.cream,
      onSurface: AppColors.charcoal,
    );

    final body = GoogleFonts.poppinsTextTheme().apply(
      bodyColor: AppColors.charcoal,
      displayColor: AppColors.charcoal,
    );
    final headline = GoogleFonts.playfairDisplay;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: body.copyWith(
        displaySmall: headline(
            fontSize: 38, fontWeight: FontWeight.w700, color: AppColors.charcoal),
        headlineMedium: headline(
            fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.charcoal),
        headlineSmall: headline(
            fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.charcoal),
        titleLarge: headline(
            fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.charcoal),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.beige),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brown,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brown,
          side: const BorderSide(color: AppColors.brown),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.beige),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.beige),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brown, width: 1.5),
        ),
      ),
    );
  }
}
