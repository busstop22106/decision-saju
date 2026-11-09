import 'package:flutter/material.dart';

/// 결정사주 — 스캐폴드용 최소 진입점.
/// 무료 화면(만세력·오늘 운세·가족 보관함)과 결정 리포트 화면은
/// 이후 단계에서 lib/screens/에 추가한다.
void main() {
  runApp(const DecisionSajuApp());
}

class DecisionSajuApp extends StatelessWidget {
  const DecisionSajuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '결정사주',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('결정사주 — 준비 중입니다'),
        ),
      ),
    );
  }
}
