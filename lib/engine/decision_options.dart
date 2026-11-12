// 카테고리별 A/B 선택지 + 사주 기반 채점 (순수 Dart)
//
// - 선택형(이직·이사·결혼): 고정된 A/B 선택지를 내 사주 + 세운(올해) +
//   월운(이달) + 대운으로 채점한다. 날짜를 쓰지 않으므로, 두 선택지의 날짜가
//   같아서 점수가 똑같이 나오는 문제가 없다.
// - 날짜형(개업·출산·기타): A/B가 날짜라 기존 날짜 점수(scoreDay)로 비교한다.
//   개업은 재성, 출산은 식상 기운이 있는 날에 +5점을 더한다.
//
// 채점 근거는 전통 사주 개념만 쓴다. 십성(관성·인성·재성·식상·비겁),
// 육합·삼합·육충, 역마·도화, 대운 교체. 모든 점수는 결정적이다
// (같은 입력 → 같은 결과). 점수는 "사주 흐름상 유리한 정도"를 나타낼 뿐,
// 결과 보장이 아니다.
//
// 간이 만세력 기준이다. 절기 경계일·진태양시 보정 등 전문 감정의 세부 사항은
// saju.dart의 주석을 참고한다.

import '../models.dart';
import 'decision.dart';
import 'saju.dart';

/// 결정 리포트의 종류 — 선택지를 고르는지, 날짜를 고르는지.
enum DecisionMode { choice, timing }

/// 카테고리별 설정.
class DecisionTopicConfig {
  final DecisionMode mode;

  /// 선택형일 때 고정 A/B 문구. 날짜형·자유 입력은 비워둔다.
  final String optionA;
  final String optionB;

  /// 자유 입력(기타)인지 — A/B를 직접 적는다.
  final bool freeText;

  /// 폼에 보여줄 설명.
  final String hint;

  const DecisionTopicConfig({
    required this.mode,
    required this.optionA,
    required this.optionB,
    required this.freeText,
    required this.hint,
  });
}

DecisionTopicConfig configForTopic(String topic) {
  switch (topic) {
    case '이직':
      return const DecisionTopicConfig(
        mode: DecisionMode.choice,
        optionA: '지금 회사에 남기',
        optionB: '다른 회사로 이직하기',
        freeText: false,
        hint: '지금 이 달의 운세와 대운으로 두 선택지를 비교해요. 날짜를 정하지 않아도 돼요.',
      );
    case '이사':
      return const DecisionTopicConfig(
        mode: DecisionMode.choice,
        optionA: '지금 집에 있기',
        optionB: '이사하기',
        freeText: false,
        hint: '지금 이 달의 운세와 대운으로 두 선택지를 비교해요. 날짜를 정하지 않아도 돼요.',
      );
    case '결혼':
      return const DecisionTopicConfig(
        mode: DecisionMode.choice,
        optionA: '지금 사람과 결혼하기',
        optionB: '새로운 인연 찾아보기',
        freeText: false,
        hint: '지금 이 달의 운세와 대운으로 두 선택지를 비교해요. 날짜를 정하지 않아도 돼요.',
      );
    case '개업':
      return const DecisionTopicConfig(
        mode: DecisionMode.timing,
        optionA: '',
        optionB: '',
        freeText: false,
        hint: '두 날짜 중 개업하기 더 좋은 날을 비교해요. 재성 기운이 있는 날이 유리해요.',
      );
    case '출산':
      return const DecisionTopicConfig(
        mode: DecisionMode.timing,
        optionA: '',
        optionB: '',
        freeText: false,
        hint: '두 날짜 중 출산하기 더 좋은 날을 비교해요. 식상 기운이 있는 날이 유리해요.',
      );
    default: // 기타
      return const DecisionTopicConfig(
        mode: DecisionMode.timing,
        optionA: '',
        optionB: '',
        freeText: true,
        hint: '두 가지 선택지와 날짜를 적어주세요. 날짜의 사주 흐름으로 비교해요.',
      );
  }
}

/// 채점 요인 1개 — A안에 더하는 점수, B안에 더하는 점수, 이유.
/// 보통 한쪽만 양수다. 양쪽 모두 양수인 요인도 reasons 표시에서 양쪽을 함께 적는다.
class _Factor {
  final int aPoints;
  final int bPoints;
  final String reason;

