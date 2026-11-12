import 'package:decision_saju/data/popular_questions.dart';
import 'package:decision_saju/engine/question_report.dart';
import 'package:decision_saju/engine/saju.dart';
import 'package:decision_saju/models.dart';
import 'package:flutter_test/flutter_test.dart';

// 픽스처: 1987-05-20생 남성 (birthHour 10)
// 일주 기사(기토 일간·사화 일지), 연주 정묘, 월주 을사.
// 용신 수, 신강. 2026-11-12 기준 세운 병오, 월운 기해, 대운 신축(35세부터, 식신).
final _baby = BabyInfo(
  surname: '',
  surnameHanja: '',
  surnameStrokes: 0,
  gender: Gender.boy,
  birth: DateTime(1987, 5, 20),
  birthHour: 10,
);

void main() {
  final saju = computeSaju(_baby);
  // 2026-11-12: 세운 병오, 월운 기해, 대운 임술(35세부터).
  final now = DateTime(2026, 11, 12);

  test('모든 카테고리의 주제 읽기가 0~100점이고 결론·근거가 있다', () {
    for (final c in questionCategories) {
      final reading = topicReading(
        baby: _baby,
        saju: saju,
        categoryId: c.id,
        now: now,
      );
      expect(reading.index, inInclusiveRange(0, 100), reason: c.id);
      expect(reading.verdict.trim(), isNotEmpty, reason: c.id);
      expect(reading.evidence, isNotEmpty, reason: c.id);
    }
  });

  test('같은 입력이면 같은 결과가 나온다 (결정적)', () {
    final a = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'wealth',
      now: now,
    );
    final b = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'wealth',
      now: now,
    );
    expect(a.index, b.index);
    expect(a.verdict, b.verdict);
    expect(a.evidence, b.evidence);
  });

  test('재물: 초점 십성(재성)이 대운·세운·월운에 없어 50점, 이번 달 해수·일지 사화 충 -8점', () {
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'wealth',
      now: now,
    );
    // 대운 신금=식신, 세운 병화=정인, 월운 기토=비견 — 재성 없음.
    // 50 - 8(사해충) = 42.
    expect(reading.index, 42);
    expect(reading.evidence.any((e) => e.contains('충')), isTrue);
  });

  test('자녀: 대운 신금(식신) +10점, 이번 달 해수·일지 사화 충 -8점', () {
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'children',
      now: now,
    );
    // 50 + 10(대운 식신) - 8(사해충) = 52. 용신은 수라 식신(금)과 안 맞아 보너스 없음.
    expect(reading.index, 52);
    expect(reading.evidence.any((e) => e.contains('대운')), isTrue);
    expect(reading.evidence.any((e) => e.contains('충')), isTrue);
  });

  test('시험: 세운 병화(정인) +8점, 이번 달 해수·일지 사화 충 -8점', () {
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'exam',
      now: now,
    );
    // 50 + 8(세운 정인) - 8(사해충) = 50.
    expect(reading.index, 50);
  });

  test('가족은 육친(인성·비겁) 흐름으로 읽는다', () {
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'family',
      now: now,
    );
    // 50 + 8(세운 병=정인, 부모) + 6(월운 기=비견, 형제)
    //     + 6(대운 축·일지 사 삼합) - 6(월운 해 공망) - 8(월운 해·일지 사 충) = 56.
    expect(reading.index, 56);
    expect(reading.evidence, isNotEmpty);
    expect(reading.verdict, contains('가족'));
  });

  test('카테고리별 초점 라벨이 있다', () {
    expect(topicFocusLabel('wealth'), '재물');
    expect(topicFocusLabel('exam'), '시험·취업');
    expect(topicFocusLabel('health'), '건강');
    expect(topicFocusLabel('unknown'), '운세');
  });

  test('건강: 부족한 오행을 채워주는 흐름이면 근거에 들어간다', () {
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'health',
      now: now,
    );
    expect(reading.index, inInclusiveRange(0, 100));
    expect(reading.verdict, contains('건강'));
  });

  test('삼형이 들어오면 경고 근거가 생긴다', () {
    // 2022년 연주 임인(인) — 일지 사와 인사신 형.
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'wealth',
      now: DateTime(2022, 11, 12),
    );
    // 50 + 8(세운 임=정재) + 4(용신 수와 같음) - 8(형) - 8(월운 충)
    //     + 6(대운 삼합) - 6(공망) = 46.
    expect(reading.index, 46);
    expect(
      reading.evidence.any((e) => e.contains('형이 있어')),
      isTrue,
    );
  });

  test('사업은 관성도 초점 십성으로 본다', () {
    // 2024년 연주 갑진(갑) — 기 일간에 정관(관성).
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'business',
      now: DateTime(2024, 11, 12),
    );
    // 50 + 8(세운 갑=정관) + 6(월운 을=편관) - 8(월운 충)
    //     + 6(대운 삼합) - 6(공망) = 56.
    expect(reading.index, 56);
    expect(
      reading.evidence.any((e) => e.contains('정관')),
      isTrue,
    );
  });

  test('이직에는 역마, 결혼에는 도화가 들어간다', () {
    final job = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'job',
      now: now,
    );
    // 이번 달 해는 일지 사의 역마(사유축→해).
    expect(job.evidence.any((e) => e.contains('역마')), isTrue);
    final marriage = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'marriage',
      now: now,
    );
    // 올해 오(병오)는 일지 사의 도화(사유축→오).
    expect(marriage.evidence.any((e) => e.contains('도화')), isTrue);
  });

  test('소송에서 비겁은 경고 요인으로만 들어간다', () {
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'legal',
      now: now,
    );
    // 이번 달 기(기해)는 기 일간에 비견 — 비겁 경고 -4점.
    expect(
      reading.evidence.any((e) => e.contains('비겁')),
      isTrue,
    );
    expect(reading.index, 38);
  });

  test('건강은 부족 보충뿐 아니라 용신 극·오행 과다도 본다', () {
    final reading = topicReading(
      baby: _baby,
      saju: saju,
      categoryId: 'health',
      now: now,
    );
    // 이번 달 기(토)는 용신 수(水)를 극하고(-8),
    // 올해 병(화)은 이미 많은 화(4개)를 더한다(-6).
    expect(
      reading.evidence.any((e) => e.contains('용신') && e.contains('극해')),
      isTrue,
    );
    expect(
      reading.evidence.any((e) => e.contains('이미 많은데')),
      isTrue,
    );
  });

  test('engineTopicForQuestion: 선택형은 이직·이사·결혼만, 날짜형은 개업·출산만 보너스가 있다', () {
    expect(engineTopicForQuestion(questionOf('q001')!), '이직');
    expect(engineTopicForQuestion(questionOf('q053')!), '이사');
    expect(engineTopicForQuestion(questionOf('q029')!), '결혼');
    expect(engineTopicForQuestion(questionOf('q055')!), isNull);
    expect(engineTopicForQuestion(questionOf('q057')!), '개업');
    expect(engineTopicForQuestion(questionOf('q085')!), '출산');
    expect(engineTopicForQuestion(questionOf('q046')!), '기타');
    expect(engineTopicForQuestion(questionOf('q067')!), isNull);
  });

  test('buildQuestionReport: 이직 선택 질문은 A/B 비교 모드다', () {
    final report = buildQuestionReport(
      baby: _baby,
      saju: saju,
      question: questionOf('q001')!,
      now: now,
    );
    expect(report.isComparison, isTrue);
    expect(report.optionALabel, '지금 회사에 남기');
    expect(report.optionBLabel, '다른 회사로 이직하기');
    expect(report.scoreA, inInclusiveRange(0, 100));
    expect(report.scoreB, inInclusiveRange(0, 100));
    expect(report.displayIndex, inInclusiveRange(0, 100));
    expect(report.evidence, isNotEmpty);
    expect(report.recordTopic, '이직·직장');
  });

  test('buildQuestionReport: 일반 질문은 단일 모드다', () {
    final report = buildQuestionReport(
      baby: _baby,
      saju: saju,
      question: questionOf('q067')!,
      now: now,
    );
    expect(report.isComparison, isFalse);
    expect(report.displayIndex, inInclusiveRange(0, 100));
    expect(report.conclusion, contains('재물'));
    expect(report.evidence, isNotEmpty);
    expect(report.recordOptionA, '제 재물운은 어떤가요?');
  });

  test('buildQuestionReport: 날짜형 질문은 두 날짜를 비교한다', () {
    final report = buildQuestionReport(
      baby: _baby,
      saju: saju,
      question: questionOf('q003')!,
      now: now,
      dateA: DateTime(2026, 11, 20),
      dateB: DateTime(2026, 11, 27),
    );
    expect(report.isComparison, isTrue);
    expect(report.optionALabel, '11월 20일');
    expect(report.optionBLabel, '11월 27일');
    expect(report.evidenceFootnote, '같은 계산에서 나온 결과입니다.');
  });

  test('buildQuestionReport: 같은 입력이면 같은 결과가 나온다', () {
    final a = buildQuestionReport(
      baby: _baby,
      saju: saju,
      question: questionOf('q001')!,
      now: now,
    );
    final b = buildQuestionReport(
      baby: _baby,
      saju: saju,
      question: questionOf('q001')!,
      now: now,
    );
    expect(a.displayIndex, b.displayIndex);
    expect(a.conclusion, b.conclusion);
    expect(a.evidence, b.evidence);
  });
}
