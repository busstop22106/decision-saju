import '../models.dart';
import 'saju.dart';

/// ── 가족 이름 궁합 ──
/// 가족 구성원(기본 아빠·엄마, 형제·조부모 등 추가 가능)의 사주와
/// 아기 이름이 얼마나 조화를 이루는지 구성원별로 채점해요.
///
/// - 오행 보완 (40점): 구성원 사주에서 부족한 오행을 이름 글자의 오행
///   (한자는 자원오행, 순우리말은 발음오행)이 채워주는지
/// - 용신 조화 (40점): 이름 오행이 구성원의 용신·희신과 상생 관계인지
/// - 띠 궁합 (20점): 구성원 띠와 아기 띠의 삼합·육합·충 관계
///   (띠는 출생연도로 정해지는 고정 요소라 비중을 낮게 뒀어요)
///
/// 전부 간이 계산이에요.

/// 지지 → 띠 이름
const Map<String, String> zodiacNames = {
  '자': '쥐띠',
  '축': '소띠',
  '인': '호랑이띠',
  '묘': '토끼띠',
  '진': '용띠',
  '사': '뱀띠',
  '오': '말띠',
  '미': '양띠',
  '신': '원숭이띠',
  '유': '닭띠',
  '술': '개띠',
  '해': '돼지띠',
};

/// 지지 → 띠 동물 이모지 (관계도 노드 표시용)
const Map<String, String> zodiacEmojis = {
  '자': '🐭',
  '축': '🐮',
  '인': '🐯',
  '묘': '🐰',
  '진': '🐲',
  '사': '🐍',
  '오': '🐴',
  '미': '🐑',
  '신': '🐵',
  '유': '🐔',
  '술': '🐶',
  '해': '🐷',
};

const List<String> _branchesOrder = [
  '자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'
];

/// 삼합(三合) 그룹
const List<Set<String>> _samhap = [
  {'신', '자', '진'},
  {'해', '묘', '미'},
  {'인', '오', '술'},
  {'사', '유', '축'},
];

/// 육합(六合) 쌍
const List<Set<String>> _yukhap = [
  {'자', '축'},
  {'인', '해'},
  {'묘', '술'},
  {'진', '유'},
  {'사', '신'},
  {'오', '미'},
];

/// 두 사람의 띠(지지 2개) 비교에서는 삼합 그룹 3개가 다 모일 수 없으므로,
/// 그룹 2개가 겹치는 경우는 삼합이 아니라 반합(半合)이다.
enum ZodiacRelation { samhap, banhap, yukhap, same, chung, normal }

/// 두 지지 사이의 띠 관계
ZodiacRelation zodiacRelation(String a, String b) {
  if (a == b) return ZodiacRelation.same;
  final pair = {a, b};
  for (final g in _samhap) {
    if (g.contains(a) && g.contains(b)) return ZodiacRelation.banhap;
  }
  for (final p in _yukhap) {
    if (p.length == pair.length && p.containsAll(pair)) {
      return ZodiacRelation.yukhap;
    }
  }
  final ia = _branchesOrder.indexOf(a);
  final ib = _branchesOrder.indexOf(b);
  if (ia >= 0 && ib >= 0 && (ia - ib).abs() == 6) {
    return ZodiacRelation.chung;
  }
  return ZodiacRelation.normal;
}

/// 띠 관계 점수 (20점 만점)
/// 반합은 15점 — 육합(17점)과 같은 띠(13점) 사이.
double zodiacScore(String memberBranch, String babyBranch) {
  switch (zodiacRelation(memberBranch, babyBranch)) {
    case ZodiacRelation.samhap:
      return 20;
    case ZodiacRelation.banhap:
      return 15;
    case ZodiacRelation.yukhap:
      return 17;
    case ZodiacRelation.same:
      return 13;
    case ZodiacRelation.normal:
      return 11;
    case ZodiacRelation.chung:
      return 4;
  }
}