  const _Factor(this.aPoints, this.bPoints, this.reason);

  int get total => aPoints + bPoints;
}

/// 점수 차가 10점 미만이면 '비슷함' (compareOptions와 같은 기준).
String _recommendationFor(int scoreA, int scoreB) {
  if ((scoreA - scoreB).abs() < 10) return '비슷함';
  return scoreA > scoreB ? 'A' : 'B';
}

String _conclusionReason(
  String recommendation,
  int scoreA,
  int scoreB,
  String labelA,
  String labelB,
) {
  if (recommendation == 'A') {
    return 'A안($labelA)의 점수가 B안보다 ${scoreA - scoreB}점 높아요. 사주 흐름상 A안이 유리합니다.';
  }
  if (recommendation == 'B') {
    return 'B안($labelB)의 점수가 A안보다 ${scoreB - scoreA}점 높아요. 사주 흐름상 B안이 유리합니다.';
  }
  return '두 선택지의 흐름 차이가 크지 않아요. 사주 흐름만으로는 우열을 가리기 어려우니, 현실 조건을 더 따져보세요.';
}

/// 천간 십성이 선택지에 주는 방향 (단위 가중치).
/// (A안 점수, B안 점수) — 이직·이사는 관성=이동, 인성=유지.
/// 결혼은 배우자성만 A안(지금 사람과 결혼) 쪽으로 본다.
(int, int) _stemPoints(String topic, Gender gender, String god) {
  if (topic == '결혼') {
    if ((gender == Gender.boy && isWealthGod(god)) ||
        (gender == Gender.girl && isOfficerGod(god))) {
      return (1, 0);
    }
    return (0, 0);
  }
  // 이직·이사
  if (isOfficerGod(god)) return (0, 1);
  if (isSealGod(god)) return (1, 0);
  return (0, 0);
}

