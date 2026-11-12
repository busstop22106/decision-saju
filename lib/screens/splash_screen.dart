import 'package:flutter/material.dart';

/// 앱 실행 직후 스플래시 카드를 보여주는 화면.
///
/// 안드로이드 12 이상에서는 시스템 스플래시가 앱 아이콘만 보여줘서
/// 풀 카드(결 로고 + 결정사주 + 나침반)가 안 나온다.
/// 그래서 앱 안에서 카드를 잠깐 보여주고 홈으로 넘긴다.
/// 카드는 이미 저장소에 있는 안드로이드 스플래시 로고(1080x2284)를 재사용한다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8F2E6),
      body: SizedBox.expand(
        child: Image(
          image: AssetImage(
            'android/app/src/main/res/drawable-xxxhdpi/splash_logo.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
