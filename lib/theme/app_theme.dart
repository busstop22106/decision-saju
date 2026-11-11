// 결정사주 테마 — '한옥 클래식' (2026-11-10 사용자 선택, 밤하늘 다크에서 변경)
// 프로토타입 5종 중 2번. 한지 질감 + 세리프, 전통 감성.
// 팔레트: 한지 크림 배경, 먹빛 글자, 주홍(단청) 액센트 1색 + 쪽빛 보조.
//
// 세리프(Noto Serif KR): 폰트 파일은 바이너리라 VM 스냅샷 푸시로 올릴 수 없다.
// 맥북에서 assets/fonts/에 직접 넣고 pubspec의 fonts 주석을 풀면 적용된다.
// 파일이 없을 때는 시스템 기본 폰트로 폴백되며, 빌드는 정상 동작한다.

import 'package:flutter/material.dart';

class AppTheme {
  // ── 팔레트 ──
  static const Color paper = Color(0xFFF6F1E3); // 한지 배경
  static const Color surface = Color(0xFFEFE7D3); // 한지보다 한 톤 깊은 면
  static const Color card = Color(0xFFFFFCF3); // 카드 (따뜻한 흰색)
  static const Color vermilion = Color(0xFFB3402A); // 주홍 (액센트 1색)
  static const Color vermilionSoft = Color(0xFFC96A52); // 밝은 주홍
  static const Color indigo = Color(0xFF2E4A6B); // 쪽빛 (보조)
  static const Color ink = Color(0xFF211D18); // 먹빛 글자
  static const Color muted = Color(0xFF7A7264); // 보조 글자
  static const Color border = Color(0xFFDDD3BC); // 1px 보더
  static const Color onAccent = Color(0xFFFFF7ED); // 주홍 위 글자

  static const double cardRadius = 16;
  static const double buttonRadius = 12;

  /// 세리프 폰트 패밀리 — 파일이 없을 때는 기본 폰트로 폴백된다.
  static const String serifFamily = 'Noto Serif KR';

  static ThemeData get theme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      colorScheme: const ColorScheme.light(
        primary: vermilion,
        onPrimary: onAccent,
        secondary: indigo,
        surface: card,
        onSurface: ink,
        error: Color(0xFFB3261E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: serifFamily,
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: vermilion),
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
      textTheme: base.textTheme
          .apply(
            fontFamily: serifFamily,
            bodyColor: ink,
            displayColor: ink,
          )
          .copyWith(
            headlineSmall: const TextStyle(
              fontFamily: serifFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            titleLarge: const TextStyle(
              fontFamily: serifFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: const TextStyle(
              fontFamily: serifFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            bodyLarge: const TextStyle(
              fontFamily: serifFamily,
              fontSize: 15,
              height: 1.6,
            ),
            bodyMedium: const TextStyle(
              fontFamily: serifFamily,
              fontSize: 14,
              height: 1.6,
            ),
            bodySmall: const TextStyle(
              fontFamily: serifFamily,
              color: muted,
              fontSize: 13,
              height: 1.5,
            ),
            labelLarge: const TextStyle(
              fontFamily: serifFamily,
              color: onAccent,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vermilion,
          foregroundColor: onAccent,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: serifFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: vermilion,
          side: const BorderSide(color: vermilion, width: 1),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: serifFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: vermilion,
          textStyle: const TextStyle(
            fontFamily: serifFamily,
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
          borderSide: const BorderSide(color: vermilion, width: 1.5),
        ),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        hintStyle: const TextStyle(color: muted, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: vermilion,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: vermilion,
        labelStyle: const TextStyle(color: ink, fontSize: 14),
        secondaryLabelStyle: const TextStyle(color: onAccent, fontSize: 14),
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
