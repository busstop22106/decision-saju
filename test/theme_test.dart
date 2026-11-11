import 'package:decision_saju/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TextButton 글자는 주홍색이다 (흰 글자 버그 재발 방지)', () {
    // 2026-11-11 실기기 확인: TextButton에 테마가 없어 textTheme.labelLarge
    // 색(onAccent, 크림색)이 그대로 쓰여 종이색 배경에서 글자가 안 보였다.
    final style = AppTheme.theme.textButtonTheme.style;
    expect(style, isNotNull);
    final foreground =
        style!.foregroundColor!.resolve(<WidgetState>{});
    expect(foreground, AppTheme.vermilion);
  });

  testWidgets('TextButton 실제 글자 색이 주홍색이다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: TextButton(
            onPressed: () {},
            child: const Text('환불정책·약관 보기'),
          ),
        ),
      ),
    );
    final textWidget =
        tester.widget<Text>(find.text('환불정책·약관 보기'));
    expect(textWidget.style, isNull);
    final defaultStyle = tester
        .widget<DefaultTextStyle>(
          find.ancestor(
            of: find.text('환불정책·약관 보기'),
            matching: find.byType(DefaultTextStyle),
          ).first,
        )
        .style;
    expect(defaultStyle.color, AppTheme.vermilion);
  });

  testWidgets('색을 안 정한 글자도 먹빛(ink)으로 보인다', (tester) async {
    // 2026-11-11 실기기 확인: 섹션 제목(titleMedium)·운세 본문(bodyMedium)·
    // 색 없는 일반 글자가 종이색 배경에서 흰색으로 보여 안 보였다.
    // 원인: textTheme.apply()로 준 ink 색이 copyWith에서 통째로 교체되며
    // 사라져 색이 null이 됐다. 모든 스타일에 색을 명시한 뒤의 회귀 테스트.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Column(
            children: [
              const Text('색 없는 일반 글자'),
              Builder(
                builder: (context) {
                  return Text(
                    'titleMedium 글자',
                    style: Theme.of(context).textTheme.titleMedium,
                  );
                },
              ),
              Builder(
                builder: (context) {
                  return Text(
                    'bodyMedium 글자',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    for (final label in ['색 없는 일반 글자', 'titleMedium 글자', 'bodyMedium 글자']) {
      final style =
          DefaultTextStyle.of(tester.element(find.text(label))).style;
      expect(style.color, AppTheme.ink, reason: label);
    }
  });
}
