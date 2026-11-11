import 'dart:convert';

import 'package:decision_saju/data/glossary.dart';
import 'package:decision_saju/data/policies.dart';
import 'package:decision_saju/engine/compat.dart';
import 'package:decision_saju/screens/lucky_days_screen.dart';
import 'package:decision_saju/screens/new_year_screen.dart';
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
        // 일지 충 감점(-20점)은 scoreDay 안에 들어 있다. 여기서 또 깎으면 안 된다.
        var expected = 100;
        for (final s in [saju, saju2]) {
          final score = scoreDay(s, d.date);
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

  group('코드 리뷰 반영 (2026-11-11)', () {
    test('일지 충인 날은 결정 지수가 20점 깎인다', () {
      final baby = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(1987, 5, 20),
        birthHour: 10,
      );
      final saju = computeSaju(baby);
      final from = DateTime(2026, 11, 10);
      // 충인 날을 하나 찾는다.
      DateTime? clashDay;
      for (var i = 0; i < 60; i++) {
        final d = DateTime(from.year, from.month, from.day + i);
        if (dayBranchClashes(saju, d)) {
          clashDay = d;
          break;
        }
      }
      expect(clashDay, isNotNull);
      final d = clashDay!;
      // 일지만 충하지 않는 쌍둥이 사주 — 나머지는 전부 같다.
      const branches = [
        '자',
        '축',
        '인',
        '묘',
        '진',
        '사',
        '오',
        '미',
        '신',
        '유',
        '술',
        '해',
      ];
      final clashBranch = dayPillar(d).branch;
      final twinBranch = branches.firstWhere(
        (b) => !branchesClash(b, clashBranch),
      );
      final twin = SajuResult(
        year: saju.year,
        month: saju.month,
        day: SajuPillar(saju.day.stem, twinBranch),
        hour: saju.hour,
        dayMaster: saju.dayMaster,
        dayElement: saju.dayElement,
        elementCounts: saju.elementCounts,
        strongBody: saju.strongBody,
        yongsin: saju.yongsin,
        huishin: saju.huishin,
        johu: saju.johu,
        notes: saju.notes,
      );
      expect(dayBranchClashes(twin, d), false);
      expect(scoreDay(twin, d) - scoreDay(saju, d), 20);
    });

    test('주의일 이유는 충이 상극보다 먼저 나온다', () {
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
      // 충이면서 천간이 나를 극하는 날을 찾는다.
      DateTime? target;
      for (var i = 0; i < 120; i++) {
        final d = DateTime(from.year, from.month, from.day + i);
        final stemEl = stemElement(dayPillar(d).stem);
        if (dayBranchClashes(saju, d) &&
            controlsTo(stemEl, saju.dayElement)) {
          target = d;
          break;
        }
      }
      expect(target, isNotNull);
      final all = worstDays(saju, from, days: 120, count: 120);
      final found = all.where((l) => l.date == target).toList();
      expect(found.length, 1);
      expect(found.first.reason, contains('충'));
    });

    test('가족 공통 길일 사유 문구는 점수 구간과 맞는다', () {
      final baby1 = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.girl,
        birth: DateTime(1990, 3, 15),
        birthHour: 14,
      );
      final baby2 = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(1987, 5, 20),
        birthHour: 10,
      );
      final days = familyLuckyDays(
        [computeSaju(baby1), computeSaju(baby2)],
        DateTime(2026, 11, 10),
      );
      expect(days.length, 3);
      for (final d in days) {
        if (d.score >= 65) {
          expect(d.reason, contains('좋은 날'));
        } else if (d.score >= 50) {
          expect(d.reason, contains('무난한 날'));
        } else {
          expect(d.reason, contains('신중히'));
        }
      }
    });

    test('조후가 용신과 같아도 희신은 남는다', () {
      // 2024년 생일을 훑어 조후==용신인 경우를 찾는다.
      // 조후 개수 0이면 용신=조후 분기라 희신이 원래 없다. 그 경우는 제외한다.
      var found = 0;
      final start = DateTime(2024, 1, 1);
      for (var i = 0; i < 366; i++) {
        final birth = DateTime(start.year, start.month, start.day + i);
        for (final gender in [Gender.boy, Gender.girl]) {
          final baby = BabyInfo(
            surname: '',
            surnameHanja: '',
            surnameStrokes: 0,
            gender: gender,
            birth: birth,
            birthHour: 10,
          );
          final saju = computeSaju(baby);
          final johu = saju.johu;
          if (johu != null &&
              johu == saju.yongsin &&
              (saju.elementCounts[johu] ?? 0) > 0) {
            found++;
            expect(saju.huishin, isNotNull);
            expect(saju.huishin, isNot(saju.yongsin));
          }
        }
      }
      expect(found, greaterThan(0));
    });
  });

  group('가족 궁합 (2차 리뷰 반영)', () {
    HanjaPick pick(String element) => HanjaPick(
          syllable: '가',
          char: '家',
          strokes: 10,
          element: element,
          meaning: '집',
        );

    SajuResult sajuOf(DateTime birth, Gender gender) {
      return computeSaju(BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: gender,
        birth: birth,
        birthHour: 10,
      ));
    }

    SajuResult findMember(bool Function(SajuResult s) matches) {
      final start = DateTime(2024, 1, 1);
      for (var i = 0; i < 366; i++) {
        final s = sajuOf(
          DateTime(start.year, start.month, start.day + i),
          Gender.boy,
        );
        if (matches(s)) return s;
      }
      throw StateError('조건에 맞는 사주를 찾지 못했다');
    }

    test('띠 2개 결합은 반합 15점이다', () {
      // 신·자·진 삼합 그룹에서 2개만 겹치면 반합이다.
      expect(zodiacRelation('신', '자'), ZodiacRelation.banhap);
      expect(zodiacScore('신', '자'), 15);
      expect(zodiacLabel('신', '자'), '반합(半合)');
      // 육합·같은 띠·충은 그대로다.
      expect(zodiacRelation('자', '축'), ZodiacRelation.yukhap);
      expect(zodiacScore('자', '축'), 17);
      expect(zodiacRelation('자', '자'), ZodiacRelation.same);
      expect(zodiacScore('자', '자'), 13);
      expect(zodiacRelation('자', '오'), ZodiacRelation.chung);
      expect(zodiacScore('자', '오'), 4);
    });

    test('이름 글자가 없어도 점수가 NaN이 되지 않는다', () {
      final member = sajuOf(DateTime(1990, 3, 15), Gender.girl);
      final baby = sajuOf(DateTime(2024, 3, 1), Gender.boy);
      final result = computeFamilyCompat(
        members: [(label: '엄마', saju: member)],
        babySaju: baby,
        picks: [],
      );
      final m = result.members.first;
      expect(m.elementScore, 0.0);
      expect(m.yongsinScore, 0.0);
      expect(m.total.isNaN, false);
      expect(result.total.isNaN, false);
    });

    test('구성원이 없으면 합계 0점, 최고 궁합은 없다', () {
      final baby = sajuOf(DateTime(2024, 3, 1), Gender.boy);
      final result = FamilyCompatResult(
        members: const [],
        babySaju: baby,
        nameElements: const [],
        balanceNote: '',
        familyCountsBefore: const {
          '목': 0,
          '화': 0,
          '토': 0,
          '금': 0,
          '수': 0,
        },
        familyCountsAfter: const {
          '목': 0,
          '화': 0,
          '토': 0,
          '금': 0,
          '수': 0,
        },
      );
      expect(result.total, 0.0);
      expect(result.best, isNull);
      expect(result.ranked, isEmpty);
    });

    test('가족 오행 분포에 아기 사주도 들어간다', () {
      final member = sajuOf(DateTime(1990, 3, 15), Gender.girl);
      final baby = sajuOf(DateTime(2024, 3, 1), Gender.boy);
      final result = computeFamilyCompat(
        members: [(label: '엄마', saju: member)],
        babySaju: baby,
        picks: [pick('목')],
      );
      for (final e in ['목', '화', '토', '금', '수']) {
        expect(
          result.familyCountsBefore[e],
          (member.elementCounts[e] ?? 0) + (baby.elementCounts[e] ?? 0),
        );
      }
    });

    test('희신 일치 점수가 상생보다 높다', () {
      final member = findMember(
        (s) => s.huishin != null && s.yongsin != null,
      );
      final baby = sajuOf(DateTime(2024, 3, 1), Gender.boy);
      final yong = member.yongsin!;
      // 용신을 생해주는 오행 (목→화→토→금→수→목 순환에서 앞 오행).
      const cycle = ['목', '화', '토', '금', '수'];
      final saeng = cycle.firstWhere((e) => generatesTo(e, yong));
      double scoreWith(String element) {
        final r = computeFamilyCompat(
          members: [(label: '아빠', saju: member)],
          babySaju: baby,
          picks: [pick(element)],
        );
        return r.members.first.yongsinScore;
      }

      expect(scoreWith(member.huishin!), greaterThan(scoreWith(saeng)));
    });

    test('부족한 오행이 2개여도 채운 오행을 알아본다', () {
      final member = findMember((s) {
        final zeros = ['목', '화', '토', '금', '수']
            .where((e) => (s.elementCounts[e] ?? 0) == 0)
            .length;
        return zeros >= 2;
      });
      final baby = sajuOf(DateTime(2024, 3, 1), Gender.boy);
      final lacking = ['목', '화', '토', '금', '수']
          .where((e) => (member.elementCounts[e] ?? 0) == 0)
          .toList();
      final other = ['목', '화', '토', '금', '수']
          .firstWhere((e) => !lacking.contains(e));

      final filled = computeFamilyCompat(
        members: [(label: '아빠', saju: member)],
        babySaju: baby,
        picks: [pick(lacking.first)],
      );
      expect(
        filled.members.first.details.any((d) => d.contains('채워줘요')),
        true,
      );

      final notFilled = computeFamilyCompat(
        members: [(label: '아빠', saju: member)],
        babySaju: baby,
        picks: [pick(other)],
      );
      expect(
        notFilled.members.first.details
            .any((d) => d.contains('다른 오행으로 보완해요')),
        true,
      );
    });

    test('상생과 상극이 공존하면 둘 다 적는다', () {
      final member = findMember((s) => s.yongsin != null);
      final baby = sajuOf(DateTime(2024, 3, 1), Gender.boy);
      final yong = member.yongsin!;
      const cycle = ['목', '화', '토', '금', '수'];
      final saeng = cycle.firstWhere((e) => generatesTo(e, yong));
      final geuk = cycle.firstWhere((e) => controlsTo(e, yong));
      final result = computeFamilyCompat(
        members: [(label: '아빠', saju: member)],
        babySaju: baby,
        picks: [pick(saeng), pick(geuk)],
      );
      final details = result.members.first.details.join('\n');
      expect(details, contains('생(生)'));
      expect(details, contains('상극'));
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

    test('순행과 역행의 시작 나이가 다르다', () {
      // 1987-05-20: 순행은 다음 절기(6월 6일, 17일 뒤) → 6세,
      // 역행은 이전 절기(5월 6일, 14일 전) → 5세.
      expect(daewoonStartAge(DateTime(1987, 5, 20), forward: true), 6);
      expect(daewoonStartAge(DateTime(1987, 5, 20), forward: false), 5);
    });

    test('첫 대운은 월주에서 1칸 이동한 간지다', () {
      const stems = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
      const branches = [
        '자',
        '축',
        '인',
        '묘',
        '진',
        '사',
        '오',
        '미',
        '신',
        '유',
        '술',
        '해',
      ];
      final baby = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(1987, 5, 20),
        birthHour: 10,
      );
      final saju = computeSaju(baby);
      // 1987년 정묘 — 정은 음간이라 남성은 역행, 시작 나이 5세(세는나이).
      expect(daewoonStartAge(baby.birth, forward: false), 5);
      // 세는나이 5세가 되는 해(1991년)에 첫 대운이 시작된다.
      final first = currentDaewoon(baby, saju, DateTime(1991, 5, 20));
      expect(first, isNotNull);
      // 월주와 같으면 안 된다 (수정 전: 첫 10년은 월주가 그대로 나왔다).
      // 역행이므로 월주에서 1칸 뒤로 이동한 간지다.
      final stemIdx = stems.indexOf(saju.month.stem);
      final branchIdx = branches.indexOf(saju.month.branch);
      expect(first!.stem, stems[(stemIdx - 1 + 10) % 10]);
      expect(first.branch, branches[(branchIdx - 1 + 12) % 12]);
    });

    test('세는나이 기준으로 대운에 들어간다', () {
      final baby = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(2019, 11, 1),
        birthHour: 10,
      );
      final saju = computeSaju(baby);
      // 2019년 기해 — 기는 음간이라 남성은 역행.
      // 이전 절기(10월 8일)까지 24일 → 시작 나이 8세.
      expect(daewoonStartAge(baby.birth, forward: false), 8);
      // 2026년 11월 10일: 만 나이 7세지만 세는나이 8세라 대운이 시작된다.
      expect(
        currentDaewoon(baby, saju, DateTime(2026, 11, 10)),
        isNotNull,
      );
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

    test('용신 문구의 조사가 받침에 맞는다', () {
      // 받침 없는 용신(화·토·수)은 '가', 받침 있는 용신(목·금)은 '이'.
      BabyInfo? findBabyWithYongsin(String element) {
        final start = DateTime(2024, 1, 1);
        for (var i = 0; i < 366; i++) {
          final b = BabyInfo(
            surname: '',
            surnameHanja: '',
            surnameStrokes: 0,
            gender: Gender.boy,
            birth: DateTime(start.year, start.month, start.day + i),
            birthHour: 10,
          );
          if (computeSaju(b).yongsin == element) return b;
        }
        return null;
      }

      final fireBaby = findBabyWithYongsin('화');
      expect(fireBaby, isNotNull);
      expect(
        evidenceLines(fireBaby!, computeSaju(fireBaby), now)[0],
        contains('화(火)가 강한 날'),
      );

      final woodBaby = findBabyWithYongsin('목');
      expect(woodBaby, isNotNull);
      expect(
        evidenceLines(woodBaby!, computeSaju(woodBaby), now)[0],
        contains('목(木)이 강한 날'),
      );
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

    testWidgets('되물음 카드에 선택한 안과 삭제 버튼이 보인다', (tester) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'decision_records_v1': jsonEncode([
          record(
            id: 'due1',
            decidedAt: now.subtract(const Duration(days: 31)),
          ).toJson(),
        ]),
      });

      await tester.pumpWidget(
        const MaterialApp(home: DecisionLogScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('선택: A안: 지금 회사에 남기'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('잘 됐어요'), findsOneWidget);
    });
  });

  group('LuckyDaysScreen', () {
    testWidgets('30일 달력이 뜨고 월이 바뀌는 날에 월이 보인다', (tester) async {
      final member = FamilyMember(
        id: 'm1',
        name: '아빠',
        relation: '아빠',
        gender: Gender.boy,
        birth: DateTime(1987, 5, 20),
        birthHour: 10,
      );

      await tester.pumpWidget(
        MaterialApp(home: LuckyDaysScreen(member: member)),
      );
      await tester.pumpAndSettle();

      expect(find.text('앞으로 30일'), findsOneWidget);
      // 30일 창 안에 1일이 있으면 '월/1' 형태로 보인다.
      final now = DateTime.now();
      DateTime? firstOfMonth;
      for (var i = 0; i < 30; i++) {
        final d = DateTime(now.year, now.month, now.day + i);
        if (d.day == 1) {
          firstOfMonth = d;
          break;
        }
      }
      if (firstOfMonth != null) {
        expect(
          find.text('${firstOfMonth.month}/1'),
          findsOneWidget,
        );
      }
    });
  });

  group('NewYearScreen', () {
    testWidgets('신년 운세가 뜨고 연도 칩이 고정돼 있다', (tester) async {
      final member = FamilyMember(
        id: 'm1',
        name: '아빠',
        relation: '아빠',
        gender: Gender.boy,
        birth: DateTime(1987, 5, 20),
        birthHour: 10,
      );
      final now = DateTime.now();
      final year = now.month >= 11 ? now.year + 1 : now.year;

      await tester.pumpWidget(
        MaterialApp(home: NewYearScreen(member: member)),
      );
      await tester.pumpAndSettle();

      expect(find.text('$year년 신년 결정 운세'), findsOneWidget);
      expect(find.text('${year - 1}년'), findsOneWidget);
      expect(find.text('$year년'), findsOneWidget);
      expect(find.text('${year + 1}년'), findsOneWidget);
      // 아래쪽 섹션은 스크롤해야 보인다.
      await tester.scrollUntilVisible(
        find.text('월별 결정 지수'),
        200,
      );
      expect(find.text('월별 결정 지수'), findsOneWidget);
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
