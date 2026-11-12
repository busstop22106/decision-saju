// 결정 리포트 결과 화면 — 결론·결정 지수 먼저, 근거, 길일 3개, 오늘 피할 것.
//
// 질문(QuestionBrowserScreen → QuestionReportFormScreen)에서 들어온다.
// 리포트 내용은 lib/engine/question_report.dart의 buildQuestionReport가 만든다.

import 'package:flutter/material.dart';

import '../data/popular_questions.dart';
import '../engine/compat.dart';
import '../engine/decision.dart';
import '../engine/question_report.dart';
import '../models.dart';
import '../services/decision_store.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/report_share_card.dart';
import 'lucky_days_screen.dart';

/// 결정 리포트 결과 화면 — 결론·결정 지수 먼저, 근거, 길일 3개, 오늘 피할 것.
class DecisionReportScreen extends StatefulWidget {
  final FamilyMember member;

  /// 가족 보관함 전체 (우리 가족 공통 길일 계산용). 없으면 빈 목록.
  final List<FamilyMember> family;

  /// 이 리포트가 답하는 질문.
  final PopularQuestion question;

  /// 날짜형 질문일 때만 쓰는 두 날짜. 그 외는 null이다.
  final DateTime? dateA;
  final DateTime? dateB;

  const DecisionReportScreen({
    super.key,
    required this.member,
    this.family = const [],
    required this.question,
    this.dateA,
    this.dateB,
  });

  @override
  State<DecisionReportScreen> createState() => _DecisionReportScreenState();
}

class _DecisionReportScreenState extends State<DecisionReportScreen> {
  bool _saved = false;
  bool _saving = false;
  final _shareKey = GlobalKey();

