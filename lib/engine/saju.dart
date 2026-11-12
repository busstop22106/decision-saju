import '../models.dart';

/// 간이 만세력 기반 사주 계산기
///
/// - 연주: 입춘(2/4) 기준 변경
/// - 월주: 12절기 간이 날짜표 + 오호둔법 (절입 시각은 연도별 천문표가 필요해
///   경계일 ±1일 출생자는 전문 만세력 대조가 필요합니다)
/// - 일주: 2000-01-01 = 무오일 기준일 검증값 사용, 23시 이후는 다음날
/// - 시주: 오자둔법, 진태양시 보정 미적용
/// - 오행 분포: 천간 4 + 지지 본기 4 = 8자 카운트 (지장간 여·중기 미포함)
/// - 용신: 신강/신약 + 조후 간이 로직 (전문 감정 아님 — 앱 내 고지)

const List<String> _stems = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
const List<String> _branches = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];

String stemElement(String stem) {
  final i = _stems.indexOf(stem);
  return ['목', '목', '화', '화', '토', '토', '금', '금', '수', '수'][i];
}

/// 지지 본기(本氣) 오행 — 간이법
String branchElement(String branch) {
  switch (branch) {
    case '자':
    case '해':
      return '수';
    case '인':
    case '묘':
      return '목';
    case '사':
    case '오':
      return '화';
    case '신':
    case '유':
      return '금';
    default:
      return '토'; // 축진술미
  }
}

const Map<String, String> _generates = {
  '목': '화', '화': '토', '토': '금', '금': '수', '수': '목',
};
const Map<String, String> _controls = {
  '목': '토', '토': '수', '수': '화', '화': '금', '금': '목',
};

/// a가 b를 생하는지 (오행 상생)
bool generatesTo(String a, String b) => _generates[a] == b;

/// a가 b를 극하는지 (오행 상극)
bool controlsTo(String a, String b) => _controls[a] == b;

String generatedBy(String e) =>
    _generates.entries.firstWhere((en) => en.value == e).key;
String controlledBy(String e) =>
    _controls.entries.firstWhere((en) => en.value == e).key;

/// 절기 간이표: (월, 일) → 월지
const List<(int, int, String)> _solarTerms = [
  (1, 6, '축'), // 소한
  (2, 4, '인'), // 입춘
  (3, 6, '묘'), // 경칩
  (4, 5, '진'), // 청명
  (5, 6, '사'), // 입하
  (6, 6, '오'), // 망종
  (7, 7, '미'), // 소서
  (8, 8, '신'), // 입추
  (9, 8, '유'), // 백로
  (10, 8, '술'), // 한로
  (11, 8, '해'), // 입동
  (12, 7, '자'), // 대설
];

String _monthBranch(int month, int day) {
  // 1월 1일~소한(1/6) 전은 전년도 자월(동지월)이다
  String branch = '자';
  for (final (m, d, b) in _solarTerms) {
    if (month > m || (month == m && day >= d)) {
      branch = b;
    } else {
      break;
    }
  }
  return branch;
}

/// 오호둔법: 연간 천간 → 정월(인월) 천간
String _firstMonthStem(String yearStem) {
  switch (yearStem) {
    case '갑':
    case '기':
      return '병';
    case '을':
    case '경':
      return '무';
    case '병':
    case '신':
      return '경';
    case '정':
    case '임':
      return '임';
    default: // 무, 계
      return '갑';
  }
}

/// 오자둔법: 일간 → 자시 천간
String _firstHourStem(String dayStem) {
  switch (dayStem) {
    case '갑':
    case '기':
      return '갑';
    case '을':
    case '경':
      return '병';
    case '병':
    case '신':
      return '무';
    case '정':
    case '임':
      return '경';
    default: // 무, 계
      return '임';
  }
}

/// 특정 날짜의 연주 (입춘 2/4 기준). 날짜만으로 판정한다.
/// computeSaju 안의 연주 계산과 같은 로직이다 — 세운(올해의 운)을 볼 때 쓴다.
SajuPillar yearPillarFor(DateTime date) {
  var y = date.year;
  if (date.month == 1 || (date.month == 2 && date.day < 4)) {
    y -= 1;
  }
  return SajuPillar(_stems[(y - 4) % 10], _branches[(y - 4) % 12]);
}

