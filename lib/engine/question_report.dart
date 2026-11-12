// 질문 리포트 — 주제(카테고리)별 운세 읽기 (순수 Dart)
//
// 선택형(이직·이사·결혼)이나 날짜형(개업·출산)처럼 A/B 비교가 아닌 질문은
// 이 파일의 주제 읽기로 답한다. "제 재물운은 어떤가요?" 같은 일반 질문과,
// 이직·이사·결혼 외 카테고리의 선택(할지 말지) 질문이 대상이다.
//
// 채점은 scoreChoiceOptions와 같은 전통 사주 개념만 쓴다.
// 초점 십성(카테고리별), 용신, 일지 충·합·형, 역마·도화, 공망.
// 모든 점수는 결정적이다 (같은 입력 → 같은 결과).
// 점수는 "지금 이 주제의 흐름이 유리한 정도"를 나타낼 뿐, 결과 보장이 아니다.
//
// 간이 만세력 기준이다. 절기 경계일·진태양시 보정 등 전문 감정의 세부 사항은
// saju.dart의 주석을 참고한다.
// Antigravity 리뷰(Claude Opus 4.6, 2026-11-12) 반영:
// 대운 지지 충·합·형, 삼형, 공망, 건강 다층(용신 극·관성 압박·오행 과다),
// 사업 관성, 이직 역마, 결혼 도화, 가족 육친, 소송 비겁 경고.
// 전문 docs/code-review-2026-11-12-questions.md.

import '../data/popular_questions.dart';
import '../models.dart';
import 'decision.dart';
import 'decision_options.dart';
import 'saju.dart';

/// 주제(카테고리)별 읽기 결과.
class TopicReading {
  /// 0~100. 50은 중립 기준이다.
  final int index;

  /// 한 줄 결론.
  final String verdict;

  /// 근거 (기여도가 큰 순서대로 최대 5개).
  final List<String> evidence;

  const TopicReading({
    required this.index,
    required this.verdict,
    required this.evidence,
  });
}

/// 카테고리별 초점 기운 라벨 — 결론 문구에 쓴다.
String topicFocusLabel(String categoryId) {
  switch (categoryId) {
    case 'job':
      return '직장·승진';
    case 'marriage':
      return '결혼·인연';
    case 'reunion':
      return '재회·인연';
    case 'moving':
      return '이사·이동';
    case 'business':
      return '사업·개업';
    case 'wealth':
      return '재물';
    case 'children':
      return '자녀';
    case 'exam':
      return '시험·취업';
    case 'health':
      return '건강';
    case 'legal':
      return '소송·계약';
    case 'abroad':
      return '해외·이동';
    case 'sidejob':
      return '부업·재물';
    case 'family':
      return '가족';
    default:
      return '운세';
  }
}

/// 카테고리별 초점 십성인지 — 대운·세운·월운의 천간을 볼 때 쓴다.
/// 배우자성(결혼·재회)은 성별에 따라 달라져서 isSpouseStar로 판정한다.
/// isSpouseStar는 천간을 받으므로, 십성 이름이 아니라 천간을 넘긴다.
/// 역마(이사·해외·이직)·도화(재회·결혼)는 지지라 여기서 보지 않고 따로 처리한다.
/// 건강은 특정 십성이 아니라 오행 균형으로 봐서 여기서 false를 돌려준다.
/// 초점 십성이 없는 카테고리(가족 외 일반)는 충·합만으로 흐름을 본다.
/// (리뷰 반영 2026-11-12: 사업에 관성 추가, 소송 비겁은 양성에서 제외,
/// 가족은 인성·비겁으로, 이사 재성은 '이사 자금' 흐름으로 한정 해석한다.)
bool _isFocusGod(
  String categoryId,
  Gender gender,
  String dayMaster,
  String stem,
) {
  final god = tenGod(dayMaster, stem);
  switch (categoryId) {
    case 'job':
      return isOfficerGod(god);
    case 'marriage':
    case 'reunion':
      return isSpouseStar(gender, dayMaster, stem);
    case 'moving':
    case 'abroad':
      // 이사·이동의 핵심은 역마·충이라 따로 본다. 여기서 재성은
      // '이사 자금'의 흐름으로만 한정 해석한다.
      return isWealthGod(god);
    case 'business':
      // 사업은 재성(수익)뿐 아니라 관성(추진력·인허가)도 함께 본다.
      return isWealthGod(god) || isOfficerGod(god);
    case 'wealth':
    case 'sidejob':
      return isWealthGod(god);
    case 'children':
      return isOutputGod(god);
    case 'exam':
      return isOfficerGod(god) || isSealGod(god);
    case 'legal':
      // 소송은 관성(법·관재)만 양성으로 본다. 비겁은 분쟁 격화 신호라
      // 따로 경고 요인으로 처리한다.
      return isOfficerGod(god);
    case 'family':
      // 가족은 육친으로 본다. 부모=인성, 형제·자매=비겁.
      return isSealGod(god) || isPeerGod(god);
    default:
      return false;
  }
}