  Future<void> _saveImage() async {
    final bytes = await capturePng(_shareKey);
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카드를 불러오는 중이에요. 잠시 뒤 다시 눌러주세요.')),
      );
      return;
    }
    final ok = await savePngToGallery(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '이미지를 갤러리에 저장했어요.' : '갤러리 저장 권한이 필요해요.'),
      ),
    );
  }

  Future<void> _shareImage(String shareText) async {
    final bytes = await capturePng(_shareKey);
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카드를 불러오는 중이에요. 잠시 뒤 다시 눌러주세요.')),
      );
      return;
    }
    await sharePngBytes(bytes, shareText);
  }

  BabyInfo get _baby => BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: widget.member.gender,
        birth: widget.member.birth,
        birthHour: widget.member.birthHour,
      );

  Future<void> _saveRecord(
    QuestionReport report, {
    DateTime? firstLuckyDay,
  }) async {
    // 연타 방지 — 저장 중에는 다시 들어오지 않는다.
    // (버튼도 _saving 동안 비활성화한다.)
    if (_saving || _saved) return;
    _saving = true;
    if (mounted) setState(() {});
    try {
      final store = await DecisionStore.load();
      final record = DecisionRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        topic: report.recordTopic,
        optionA: report.recordOptionA,
        optionB: report.recordOptionB,
        chosen: report.recordChosen,
        decidedAt: DateTime.now(),
        summary: report.conclusion,
        index: report.displayIndex,
      );
      await store.add(record);
      // 되물음 알림 3단계 예약 — 길일 당일 아침·길일 3일 뒤·결정 30일 뒤.
      // 예약 실패가 저장까지 막으면 안 된다. 예약 여부를 스낵바에 반영한다.
      var scheduled = false;
      try {
        scheduled = await followUpNotifications.scheduleFollowUp(
          record,
          luckyDay: firstLuckyDay,
        );
      } catch (_) {
        // 알림 없이 저장만 된다. 되물음은 인앱 배너가 대신 알린다.
        scheduled = false;
      }
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduled
                ? '결정 기록에 저장했어요. 길일 당일과 3일 뒤, 30일 뒤에 다시 물어볼게요.'
                : '결정 기록에 저장했어요. 알림 예약에 실패해서, 결정 일지에서 결과를 직접 기록해 주세요.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장에 실패했어요. 다시 시도해 주세요.')),
      );
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  String _dateLabel(DateTime d) => '${d.month}월 ${d.day}일';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final saju = sajuOfBirth(widget.member.birth, widget.member.birthHour);
    final report = buildQuestionReport(
      baby: _baby,
      saju: saju,
      question: widget.question,
      now: now,
      dateA: widget.dateA,
      dateB: widget.dateB,
    );
    final displayIndex = report.displayIndex;
    final conclusion = report.conclusion;
    final lucky = luckyDays(saju, now);
    final worst = worstDays(saju, now);
    final familyLucky = widget.family.length > 1
        ? familyLuckyDays(
            widget.family
                .map((m) => sajuOfBirth(m.birth, m.birthHour))
                .toList(),
            now,
          )
        : <LuckyDay>[];
    final evidence = report.evidence;
    final avoid = avoidLine(saju, now);

    return Scaffold(
      appBar: AppBar(title: Text('${report.recordTopic} 결정 리포트')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 결론 카드 — 결정 지수 + 결론 먼저
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.question.text,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$displayIndex',
                        style: const TextStyle(
                          color: AppTheme.vermilion,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '/ 100 · ${scoreLabel(displayIndex)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.isComparison
                        ? '추천 선택지의 결정 지수 — ${widget.member.name}님의 ${report.recordTopic} 결정'
                        : '주제 지수 — ${widget.member.name}님의 ${report.recordTopic} 결정',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    conclusion,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  if (report.isComparison) ...[
                    const SizedBox(height: 12),
                    _scoreBar(
                      'A안 · ${report.optionALabel}',
                      report.scoreA!,
                    ),
                    const SizedBox(height: 8),
                    _scoreBar(
                      'B안 · ${report.optionBLabel}',
                      report.scoreB!,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.comparisonReason ?? '',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, report.evidenceTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < evidence.length; i++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}.',
                          style: const TextStyle(
                            color: AppTheme.vermilion,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            evidence[i],
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    if (i < evidence.length - 1) const SizedBox(height: 10),
                  ],
                  if (report.evidenceFootnote != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      report.evidenceFootnote!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '30일 길일 3개'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in lucky) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: AppTheme.vermilion,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_dateLabel(day.date)} · ${day.score}점',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                day.reason,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    '길일은 앞으로 30일 중 결정 지수가 가장 높은 날이에요.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LuckyDaysScreen(member: widget.member),
                          ),
                        );
                      },
                      child: const Text('30일 달력으로 보기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '오늘 피할 것'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(avoid, style: theme.textTheme.bodyMedium),
            ),
          ),
          if (familyLucky.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle(theme, '우리 가족 공통 길일'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final day in familyLucky) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.groups,
                            color: AppTheme.vermilion,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_dateLabel(day.date)} · ${day.score}점',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  day.reason,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      '가족 보관함에 등록된 모두에게 좋은 날이에요. 이사·계약·여행·돌잔치처럼 가족이 함께 결정할 때 참고하세요.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _sectionTitle(theme, '조심할 날 2개'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in worst) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: AppTheme.vermilion,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_dateLabel(day.date)} · ${day.score}점',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                day.reason,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    '좋은 날만큼 피해야 할 날도 중요해요. 이 날은 큰 결정을 미루는 게 좋아요.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_saved || _saving)
                  ? null
                  : () => _saveRecord(
                        report,
                        firstLuckyDay:
                            lucky.isNotEmpty ? lucky.first.date : null,
                      ),
              child: Text(_saved ? '결정 기록에 저장했어요' : '결정 기록에 저장하기'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '저장하면 길일 당일 아침과 3일 뒤, 30일 뒤에 "그 결정, 어떻게 됐어요?"라고 다시 물어봐요.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, '공유하기'),
          RepaintBoundary(
            key: _shareKey,
            child: ReportShareCard(
              memberName: widget.member.name,
              topic: report.recordTopic,
              index: displayIndex,
              conclusion: conclusion,
              luckyDays: lucky,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saveImage,
                  child: const Text('이미지로 저장'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _shareImage(
                    '[결정사주] ${widget.member.name}님의 ${report.recordTopic} 결정 리포트 — 결정 지수 $displayIndex점. $conclusion',
                  ),
                  child: const Text('공유하기'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '공유하기를 누르면 카카오톡·메시지 등으로 보낼 수 있어요.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
  }

  Widget _scoreBar(String label, int score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
            Text(
              '$score점',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: AppTheme.surface,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.vermilion,
            ),
          ),
        ),
      ],
    );
  }
}
