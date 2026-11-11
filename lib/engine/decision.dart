// 결정 엔진 — 결정 지수·양자택일·30일 길일·간이 대운·근거 3줄 (순수 Dart)
//
// 기반: saju.dart의 간이 만세력. 일주 기준일(2000-01-01 = 무오일)과
// 60갑자 표를 그대로 쓴다. 모든 점수는 결정적이다 (같은 입력 → 같은 결과).
// 점수는 "사주 흐름상 유리한 정도"를 나타낼 뿐, 결과 보장이 아니다.

import '../models.dart';
import 'saju.dart';

const List<String> _stems = [
  '갑',
  '을',
  '병',
  '정',
  '무',
  '기',
  '경',
  '신',
  '임',
  '계',
];
const List<String> _branches = [
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

/// 특정 날짜의 일주(日柱). 23시 자시 보정은 하지 않는다 (날짜 기준).
SajuPillar dayPillar(DateTime date) {
  final anchor = DateTime(2000, 1, 1); // 무오일 (saju.dart와 같은 기준일)
  final d = DateTime(date.year, date.month, date.day);
  final diff = d.difference(anchor).inDays;
  final idx = (((55 + diff - 1) % 60) + 60) % 60 + 1; // 1=갑자 … 55=무오
  return SajuPillar(_stems[(idx - 1) % 10], _branches[(idx - 1) % 12]);
}

/// 하루의 결정 지수 (0~100). 그날의 일진 오행이 내 사주와 얼마나 잘 맞는지.
///
/// - 천간: 용신 +25, 조후 +10, 나를 생해주는 오행(인성) +15, 나와 같은 오행(비겁) +10,
///   내가 생해주는 오행(식상) +10, 내가 극하는 오행(재성) +5, 나를 극하는 오행(관성) -10
/// - 지지: 용신 +12, 조후 +5, 나를 극하는 오행 -5
int scoreDay(SajuResult saju, DateTime date) {
  final pillar = dayPillar(date);
  final stemEl = stemElement(pillar.stem);
  final branchEl = branchElement(pillar.branch);
  final yongsin = saju.yongsin;
  final johu = saju.johu;
  final me = saju.dayElement;

  var score = 50;
  if (yongsin != null && stemEl == yongsin) score += 25;
  if (johu != null && stemEl == johu) score += 10;
  if (generatesTo(stemEl, me)) score += 15;
  if (stemEl == me) score += 10;
  if (generatesTo(me, stemEl)) score += 10;
  if (controlsTo(me, stemEl)) score += 5;
  if (controlsTo(stemEl, me)) score -= 10;

  if (yongsin != null && branchEl == yongsin) score += 12;
  if (johu != null && branchEl == johu) score += 5;
  if (controlsTo(branchEl, me)) score -= 5;

  return score.clamp(0, 100);
}

/// 오늘의 결정 지수 (scoreDay의 오늘 버전).
int decisionIndex(SajuResult saju, DateTime now) => scoreDay(saju, now);

/// 점수 구간 라벨.
String scoreLabel(int score) {
  if (score >= 80) return '아주 좋은 날';
  if (score >= 65) return '좋은 날';
  if (score >= 50) return '무난한 날';
  if (score >= 35) return '신중히 결정할 날';
  return '결정을 미루면 좋은 날';
}

/// 길일 1개 — 날짜·점수·이유.
class LuckyDay {
  final DateTime date;
  final int score;
  final String reason;

  const LuckyDay(this.date, this.score, this.reason);
}

String _dayReason(SajuResult saju, DateTime date) {
  final pillar = dayPillar(date);
  final stemEl = stemElement(pillar.stem);
  final branchEl = branchElement(pillar.branch);
  final yongsin = saju.yongsin;
  final johu = saju.johu;
  final me = saju.dayElement;

  if (yongsin != null && stemEl == yongsin) {
    return '용신 ${elementNames[yongsin]} 기운이 강한 날';
  }
  if (yongsin != null && branchEl == yongsin) {
    return '용신 ${elementNames[yongsin]} 기운이 받쳐주는 날';
  }
  if (johu != null && stemEl == johu) {
    return '조후 ${elementNames[johu]} 기운이 채워지는 날';
  }
  if (generatesTo(stemEl, me)) {
    return '${elementNames[stemEl]} 기운이 나를 생해주는 날';
  }
  return '오행 흐름이 안정적인 날';
}

/// 앞으로 [days]일 전체의 날짜별 점수를 날짜 순으로 돌려준다 (달력 뷰용).
List<LuckyDay> dayScores(
  SajuResult saju,
  DateTime from, {
  int days = 30,
}) {
  final start = DateTime(from.year, from.month, from.day);
  return [
    for (var i = 0; i < days; i++)
      LuckyDay(
        start.add(Duration(days: i)),
        scoreDay(saju, start.add(Duration(days: i))),
        _dayReason(saju, start.add(Duration(days: i))),
      ),
  ];
}

/// 한 달의 결정 지수 요약.
class YearMonthScore {
  final int month;
  final double avgScore;
  final DateTime bestDay;
  final int bestScore;

  const YearMonthScore(this.month, this.avgScore, this.bestDay, this.bestScore);
}

/// 한 해(1~12월)의 월별 결정 지수 요약 — 신년 운세(올해의 결정형)용.
/// 월 평균 지수·그 달의 가장 좋은 날을 돌려준다.
List<YearMonthScore> yearMonthScores(SajuResult saju, int year) {
  final result = <YearMonthScore>[];
  for (var month = 1; month <= 12; month++) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    var sum = 0;
    var bestDay = DateTime(year, month, 1);
    var bestScore = -1;
    for (var day = 1; day <= daysInMonth; day++) {
      final d = DateTime(year, month, day);
      final s = scoreDay(saju, d);
      sum += s;
      if (s > bestScore) {
        bestScore = s;
        bestDay = d;
      }
    }
    result.add(YearMonthScore(month, sum / daysInMonth, bestDay, bestScore));
  }
  return result;
}