String zodiacLabel(String memberBranch, String babyBranch) {
  switch (zodiacRelation(memberBranch, babyBranch)) {
    case ZodiacRelation.samhap:
      return '삼합(三合)';
    case ZodiacRelation.banhap:
      return '반합(半合)';
    case ZodiacRelation.yukhap:
      return '육합(六合)';
    case ZodiacRelation.same:
      return '같은 띠';
    case ZodiacRelation.normal:
      return '무난한 관계';
    case ZodiacRelation.chung:
      return '충(沖)';
  }
}

/// 역할 이름으로 성별 기호를 돌려준다.
/// '동생'은 역할만으로 성별을 알 수 없어 빈 문자열이다.
String genderSymbolForRole(String role) {
  switch (role) {
    case '아빠':
    case '형':
    case '오빠':
    case '할아버지':
      return '♂';
    case '엄마':
    case '누나':
    case '언니':
    case '할머니':
      return '♀';
    default:
      return '';
  }
}

/// 구성원 한 명과의 궁합 결과
class MemberCompat {
  final String label; // '아빠', '엄마', '형' 등 표시 이름
  final SajuResult memberSaju;
  final double elementScore; // 오행 보완 (40 만점)
  final double yongsinScore; // 용신 조화 (40 만점)
  final double zodiacScoreValue; // 띠 궁합 (20 만점)
  final List<String> details;

  const MemberCompat({
    required this.label,
    required this.memberSaju,
    required this.elementScore,
    required this.yongsinScore,
    required this.zodiacScoreValue,
    required this.details,
  });

  double get total => elementScore + yongsinScore + zodiacScoreValue;
}

/// 가족 궁합 전체 결과
class FamilyCompatResult {
  final List<MemberCompat> members; // 입력 순서 유지
  final SajuResult babySaju;
  final List<String> nameElements; // 이름 2자의 오행
  final String balanceNote; // 가족 오행 균형 한 줄
  final Map<String, int> familyCountsBefore; // 가족 전체(아기 포함) 합산 오행 분포
  final Map<String, int> familyCountsAfter; // 이름 오행 반영 후

  const FamilyCompatResult({
    required this.members,
    required this.babySaju,
    required this.nameElements,
    required this.balanceNote,
    required this.familyCountsBefore,
    required this.familyCountsAfter,
  });

  double get total =>
      members.isEmpty
          ? 0.0
          : members.map((m) => m.total).reduce((a, b) => a + b) /
              members.length;

  /// 가장 잘 맞는 구성원. 구성원이 없으면 null.
  MemberCompat? get best =>
      members.isEmpty ? null : members.reduce((a, b) => a.total >= b.total ? a : b);

  /// 점수 내림차순 정렬본 (순위 표시용)
  List<MemberCompat> get ranked =>
      [...members]..sort((a, b) => b.total.compareTo(a.total));

  /// 종합 점수에 따른 한 줄 평가. 55점 미만은 문구를 두지 않는다
  /// (예전 '참고로만 봐주세요'는 책임 회피처럼 보여서 뺐다).
  /// 빈 문자열이면 요약 카드에서 이 행을 그리지 않는다.
  String get grade {
    final t = total;
    if (t >= 85) return '아주 잘 맞는 이름이에요';
    if (t >= 70) return '잘 맞는 편이에요';
    if (t >= 55) return '무난한 궁합이에요';
    return '';
  }
}

/// 생년월일(+시간)로 사주를 뽑는 헬퍼
/// computeSaju는 성씨·획수와 무관하게 생년월일시만 사용해요.
SajuResult sajuOfBirth(DateTime birth, int? hour) {
  return computeSaju(BabyInfo(
    surname: '김',
    surnameStrokes: 8,
    gender: Gender.boy,
    birth: birth,
    birthHour: hour,
  ));
}