/// '올해'·'이번 달'·'대운' 뒤에 붙는 은/는 조사.
/// '올해'는 받침이 없어 '는', '이번 달'·'대운'은 받침이 있어 '은'.
String _topicParticle(String key) => key == '올해' ? '는' : '은';

/// 채점 요인 1개 — 점수와 이유.
class _TopicFactor {
  final int points;
  final String reason;

  const _TopicFactor(this.points, this.reason);
}

/// 주제별 운세 읽기 — 내 사주 + 세운(올해) + 월운(이달) + 대운으로
/// 지금 이 주제의 흐름을 0~100점으로 읽는다.
///
/// [baby]는 대운 방향·배우자성 판정에 필요한 생년월일·성별이다.
/// [now]는 "세운·월운"의 기준 날짜다 (보통 오늘).
TopicReading topicReading({
  required BabyInfo baby,
  required SajuResult saju,
  required String categoryId,
  required DateTime now,
}) {
  final factors = <_TopicFactor>[];
  final dayBranch = saju.day.branch;
  final dayMaster = saju.dayMaster;
  final yearP = yearPillarFor(now);
  final monthP = monthPillarFor(now);
  final daewoon = currentDaewoon(baby, saju, now);
  final yongsin = saju.yongsin;
  final focusLabel = topicFocusLabel(categoryId);

  // ── 1. 초점 십성 (대운·세운·월운) ──
  // 초점 십성이 들어온 흐름은 그 주제에 힘이 된다.
  // 가중치는 대운 10, 올해 8, 이번 달 6.
  final stemSources = {'대운': daewoon, '올해': yearP, '이번 달': monthP};
  final stemWeights = {'대운': 10, '올해': 8, '이번 달': 6};
  for (final entry in stemSources.entries) {
    final pillar = entry.value;
    if (pillar == null) continue;
    final god = tenGod(dayMaster, pillar.stem);
    if (!_isFocusGod(categoryId, baby.gender, dayMaster, pillar.stem)) continue;
    final w = stemWeights[entry.key]!;
    factors.add(
      _TopicFactor(
        w,
        '${entry.key}(${pillar.stem}${pillar.branch})에 $focusLabel의 기운($god)이 들어와 있어요.',
      ),
    );
  }

  // ── 2. 용신 ──
  // 초점 십성의 오행이 용신과 같으면 그 흐름을 더 밀어준다.
  if (yongsin != null) {
    for (final entry in stemSources.entries) {
      final pillar = entry.value;
      if (pillar == null) continue;
      if (!_isFocusGod(categoryId, baby.gender, dayMaster, pillar.stem)) continue;
      if (stemElement(pillar.stem) != yongsin) continue;
      factors.add(
        _TopicFactor(
          4,
          '${entry.key}의 ${elementNames[yongsin]} 기운이 용신과 같아 $focusLabel 흐름을 밀어줘요.',
        ),
      );
      break;
    }
  }

  // ── 3. 일지 충·합·형 (올해·이달·대운) ──
  // 충·형은 조심할 신호, 합·삼합은 순조로운 신호다.
  // 대운(10년 흐름)도 일지와 충·합·형을 보는데, 가장 큰 흐름이라 가중치가 크다.
  // (리뷰 반영 2026-11-12: 대운 지지 추가, 삼형 추가,
  // 육합 +6보다 반합인 삼합을 +4로 약하게 본다.
  // 충과 형이 겹치는 지지(예: 일지 인에 신)는 충으로 한 번만 센다.)
  final branchSources = {
    '올해': (branch: yearP.branch, clash: -8, punish: -8, combine: 6, triple: 4),
    '이번 달': (
      branch: monthP.branch,
      clash: -8,
      punish: -8,
      combine: 6,
      triple: 4
    ),
    if (daewoon != null)
      '대운': (
        branch: daewoon.branch,
        clash: -10,
        punish: -10,
        combine: 8,
        triple: 6
      ),
  };
  for (final entry in branchSources.entries) {
    final branch = entry.value.branch;
    final particle = _topicParticle(entry.key);
    if (branchesClash(branch, dayBranch)) {
      factors.add(
        _TopicFactor(
          entry.value.clash,
          '${entry.key}$particle 일지($dayBranch)와 충이 있어 $focusLabel 결정은 신중히 살펴보세요.',
        ),
      );
    } else if (branchesPunish(branch, dayBranch)) {
      factors.add(
        _TopicFactor(
          entry.value.punish,
          '${entry.key}$particle 일지($dayBranch)와 형이 있어 $focusLabel 결정은 신중히 살펴보세요.',
        ),
      );
    } else if (branchesCombine(branch, dayBranch)) {
      factors.add(
        _TopicFactor(
          entry.value.combine,
          '${entry.key}$particle 일지($dayBranch)와 합이 들어와 $focusLabel 흐름이 순조로워요.',
        ),
      );
    } else if (branchesTriple(branch, dayBranch)) {
      factors.add(
        _TopicFactor(
          entry.value.triple,
          '${entry.key}$particle 일지($dayBranch)와 삼합이 들어와 $focusLabel 흐름이 순조로워요.',
        ),
      );
    }
  }

  // ── 4. 역마 (이사·해외·이직) ──
  // 역마는 이동의 기운이다. 올해·이번 달·대운에 역마가 들어오면 이동이 순조롭다.
  // (리뷰 반영 2026-11-12: 역마는 직장 이동·이직의 지표라 job에도 적용한다.)
  if (categoryId == 'moving' ||
      categoryId == 'abroad' ||
      categoryId == 'job') {
    final horse = travellingHorse(dayBranch);
    final horseLabel = categoryId == 'job' ? '직장 이동' : '이동';
    if (yearP.branch == horse) {
      factors.add(
        _TopicFactor(8, '올해는 역마($horse)가 들어와 $horseLabel의 기운이 강해요.'),
      );
    }
    if (monthP.branch == horse) {
      factors.add(
        _TopicFactor(6, '이번 달은 역마($horse)가 들어와 $horseLabel의 기운이 강해요.'),
      );
    }
    if (daewoon != null && daewoon.branch == horse) {
      factors.add(
        _TopicFactor(
          6,
          '대운(${daewoon.stem}${daewoon.branch})에 역마($horse)가 들어와 $horseLabel의 기운이 강해요.',
        ),
      );
    }
  }

  // ── 5. 도화 (재회·결혼) ──
  // 도화는 새로운 만남의 기운이다. 재회 질문에서는 지금 인연보다
  // 새로운 만남 쪽의 기운으로 읽는다. 결혼에서도 새 인연·매력의 기운이다.
  // (리뷰 반영 2026-11-12: 도화는 결혼에도 의미가 있어 marriage에도 적용한다.)
  if (categoryId == 'reunion' || categoryId == 'marriage') {
    final blossom = peachBlossom(dayBranch);
    final blossomLabel =
        categoryId == 'marriage' ? '새로운 인연·매력' : '새로운 인연';
    if (yearP.branch == blossom) {
      factors.add(
        _TopicFactor(8, '올해는 도화($blossom)가 들어와 $blossomLabel의 기운이 강해요.'),
      );
    }
    if (monthP.branch == blossom) {
      factors.add(
        _TopicFactor(6, '이번 달은 도화($blossom)가 들어와 $blossomLabel의 기운이 강해요.'),
      );
    }
  }

  // ── 6. 건강 — 오행 균형 + 용신·관성·과다 ──
  // 건강은 특정 십성이 아니라 오행 균형으로 본다.
  // (리뷰 반영 2026-11-12: "부족한 오행 보충"만으로는 부족해서,
  // 용신이 극을 받는지·신약한 일간에 관성이 들어오는지·오행 과다인지를 함께 본다.
  // 천간뿐 아니라 지지 본기 오행도 함께 확인한다.)
  if (categoryId == 'health') {
    final lacking = lackingElements(saju.elementCounts);
    final yongsinController =
        yongsin != null ? controlledBy(yongsin) : null;
    for (final entry in {'올해': yearP, '이번 달': monthP}.entries) {
      final pillar = entry.value;
      final stemEl = stemElement(pillar.stem);
      final branchEl = branchElement(pillar.branch);
      final stemGod = tenGod(dayMaster, pillar.stem);
      // 부족한 오행을 채워주면 몸의 균형에 도움이 된다.
      if (lacking.contains(stemEl)) {
        factors.add(
          _TopicFactor(
            8,
            '${entry.key}의 ${elementNames[stemEl]} 기운이 부족한 오행을 채워줘 몸의 균형에 도움이 돼요.',
          ),
        );
      }
      if (branchEl != stemEl && lacking.contains(branchEl)) {
        factors.add(
          _TopicFactor(
            6,
            '${entry.key} 지지(${pillar.branch})의 ${elementNames[branchEl]} 기운도 부족한 오행을 채워줘요.',
          ),
        );
      }
      // 용신이 극을 받으면 건강이 위태롭다.
      if (yongsinController != null && stemEl == yongsinController) {
        factors.add(
          _TopicFactor(
            -8,
            '${entry.key}의 ${elementNames[stemEl]} 기운이 용신(${elementNames[yongsin!]})을 극해 건강에 주의가 필요해요.',
          ),
        );
      }
      // 신약한 일간에 관성이 들어오면 건강 압박이 된다.
      if (!saju.strongBody && isOfficerGod(stemGod)) {
        factors.add(
          _TopicFactor(
            -6,
            '${entry.key}의 관성($stemGod) 기운이 약한 일간을 눌러 몸이 지치기 쉬워요.',
          ),
        );
      }
      // 이미 과다한 오행이 더 들어오면 균형이 깨진다.
      final count = saju.elementCounts[stemEl] ?? 0;
      if (count >= 3 && !lacking.contains(stemEl)) {
        factors.add(
          _TopicFactor(
            -6,
            '${entry.key}의 ${elementNames[stemEl]} 기운이 이미 많은데 더 들어와 균형이 깨지기 쉬워요.',
          ),
        );
      }
    }
  }

  // ── 7. 공망(空亡) ──
  // 일주의 공망 지지가 올해·이번 달·대운에 나타나면 기운이 비어
  // 기대한 만큼 결과가 안 나올 수 있다.
  // (리뷰 반영 2026-11-12: 공망은 전통 감정의 기본 체크 항목이다.)
  final voidBs = voidBranches(saju.day.stem, dayBranch);
  if (voidBs.isNotEmpty) {
    final voidLabel = voidBs.join('·');
    if (voidBs.contains(yearP.branch)) {
      factors.add(
        _TopicFactor(
          -6,
          '올해${_topicParticle('올해')} 공망($voidLabel)이라 기운이 비어 있어요. 기대한 만큼 결과가 안 나올 수 있어요.',
        ),
      );
    }
    if (voidBs.contains(monthP.branch)) {
      factors.add(
        _TopicFactor(
          -6,
          '이번 달${_topicParticle('이번 달')} 공망($voidLabel)이라 기운이 비어 있어요. 기대한 만큼 결과가 안 나올 수 있어요.',
        ),
      );
    }
    if (daewoon != null && voidBs.contains(daewoon.branch)) {
      factors.add(
        _TopicFactor(
          -8,
          '대운${_topicParticle('대운')} 공망($voidLabel)이라 기운이 비어 있어요. 기대한 만큼 결과가 안 나올 수 있어요.',
        ),
      );
    }
  }

  // ── 8. 소송 비겁 경고 ──
  // 소송에서 비겁은 분쟁이 격화될 수 있다는 주의 신호다.
  // 양성 점수를 주지 않고 경고 요인으로만 본다.
  // (리뷰 반영 2026-11-12)
  if (categoryId == 'legal') {
    for (final entry in stemSources.entries) {
      final pillar = entry.value;
      if (pillar == null) continue;
      if (!isPeerGod(tenGod(dayMaster, pillar.stem))) continue;
      factors.add(
        _TopicFactor(
          -4,
          '${entry.key}에 비겁이 들어와 분쟁이 격화될 수 있어요. 감정보다 조건을 따져보세요.',
        ),
      );
    }
  }

  // 점수는 요인을 합산해 0~100으로 묶는다. 50이 중립 기준이다.
  var index = 50;
  for (final f in factors) {
    index += f.points;
  }
  index = index.clamp(0, 100);

  // 근거는 영향이 큰 순서대로 최대 5개까지, 점수를 함께 적는다.
  // 절댓값이 큰 요인(긍정·부정 모두)을 먼저 보여줘서,
  // 가장 중요한 경고가 잘리지 않게 한다.
  final List<String> evidence;
  {
    final sorted = [...factors]
      ..sort((x, y) => y.points.abs().compareTo(x.points.abs()));
    evidence = sorted.take(5).map((f) {
      final sign = f.points >= 0 ? '+' : '';
      return '${f.reason} ($sign${f.points}점)';
    }).toList();
    if (evidence.isEmpty) {
      evidence.add(
        '지금은 $focusLabel 기운이 특별히 강하지도 약하지도 않아요. 오늘의 결정 지수 ${decisionIndex(saju, now)}점을 참고하세요.',
      );
    }
  }

  // 결론 — 점수 구간으로 나눈다.
  final String verdict;
  if (index >= 70) {
    verdict = '지금은 $focusLabel 흐름이 좋아요. 적극적으로 움직여도 되는 때예요.';
  } else if (index >= 50) {
    verdict = '지금은 $focusLabel 흐름이 무난해요. 서두르지 말고 차근차근 가세요.';
  } else {
    verdict = '지금은 $focusLabel 흐름이 조심스러워요. 큰 결정은 미루고 준비하는 게 좋아요.';
  }

  return TopicReading(index: index, verdict: verdict, evidence: evidence);
}