/// 선택형 채점 — 내 사주 + 세운(올해) + 월운(이달) + 대운으로 A/B를 비교한다.
///
/// [baby]는 대운 방향·배우자성 판정에 필요한 생년월일·성별이다.
/// [now]는 "이번달 운세"의 기준 날짜다 (보통 오늘).
DecisionComparison scoreChoiceOptions({
  required BabyInfo baby,
  required SajuResult saju,
  required String topic,
  required DateTime now,
}) {
  final config = configForTopic(topic);
  final factors = <_Factor>[];
  final dayBranch = saju.day.branch;
  final dayMaster = saju.dayMaster;
  final yearP = yearPillarFor(now);
  final monthP = monthPillarFor(now);
  final daewoon = currentDaewoon(baby, saju, now);
  final horse = travellingHorse(dayBranch);
  final blossom = peachBlossom(dayBranch);
  final yongsin = saju.yongsin;

  // ── 1. 천간 십성 (대운·세운·월운) ──
  // 가중치: 결혼은 올해를 가장 크게 본다. 이직·이사는 대운을 가장 크게 본다.
  final stemWeights = topic == '결혼'
      ? {'대운': 10, '올해': 12, '이번 달': 8}
      : {'대운': 10, '올해': 8, '이번 달': 6};
  final stemSources = {
    '대운': daewoon,
    '올해': yearP,
    '이번 달': monthP,
  };
  for (final entry in stemSources.entries) {
    final pillar = entry.value;
    if (pillar == null) continue;
    final god = tenGod(dayMaster, pillar.stem);
    final (a, b) = _stemPoints(topic, baby.gender, god);
    if (a == 0 && b == 0) continue;
    final w = stemWeights[entry.key]!;
    final side = a > b ? 'A안' : 'B안';
    final what = topic == '결혼'
        ? '배우자성($god)'
        : isOfficerGod(god)
            ? '관성($god)'
            : '인성($god)';
    factors.add(
      _Factor(
        a * w,
        b * w,
        '${entry.key}(${pillar.stem}${pillar.branch})에 $what 기운이 들어와 $side 쪽이 유리해요.',
      ),
    );
  }

  // ── 2. 역마 (이직·이사만) ──
  if (topic != '결혼') {
    final horseSources = {'올해': (yearP.branch, 8), '이번 달': (monthP.branch, 6)};
    for (final entry in horseSources.entries) {
      if (entry.value.$1 == horse) {
        factors.add(
          _Factor(
            0,
            entry.value.$2,
            '${entry.key}에 역마($horse)가 들어와 이동의 기운이 강해요.',
          ),
        );
      }
    }
    if (daewoon != null && daewoon.branch == horse) {
      factors.add(
        _Factor(0, 6, '대운(${daewoon.stem}${daewoon.branch})에 역마($horse)가 들어와 이동의 기운이 강해요.'),
      );
    }
  }

  // ── 3. 일지 충·합 (배우자궁·자신의 자리와 올해·이달의 관계) ──
  final branchSources = {'올해': yearP.branch, '이번 달': monthP.branch};
  for (final entry in branchSources.entries) {
    final branch = entry.value;
    final clashWeight = topic == '결혼' ? (entry.key == '올해' ? 8 : 5) : (entry.key == '올해' ? 10 : 6);
    final combineWeight = topic == '결혼' ? (entry.key == '올해' ? 10 : 5) : (entry.key == '올해' ? 4 : 2);
    if (branchesClash(branch, dayBranch)) {
      if (topic == '결혼') {
        factors.add(
          _Factor(
            0,
            clashWeight,
            '${entry.key}는 일지($dayBranch)와 충이 있어 지금 인연은 신중히 살펴보세요.',
          ),
        );
      } else {
        factors.add(
          _Factor(
            clashWeight,
            0,
            '${entry.key}는 일지($dayBranch)와 충이 있어 큰 변화는 피하는 게 좋아요.',
          ),
        );
      }
    } else if (branchesCombine(branch, dayBranch) ||
        branchesTriple(branch, dayBranch)) {
      if (topic == '결혼') {
        factors.add(
          _Factor(
            combineWeight,
            0,
            '${entry.key}는 일지($dayBranch)와 합이 들어와 지금 인연이 안정적이에요.',
          ),
        );
      } else {
        factors.add(
          _Factor(
            0,
            combineWeight,
            '${entry.key}는 일지($dayBranch)와 합이 들어와 이동이 순조로워요.',
          ),
        );
      }
    }
  }

  // ── 4. 도화 (결혼만) ──
  if (topic == '결혼') {
    if (yearP.branch == blossom) {
      factors.add(
        _Factor(0, 12, '올해는 도화($blossom)가 들어와 새로운 인연이 들어올 수 있어요.'),
      );
    }
    if (monthP.branch == blossom) {
      factors.add(
        _Factor(0, 8, '이번 달은 도화($blossom)가 들어와 새로운 인연이 들어올 수 있어요.'),
      );
    }
    // 배우자성이 대운·세운·월운 어디에도 없고 도화가 있으면, 새로운 만남 쪽이 유리하다.
    final hasSpouseStar = [
      daewoon?.stem,
      yearP.stem,
      monthP.stem,
    ].any(
      (stem) =>
          stem != null && isSpouseStar(baby.gender, dayMaster, stem),
    );
    final hasBlossom =
        yearP.branch == blossom || monthP.branch == blossom;
    if (!hasSpouseStar && hasBlossom) {
      factors.add(
        _Factor(0, 6, '지금은 배우자성보다 새로운 만남의 기운이 강해요.'),
      );
    }
  }

  // ── 5. 대운 교체 해 (이직·이사만) ──
  if (topic != '결혼') {
    final birth = DateTime(baby.birth.year, baby.birth.month, baby.birth.day);
    final forward =
        (baby.gender == Gender.boy && isYangStem(saju.year.stem)) ||
        (baby.gender == Gender.girl && !isYangStem(saju.year.stem));
    final startAge = daewoonStartAge(birth, forward: forward);
    final age = now.year - birth.year + 1; // 세는나이
    if (age >= startAge && (age - startAge) % 10 == 0) {
      factors.add(
        _Factor(0, 8, '올해는 대운이 바뀌는 해라 이동의 기운이 강해요.'),
      );
    }
  }

  // ── 6. 용신 (이번 달 월간이 용신과 같으면, 그 십성이 가리키는 쪽에 +4) ──
  if (yongsin != null && stemElement(monthP.stem) == yongsin) {
    final god = tenGod(dayMaster, monthP.stem);
    final (a, b) = _stemPoints(topic, baby.gender, god);
    if (a > 0 || b > 0) {
      final side = a > b ? 'A안' : 'B안';
      factors.add(
        _Factor(
          a * 4,
          b * 4,
          '이번 달(${monthP.stem}${monthP.branch})의 ${elementNames[yongsin]} 기운이 용신과 같아 $side 쪽을 밀어줘요.',
        ),
      );
    }
  }

  // ── 합산 (50점 기준, 0~100으로 고정) ──
  // 50점은 중립 기준이다. 요인은 각 선택지의 지지도를 더하는 방식이라
  // 점수는 50점에서 위로만 올라간다. 우열은 두 점수의 차이(10점 기준)로 가린다.
  var scoreA = 50;
  var scoreB = 50;
  for (final f in factors) {
    scoreA += f.aPoints;
    scoreB += f.bPoints;
  }
  scoreA = scoreA.clamp(0, 100);
  scoreB = scoreB.clamp(0, 100);

  // 근거는 기여도가 큰 순서대로 최대 5개까지, 점수를 함께 적는다.
  // 양쪽 모두 양수인 요인은 양쪽 점수를 함께 적는다.
  final sorted = [...factors]..sort((x, y) => y.total.compareTo(x.total));
  final reasons = sorted.take(5).map((f) {
    if (f.aPoints > 0 && f.bPoints > 0) {
      return '${f.reason} (A안 +${f.aPoints}점 · B안 +${f.bPoints}점)';
    }
    final points = f.aPoints > 0 ? f.aPoints : f.bPoints;
    final side = f.aPoints > 0 ? 'A안' : 'B안';
    return '${f.reason} ($side +$points점)';
  }).toList();

  final recommendation = _recommendationFor(scoreA, scoreB);
  return DecisionComparison(
    recommendation,
    scoreA,
    scoreB,
    _conclusionReason(
      recommendation,
      scoreA,
      scoreB,
      config.optionA,
      config.optionB,
    ),
    reasons: reasons,
  );
}