/// 오행 부족도 (0~1) — 8자 분포에서 적을수록 높음
double _needOf(Map<String, int> counts, String element) {
  final c = counts[element] ?? 0;
  if (c == 0) return 1.0;
  if (c == 1) return 0.6;
  if (c == 2) return 0.3;
  if (c == 3) return 0.1;
  return -0.3; // 이미 과다한 오행은 이름으로 더하면 감점
}

/// 이름 오행 하나가 구성원 용신/희신과 맺는 조화도 (0~1)
/// 희신은 용신을 생해주는 길한 기운이라 상생(0.85)보다 높게 본다.
double _harmonyOf(String nameElement, SajuResult member) {
  final yong = member.yongsin;
  if (yong == null) return 0.5;
  if (nameElement == yong) return 1.0;
  if (member.huishin != null && nameElement == member.huishin) return 0.9;
  if (generatesTo(nameElement, yong)) return 0.85; // 이름이 용신을 생함
  if (controlsTo(nameElement, yong)) return 0.1; // 이름이 용신을 극함
  if (generatesTo(yong, nameElement)) return 0.55; // 용신이 이름을 생함
  if (controlsTo(yong, nameElement)) return 0.35; // 용신이 이름을 극함
  return 0.5; // 비화 등 무난
}

MemberCompat _memberCompat({
  required String label,
  required SajuResult member,
  required List<String> nameElements,
  required String babyBranch,
  required String babyZodiac,
}) {
  final counts = member.elementCounts;
  final details = <String>[];

  // ── 오행 보완 (40) ──
  var elemSum = 0.0;
  for (final e in nameElements) {
    elemSum += _needOf(counts, e);
  }
  // 이름 글자가 없으면 0점이다. 0으로 나누면 NaN이 된다.
  final elementScore = nameElements.isEmpty
      ? 0.0
      : (elemSum / nameElements.length).clamp(0.0, 1.0) * 40;
  // 가장 적은 오행이 2개 이상이면 전부 부족한 오행이다. 하나만 보면
  // 이름이 다른 부족한 오행을 채워줘도 "다른 오행으로 보완"이라 틀리게 나온다.
  final minCount = ['목', '화', '토', '금', '수']
      .map((e) => counts[e] ?? 0)
      .reduce((a, b) => a < b ? a : b);
  final lackingElements = ['목', '화', '토', '금', '수']
      .where((e) => (counts[e] ?? 0) == minCount)
      .toSet();
  final filled = nameElements
      .where((e) => lackingElements.contains(e))
      .toSet();
  details.add(filled.isNotEmpty
      ? '$label 사주에 부족한 ${filled.map((e) => elementNames[e]).join('·')} 기운을 이름이 채워줘요.'
      : '$label 사주에 부족한 기운은 ${lackingElements.map((e) => elementNames[e]).join('·')}이에요. 이 이름은 다른 오행으로 보완해요.');

  // ── 용신 조화 (40) ──
  var harmSum = 0.0;
  for (final e in nameElements) {
    harmSum += _harmonyOf(e, member);
  }
  final yongsinScore = nameElements.isEmpty
      ? 0.0
      : (harmSum / nameElements.length).clamp(0.0, 1.0) * 40;
  final yong = member.yongsin;
  if (yong != null) {
    final hasYong = nameElements.contains(yong);
    final hasSaeng = nameElements.any((e) => generatesTo(e, yong));
    final hasGeuk = nameElements.any((e) => controlsTo(e, yong));
    // 상생하는 글자와 상극인 글자가 공존하면 둘 다 적는다.
    // else-if로 묶으면 상생만 나와 점수와 설명이 어긋난다.
    if (hasYong) {
      details.add('이름에 $label의 용신인 ${elementNames[yong]} 기운이 직접 들어 있어요.');
      if (hasGeuk) {
        details.add('다만 이름의 다른 기운 중 일부가 용신과 상극이라 조화 점수가 깎여요.');
      }
    } else if (hasSaeng && hasGeuk) {
      details.add(
          '이름의 기운 중 일부가 $label의 용신(${elementNames[yong]})을 생(生)해주지만, 다른 일부는 상극이라 조화 점수가 깎여요.');
    } else if (hasSaeng) {
      details.add(
          '이름의 기운이 $label의 용신(${elementNames[yong]})을 생(生)해줘서 힘을 보태요.');
    } else if (hasGeuk) {
      details.add('이름의 기운 중 일부가 $label의 용신(${elementNames[yong]})과 상극이라 조화 점수가 낮아요.');
    } else {
      details.add('$label의 용신은 ${elementNames[yong]}이에요. 이름과는 무난한 관계예요.');
    }
  }

  // ── 띠 궁합 (20) ──
  final zScore = zodiacScore(member.year.branch, babyBranch);
  final zLabel = zodiacLabel(member.year.branch, babyBranch);
  final memberZodiac = zodiacNames[member.year.branch] ?? '';
  details.add('$label $memberZodiac · 아기 $babyZodiac — $zLabel 관계예요.');

  return MemberCompat(
    label: label,
    memberSaju: member,
    elementScore: elementScore,
    yongsinScore: yongsinScore,
    zodiacScoreValue: zScore,
    details: details,
  );
}

