// 홈 — 오늘 운세 3줄 + 결정 리포트 진입 + 가족 보관함 요약

import 'package:flutter/material.dart';

import '../engine/compat.dart';
import '../engine/daily_fortune.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import 'decision_report_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<FamilyMember> members;
  final VoidCallback onGoToFamily;
  final Future<void> Function(FamilyMember) onAddMember;

  const HomeScreen({
    super.key,
    required this.members,
    required this.onGoToFamily,
    required this.onAddMember,
  });

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _todayLabel(DateTime now) =>
      '${now.month}월 ${now.day}일 ${_weekdays[now.weekday - 1]}요일';

  /// 가장 잘 맞는 구성원 쌍 (띠 점수 기준). 2명 미만이면 null.
  ({FamilyMember a, FamilyMember b, String label, double score})? _bestPair() {
    if (members.length < 2) return null;
    ({FamilyMember a, FamilyMember b, String label, double score})? best;
    for (var i = 0; i < members.length; i++) {
      for (var j = i + 1; j < members.length; j++) {
        final aBranch =
            sajuOfBirth(members[i].birth, members[i].birthHour).year.branch;
        final bBranch =
            sajuOfBirth(members[j].birth, members[j].birthHour).year.branch;
        final score = zodiacScore(aBranch, bBranch);
        if (best == null || score > best.score) {
          best = (
            a: members[i],
            b: members[j],
            label: zodiacLabel(aBranch, bBranch),
            score: score,
          );
        }
      }
    }
    return best;
  }

  void _openReportForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DecisionFormScreen(
          members: members,
          onAddMember: onAddMember,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.vermilion,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Text(
                '결',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('결정사주'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (members.isEmpty) ...[
            _sectionTitle(theme, '오늘의 운세'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '생년월일을 입력하면\n오늘 운세 3줄을 보여드려요.',
                      style: TextStyle(fontSize: 17, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onGoToFamily,
                        child: const Text('가족 구성원 추가하기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            _sectionTitle(theme, '오늘의 운세 · ${_todayLabel(now)}'),
            _fortuneCard(context, members.first, now),
          ],
          const SizedBox(height: 20),
          _sectionTitle(theme, '결정 리포트'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note, color: AppTheme.vermilion),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '결정할 일이 있나요?',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A/B 양자택일 결론 + 근거 3줄 · 30일 길일 3개 · 오늘 피할 것 1개 · 30일 뒤 되물음',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        '4,900원',
                        style: TextStyle(
                          color: AppTheme.vermilionSoft,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('일회성 · 구독 없음', style: theme.textTheme.bodySmall),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => _openReportForm(context),
                        child: const Text('만들기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, '가족 보관함'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (members.isEmpty)
                    Text(
                      '아직 저장된 가족이 없어요. 최대 3명까지 저장할 수 있어요.',
                      style: theme.textTheme.bodySmall,
                    )
                  else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members
                          .map(
                            (m) => Chip(
                              label: Text('${m.name} · ${m.relation}'),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final best = _bestPair();
                        if (best == null) {
                          return Text(
                            '구성원을 2명 이상 추가하면 가장 잘 맞는 궁합을 보여드려요.',
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return Text(
                          '가장 잘 맞는 궁합 — ${best.a.name} × ${best.b.name} ${best.label}',
                          style: const TextStyle(
                            color: AppTheme.vermilionSoft,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onGoToFamily,
                      child: const Text('가족 보관함 관리'),
                    ),
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

  Widget _fortuneCard(
    BuildContext context,
    FamilyMember primary,
    DateTime now,
  ) {
    final saju = sajuOfBirth(primary.birth, primary.birthHour);
    final fortune = dailyFortune(saju, now);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppTheme.vermilion),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${primary.name}님의 오늘',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${saju.dayMaster}일생',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _fortuneLine(
              Icons.auto_awesome,
              '오늘의 기운',
              fortune.energy,
              theme,
            ),
            const SizedBox(height: 12),
            _fortuneLine(
              Icons.check_circle_outline,
              '결정에 참고할 것',
              fortune.decision,
              theme,
            ),
            const SizedBox(height: 12),
            _fortuneLine(
              Icons.warning_amber_outlined,
              '오늘 피할 것',
              fortune.caution,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fortuneLine(
    IconData icon,
    String label,
    String text,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.vermilion, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.vermilionSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(text, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
