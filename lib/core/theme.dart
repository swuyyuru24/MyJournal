import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// MyJournal palette — warm, earthy, growth-oriented.
/// Sage / cream / terracotta with soft yellow accents.
class JournalPalette {
  static const sage = Color(0xFF6F8B7B);
  static const sageDark = Color(0xFF3F574A);
  static const sageLight = Color(0xFFD8E3DC);
  static const cream = Color(0xFFFAF6EE);
  static const creamWarm = Color(0xFFF1EBDB);
  static const terracotta = Color(0xFFD08568);
  static const terracottaSoft = Color(0xFFF3D8C7);
  static const honey = Color(0xFFE8B14E);
  static const ink = Color(0xFF2D2A26);
  static const inkSoft = Color(0xFF6B655C);
}

ThemeData buildJournalTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: JournalPalette.sage,
      primary: JournalPalette.sageDark,
      onPrimary: JournalPalette.cream,
      secondary: JournalPalette.terracotta,
      onSecondary: Colors.white,
      tertiary: JournalPalette.honey,
      surface: JournalPalette.cream,
      onSurface: JournalPalette.ink,
      surfaceContainerHighest: JournalPalette.creamWarm,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: JournalPalette.cream,
  );

  final display = GoogleFonts.fraunces;
  final body = GoogleFonts.manrope;

  final textTheme = base.textTheme.copyWith(
    displayLarge: display(
      fontSize: 48,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: JournalPalette.ink,
    ),
    displayMedium: display(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: JournalPalette.ink,
    ),
    headlineLarge: display(
      fontSize: 30,
      fontWeight: FontWeight.w600,
      color: JournalPalette.ink,
    ),
    headlineMedium: display(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: JournalPalette.ink,
    ),
    headlineSmall: display(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: JournalPalette.ink,
    ),
    titleLarge: display(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: JournalPalette.ink,
    ),
    titleMedium: body(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: JournalPalette.ink,
    ),
    titleSmall: body(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: JournalPalette.inkSoft,
      letterSpacing: 0.5,
    ),
    bodyLarge: body(fontSize: 16, color: JournalPalette.ink, height: 1.5),
    bodyMedium: body(fontSize: 14, color: JournalPalette.ink, height: 1.5),
    bodySmall: body(fontSize: 12, color: JournalPalette.inkSoft, height: 1.4),
    labelLarge: body(fontSize: 15, fontWeight: FontWeight.w600),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: JournalPalette.cream,
      foregroundColor: JournalPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: display(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: JournalPalette.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: JournalPalette.sageLight, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: JournalPalette.sageLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: JournalPalette.sageLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: JournalPalette.sage, width: 2),
      ),
      labelStyle: body(color: JournalPalette.inkSoft),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: JournalPalette.sageDark,
        foregroundColor: JournalPalette.cream,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: body(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: JournalPalette.terracotta,
      foregroundColor: Colors.white,
      elevation: 2,
      extendedTextStyle: body(fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: JournalPalette.sageLight,
      labelStyle: body(color: JournalPalette.sageDark),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: JournalPalette.cream,
      indicatorColor: JournalPalette.sageLight,
      labelTextStyle: WidgetStatePropertyAll(
        body(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconTheme: const WidgetStatePropertyAll(
        IconThemeData(color: JournalPalette.sageDark),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: JournalPalette.sageDark,
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: JournalPalette.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 13,
        color: JournalPalette.inkSoft,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: JournalPalette.sageLight,
      thickness: 1,
    ),
  );
}

/// Plant-growth indicator for habit streaks.
String streakPlant(int streak) {
  if (streak <= 0) return '🌱';
  if (streak < 3) return '🌱';
  if (streak < 7) return '🌿';
  if (streak < 21) return '🌳';
  if (streak < 60) return '🌸';
  return '✨';
}

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 21) return 'Good evening';
  return 'Quiet night';
}

const friendlyWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const friendlyMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String prettyDate(DateTime d) =>
    '${friendlyWeekdays[d.weekday - 1]}, ${friendlyMonths[d.month - 1]} ${d.day}';
