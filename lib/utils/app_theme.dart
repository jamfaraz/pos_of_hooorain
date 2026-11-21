import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';

abstract final class AppTheme {
  static const cardRadius = 14.0;
  static const buttonRadius = 10.0;
  static const drawerRadius = 18.0;

  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt,
    text: AppColors.text,
    subtext: AppColors.subtext,
    line: AppColors.line,
    primary: AppColors.primary,
    primarySoft: AppColors.primarySoft,
    accent: AppColors.accent,
    shadow: const Color(0xFF0F2A20).withValues(alpha: 0.07),
  );

  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceAlt: AppColors.darkSurfaceAlt,
    text: AppColors.darkText,
    subtext: const Color(0xFF93A69D),
    line: AppColors.darkLine,
    primary: AppColors.darkPrimary,
    primarySoft: const Color(0xFF16322A),
    accent: AppColors.darkAccent,
    shadow: Colors.black.withValues(alpha: 0.35),
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color text,
    required Color subtext,
    required Color line,
    required Color primary,
    required Color primarySoft,
    required Color accent,
    required Color shadow,
  }) {
    final isDark = brightness == Brightness.dark;
    final onPrimary = isDark ? AppColors.darkBackground : Colors.white;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: accent,
          surface: surface,
          error: AppColors.bad,
          onSurface: text,
          outline: line,
          outlineVariant: line,
          surfaceTint: Colors.transparent,
        );

    final base = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness, useMaterial3: true).textTheme,
    ).apply(bodyColor: text, displayColor: text);

    // Slightly tighter, heavier headings = a more premium look.
    final textTheme = base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(color: subtext, height: 1.4),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );

    RoundedRectangleBorder rounded(double r, {BorderSide? side}) =>
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: side ?? BorderSide.none,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryTextTheme: textTheme,
      textTheme: textTheme,
      dividerColor: line,
      cardColor: surface,
      splashFactory: InkRipple.splashFactory,
      hoverColor: primary.withValues(alpha: 0.05),
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: text.withValues(alpha: 0.82), size: 20),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 3,
        shadowColor: shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: rounded(cardRadius, side: BorderSide(color: line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceAlt : surface,
        hintStyle: TextStyle(color: subtext.withValues(alpha: 0.75)),
        labelStyle: TextStyle(color: subtext),
        floatingLabelStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: AppColors.bad.withValues(alpha: 0.8)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.bad, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: rounded(buttonRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: rounded(buttonRadius),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: rounded(buttonRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: line),
          shape: rounded(buttonRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: text,
          backgroundColor: surface,
          side: BorderSide(color: line),
          shape: rounded(buttonRadius + 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primarySoft,
        secondarySelectedColor: primarySoft,
        labelStyle: TextStyle(
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        side: BorderSide(color: line),
        shape: rounded(10),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: subtext,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: primary,
        dividerColor: line,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: shadow,
        shape: rounded(drawerRadius, side: BorderSide(color: line)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: shadow,
        shape: rounded(12, side: BorderSide(color: line)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceAlt : const Color(0xFF14201B),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: rounded(12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? surfaceAlt : const Color(0xFF14201B),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      listTileTheme: ListTileThemeData(iconColor: subtext, shape: rounded(10)),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(surfaceAlt),
        headingTextStyle: TextStyle(
          color: subtext,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.4,
        ),
        dividerThickness: 1,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: primary,
        headerForegroundColor: onPrimary,
        shape: rounded(drawerRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: line,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(subtext.withValues(alpha: 0.3)),
        radius: const Radius.circular(10),
        thickness: const WidgetStatePropertyAll(6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onPrimary : subtext,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
