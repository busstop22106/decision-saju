// 30일 길일 달력 — 결정 리포트의 길일 3개와 같은 엔진 데이터로 달력 뷰를 보여준다.
//
// 점수는 그 사람의 사주 흐름 기준이다. 목적 필터(이사·결혼·개업·이직)는
// 점수를 바꾸지 않고, 그 목적의 날짜로 잡을 때의 한 줄 안내만 바꿔준다.

import 'package:flutter/material.dart';

import '../engine/compat.dart';
import '../engine/decision.dart';
import '../models.dart';
import '../theme/app_theme.dart';

const List<String> _purposes = ['전체', '이사', '결혼', '개업', '이직'];

class LuckyDaysScreen extends StatefulWidget {
  final FamilyMember member;

  const LuckyDaysScreen({super.key, required this.member});

  @override
  State<LuckyDaysScreen> createState() => _LuckyDaysScreenState();
}

class _LuckyDaysScreenState extends State<LuckyDaysScreen> {
  String _purpose = '전체';
  late DateTime _selected;
  // 30일치 점수는 목적 필터·선택 날짜와 무관하다. build마다 다시 계산하지
  // 않고 진입 시 1회만 계산해 둔다.
  late DateTime _today;
  late SajuResult _saju;
  late List<LuckyDay> _days;
  late List<LuckyDay> _top3;
  late List<LuckyDay> _worst2;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = now;
    _today = DateTime(now.year, now.month, now.day);
    _saju = sajuOfBirth(widget.member.birth, widget.member.birthHour);
    _days = dayScores(_saju, _today);
    _top3 = luckyDays(_saju, _today);
    _worst2 = worstDays(_saju, _today);
  }

  String _dateLabel(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

  String _purposeLine(int score) {
    if (_purpose == '전체') return '';
    if (score >= 65) return '$_purpose하기 좋은 날이에요.';
    if (score >= 50) return '$_purpose 날짜로 무난해요.';
    return '$_purpose 날짜로는 신중하게 잡는 게 좋아요.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = _today;
    final days = _days;
    final top3 = _top3;
    final worst2 = _worst2;
    final topDates = top3.map((d) => d.date).toSet();
    final selectedDay =
        days.firstWhere((d) => d.date == DateTime(
              _selected.year,
              _selected.month,
              _selected.day,
            ), orElse: () => days.first);
    final selectedScore = selectedDay.score;
    final pillar = dayPillar(selectedDay.date);

    // 달력 앞 빈칸: 일요일 시작 기준
    final leadingBlanks = today.weekday % 7;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.member.name}님의 30일 길일')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('무엇을 위한 길일인가요?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in _purposes)
                ChoiceChip(
                  label: Text(p),
                  selected: _purpose == p,
                  onSelected: (_) => setState(() => _purpose = p),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('앞으로 30일', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '주홍색으로 표시된 날이 결정 지수가 가장 높은 길일 3개예요. 날짜를 누르면 그날의 흐름을 볼 수 있어요.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final w in ['일', '월', '화', '수', '목', '금', '토'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        color: w == '일' ? AppTheme.vermilion : AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.85,
            ),
            itemCount: leadingBlanks + days.length,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) {
                return const SizedBox.shrink();
              }
              final day = days[index - leadingBlanks];
              final isTop = topDates.contains(day.date);
              final isToday = day.date == today;
              final isSelected = day.date ==
                  DateTime(
                    _selected.year,
                    _selected.month,
                    _selected.day,
                  );
              return InkWell(
                onTap: () => setState(() => _selected = day.date),
                borderRadius: BorderRadius.circular(10),
                // InkWell 안에 불투명 Container를 두면 리플이 배경 뒤에 가려진다.
                // Ink에 decoration을 두면 리플이 그 위에 보인다.
                child: Ink(
                  decoration: BoxDecoration(
                    color: isTop ? AppTheme.vermilion : AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          // 길일(주홍 배경)을 고르면 주홍 테두리가 배경에 묻힌다.
                          // 흰색 테두리로 선택 표시가 보이게 한다.
                          ? (isTop ? Colors.white : AppTheme.vermilion)
                          : isToday
                              ? AppTheme.indigo
                              : AppTheme.border,
                      width: isSelected || isToday ? 1.5 : 1,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      // 큰 글씨에서도 타일을 넘지 않게 축소한다.
                      // mainAxisSize.min이어야 내용 높이가 그대로 측량돼
                      // FittedBox가 넘칠 때만 줄인다.
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          // 30일 창은 월을 넘는다. 매월 1일에는 월을 함께 적는다.
                          day.date.day == 1
                              ? '${day.date.month}/1'
                              : '${day.date.day}',
                          style: TextStyle(
                            color: isTop ? Colors.white : AppTheme.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${day.score}점',
                          style: TextStyle(
                            color: isTop
                                ? Colors.white
                                : AppTheme.vermilionSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, '선택한 날'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateLabel(selectedDay.date),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '$selectedScore점 · ${scoreLabel(selectedScore)}',
                        style: const TextStyle(
                          color: AppTheme.vermilion,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '일진 ${pillar.stem}${pillar.branch} — ${selectedDay.reason}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_purposeLine(selectedScore).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _purposeLine(selectedScore),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '길일 3개'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in top3) ...[
                    InkWell(
                      onTap: () => setState(() => _selected = day.date),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
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
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    '길일은 앞으로 30일 중 결정 지수가 가장 높은 날이에요.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '조심할 날 2개'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in worst2) ...[
                    InkWell(
                      onTap: () => setState(() => _selected = day.date),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
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
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    '이 날은 큰 결정을 미루는 게 좋아요.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
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
}
