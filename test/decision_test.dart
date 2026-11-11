import 'dart:convert';

import 'package:decision_saju/data/glossary.dart';
import 'package:decision_saju/data/policies.dart';
import 'package:decision_saju/engine/compat.dart';
import 'package:decision_saju/screens/policies_screen.dart';
import 'package:decision_saju/services/payment_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:decision_saju/engine/saju.dart';
import 'package:decision_saju/engine/decision.dart';
import 'package:decision_saju/models.dart';
import 'package:decision_saju/screens/decision_log_screen.dart';
import 'package:decision_saju/screens/home_screen.dart';
import 'package:decision_saju/services/decision_store.dart';
import 'package:decision_saju/services/share_service.dart';
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

    test('dayScores는 30일 전체를 날짜 순으로 돌려준다', () {
      final all = dayScores(saju, from);
      expect(all.length, 30);
      for (var i = 0; i < 30; i++) {
        expect(all[i].date, from.add(Duration(days: i)));
        expect(all[i].score, scoreDay(saju, from.add(Duration(days: i))));
      }
      final top = luckyDays(saju, from);
      for (final t in top) {
        expect(all.map((d) => d.date).contains(t.date), true);
      }
    });
  });

  group('worstDays · familyLuckyDays', () {
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

    test('육충은 마주 보는 지지끼리만 충한다', () {
      expect(branchesClash('자', '오'), true);
      expect(branchesClash('인', '신'), true);
      expect(branchesClash('자', '자'), false);
      expect(branchesClash('자', '축'), false);
    });

    test('주의일은 2개, 날짜 순, 30일 중 가장 낮은 점수 2개다', () {
      final worst = worstDays(saju, from);
      expect(worst.length, 2);
      expect(worst[0].date.isBefore(worst[1].date), true);
      final scores = [
        for (var i = 0; i < 30; i++) scoreDay(saju, from.add(Duration(days: i))),
      ]..sort();
      expect(worst.map((d) => d.score).toSet(), {scores[0], scores[1]});
      for (final d in worst) {
        expect(d.reason, isNotEmpty);
      }
    });

    test('가족 공통 길일은 구성원 중 가장 낮은 지수가 점수다', () {
      final baby2 = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(1987, 5, 20),
        birthHour: 10,
      );
      final saju2 = computeSaju(baby2);
      final days = familyLuckyDays([saju, saju2], from);
      expect(days.length, 3);
      expect(days[0].date.isBefore(days[1].date), true);
      for (final d in days) {
        var expected = 100;
        for (final s in [saju, saju2]) {
          var score = scoreDay(s, d.date);
          if (dayBranchClashes(s, d.date)) score = (score - 20).clamp(0, 100);
          if (score < expected) expected = score;
        }
        expect(d.score, expected);
        // 한 명이라도 나쁜 날은 가족 길일이 될 수 없다.
        expect(d.score, lessThanOrEqualTo(scoreDay(saju, d.date)));
        expect(d.score, lessThanOrEqualTo(scoreDay(saju2, d.date)));
      }
    });

    test('가족이 없으면 공통 길일도 없다', () {
      expect(familyLuckyDays([], from), isEmpty);
    });
  });

  group('yearMonthScores', () {
    final baby = BabyInfo(
      surname: '',
      surnameHanja: '',
      surnameStrokes: 0,
      gender: Gender.boy,
      birth: DateTime(1987, 5, 20),
      birthHour: 10,
    );
    final saju = computeSaju(baby);

    test('12개월을 돌려주고 평균·최고날이 그 달 안에 있다', () {
      final months = yearMonthScores(saju, 2027);
      expect(months.length, 12);
      for (var m = 0; m < 12; m++) {
        expect(months[m].month, m + 1);
        expect(months[m].avgScore, inInclusiveRange(0, 100));
        expect(months[m].bestDay.year, 2027);
        expect(months[m].bestDay.month, m + 1);
        expect(months[m].bestScore, inInclusiveRange(0, 100));
        // 그 달의 최고 점수와 일치한다
        var max = 0;
        final daysInMonth = DateTime(2027, m + 2, 0).day;
        for (var d = 1; d <= daysInMonth; d++) {
          final s = scoreDay(saju, DateTime(2027, m + 1, d));
          if (s > max) max = s;
        }
        expect(months[m].bestScore, max);
      }
    });

    test('평균이 가장 높은 달이 좋은 달 1위다', () {
      final months = yearMonthScores(saju, 2027);
      final sorted = [...months]
        ..sort((a, b) => b.avgScore.compareTo(a.avgScore));
      expect(sorted.first.avgScore, months.map((m) => m.avgScore).reduce((a, b) => a > b ? a : b));
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

  group('share_service', () {
    testWidgets('RepaintBoundary를 PNG 바이트로 캡처한다', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Container(
                width: 200,
                height: 100,
                color: Colors.white,
                child: const Text('공유 카드'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // toImage는 엔진 래스터 콜백을 기다리므로 runAsync 안에서 돌린다.
      final bytes = await tester.runAsync(() => capturePng(key));
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, true);
      // PNG 시그니처 (89 50 4E 47)
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });
  });

  group('payment', () {
    PurchaseDetails details(PurchaseStatus status) {
      return PurchaseDetails(
        productID: reportProductId,
        purchaseID: 'test-purchase',
        transactionDate: '2026-11-11',
        status: status,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test',
        ),
      );
    }

    test('구매 상태를 결과로 바꾼다', () {
      expect(mapPurchaseStatus(details(PurchaseStatus.purchased)),
          PaymentResult.success);
      expect(mapPurchaseStatus(details(PurchaseStatus.restored)),
          PaymentResult.success);
      expect(mapPurchaseStatus(details(PurchaseStatus.canceled)),
          PaymentResult.cancelled);
      expect(mapPurchaseStatus(details(PurchaseStatus.error)),
          PaymentResult.error);
    });

    test('평생 패스 구매는 구매·복원 상태일 때만 인정한다', () {
      expect(hasPassPurchase([details(PurchaseStatus.purchased)]), true);
      expect(hasPassPurchase([details(PurchaseStatus.restored)]), true);
      expect(hasPassPurchase([details(PurchaseStatus.canceled)]), false);
      expect(hasPassPurchase([details(PurchaseStatus.error)]), false);
      expect(hasPassPurchase([]), false);
      final other = PurchaseDetails(
        productID: 'some_other_product',
        purchaseID: 'x',
        transactionDate: '2026-11-11',
        status: PurchaseStatus.purchased,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test',
        ),
      );
      expect(hasPassPurchase([other]), false);
    });

    test('해금 플래그가 있으면 패스를 산 것으로 본다', () async {
      SharedPreferences.setMockInitialValues({reportPassUnlockKey: true});
      expect(await PaymentService.isPassUnlocked(), true);
      SharedPreferences.setMockInitialValues({});
      expect(await PaymentService.isPassUnlocked(), false);
    });

    test('환불정책에 만세력 계산 기준이 명시돼 있다', () {
      final refund = policies[1];
      expect(refund.$1, '환불정책');
      expect(refund.$2, contains('진태양시'));
      expect(refund.$2, contains('23시'));
      expect(refund.$2, contains('계산 오류가 아니에요'));
    });

    test('정책 문서는 4종이고 내용이 비어 있지 않다', () {
      expect(policies.length, 4);
      final titles = policies.map((p) => p.$1).toSet();
      expect(titles.contains('환불정책'), true);
      expect(titles.contains('개인정보처리방침'), true);
      expect(titles.contains('이용약관'), true);
      expect(titles.contains('재미·참고용 고지'), true);
      for (final (_, body) in policies) {
        expect(body.isNotEmpty, true);
      }
    });

    testWidgets('정책 화면에 4종 제목이 보인다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PoliciesScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('재미·참고용 고지'), findsOneWidget);
      expect(find.text('환불정책'), findsOneWidget);
      // 목록 아래쪽 항목은 스크롤해야 보인다 (환불정책 본문이 길어짐)
      await tester.scrollUntilVisible(find.text('개인정보처리방침'), 200);
      await tester.pumpAndSettle();
      expect(find.text('개인정보처리방침'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('이용약관'), 200);
      await tester.pumpAndSettle();
      expect(find.text('이용약관'), findsOneWidget);
    });
  });

  group('glossary', () {
    test('용어가 10개 이상이고 해설은 한 줄이다', () {
      expect(glossary.length, greaterThanOrEqualTo(10));
      final terms = glossary.map((e) => e.$1).toSet();
      expect(terms.length, glossary.length); // 용어 중복 없음
      for (final (term, desc) in glossary) {
        expect(desc.isNotEmpty, true, reason: term);
        expect(desc.length, lessThanOrEqualTo(60), reason: term);
        expect(glossaryOf(term), desc);
      }
      expect(glossaryOf('없는용어'), isNull);
    });
  });

  group('HomeScreen 오늘의 결정 지수', () {
    testWidgets('홈 맨 위에 오늘의 결정 지수 카드가 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final member = FamilyMember(
        id: '1',
        name: '진욱',
        relation: '아빠',
        gender: Gender.boy,
        birth: DateTime(1987, 5, 20),
        birthHour: 10,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            members: [member],
            onGoToFamily: () {},
            onAddMember: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('오늘의 결정 지수'), findsOneWidget);
      final saju = sajuOfBirth(member.birth, member.birthHour);
      final index = decisionIndex(saju, DateTime.now());
      expect(find.text('$index'), findsOneWidget);
      // 운세 3줄 카드도 그대로 있다
      expect(find.text('진욱님의 오늘'), findsOneWidget);
    });

    testWidgets('구성원이 없으면 결정 지수 카드가 안 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            members: const [],
            onGoToFamily: () {},
            onAddMember: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('오늘의 결정 지수'), findsNothing);
    });
  });
}
