import 'dart:convert';

import 'package:decision_saju/engine/saju.dart';
import 'package:decision_saju/engine/decision.dart';
import 'package:decision_saju/models.dart';
import 'package:decision_saju/screens/decision_log_screen.dart';
import 'package:decision_saju/services/decision_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('dayPillar', () {
    test('기준일 2000-01-01은 무오일이다', () {
      final p = dayPillar(DateTime(2000, 1, 1));
      expect(p.stem, '무');
      expect(p.branch, '오');
    });

    test('computeSaju의 일주와 일치한다', () {
      final baby = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(2026, 11, 10),
      );
      final saju = computeSaju(baby);
      final p = dayPillar(DateTime(2026, 11, 10));
      expect(p.stem, saju.day.stem);
      expect(p.branch, saju.day.branch);
    });
  });

  group('scoreDay / decisionIndex', () {
    final baby = BabyInfo(
      surname: '',
      surnameHanja: '',
      surnameStrokes: 0,
      gender: Gender.boy,
      birth: DateTime(1987, 5, 20),
      birthHour: 10,
    );
    final saju = computeSaju(baby);

    test('점수는 0~100 사이이고 결정적이다', () {
      final a = scoreDay(saju, DateTime(2026, 11, 10));
      final b = scoreDay(saju, DateTime(2026, 11, 10));
      expect(a, b);
      expect(a, inInclusiveRange(0, 100));
    });

    test('30일 범위의 점수가 모두 0~100 사이다', () {
      for (var i = 0; i < 30; i++) {
        final s = scoreDay(saju, DateTime(2026, 11, 10).add(Duration(days: i)));
        expect(s, inInclusiveRange(0, 100));
      }
    });

    test('오늘의 결정 지수는 scoreDay와 같다', () {
      final now = DateTime(2026, 11, 10);
      expect(decisionIndex(saju, now), scoreDay(saju, now));
    });
  });

  group('luckyDays', () {
    final baby = BabyInfo(
      surname: '',
      surnameHanja: '',
      surnameStrokes: 0,
      gender: Gender.girl,
      birth: DateTime(1990, 3, 15),
      birthHour: 14,
    );
    final saju = computeSaju(baby);
    final from = DateTime(2026, 11, 10);

    test('3개를 날짜 순으로 돌려준다', () {
      final days = luckyDays(saju, from);
      expect(days.length, 3);
      expect(days[0].date.isBefore(days[1].date), true);
      expect(days[1].date.isBefore(days[2].date), true);
    });

    test('돌려준 3개에 30일 중 최고 점수가 포함된다', () {
      final days = luckyDays(saju, from);
      var max = 0;
      for (var i = 0; i < 30; i++) {
        final s = scoreDay(saju, from.add(Duration(days: i)));
        if (s > max) max = s;
      }
      expect(days.map((d) => d.score).contains(max), true);
    });
  });

  group('compareOptions', () {
    final baby = BabyInfo(
      surname: '',
      surnameHanja: '',
      surnameStrokes: 0,
      gender: Gender.boy,
      birth: DateTime(1987, 5, 20),
      birthHour: 10,
    );
    final saju = computeSaju(baby);

    test('같은 날짜면 비슷함이다', () {
      final c = compareOptions(
        saju,
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 10),
      );
      expect(c.recommendation, '비슷함');
    });

    test('추천은 점수가 높은 쪽이다', () {
      final dateA = DateTime(2026, 11, 10);
      final dateB = DateTime(2026, 11, 17);
      final c = compareOptions(saju, dateA, dateB);
      if (c.scoreA > c.scoreB + 9) {
        expect(c.recommendation, 'A');
      } else if (c.scoreB > c.scoreA + 9) {
        expect(c.recommendation, 'B');
      } else {
        expect(c.recommendation, '비슷함');
      }
    });
  });

  group('간이 대운', () {
    test('대운 시작 나이는 1~10세다', () {
      expect(daewoonStartAge(DateTime(1987, 5, 20)), inInclusiveRange(1, 10));
      expect(daewoonStartAge(DateTime(1990, 3, 15)), inInclusiveRange(1, 10));
    });

    test('성인은 현재 대운이 있고, 신생아는 대운 전이다', () {
      final adult = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(1987, 5, 20),
      );
      final adultSaju = computeSaju(adult);
      expect(
        currentDaewoon(adult, adultSaju, DateTime(2026, 11, 10)),
        isNotNull,
      );

      final newborn = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.girl,
        birth: DateTime(2026, 11, 1),
      );
      final newbornSaju = computeSaju(newborn);
      expect(
        currentDaewoon(newborn, newbornSaju, DateTime(2026, 11, 10)),
        isNull,
      );
    });
  });

  group('근거 3줄 · 오늘 피할 것', () {
    final baby = BabyInfo(
      surname: '',
      surnameHanja: '',
      surnameStrokes: 0,
      gender: Gender.boy,
      birth: DateTime(1987, 5, 20),
      birthHour: 10,
    );
    final saju = computeSaju(baby);
    final now = DateTime(2026, 11, 10);

    test('근거는 3줄이고 용신·일진·대운을 담는다', () {
      final lines = evidenceLines(baby, saju, now);
      expect(lines.length, 3);
      expect(lines[0], contains('용신'));
      expect(lines[1], contains('일진'));
      expect(lines[2], contains('대운'));
    });

    test('오늘 피할 것은 비어 있지 않다', () {
      expect(avoidLine(saju, now).isNotEmpty, true);
    });
  });

  group('DecisionStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    DecisionRecord record({required DateTime decidedAt}) {
      return DecisionRecord(
        id: 'r1',
        topic: '이직',
        optionA: '지금 회사에 남기',
        optionB: '다른 회사로 옮기기',
        chosen: 'A',
        decidedAt: decidedAt,
        summary: 'A안이 유리해요.',
        index: 72,
      );
    }

    test('저장·불러오기 왕복', () async {
      final store = await DecisionStore.load();
      await store.add(record(decidedAt: DateTime(2026, 11, 10)));
      final all = store.loadAll();
      expect(all.length, 1);
      expect(all.first.topic, '이직');
      expect(all.first.chosen, 'A');
    });

    test('30일이 지난 기록만 되물음 대상이다', () async {
      final store = await DecisionStore.load();
      final now = DateTime.now();
      await store.add(record(decidedAt: now.subtract(const Duration(days: 31))));
      await store.add(
        DecisionRecord(
          id: 'r2',
          topic: '이사',
          optionA: '지금 집',
          optionB: '새 집',
          chosen: 'B',
          decidedAt: now.subtract(const Duration(days: 29)),
          summary: 'B안이 유리해요.',
          index: 65,
        ),
      );
      final due = store.dueFollowUps();
      expect(due.length, 1);
      expect(due.first.id, 'r1');
    });

    test('되물음에 답하면 대상에서 빠진다', () async {
      final store = await DecisionStore.load();
      final now = DateTime.now();
      await store.add(record(decidedAt: now.subtract(const Duration(days: 31))));
      expect(await store.answerFollowUp('r1', '잘 됐어요'), true);
      expect(store.dueFollowUps(), isEmpty);
      expect(store.loadAll().first.followUp, '잘 됐어요');
    });
  });

  group('DecisionLogScreen', () {
    DecisionRecord record({required String id, required DateTime decidedAt}) {
      return DecisionRecord(
        id: id,
        topic: '이직',
        optionA: '지금 회사에 남기',
        optionB: '다른 회사로 옮기기',
        chosen: 'A',
        decidedAt: decidedAt,
        summary: 'A안이 유리해요.',
        index: 72,
      );
    }

    testWidgets('저장된 기록이 보이고 되물음에 답하면 사라진다', (tester) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'decision_records_v1': jsonEncode([
          record(
            id: 'due1',
            decidedAt: now.subtract(const Duration(days: 31)),
          ).toJson(),
          record(
            id: 'recent1',
            decidedAt: now.subtract(const Duration(days: 5)),
          ).toJson(),
        ]),
      });

      await tester.pumpWidget(
        const MaterialApp(home: DecisionLogScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('30일이 지난 결정'), findsOneWidget);
      expect(find.text('지난 결정'), findsOneWidget);
      expect(find.text('잘 됐어요'), findsOneWidget);

      await tester.tap(find.text('잘 됐어요'));
      await tester.pumpAndSettle();

      expect(find.text('30일이 지난 결정'), findsNothing);
      expect(find.text('지난 결정'), findsOneWidget);
    });

    testWidgets('기록이 없으면 빈 상태를 보여준다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: DecisionLogScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('아직 저장된 결정이 없어요.'), findsOneWidget);
    });
  });
}
