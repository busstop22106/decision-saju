// 신년 운세 — "올해의 운세" 일반형이 아니라 "올해의 결정"형.
//
// 올해 결정하기 좋은 달·피할 달, 월별 결정 지수, 그 달의 가장 좋은 날을 보여준다.
// 1월 성수기에 들어오는 사용자가 "올해 언제 결정하면 좋을지"를 한눈에 본다.

import 'package:flutter/material.dart';

import '../engine/compat.dart';
import '../engine/decision.dart';
import '../models.dart';
import '../theme/app_theme.dart';

class NewYearScreen extends StatefulWidget {
  final FamilyMember member;

  const NewYearScreen({super.key, required this.member});

  @override
  State<NewYearScreen> createState() => _NewYearScreenState();
}

class _NewYearScreenState extends State<NewYearScreen> {
  late int _year;
  // 칩 목록 기준 연도. _year를 기준으로 삼으면 이전 해 칩을 누를 때마다
  // 목록이 바뀌어 누른 칩이 가운데로 이동한다. 진입 연도로 고정한다.
  late final int _baseYear;
  // 1년치(365일) 점수 계산은 build마다 하지 않고 연도가 바뀔 때만 한다.
  late SajuResult _saju;
  late List<YearMonthScore> _months;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 11~12월에는 다가올 해를, 그 외에는 올해를 기본으로 보여준다.
    _year = now.month >= 11 ? now.year + 1 : now.year;
    _baseYear = _year;
    _saju = sajuOfBirth(widget.member.birth, widget.member.birthHour);
    _recompute();
  }

  void _recompute() {
    _months = yearMonthScores(_saju, _year);
  }

  String _dateLabel(DateTime d) => '${d.month}월 ${d.day}일';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = _months;
    final sorted = [...months]..sort((a, b) => b.avgScore.compareTo(a.avgScore));
    final bestMonths = sorted.take(3).toList();
    final worstMonths = sorted.reversed.take(2).toList();
    final yearAvg =
        months.fold<double>(0, (sum, m) => sum + m.avgScore) / months.length;

    return Scaffold(
      appBar: AppBar(title: Text('$_year년 신년 결정 운세')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final y in [_baseYear - 1, _baseYear, _baseYear + 1])
                ChoiceChip(
                  label: Text('$y년'),
                  selected: _year == y,
                  onSelected: (_) => setState(() {
                    _year = y;
                    _recompute();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // 올해의 결정 지수
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.member.name}님의 $_year년',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        yearAvg.toStringAsFixed(0),
                        style: const TextStyle(
                          color: AppTheme.vermilion,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            '/ 100 · 올해의 결정 지수',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '올해의 결정 지수는 12개월 결정 지수의 평균이에요. 월별로 흐름이 다르니, 아래에서 좋은 달을 확인하세요.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '결정하기 좋은 달'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final m in bestMonths) ...[
                    _monthRow(
                      '${m.month}월',
                      '평균 ${m.avgScore.toStringAsFixed(0)}점 · 가장 좋은 날 ${_dateLabel(m.bestDay)} (${m.bestScore}점)',
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '큰 결정은 이 달에 잡으면 흐름을 탈 수 있어요.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '신중하게 잡으면 좋은 달'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final m in worstMonths) ...[
                    _monthRow(
                      '${m.month}월',
                      '평균 ${m.avgScore.toStringAsFixed(0)}점 · 가장 좋은 날 ${_dateLabel(m.bestDay)} (${m.bestScore}점)',
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '이 달에는 결정을 미루거나, 그 달의 가장 좋은 날을 골라 잡는 게 좋아요.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '월별 결정 지수'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  for (var i = 0; i < months.length; i++) ...[
                    _monthBar(months[i]),
                    // 마지막 항목 뒤에는 간격을 두지 않는다.
                    // 월 숫자(12)로 판정하지 않고 위치로 판정한다.
                    if (i < months.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '사주는 참고용이에요. 월별 흐름은 결정을 "언제" 할지 정하는 데 참고하세요.',
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

  Widget _monthRow(String month, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            month,
            style: const TextStyle(
              color: AppTheme.vermilion,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(desc, style: const TextStyle(fontSize: 14, height: 1.5)),
        ),
      ],
    );
  }

  Widget _monthBar(YearMonthScore m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${m.month}월',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: m.avgScore / 100,
                  minHeight: 8,
                  backgroundColor: AppTheme.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.vermilion,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              // 고정 너비 52는 큰 글씨에서 '100점'이 잘린다.
              // 최소 너비만 두고 글씨가 크면 늘어나게 한다.
              constraints: const BoxConstraints(minWidth: 52),
              child: Text(
                '${m.avgScore.toStringAsFixed(0)}점',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 2),
          child: Text(
            '가장 좋은 날 ${_dateLabel(m.bestDay)} (${m.bestScore}점)',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
