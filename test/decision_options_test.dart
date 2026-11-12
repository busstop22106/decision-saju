import 'package:decision_saju/engine/decision.dart';
import 'package:decision_saju/engine/decision_options.dart';
import 'package:decision_saju/engine/saju.dart';
import 'package:decision_saju/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 1987-05-20생 남성 — 일주 기사(기토 일간, 사화 일지)다.
  final baby = BabyInfo(
    surname: '',
    surnameHanja: '',
    surnameStrokes: 0,
    gender: Gender.boy,
    birth: DateTime(1987, 5, 20),
    birthHour: 10,
  );
  final saju = computeSaju(baby);

  group('tenGod', () {
    test('갑 일간 기준 십성이 맞다', () {
      expect(tenGod('갑', '갑'), '비견');
      expect(tenGod('갑', '을'), '겁재');
      expect(tenGod('갑', '병'), '식신');
      expect(tenGod('갑', '정'), '상관');
      expect(tenGod('갑', '무'), '편재');
      expect(tenGod('갑', '기'), '정재');
      expect(tenGod('갑', '경'), '편관');
      expect(tenGod('갑', '신'), '정관');
      expect(tenGod('갑', '임'), '편인');
      expect(tenGod('갑', '계'), '정인');
    });

    test('기 일간 기준 십성이 맞다', () {
      expect(tenGod('기', '기'), '비견');
      expect(tenGod('기', '무'), '겁재');
      expect(tenGod('기', '경'), '상관');
      expect(tenGod('기', '신'), '식신');
      expect(tenGod('기', '임'), '정재');
      expect(tenGod('기', '계'), '편재');
      expect(tenGod('기', '갑'), '정관');
      expect(tenGod('기', '을'), '편관');
      expect(tenGod('기', '병'), '정인');
      expect(tenGod('기', '정'), '편인');
    });

    test('배우자성은 남명 재성·여명 관성이다', () {
      // 기 일간 남성: 재성(임·계)이 배우자성이다.
      expect(isSpouseStar(Gender.boy, '기', '임'), isTrue);
      expect(isSpouseStar(Gender.boy, '기', '계'), isTrue);
      expect(isSpouseStar(Gender.boy, '기', '갑'), isFalse);
      // 기 일간 여성: 관성(갑·을)이 배우자성이다.
      expect(isSpouseStar(Gender.girl, '기', '갑'), isTrue);
      expect(isSpouseStar(Gender.girl, '기', '을'), isTrue);
      expect(isSpouseStar(Gender.girl, '기', '임'), isFalse);
    });
  });

  group('지지 관계', () {
    test('육합은 정해진 6쌍만 맞다', () {
      for (final pair in [
        ('자', '축'),
        ('인', '해'),
        ('묘', '술'),
        ('진', '유'),
        ('사', '신'),
        ('오', '미'),
      ]) {
        expect(branchesCombine(pair.$1, pair.$2), isTrue,
            reason: '${pair.$1}-${pair.$2}');
        expect(branchesCombine(pair.$2, pair.$1), isTrue);
      }
      expect(branchesCombine('자', '오'), isFalse);
      expect(branchesCombine('자', '자'), isFalse);
    });

    test('삼합은 같은 삼합국끼리만 맞다', () {
      expect(branchesTriple('신', '자'), isTrue);
      expect(branchesTriple('자', '진'), isTrue);
      expect(branchesTriple('해', '묘'), isTrue);
      expect(branchesTriple('묘', '미'), isTrue);
      expect(branchesTriple('인', '오'), isTrue);
      expect(branchesTriple('오', '술'), isTrue);
      expect(branchesTriple('사', '유'), isTrue);
      expect(branchesTriple('유', '축'), isTrue);
      expect(branchesTriple('신', '해'), isFalse);
      expect(branchesTriple('자', '자'), isFalse);
    });

    test('삼형은 인사신·축술미·자묘 그룹끼리만 맞다', () {
      // 인사신(무은지형)
      expect(branchesPunish('인', '사'), isTrue);
      expect(branchesPunish('사', '신'), isTrue);
      expect(branchesPunish('인', '신'), isTrue);
      // 축술미(지세지형)
      expect(branchesPunish('축', '술'), isTrue);
      expect(branchesPunish('술', '미'), isTrue);
      expect(branchesPunish('축', '미'), isTrue);
      // 자묘(무례지형)
      expect(branchesPunish('자', '묘'), isTrue);
      // 다른 조합은 형이 아니다
      expect(branchesPunish('인', '해'), isFalse);
      expect(branchesPunish('자', '오'), isFalse);
      expect(branchesPunish('자', '자'), isFalse);
    });

    test('공망은 일주의 60갑자 순으로 정해진다', () {
      // 갑자일(순수 자): 공망 술·해
      expect(voidBranches('갑', '자'), ['술', '해']);
      // 을축일도 갑자순: 공망 술·해
      expect(voidBranches('을', '축'), ['술', '해']);
      // 갑술일(순수 술): 공망 신·유
      expect(voidBranches('갑', '술'), ['신', '유']);
      // 갑신일(순수 신): 공망 오·미
      expect(voidBranches('갑', '신'), ['오', '미']);
      // 갑오일(순수 오): 공망 진·사
      expect(voidBranches('갑', '오'), ['진', '사']);
      // 갑진일(순수 진): 공망 인·묘
      expect(voidBranches('갑', '진'), ['인', '묘']);
      // 갑인일(순수 인): 공망 자·축
      expect(voidBranches('갑', '인'), ['자', '축']);
      // 픽스처 일주 기사(기토·사화): 기사는 6번(갑자순)이라 공망 술·해
      expect(voidBranches('기', '사'), ['술', '해']);
    });

    test('역마·도화가 삼합국별로 맞다', () {
      expect(travellingHorse('인'), '신');
      expect(travellingHorse('오'), '신');
      expect(travellingHorse('술'), '신');
      expect(travellingHorse('신'), '인');
      expect(travellingHorse('자'), '인');
      expect(travellingHorse('진'), '인');
      expect(travellingHorse('사'), '해');
      expect(travellingHorse('유'), '해');
      expect(travellingHorse('축'), '해');
      expect(travellingHorse('해'), '사');
      expect(travellingHorse('묘'), '사');
      expect(travellingHorse('미'), '사');

      expect(peachBlossom('인'), '묘');
      expect(peachBlossom('오'), '묘');
      expect(peachBlossom('술'), '묘');
      expect(peachBlossom('신'), '유');
      expect(peachBlossom('자'), '유');
      expect(peachBlossom('진'), '유');
      expect(peachBlossom('사'), '오');
      expect(peachBlossom('유'), '오');
      expect(peachBlossom('축'), '오');
      expect(peachBlossom('해'), '자');
      expect(peachBlossom('묘'), '자');
      expect(peachBlossom('미'), '자');
    });
  });

  group('yearPillarFor / monthPillarFor', () {
    test('2026-11-12는 병오년 기해월이다', () {
      final y = yearPillarFor(DateTime(2026, 11, 12));
      expect(y.stem, '병');
      expect(y.branch, '오');
      final m = monthPillarFor(DateTime(2026, 11, 12));
      expect(m.stem, '기');
      expect(m.branch, '해');
    });

    test('입춘 전후로 연주가 바뀐다', () {
      final before = yearPillarFor(DateTime(2026, 2, 3));
      expect(before.stem, '을');
      expect(before.branch, '사');
      final after = yearPillarFor(DateTime(2026, 2, 4));
      expect(after.stem, '병');
      expect(after.branch, '오');
    });

    test('2026-02-10은 경인월이다', () {
      final m = monthPillarFor(DateTime(2026, 2, 10));
      expect(m.stem, '경');
      expect(m.branch, '인');
    });

    test('computeSaju의 연·월주와 일치한다', () {
      final b = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(2026, 11, 12),
      );
      final s = computeSaju(b);
      expect(s.year.stem, yearPillarFor(DateTime(2026, 11, 12)).stem);
      expect(s.year.branch, yearPillarFor(DateTime(2026, 11, 12)).branch);
      expect(s.month.stem, monthPillarFor(DateTime(2026, 11, 12)).stem);
      expect(s.month.branch, monthPillarFor(DateTime(2026, 11, 12)).branch);
    });

    test('23시 이후 출생은 다음날 기준으로 연·월주를 계산한다', () {
      // 2024-02-03 23시생: 출생일 기준이면 계묘년 을축월이지만,
      // 다음날(2/4 입춘) 기준이면 갑진년 병인월이다.
      final b = BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: Gender.boy,
        birth: DateTime(2024, 2, 3),
        birthHour: 23,
      );
      final s = computeSaju(b);
      expect(s.year.stem, '갑');
      expect(s.year.branch, '진');
      expect(s.month.stem, '병');
      expect(s.month.branch, '인');
      // 다음날 기준 헬퍼와 일치한다.
      expect(s.year.stem, yearPillarFor(DateTime(2024, 2, 4)).stem);
      expect(s.year.branch, yearPillarFor(DateTime(2024, 2, 4)).branch);
      expect(s.month.stem, monthPillarFor(DateTime(2024, 2, 4)).stem);
      expect(s.month.branch, monthPillarFor(DateTime(2024, 2, 4)).branch);
    });
  });

  group('대운 교체 해', () {
    test('대운은 시작 나이부터 10년마다 바뀐다 (세는나이 기준)', () {
      // 1987-05-20생 남성: 역행, 시작 나이 5세(세는나이).
      final d1990 = currentDaewoon(baby, saju, DateTime(1990, 6, 1));
      final d1991 = currentDaewoon(baby, saju, DateTime(1991, 6, 1));
      final d2000 = currentDaewoon(baby, saju, DateTime(2000, 6, 1));
      final d2001 = currentDaewoon(baby, saju, DateTime(2001, 6, 1));
      final d2010 = currentDaewoon(baby, saju, DateTime(2010, 6, 1));
      final d2011 = currentDaewoon(baby, saju, DateTime(2011, 6, 1));
      expect(d1990, isNull);
      expect(d1991, isNotNull);
      // 첫 대운은 1991~2000년(5~14세) 유지된다.
      expect(d2000?.stem, d1991?.stem);
      expect(d2000?.branch, d1991?.branch);
      // 두 번째 대운은 2001년(15세)에 시작한다.
      expect(d2001?.stem, isNot(d1991?.stem));
      expect(d2010?.stem, d2001?.stem);
      // 세 번째 대운은 2011년(25세)에 시작한다.
      expect(d2011?.stem, isNot(d2001?.stem));
    });
  });

  group('configForTopic', () {
    test('이직·이사·결혼은 선택형, 고정 문구가 있다', () {
      final move = configForTopic('이직');
      expect(move.mode, DecisionMode.choice);
      expect(move.optionA, '지금 회사에 남기');
      expect(move.optionB, '다른 회사로 이직하기');
      expect(move.freeText, isFalse);

      final house = configForTopic('이사');
      expect(house.mode, DecisionMode.choice);
      expect(house.optionA, '지금 집에 있기');
      expect(house.optionB, '이사하기');

      final marry = configForTopic('결혼');
      expect(marry.mode, DecisionMode.choice);
      expect(marry.optionA, '지금 사람과 결혼하기');
      expect(marry.optionB, '새로운 인연 찾아보기');
    });

    test('개업·출산은 날짜형, 기타는 자유 입력이다', () {
      expect(configForTopic('개업').mode, DecisionMode.timing);
      expect(configForTopic('개업').freeText, isFalse);
      expect(configForTopic('출산').mode, DecisionMode.timing);
      expect(configForTopic('출산').freeText, isFalse);
      expect(configForTopic('기타').mode, DecisionMode.timing);
      expect(configForTopic('기타').freeText, isTrue);
    });
  });

  group('scoreChoiceOptions', () {
    test('점수는 0~100 사이이고 결정적이다', () {
      for (final topic in ['이직', '이사', '결혼']) {
        final a = scoreChoiceOptions(
          baby: baby,
          saju: saju,
          topic: topic,
          now: DateTime(2026, 11, 12),
        );
        final b = scoreChoiceOptions(
          baby: baby,
          saju: saju,
          topic: topic,
          now: DateTime(2026, 11, 12),
        );
        expect(a.scoreA, b.scoreA);
        expect(a.scoreB, b.scoreB);
        expect(a.scoreA, inInclusiveRange(0, 100));
        expect(a.scoreB, inInclusiveRange(0, 100));
      }
    });

    test('같은 달 안에서는 날짜가 달라도 점수가 같다 (날짜를 안 쓴다)', () {
      final a = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: '이직',
        now: DateTime(2026, 11, 12),
      );
      final b = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: '이직',
        now: DateTime(2026, 11, 15),
      );
      expect(a.scoreA, b.scoreA);
      expect(a.scoreB, b.scoreB);
    });

    test('월운이 바뀌면 점수가 바뀐다 — 이직, 11월(해월) vs 2월(인월)', () {
      // 일지 사(巳). 11월 해월은 일지와 충(A+6) + 역마 해(B+6).
      // 2월 인월은 일지와 충·합·역마가 없다. 대운·세운은 같은 해라 같다.
      final nov = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: '이직',
        now: DateTime(2026, 11, 12),
      );
      final feb = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: '이직',
        now: DateTime(2026, 2, 10),
      );
      expect(nov.scoreA, greaterThan(feb.scoreA));
      expect(nov.scoreB, greaterThan(feb.scoreB));
    });

    test('결혼, 배우자성이 있는 달(4월 진월)이 없는 달(11월 해월)보다 A안이 높다', () {
      // 기 일간 남성: 배우자성은 재성(임·계). 4월 월간 임은 정재(배우자성, A+8).
      // 11월 월간 기는 비견이라 배우자성이 아니다. 월지 차이(충)도 B안에만 간다.
      final apr = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: '결혼',
        now: DateTime(2026, 4, 10),
      );
      final nov = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: '결혼',
        now: DateTime(2026, 11, 12),
      );
      expect(apr.scoreA, greaterThan(nov.scoreA));
    });

    test('추천은 점수가 높은 쪽이고, 10점 미만이면 비슷함이다', () {
      final c = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: '이직',
        now: DateTime(2026, 11, 12),
      );
      if ((c.scoreA - c.scoreB).abs() >= 10) {
        expect(c.recommendation, c.scoreA > c.scoreB ? 'A' : 'B');
      } else {
        expect(c.recommendation, '비슷함');
      }
    });

    test('근거가 있으면 이유와 점수가 함께 적힌다', () {
      final c = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: '이직',
        now: DateTime(2026, 11, 12),
      );
      expect(c.reasons, isNotEmpty);
      for (final r in c.reasons) {
        expect(r, contains('점)'));
      }
    });
  });

  group('scoreTimingOptions', () {
    test('같은 날짜면 비슷함이다', () {
      final c = scoreTimingOptions(
        saju: saju,
        topic: '개업',
        dateA: DateTime(2026, 11, 20),
        dateB: DateTime(2026, 11, 20),
      );
      expect(c.scoreA, c.scoreB);
      expect(c.recommendation, '비슷함');
    });

    test('개업은 재성 기운이 있는 날에 +5점이다', () {
      // 기 일간: 재성은 수(임·계). 재성 날짜를 찾아서 보너스를 확인한다.
      DateTime? wealthDate;
      for (var i = 0; i < 60; i++) {
        final d = DateTime(2026, 11, 12 + i);
        final god = tenGod(saju.dayMaster, dayPillar(d).stem);
        if (isWealthGod(god)) {
          wealthDate = d;
          break;
        }
      }
      expect(wealthDate, isNotNull);
      final other = DateTime(2026, 11, 12);
      final c = scoreTimingOptions(
        saju: saju,
        topic: '개업',
        dateA: wealthDate!,
        dateB: other,
      );
      expect(
        c.scoreA,
        (scoreDay(saju, wealthDate) + 5).clamp(0, 100),
      );
      expect(c.reasons.any((r) => r.contains('재성')), isTrue);
    });

    test('출산은 식상 기운이 있는 날에 +5점이다', () {
      // 기 일간: 식상은 금(경·신). 식상 날짜를 찾아서 보너스를 확인한다.
      DateTime? outputDate;
      for (var i = 0; i < 60; i++) {
        final d = DateTime(2026, 11, 12 + i);
        final god = tenGod(saju.dayMaster, dayPillar(d).stem);
        if (isOutputGod(god)) {
          outputDate = d;
          break;
        }
      }
      expect(outputDate, isNotNull);
      final other = DateTime(2026, 11, 12);
      final c = scoreTimingOptions(
        saju: saju,
        topic: '출산',
        dateA: outputDate!,
        dateB: other,
      );
      expect(
        c.scoreA,
        (scoreDay(saju, outputDate) + 5).clamp(0, 100),
      );
      expect(c.reasons.any((r) => r.contains('식상')), isTrue);
    });

    test('기타는 보너스가 없어 날짜 점수 그대로다', () {
      final a = DateTime(2026, 11, 20);
      final b = DateTime(2026, 11, 25);
      final c = scoreTimingOptions(
        saju: saju,
        topic: '기타',
        dateA: a,
        dateB: b,
      );
      expect(c.scoreA, scoreDay(saju, a));
      expect(c.scoreB, scoreDay(saju, b));
    });
  });
}
