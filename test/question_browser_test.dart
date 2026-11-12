import 'package:decision_saju/data/popular_questions.dart';
import 'package:decision_saju/models.dart';
import 'package:decision_saju/screens/question_browser_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _noopAddMember(FamilyMember _) async {}

void main() {
  Future<void> pumpBrowser(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuestionBrowserScreen(
          members: [],
          onAddMember: _noopAddMember,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }


  testWidgets('카테고리 칩이 보이고 첫 카테고리의 질문이 나온다', (tester) async {
    await pumpBrowser(tester);
    expect(find.text('이직·직장'), findsOneWidget);
    expect(find.text('결혼·연애'), findsOneWidget);
    expect(
      find.text('지금 회사에 남는 게 좋을까요, 이직하는 게 좋을까요?'),
      findsOneWidget,
    );
  });

  testWidgets('카테고리를 바꾸면 그 카테고리의 질문이 나온다', (tester) async {
    await pumpBrowser(tester);
    await tester.tap(find.text('결혼·연애'));
    await tester.pumpAndSettle();
    expect(find.text('저는 언제 결혼할 수 있을까요?'), findsOneWidget);
    expect(
      find.text('지금 회사에 남는 게 좋을까요, 이직하는 게 좋을까요?'),
      findsNothing,
    );
  });

  testWidgets('질문을 누르면 공감 문구와 리포트 만들기 버튼이 나온다', (tester) async {
    await pumpBrowser(tester);
    await tester.tap(
      find.text('지금 회사에 남는 게 좋을까요, 이직하는 게 좋을까요?'),
    );
    await tester.pumpAndSettle();
    expect(find.text('남을지 떠날지, 매일 출근길마다 마음이 흔들리죠.'), findsOneWidget);
    expect(find.text('리포트 만들기'), findsOneWidget);
  });

  testWidgets('날짜형 질문에는 날짜 비교 안내가 보인다', (tester) async {
    await pumpBrowser(tester);
    await tester.ensureVisible(find.text('이직하기 좋은 시기는 언제인가요?'));
    await tester.pumpAndSettle();
    expect(find.text('날짜를 골라 비교해요'), findsWidgets);
  });

  testWidgets('모든 카테고리에 질문이 있다', (tester) async {
    await pumpBrowser(tester);
    for (final c in questionCategories) {
      await tester.ensureVisible(find.text(c.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(c.label));
      await tester.pumpAndSettle();
      expect(
        find.byType(Card),
        findsWidgets,
        reason: c.id,
      );
    }
  });
}
