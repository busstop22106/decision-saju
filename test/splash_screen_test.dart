import 'package:decision_saju/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('스플래시 카드 이미지가 보인다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
