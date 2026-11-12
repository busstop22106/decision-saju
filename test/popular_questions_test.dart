import 'package:decision_saju/data/popular_questions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('질문은 139개, 카테고리는 13개', () {
    expect(popularQuestions.length, 139);
    expect(questionCategories.length, 13);
  });

  test('질문 id는 모두 유일하고 q001~q139 순서대로', () {
    final ids = popularQuestions.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
    for (var i = 0; i < ids.length; i++) {
      expect(ids[i], 'q${(i + 1).toString().padLeft(3, '0')}');
    }
  });

  test('모든 질문의 카테고리가 존재하고, 문구·공감 문장이 비어 있지 않다', () {
    for (final q in popularQuestions) {
      expect(categoryOf(q.categoryId), isNotNull, reason: q.id);
      expect(q.text.trim(), isNotEmpty, reason: q.id);
      expect(q.empathy.trim(), isNotEmpty, reason: q.id);
    }
  });

  test('카테고리별 질문이 있고, questionsForCategory가 일치한다', () {
    for (final c in questionCategories) {
      final list = questionsForCategory(c.id);
      expect(list, isNotEmpty, reason: c.id);
      expect(list.every((q) => q.categoryId == c.id), isTrue);
    }
    expect(
      questionCategories
          .map((c) => questionsForCategory(c.id).length)
          .fold<int>(0, (a, b) => a + b),
      popularQuestions.length,
    );
  });

  test('유형 분포: choice·timing·general이 모두 있다', () {
    final kinds = popularQuestions.map((q) => q.kind).toSet();
    expect(kinds, containsAll(QuestionKind.values));
    final timing = popularQuestions
        .where((q) => q.kind == QuestionKind.timing)
        .length;
    expect(timing, greaterThan(30));
  });

  test('questionOf가 id로 질문을 찾는다', () {
    expect(questionOf('q001')?.text, contains('이직'));
    expect(questionOf('q139')?.text, contains('내년'));
    expect(questionOf('q999'), isNull);
  });
}