/// 앞으로 [days]일 중 점수가 가장 높은 날 [count]개를 날짜 순으로 돌려준다.
List<LuckyDay> luckyDays(
  SajuResult saju,
  DateTime from, {
  int days = 30,
  int count = 3,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final scored = <LuckyDay>[];
  for (var i = 0; i < days; i++) {
    final d = start.add(Duration(days: i));
    scored.add(LuckyDay(d, scoreDay(saju, d), _dayReason(saju, d)));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  final top = scored.take(count).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return top;
}

/// 지지 육충(六沖) — 마주 보는 지지끼리 충한다 (자↔오, 축↔미, 인↔신,
/// 묘↔유, 진↔술, 사↔해). 그날의 지지와 내 일지가 충이면 그날은 피하는 날이다.
bool branchesClash(String a, String b) {
  final ai = _branches.indexOf(a);
  final bi = _branches.indexOf(b);
  if (ai < 0 || bi < 0) return false;
  return (ai - bi).abs() == 6;
}

/// 그날의 지지가 내 일지와 충하는지.
bool dayBranchClashes(SajuResult saju, DateTime date) {
  return branchesClash(dayPillar(date).branch, saju.day.branch);
}

/// 주의일 1개의 이유 — 왜 피해야 하는 날인지.
String _cautionReason(SajuResult saju, DateTime date) {
  final pillar = dayPillar(date);
  final stemEl = stemElement(pillar.stem);
  final branchEl = branchElement(pillar.branch);
  final me = saju.dayElement;

  if (controlsTo(stemEl, me)) {
    return '나를 극하는 ${elementNames[stemEl]} 기운이 강한 날이에요. 큰 결정은 피하세요.';
  }
  if (controlsTo(branchEl, me)) {
    return '나를 극하는 ${elementNames[branchEl]} 기운이 받쳐요. 무리한 약속은 잡지 않는 게 좋아요.';
  }
  if (dayBranchClashes(saju, date)) {
    return '일지와 충하는 날이에요. 중요한 일은 다음 날로 미루는 게 좋아요.';
  }
  return '결정 지수가 낮은 날이에요. 큰 결정보다 작은 일부터 정리하세요.';
}

/// 앞으로 [days]일 중 점수가 가장 낮은 날 [count]개를 날짜 순으로 돌려준다.
/// 좋은 날만큼 "피해야 할 날"도 의사결정자에게는 가치가 크다.
List<LuckyDay> worstDays(
  SajuResult saju,
  DateTime from, {
  int days = 30,
  int count = 2,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final scored = <LuckyDay>[];
  for (var i = 0; i < days; i++) {
    final d = start.add(Duration(days: i));
    scored.add(LuckyDay(d, scoreDay(saju, d), _cautionReason(saju, d)));
  }
  scored.sort((a, b) => a.score.compareTo(b.score));
  final bottom = scored.take(count).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return bottom;
}

/// 우리 가족 공통 길일 — 가족 보관함에 등록된 모두에게 좋은 날 [count]개.
///
/// 가족 점수는 구성원 중 가장 낮은 지수(가장 약한 고리)다. 한 명이라도
/// 나쁜 날은 가족 공통 길일이 될 수 없다. 일지 충인 구성원이 있으면
/// 그 구성원의 지수에서 20점을 깎고 본다.
List<LuckyDay> familyLuckyDays(
  List<SajuResult> sajus,
  DateTime from, {
  int days = 30,
  int count = 3,
}) {
  if (sajus.isEmpty) return [];
  final start = DateTime(from.year, from.month, from.day);
  final scored = <LuckyDay>[];
  for (var i = 0; i < days; i++) {
    final d = start.add(Duration(days: i));
    var familyScore = 100;
    for (final saju in sajus) {
      var s = scoreDay(saju, d);
      if (dayBranchClashes(saju, d)) s = (s - 20).clamp(0, 100);
      if (s < familyScore) familyScore = s;
    }
    final reason = familyScore >= 65
        ? '가족 모두에게 좋은 날이에요 (가장 낮은 지수 $familyScore점)'
        : '가족 모두에게 무난한 날이에요 (가장 낮은 지수 $familyScore점)';
    scored.add(LuckyDay(d, familyScore, reason));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  final top = scored.take(count).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return top;
}

/// A/B 양자택일 비교 결과.
class DecisionComparison {
  /// 'A' | 'B' | '비슷함'
  final String recommendation;
  final int scoreA;
  final int scoreB;
  final String reason;

  const DecisionComparison(
    this.recommendation,
    this.scoreA,
    this.scoreB,
    this.reason,
  );
}

/// 두 날짜의 결정 지수를 비교한다. 점수 차가 10점 미만이면 '비슷함'.
DecisionComparison compareOptions(
  SajuResult saju,
  DateTime dateA,
  DateTime dateB,
) {
  final a = scoreDay(saju, dateA);
  final b = scoreDay(saju, dateB);
  if ((a - b).abs() < 10) {
    return DecisionComparison(
      '비슷함',
      a,
      b,
      '두 날의 흐름 차이가 크지 않아요. 사주 흐름만으로는 우열을 가리기 어려우니, 현실 조건을 더 따져보세요.',
    );
  }
  if (a > b) {
    return DecisionComparison(
      'A',
      a,
      b,
      'A안 날짜의 결정 지수가 B안보다 ${a - b}점 높아요. 사주 흐름상 A안이 유리합니다.',
    );
  }
  return DecisionComparison(
    'B',
    a,
    b,
    'B안 날짜의 결정 지수가 A안보다 ${b - a}점 높아요. 사주 흐름상 B안이 유리합니다.',
  );
}

/// 오늘 피할 것 1줄 — 오늘 일진에서 나를 극하는 기운이 있으면 그 기운을 짚는다.
String avoidLine(SajuResult saju, DateTime now) {
  final pillar = dayPillar(now);
  final stemEl = stemElement(pillar.stem);
  final branchEl = branchElement(pillar.branch);
  final me = saju.dayElement;

  if (controlsTo(stemEl, me)) {
    return '오늘은 ${elementNames[stemEl]} 기운이 강해요. 중요한 결정을 서두르지 않는 게 좋아요.';
  }
  if (controlsTo(branchEl, me)) {
    return '오늘은 ${elementNames[branchEl]} 기운이 받쳐요. 무리한 약속은 잡지 않는 게 좋아요.';
  }
  final score = scoreDay(saju, now);
  if (score < 50) {
    return '오늘은 큰 결정보다 작은 일부터 정리하는 게 좋아요.';
  }
  return '오늘은 무리한 약속을 잡지 않는 게 좋아요.';
}

// ── 간이 대운 (10년 운) ──────────────────────────────────────────────
// 절기 간이표 기준. 전문 감정이 아니라 "지금 흐르는 10년 기운"의 참고값이다.
// - 순행/역행: 남성+양간 또는 여성+음간 → 순행, 그 외 역행.
// - 시작 나이: 출생일부터 다음 절기까지의 일수 ÷ 3 (1~10세로 반올림).
// - 대운 간지: 월주에서 10년마다 한 칸씩 이동한다.

const List<(int, int)> _termDates = [
  (1, 6),
  (2, 4),
  (3, 6),
  (4, 5),
  (5, 6),
  (6, 6),
  (7, 7),
  (8, 8),
  (9, 8),
  (10, 8),
  (11, 8),
  (12, 7),
];

bool _isYangStem(String stem) => _stems.indexOf(stem) % 2 == 0;

/// 대운 시작 나이 (1~10). 출생일부터 다음 절기까지의 일수 ÷ 3.
int daewoonStartAge(DateTime birth) {
  final b = DateTime(birth.year, birth.month, birth.day);
  DateTime? nextTerm;
  for (final (m, d) in _termDates) {
    final t = DateTime(b.year, m, d);
    if (t.isAfter(b)) {
      nextTerm = t;
      break;
    }
  }
  nextTerm ??= DateTime(b.year + 1, _termDates.first.$1, _termDates.first.$2);
  final days = nextTerm.difference(b).inDays;
  return (days / 3).round().clamp(1, 10);
}

/// 현재 대운 간지. 대운 시작 전이면 null.
SajuPillar? currentDaewoon(BabyInfo baby, SajuResult saju, DateTime now) {
  final birth = DateTime(baby.birth.year, baby.birth.month, baby.birth.day);
  var age = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    age -= 1;
  }
  final startAge = daewoonStartAge(birth);
  // Dart의 ~/는 0 쪽으로 버림이라 (age - startAge)가 음수여도 0이 될 수 있다.
  // 대운 시작 전인지는 나이로 직접 판정한다.
  if (age < startAge) return null;
  final steps = (age - startAge) ~/ 10;

  final forward =
      (baby.gender == Gender.boy && _isYangStem(saju.year.stem)) ||
      (baby.gender == Gender.girl && !_isYangStem(saju.year.stem));
  final dir = forward ? 1 : -1;
  final stemIdx = (_stems.indexOf(saju.month.stem) + dir * steps) % 10;
  final branchIdx = (_branches.indexOf(saju.month.branch) + dir * steps) % 12;
  return SajuPillar(
    _stems[(stemIdx + 10) % 10],
    _branches[(branchIdx + 12) % 12],
  );
}

/// 근거 3줄 — 용신·일진·대운. "같은 계산에서 나온 결과입니다"의 근거다.
List<String> evidenceLines(BabyInfo baby, SajuResult saju, DateTime now) {
  final lines = <String>[];

  // 1. 용신
  if (saju.yongsin != null) {
    lines.add(
      '용신은 ${elementNames[saju.yongsin]} 기운이에요. ${elementNames[saju.yongsin]}이 강한 날에 결정하면 흐름을 탈 수 있어요.',
    );
  } else {
    final lacking = lackingElements(saju.elementCounts);
    lines.add(
      '부족한 오행은 ${lacking.map((e) => elementNames[e]).join('·')}이에요. 이 기운을 채우는 날짜를 길일로 골랐어요.',
    );
  }

  // 2. 일진
  final pillar = dayPillar(now);
  final index = scoreDay(saju, now);
  lines.add(
    '오늘 일진은 ${pillar.stem}${pillar.branch} — ${elementNames[stemElement(pillar.stem)]} 기운이 강해요. 오늘의 결정 지수는 $index점이에요.',
  );

  // 3. 대운
  final daewoon = currentDaewoon(baby, saju, now);
  if (daewoon == null) {
    lines.add('대운이 시작되기 전이에요. 지금은 월운의 흐름을 먼저 보세요.');
  } else {
    final el = stemElement(daewoon.stem);
    final extra = saju.yongsin != null && el == saju.yongsin
        ? '용신과 같은 기운이라 결정을 밀어주는 시기에요.'
        : '지금 대운의 ${elementNames[el]} 기운을 참고하세요.';
    lines.add('지금 대운은 ${daewoon.stem}${daewoon.branch} — ${elementNames[el]} 기운이 흐르고 있어요. $extra');
  }

  return lines;
}
