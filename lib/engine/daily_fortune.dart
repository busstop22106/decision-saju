// 오늘 운세 3줄 — 순수 Dart (Flutter import 없음).
//
// 간이 만세력 계산 결과(일간 오행·용신·조후·부족한 오행)에서만 도출한다.
// 같은 사람·같은 날짜에는 항상 같은 3줄이 나온다 (결정적).
// 날짜가 바뀌면 씨드가 바뀌어 문구가 순환한다.
// 어떤 줄도 결과를 보장하지 않는다 — 조언형 문장만 쓴다.

import '../models.dart';
import 'saju.dart';

/// 오늘 운세 3줄
class DailyFortune {
  /// 오늘의 기운
  final String energy;

  /// 결정에 참고할 것
  final String decision;

  /// 오늘 피할 것
  final String caution;

  const DailyFortune({
    required this.energy,
    required this.decision,
    required this.caution,
  });

  List<String> get lines => [energy, decision, caution];
}

/// 오행별 '결정에 어울리는 일' 한 줄
const Map<String, String> _elementDecisionHint = {
  '목': '시작하고 키우는 일',
  '화': '마음을 표현하는 일',
  '토': '기반을 다지고 정리하는 일',
  '금': '정리하고 결단하는 일',
  '수': '흐름을 타고 유연하게 가는 일',
};

/// 조후(계절에 모자라기 쉬운 기운)별 주의 한 줄
const Map<String, String> _johuCaution = {
  '화': '몸을 따뜻하게 하고, 무리한 약속은 줄이는 게 좋아요.',
  '수': '감정이 앞서기 쉬운 날이에요. 큰 결정은 한 번 더 생각해요.',
};

/// 가장 많은 오행별 '과하면' 주의 한 줄
const Map<String, String> _excessCaution = {
  '목': '서두르기 쉬운 날이에요. 한 번 더 확인하고 움직여요.',
  '화': '감정이 앞서기 쉬운 날이에요. 말하기 전에 한 번 더 생각해요.',
  '토': '고집이 세지기 쉬운 날이에요. 다른 의견도 한 번 들어봐요.',
  '금': '날이 서기 쉬운 날이에요. 부드럽게 말하는 게 좋아요.',
  '수': '흘러가기만 하기 쉬운 날이에요. 오늘 할 일 하나는 정해두어요.',
};

DailyFortune dailyFortune(SajuResult saju, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  // 씨드: 날짜 + 일간 — 같은 사람·같은 날은 같은 결과, 날짜가 바뀌면 순환
  var seed = day.year * 372 + day.month * 31 + day.day;
  for (final c in saju.dayMaster.codeUnits) {
    seed += c;
  }

  // ── 1줄: 오늘의 기운 ──
  final me = elementNames[saju.dayElement] ?? saju.dayElement;
  final energyPool = saju.strongBody
      ? <String>[
          '오늘은 $me 기운이 단단한 날이에요. 하고 싶은 일은 미루지 말고 시작해요.',
          '오늘은 $me 기운이 안정적인 날이에요. 오래 미뤄둔 일을 처리하기 좋아요.',
          '오늘은 $me 기운이 또렷한 날이에요. 내 생각을 분명히 말해봐요.',
        ]
      : <String>[
          '오늘은 $me 기운을 보태주는 날이에요. 믿을 만한 사람과 상의하면 힘이 돼요.',
          '오늘은 $me 기운이 잔잔한 날이에요. 무리하지 말고, 할 수 있는 만큼만 해요.',
          '오늘은 $me 기운을 채우는 날이에요. 푹 쉬고, 잘 먹는 것부터 챙겨요.',
        ];
  final energy = energyPool[seed % energyPool.length];

  // ── 2줄: 결정에 참고할 것 (용신·부족한 오행 기준) ──
  final yong = saju.yongsin;
  final lacking = lackingElements(saju.elementCounts);
  final focus = yong ?? lacking.first;
  final focusName = elementNames[focus] ?? focus;
  final hint = _elementDecisionHint[focus] ?? '마음 가는 대로 하는 일';
  final decisionPool = <String>[
    '오늘 결정할 일이 있다면, $focusName 기운과 어울리는 $hint이 힘을 받아요.',
    '오늘은 $focusName 기운이 필요한 날이에요. $hint부터 먼저 챙겨봐요.',
    '결정을 앞두고 있다면 $focusName 기운을 떠올려봐요. $hint이 실마리가 돼요.',
  ];
  final decision = decisionPool[(seed + 1) % decisionPool.length];

  // ── 3줄: 오늘 피할 것 (조후 우선, 없으면 가장 많은 오행) ──
  String caution;
  if (saju.johu != null && _johuCaution.containsKey(saju.johu)) {
    caution = _johuCaution[saju.johu]!;
  } else {
    final most = ['목', '화', '토', '금', '수']
      ..sort((a, b) =>
          (saju.elementCounts[b] ?? 0).compareTo(saju.elementCounts[a] ?? 0));
    caution = _excessCaution[most.first]!;
  }
  // 조후 주의 문구는 하나뿐이라 날짜 순환이 필요 없지만,
  // 3줄 전체가 날짜마다 조금씩 달라지도록 접두어를 순환한다.
  final cautionPrefix = seed % 2 == 0 ? '오늘 피할 것 — ' : '오늘은 조심 — ';
  if (!caution.startsWith('오늘')) {
    caution = '$cautionPrefix$caution';
  }

  return DailyFortune(
    energy: energy,
    decision: decision,
    caution: caution,
  );
}