/// 가족 오행 균형 한 줄 설명 (가족 전체 분포에 이름 오행 반영 전/후 비교)
String _balanceNote(Map<String, int> before, Map<String, int> after,
    List<String> nameElements) {
  double spread(Map<String, int> m) {
    final vals = m.values.toList();
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    var s = 0.0;
    for (final v in vals) {
      s += (v - mean) * (v - mean);
    }
    return s;
  }

  final filled = nameElements.toSet().join('·');
  if (spread(after) < spread(before)) {
    return '이 이름($filled 기운)을 더하면 가족 전체의 오행 분포가 더 고르게 균형 잡혀요.';
  }
  if (spread(after) > spread(before)) {
    return '이 이름($filled 기운)을 더하면 가족 전체의 오행 분포가 한쪽으로 더 치우쳐요.';
  }
  return '가족 오행 분포가 이미 고른 편이라 이름의 영향은 작아요.';
}

/// 가족 궁합 계산 진입점
/// members: (표시 이름, 사주) 목록 — 최소 1명
FamilyCompatResult computeFamilyCompat({
  required List<({String label, SajuResult saju})> members,
  required SajuResult babySaju,
  required List<HanjaPick> picks,
}) {
  assert(members.isNotEmpty);
  final nameElements = picks.map((p) => p.element).toList();
  final babyBranch = babySaju.year.branch;
  final babyZodiac = zodiacNames[babyBranch] ?? '';

  final results = members
      .map((m) => _memberCompat(
            label: m.label,
            member: m.saju,
            nameElements: nameElements,
            babyBranch: babyBranch,
            babyZodiac: babyZodiac,
          ))
      .toList();

  final before = {'목': 0, '화': 0, '토': 0, '금': 0, '수': 0};
  // 가족 전체 분포에는 새로 태어난 아기 자신의 사주 8자도 들어간다.
  // 구성원만 합산하면 아기 오행이 통째로 빠진다.
  babySaju.elementCounts
      .forEach((k, v) => before[k] = (before[k] ?? 0) + v);
  for (final m in members) {
    m.saju.elementCounts
        .forEach((k, v) => before[k] = (before[k] ?? 0) + v);
  }
  final after = Map<String, int>.from(before);
  for (final e in nameElements) {
    after[e] = (after[e] ?? 0) + 1;
  }

  return FamilyCompatResult(
    members: results,
    babySaju: babySaju,
    nameElements: nameElements,
    balanceNote: _balanceNote(before, after, nameElements),
    familyCountsBefore: before,
    familyCountsAfter: after,
  );
}