/// 특정 날짜의 월주 (12절기 간이표 + 오호둔법). 날짜만으로 판정한다.
/// computeSaju 안의 월주 계산과 같은 로직이다 — 월운(이달의 운)을 볼 때 쓴다.
SajuPillar monthPillarFor(DateTime date) {
  final yearStem = yearPillarFor(date).stem;
  final mBranch = _monthBranch(date.month, date.day);
  final mBranchIdx = _branches.indexOf(mBranch);
  final baseStem = _firstMonthStem(yearStem);
  final baseIdx = _stems.indexOf(baseStem);
  final mStem = _stems[(baseIdx + (mBranchIdx - 2 + 12) % 12) % 10];
  return SajuPillar(mStem, mBranch);
}

/// 천간의 음양 — 짝수 인덱스(갑·병·무·경·임)가 양간, 홀수가 음간이다.
bool isYangStem(String stem) => _stems.indexOf(stem) % 2 == 0;

/// 십성(十星) — 일간을 기준으로 상대 천간이 어떤 역할인지.
/// 비견·겁재(나와 같은 오행), 식신·상관(내가 생하는 오행),
/// 편재·정재(내가 극하는 오행), 편관·정관(나를 극하는 오행),
/// 편인·정인(나를 생하는 오행). 음양이 같으면 편(偏), 다르면 정(正)이다.
String tenGod(String dayMasterStem, String targetStem) {
  final meEl = stemElement(dayMasterStem);
  final el = stemElement(targetStem);
  final sameYinYang = isYangStem(dayMasterStem) == isYangStem(targetStem);
  if (el == meEl) return sameYinYang ? '비견' : '겁재';
  if (generatesTo(meEl, el)) return sameYinYang ? '식신' : '상관';
  if (controlsTo(meEl, el)) return sameYinYang ? '편재' : '정재';
  if (controlsTo(el, meEl)) return sameYinYang ? '편관' : '정관';
  return sameYinYang ? '편인' : '정인';
}

/// 십성이 관성(정관·편관)인지 — 사업·직장·변동의 별.
bool isOfficerGod(String tenGodName) =>
    tenGodName == '정관' || tenGodName == '편관';

/// 십성이 인성(정인·편인)인지 — 안정·보호·집의 별.
bool isSealGod(String tenGodName) =>
    tenGodName == '정인' || tenGodName == '편인';

/// 십성이 재성(정재·편재)인지 — 재물·배우자(남명)의 별.
bool isWealthGod(String tenGodName) =>
    tenGodName == '정재' || tenGodName == '편재';

/// 십성이 식상(식신·상관)인지 — 표현·자녀의 별.
bool isOutputGod(String tenGodName) =>
    tenGodName == '식신' || tenGodName == '상관';

/// 십성이 비겁(비견·겁재)인지 — 나와 같은 오행, 동료·유지의 별.
bool isPeerGod(String tenGodName) =>
    tenGodName == '비견' || tenGodName == '겁재';

/// 배우자성 — 남명은 재성(정재·편재)이 아내성, 여명은 관성(정관·편관)이 남편성이다.
bool isSpouseStar(Gender gender, String dayMasterStem, String targetStem) {
  final god = tenGod(dayMasterStem, targetStem);
  return gender == Gender.boy ? isWealthGod(god) : isOfficerGod(god);
}

/// 육합(六合) — 자↔축, 인↔해, 묘↔술, 진↔유, 사↔신, 오↔미.
bool branchesCombine(String a, String b) {
  const pairs = {
    '자': '축',
    '축': '자',
    '인': '해',
    '해': '인',
    '묘': '술',
    '술': '묘',
    '진': '유',
    '유': '진',
    '사': '신',
    '신': '사',
    '오': '미',
    '미': '오',
  };
  return pairs[a] == b;
}