/// ── 질문 → 리포트 모델 ──

/// 질문 리포트 — 화면이 바로 쓸 수 있는 완성된 리포트.
/// 비교 모드(선택형·날짜형)는 A/B 점수를, 단일 모드(일반·기타 선택)는
/// 주제 지수 하나만 갖는다.
class QuestionReport {
  final PopularQuestion question;

  /// 크게 보여줄 지수 (0~100).
  final int displayIndex;

  /// 한 줄 결론.
  final String conclusion;

  /// 비교 모드일 때만 있는 A/B 라벨·점수.
  final String? optionALabel;
  final int? scoreA;
  final String? optionBLabel;
  final int? scoreB;

  /// 비교 모드일 때만 있는 결론 이유.
  final String? comparisonReason;

  /// 근거 목록.
  final List<String> evidence;

  /// 근거 섹션 제목.
  final String evidenceTitle;

  /// 날짜형일 때만 있는 각주.
  final String? evidenceFootnote;

  /// 결정 기록에 저장할 값.
  final String recordTopic;
  final String recordOptionA;
  final String recordOptionB;
  final String recordChosen;

  const QuestionReport({
    required this.question,
    required this.displayIndex,
    required this.conclusion,
    this.optionALabel,
    this.scoreA,
    this.optionBLabel,
    this.scoreB,
    this.comparisonReason,
    required this.evidence,
    required this.evidenceTitle,
    this.evidenceFootnote,
    required this.recordTopic,
    required this.recordOptionA,
    required this.recordOptionB,
    required this.recordChosen,
  });