/// 날짜형 채점 — 두 날짜의 결정 지수를 비교한다.
/// 개업은 재성, 출산은 식상 기운이 있는 날에 +5점을 더한다.
DecisionComparison scoreTimingOptions({
  required SajuResult saju,
  required String topic,
  required DateTime dateA,
  required DateTime dateB,
}) {
  var scoreA = scoreDay(saju, dateA);
  var scoreB = scoreDay(saju, dateB);
  final reasons = <String>[
    'A안 날짜: ${dayReason(saju, dateA)}',
    'B안 날짜: ${dayReason(saju, dateB)}',
  ];

  if (topic == '개업' || topic == '출산') {
    final wantGod = topic == '개업' ? '재성' : '식상';
    bool isWant(String god) =>
        topic == '개업' ? isWealthGod(god) : isOutputGod(god);
    final godA = tenGod(saju.dayMaster, dayPillar(dateA).stem);
    final godB = tenGod(saju.dayMaster, dayPillar(dateB).stem);
    if (isWant(godA)) {
      scoreA = (scoreA + 5).clamp(0, 100);
      reasons.add(
        'A안 날짜에는 $wantGod($godA) 기운이 들어와 ${topic == '개업' ? '개업하기 좋은 날' : '출산하기 좋은 날'}이에요 (+5점).',
      );
    }
    if (isWant(godB)) {
      scoreB = (scoreB + 5).clamp(0, 100);
      reasons.add(
        'B안 날짜에는 $wantGod($godB) 기운이 들어와 ${topic == '개업' ? '개업하기 좋은 날' : '출산하기 좋은 날'}이에요 (+5점).',
      );
    }
  }

  final recommendation = _recommendationFor(scoreA, scoreB);
  return DecisionComparison(
    recommendation,
    scoreA,
    scoreB,
    _conclusionReason(
      recommendation,
      scoreA,
      scoreB,
      '${dateA.month}월 ${dateA.day}일',
      '${dateB.month}월 ${dateB.day}일',
    ),
    reasons: reasons,
  );
}