/// 삼합(三合) — 같은 삼합국에 속하는 서로 다른 지지인지.
/// 신자진(수국)·해묘미(목국)·인오술(화국)·사유축(금국).
bool branchesTriple(String a, String b) {
  if (a == b) return false;
  const groups = [
    {'신', '자', '진'},
    {'해', '묘', '미'},
    {'인', '오', '술'},
    {'사', '유', '축'},
  ];
  return groups.any((g) => g.contains(a) && g.contains(b));
}

/// 역마(驛馬) — 일지를 기준으로 이동·변동의 별.
/// 인오술(화국)은 신, 신자진(수국)은 인, 사유축(금국)은 해, 해묘미(목국)는 사.
String travellingHorse(String dayBranch) {
  if ({'인', '오', '술'}.contains(dayBranch)) return '신';
  if ({'신', '자', '진'}.contains(dayBranch)) return '인';
  if ({'사', '유', '축'}.contains(dayBranch)) return '해';
  return '사'; // 해묘미
}

/// 도화(桃花) — 일지를 기준으로 새로운 인연의 별.
/// 인오술은 묘, 신자진은 유, 사유축은 오, 해묘미는 자.
String peachBlossom(String dayBranch) {
  if ({'인', '오', '술'}.contains(dayBranch)) return '묘';
  if ({'신', '자', '진'}.contains(dayBranch)) return '유';
  if ({'사', '유', '축'}.contains(dayBranch)) return '오';
  return '자'; // 해묘미
}

