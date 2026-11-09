// 결정사주 테마 — '밤하늘 다크' (2026-11-09 사용자 선택)
// 프로토타입 5종 중 3번. 다크 배경 + 금빛 포인트, 가독성 우선.

import 'package:flutter/material.dart';

class AppTheme {
  // ── 팔레트 ──
  static const Color nightBg = Color(0xFF0B1026); // 밤하늘 배경
  static const Color surface = Color(0xFF141A33); // 섹션 배경
  static const Color card = Color(0xFF1A2140); // 카드 배경
  static const Color gold = Color(0xFFD4AF37); // 금빛 포인트 (액센트 1색)
  static const Color goldSoft = Color(0xFFE8C96A); // 밝은 금빛
  static const Color goldDim = Color(0xFF8C7326); // 어두운 금빛 (비활성)
  static const Color ink = Color(0xFFF5F1E6); // 따뜻한 흰 글자
  static const Color muted = Color(0xFF9AA3B8); // 보조 글자
  static const Color border = Color(0xFF2A3358); // 1px 보더
  static const Color onGold = Color(0xFF1A1405); // 금빛 위 글자

  static const double cardRadius = 16;
  static const double buttonRadius = 12;

  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: nightBg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: onGold,
        secondary: goldSoft,
        surface: card,
        onSurface: ink,
        error: Color(0xFFE57373),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: nightBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: gold),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: const TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(color: ink, fontSize: 15, height: 1.55),
        bodyMedium: const TextStyle(color: ink, fontSize: 14, height: 1.55),
        bodySmall: const TextStyle(color: muted, fontSize: 13, height: 1.5),
        labelLarge: const TextStyle(
          color: onGold,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: onGold,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldSoft,
          side: const BorderSide(color: gold, width: 1),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        hintStyle: const TextStyle(color: muted, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: gold,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: gold,
        labelStyle: const TextStyle(color: ink, fontSize: 14),
        secondaryLabelStyle: const TextStyle(color: onGold, fontSize: 14),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      dialogTheme: const DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        ),
      ),
    );
  }
}