  /// A/B 비교가 있는 리포트인지.
  bool get isComparison => optionALabel != null && scoreA != null;
}

/// 질문의 카테고리를 기존 엔진 주제(이직·이사·결혼·개업·출산)로 바꾼다.
/// 선택형은 이직·이사·결혼만 채점기가 있고,
/// 날짜형 보너스(재성·식상)는 개업·출산에만 있다.
/// 해당이 없으면 null을 돌려주고, 그 질문은 주제 읽기로 답한다.
String? engineTopicForQuestion(PopularQuestion question) {
  switch (question.kind) {
    case QuestionKind.choice:
      switch (question.categoryId) {
        case 'job':
          return '이직';
        case 'moving':
          return '이사';
        case 'marriage':
          return '결혼';
        default:
          return null;
      }
    case QuestionKind.timing:
      switch (question.categoryId) {
        case 'business':
          return '개업';
        case 'children':
          return '출산';
        default:
          return '기타';
      }
    case QuestionKind.general:
      return null;
  }
}

String _dateLabel(DateTime d) => '${d.month}월 ${d.day}일';

/// 질문 리포트를 만든다.
/// [dateA]/[dateB]는 날짜형 질문일 때만 쓴다 (둘 다 있어야 한다).
QuestionReport buildQuestionReport({
  required BabyInfo baby,
  required SajuResult saju,
  required PopularQuestion question,
  required DateTime now,
  DateTime? dateA,
  DateTime? dateB,
}) {
  final categoryLabel =
      categoryOf(question.categoryId)?.label ?? question.categoryId;

  // ── 선택형: 이직·이사·결혼은 A/B 채점기로, 나머지는 주제 읽기로 ──
  if (question.kind == QuestionKind.choice) {
    final topic = engineTopicForQuestion(question);
    if (topic != null) {
      final config = configForTopic(topic);
      final comparison = scoreChoiceOptions(
        baby: baby,
        saju: saju,
        topic: topic,
        now: now,
      );
      final displayIndex = comparison.scoreA > comparison.scoreB
          ? comparison.scoreA
          : comparison.scoreB;
      final String conclusion;
      if (comparison.recommendation == 'A') {
        conclusion = '사주 흐름상 A안(${config.optionA})이 유리해요.';
      } else if (comparison.recommendation == 'B') {
        conclusion = '사주 흐름상 B안(${config.optionB})이 유리해요.';
      } else {
        conclusion = '두 선택지의 흐름 차이가 크지 않아요. 현실 조건을 더 따져보세요.';
      }
      return QuestionReport(
        question: question,
        displayIndex: displayIndex,
        conclusion: conclusion,
        optionALabel: config.optionA,
        scoreA: comparison.scoreA,
        optionBLabel: config.optionB,
        scoreB: comparison.scoreB,
        comparisonReason: comparison.reason,
        evidence: comparison.reasons,
        evidenceTitle: '이렇게 판단했어요',
        recordTopic: categoryLabel,
        recordOptionA: config.optionA,
        recordOptionB: config.optionB,
        recordChosen: comparison.recommendation,
      );
    }
    // 그 외 카테고리의 선택 질문은 주제 읽기로 답한다.
    final reading = topicReading(
      baby: baby,
      saju: saju,
      categoryId: question.categoryId,
      now: now,
    );
    return QuestionReport(
      question: question,
      displayIndex: reading.index,
      conclusion: reading.verdict,
      evidence: reading.evidence,
      evidenceTitle: '이렇게 판단했어요',
      recordTopic: categoryLabel,
      recordOptionA: question.text,
      recordOptionB: '',
      recordChosen: '리포트',
    );
  }

  // ── 날짜형: 두 날짜를 비교한다 ──
  if (question.kind == QuestionKind.timing) {
    final topic = engineTopicForQuestion(question) ?? '기타';
    final comparison = scoreTimingOptions(
      saju: saju,
      topic: topic,
      dateA: dateA!,
      dateB: dateB!,
    );
    final String conclusion;
    if (comparison.recommendation == 'A') {
      conclusion = '사주 흐름상 A안(${_dateLabel(dateA)})이 유리해요.';
    } else if (comparison.recommendation == 'B') {
      conclusion = '사주 흐름상 B안(${_dateLabel(dateB)})이 유리해요.';
    } else {
      conclusion = '두 날짜의 흐름 차이가 크지 않아요. 현실 조건을 더 따져보세요.';
    }
    return QuestionReport(
      question: question,
      displayIndex: decisionIndex(saju, now),
      conclusion: conclusion,
      optionALabel: _dateLabel(dateA),
      scoreA: comparison.scoreA,
      optionBLabel: _dateLabel(dateB),
      scoreB: comparison.scoreB,
      comparisonReason: comparison.reason,
      evidence: comparison.reasons,
      evidenceTitle: '근거 3줄',
      evidenceFootnote: '같은 계산에서 나온 결과입니다.',
      recordTopic: categoryLabel,
      recordOptionA: _dateLabel(dateA),
      recordOptionB: _dateLabel(dateB),
      recordChosen: comparison.recommendation,
    );
  }

  // ── 일반형: 주제 읽기로 답한다 ──
  final reading = topicReading(
    baby: baby,
    saju: saju,
    categoryId: question.categoryId,
    now: now,
  );
  return QuestionReport(
    question: question,
    displayIndex: reading.index,
    conclusion: reading.verdict,
    evidence: reading.evidence,
    evidenceTitle: '이렇게 판단했어요',
    recordTopic: categoryLabel,
    recordOptionA: question.text,
    recordOptionB: '',
    recordChosen: '리포트',
  );
}