SajuResult computeSaju(BabyInfo baby) {
  final notes = <String>[
    '간이 만세력으로 계산한 사주예요. 절기 경계일에 태어났다면, 경계를 어느 쪽으로 보느냐에 따라 결과가 달라질 수 있어요.',
  ];

  // ── 기준일: 23시 이후 출생은 자시(子時)라 다음날로 본다 ──
  // 일주뿐 아니라 연주(입춘 판정)·월주(절기 판정)도 같은 기준일을 써야 한다.
  // 2024-02-03 23시생은 출생일 기준이면 계묘년 을축월이지만,
  // 다음날(2/4 입춘) 기준이면 갑진년 병인월이다.
  var dayDate = DateTime(baby.birth.year, baby.birth.month, baby.birth.day);
  if (!baby.timeUnknown && baby.birthHour != null && baby.birthHour! >= 23) {
    dayDate = dayDate.add(const Duration(days: 1));
    notes.add('23시 이후 출생이라 연·월·일주를 다음날 기준으로 계산했어요.');
  }

  // ── 연주 (입춘 기준) ──
  if (dayDate.month == 1 || (dayDate.month == 2 && dayDate.day < 4)) {
    notes.add('입춘(2/4) 이전 출생이라 연주는 전해 기준으로 계산했어요.');
  }
  final yearPillar = yearPillarFor(dayDate);
  final yearStem = yearPillar.stem;
  final yearBranch = yearPillar.branch;

  // ── 월주 ──
  final monthPillar = monthPillarFor(dayDate);
  final mStem = monthPillar.stem;
  final mBranch = monthPillar.branch;

  // ── 일주 (기준일 2000-01-01 = 무오) ──
  // dayDate는 위에서 23시 자시 보정이 끝난 기준일이다.
  // UTC 날짜로 일수 차이를 구한다. 로컬 시간으로 구하면 DST 전환일에
  // 하루가 어긋날 수 있다 (한국은 DST가 없어 영향이 작지만, 안전하게).
  final anchor = DateTime.utc(2000, 1, 1);
  final dayDateUtc =
      DateTime.utc(dayDate.year, dayDate.month, dayDate.day);
  final diff = dayDateUtc.difference(anchor).inDays;
  final idx = (((55 + diff - 1) % 60) + 60) % 60 + 1; // 1=갑자 … 55=무오
  final dayStem = _stems[(idx - 1) % 10];
  final dayBranch = _branches[(idx - 1) % 12];

  // ── 시주 ──
  SajuPillar? hourPillar;
  if (!baby.timeUnknown && baby.birthHour != null) {
    final h = baby.birthHour!;
    final hBranchIdx = ((h + 1) ~/ 2) % 12; // 0=자
    final hBase = _firstHourStem(dayStem);
    final hStem =
        _stems[((_stems.indexOf(hBase) + hBranchIdx) % 10 + 10) % 10];
    hourPillar = SajuPillar(hStem, _branches[hBranchIdx]);
  } else {
    notes.add('태어난 시간을 입력하지 않아 시주 없이 6글자로 분석했어요.');
  }

  // ── 오행 분포 (천간 + 지지 본기) ──
  final counts = {'목': 0, '화': 0, '토': 0, '금': 0, '수': 0};
  final pillars = [
    SajuPillar(yearStem, yearBranch),
    SajuPillar(mStem, mBranch),
    SajuPillar(dayStem, dayBranch),
    ?hourPillar,
  ];
  for (final p in pillars) {
    final se = stemElement(p.stem);
    final be = branchElement(p.branch);
    counts[se] = counts[se]! + 1;
    counts[be] = counts[be]! + 1;
  }

  // ── 신강 / 신약 ──
  final me = stemElement(dayStem);
  final help = counts[me]! + counts[generatedBy(me)]!;
  final drain = counts[_generates[me]]! +
      counts[_controls[me]]! +
      counts[controlledBy(me)]!;
  final strongBody = help > drain;

  // ── 조후 ──
  String? johu;
  if (['해', '자', '축'].contains(mBranch)) {
    johu = '화'; // 겨울생은 화 기운 필요
  } else if (['사', '오', '미'].contains(mBranch)) {
    johu = '수'; // 여름생은 수 기운 필요
  }

  // ── 용신 / 희신 (간이) ──
  String? yongsin;
  String? huishin;
  int cnt(String e) => counts[e] ?? 0;
  if (johu != null && cnt(johu) == 0) {
    yongsin = johu;
  } else if (strongBody) {
    // 설기(식상·재성·관성) 중 가장 부족한 오행
    // ignore: unnecessary_non_null_assertion
    final cands = <String>[_generates[me]!, _controls[me]!, controlledBy(me)!];
    cands.sort((a, b) => cnt(a).compareTo(cnt(b)));
    yongsin = cands.first;
    // 희신은 조후가 우선이지만, 조후가 용신과 같으면 다음 후보를 쓴다.
    // (기존에는 조후가 용신과 같으면 희신이 null이 됐다.)
    huishin = (johu != null && johu != yongsin)
        ? johu
        : (cands.length > 1 ? cands[1] : null);
  } else {
    // 생조(인성·비겁) 중 가장 부족한 오행
    // ignore: unnecessary_non_null_assertion
    final cands = <String>[generatedBy(me)!, me];
    cands.sort((a, b) => cnt(a).compareTo(cnt(b)));
    yongsin = cands.first;
    huishin = (johu != null && johu != yongsin)
        ? johu
        : (cands.length > 1 ? cands[1] : null);
  }
  if (huishin == yongsin) huishin = null;

  return SajuResult(
    year: SajuPillar(yearStem, yearBranch),
    month: SajuPillar(mStem, mBranch),
    day: SajuPillar(dayStem, dayBranch),
    hour: hourPillar,
    dayMaster: dayStem,
    dayElement: me,
    elementCounts: counts,
    strongBody: strongBody,
    yongsin: yongsin,
    huishin: huishin,
    johu: johu,
    notes: notes,
  );
}

/// 오행 이름 (화면에 표시용)
const Map<String, String> elementNames = {
  '목': '목(木)',
  '화': '화(火)',
  '토': '토(土)',
  '금': '금(金)',
  '수': '수(水)',
};

/// 사주에서 개수가 가장 적은 오행들을 목→화→토→금→수 순서로 돌려준다.
/// 동점인 오행은 모두 포함한다. 없는 오행은 0개로 취급한다.
/// 이름 한자에 어떤 오행을 더하면 보완이 되는지 알려주는 기준이다.
List<String> lackingElements(Map<String, int> counts) {
  const order = ['목', '화', '토', '금', '수'];
  var min = 1 << 30;
  for (final e in order) {
    final c = counts[e] ?? 0;
    if (c < min) min = c;
  }
  return order.where((e) => (counts[e] ?? 0) == min).toList();
}

const Map<String, String> elementColors = {
  '목': '초록',
  '화': '빨강',
  '토': '노랑',
  '금': '흰색',
  '수': '검정',
};
