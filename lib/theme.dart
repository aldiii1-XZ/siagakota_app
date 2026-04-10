import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom theme untuk SiagaKota app
class AppTheme {
  // ============ COLOR PALETTE ============
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);
  
  static const Color secondary = Color(0xFF00BCD4);
  static const Color secondaryDark = Color(0xFF0097A7);
  
  static const Color accent = Color(0xFFFF6F00);
  static const Color accentLight = Color(0xFFFFB74D);
  
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF2196F3);
  
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFEEEEEE);
  static const Color neutral300 = Color(0xFFE0E0E0);
  static const Color neutral400 = Color(0xFFBDBDBD);
  static const Color neutral500 = Color(0xFF9E9E9E);
  static const Color neutral600 = Color(0xFF757575);
  static const Color neutral700 = Color(0xFF616161);
  static const Color neutral800 = Color(0xFF424242);
  static const Color neutral900 = Color(0xFF212121);

  // ============ SPACING SYSTEM ============
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // ============ BORDER RADIUS ============
  static const double radiusSm = 6;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // ============ ELEVATION & SHADOWS ============
  static const double elevationSm = 1;
  static const double elevationMd = 4;
  static const double elevationLg = 8;

  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  // ============ THEME DATA ============
  static ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // PRIMARY COLORS
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryLight.withAlpha((0.12 * 255).round()),
        onPrimaryContainer: primaryDark,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: accent,
        error: error,
        onError: Colors.white,
        surface: neutral50,
        onSurface: neutral900,
        outline: neutral300,
        outlineVariant: neutral200,
      ),

      // TYPOGRAPHY
      textTheme: _buildTextTheme(),

      // SCAFFOLD & BACKGROUND
      scaffoldBackgroundColor: neutral50,

      // APP BAR
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: neutral900,
        surfaceTintColor: transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: neutral900,
        ),
      ),

      // BUTTONS
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: lg,
            vertical: md,
          ),
          minimumSize: const Size(0, 44),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          elevation: 0,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: lg,
            vertical: md,
          ),
          minimumSize: const Size(0, 44),
          backgroundColor: Colors.white,
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          elevation: 0,
          side: const BorderSide(color: neutral200),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: lg,
            vertical: md,
          ),
          minimumSize: const Size(0, 44),
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: neutral300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),

      // INPUT & FORMS
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: lg,
          vertical: md,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: neutral300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: neutral300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: neutral600,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: neutral400,
        ),
      ),

      // CARDS
      cardTheme: CardThemeData(
        elevation: elevationMd,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        color: Colors.white,
        surfaceTintColor: transparent,
        shadowColor: const Color(0x1A000000),
      ),

      // CHIP
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(
          horizontal: md,
          vertical: sm,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: neutral100,
        selectedColor: primary.withAlpha((0.12 * 255).round()),
        disabledColor: neutral200,
        deleteIconColor: neutral600,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        side: const BorderSide(color: neutral300),
      ),

      // DIALOG
      dialogTheme: DialogThemeData(
        elevation: elevationLg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: transparent,
      ),

      // BOTTOM SHEET
      bottomSheetTheme: BottomSheetThemeData(
        elevation: elevationLg,
        backgroundColor: Colors.white,
        surfaceTintColor: transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radiusXl),
            topRight: Radius.circular(radiusXl),
          ),
        ),
      ),

      // TAB BAR
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: neutral600,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primary, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 0),
        ),
      ),

      // SLIDER
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: neutral300,
        thumbColor: primary,
        overlayColor: primary.withAlpha((0.16 * 255).round()),
        valueIndicatorColor: primary,
      ),

      // SNACKBAR
      snackBarTheme: SnackBarThemeData(
        elevation: elevationLg,
        backgroundColor: neutral800,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      // FLOATING ACTION BUTTON
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: elevationMd,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      // ICON
      iconTheme: const IconThemeData(
        color: neutral700,
        size: 24,
      ),
    );
  }

  // ============ TEXT THEME ============
  static TextTheme _buildTextTheme() {
    return TextTheme(
      // Display
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: neutral900,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: neutral900,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.33,
        color: neutral900,
      ),
      
      // Headline
      headlineLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.36,
        color: neutral900,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: neutral900,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.44,
        color: neutral900,
      ),
      
      // Title
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: neutral900,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.57,
        color: neutral900,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.66,
        color: neutral900,
      ),
      
      // Body
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: neutral900,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.57,
        color: neutral700,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.66,
        color: neutral600,
      ),
      
      // Label
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.57,
        color: neutral900,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.66,
        color: neutral700,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.82,
        color: neutral600,
        letterSpacing: 0.5,
      ),
    );
  }

  // ============ UTILITY ============
  static const Color transparent = Color(0x00000000);
}

/// Helper untuk severity colors
Color severityColor(double severity) {
  if (severity >= 4.5) return AppTheme.error;
  if (severity >= 3.5) return AppTheme.accent;
  if (severity >= 2.5) return AppTheme.warning;
  return AppTheme.success;
}
