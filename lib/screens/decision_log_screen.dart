// 결정 일지 — 저장된 결정 목록 + 30일 뒤 되물음
//
// 결정사주의 핵심 차별점(검증 루프)의 화면이다. 30일이 지난 결정은
// 맨 위에 "어떻게 됐어요?" 되물음과 함께 보여준다.

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/decision_store.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class DecisionLogScreen extends StatefulWidget {
  const DecisionLogScreen({super.key});

  @override
  State<DecisionLogScreen> createState() => _DecisionLogScreenState();
}

class _DecisionLogScreenState extends State<DecisionLogScreen> {
  DecisionStore? _store;
  List<DecisionRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await DecisionStore.load();
    if (!mounted) return;
    setState(() {
      _store = store;
      _records = store.loadAll();
      _loading = false;
    });
  }

  Future<void> _answer(String id, String answer) async {
    await _store?.answerFollowUp(id, answer);
    try {
      await followUpNotifications.cancelFollowUp(id);
    } catch (_) {
      // 알림 취소 실패가 답 저장을 막으면 안 된다.
    }
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('기록했어요. 다음 결정에도 참고할게요.')),
    );
  }

  Future<void> _remove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결정 기록 삭제'),
        content: const Text('이 결정 기록을 삭제할까요? 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store?.remove(id);
    try {
      await followUpNotifications.cancelFollowUp(id);
    } catch (_) {
      // 알림 취소 실패가 삭제를 막으면 안 된다.
    }
    await _load();
  }

  String _dateLabel(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = _records.where((r) => r.followUpDue).toList();
    final done = _records.where((r) => !r.followUpDue).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('결정 일지')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history,
                          color: AppTheme.vermilion,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '아직 저장된 결정이 없어요.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '결정 리포트를 만들고 저장하면 여기에 쌓여요. 30일 뒤에 "그 결정, 어떻게 됐어요?"라고 다시 물어봐요.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (due.isNotEmpty) ...[
                      Text('30일이 지난 결정', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '한 달 전 결정, 어떻게 됐어요? 답하면 다음 결정에 참고할게요.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      for (final r in due) _dueCard(r, theme),
                      const SizedBox(height: 20),
                    ],
                    if (done.isNotEmpty) ...[
                      Text('지난 결정', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      for (final r in done) _recordCard(r, theme),
                    ],
                  ],
                ),
    );
  }

  Widget _dueCard(DecisionRecord r, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.topic} · ${_dateLabel(r.decidedAt)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${r.index}점',
                  style: const TextStyle(
                    color: AppTheme.vermilion,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(r.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final answer in ['잘 됐어요', '아직 몰라요', '안 됐어요'])
                  OutlinedButton(
                    onPressed: () => _answer(r.id, answer),
                    child: Text(answer),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(DecisionRecord r, ThemeData theme) {
    final chosenText = r.chosen == '비슷함'
        ? '비슷함'
        : r.chosen == 'A'
            ? 'A안: ${r.optionA}'
            : 'B안: ${r.optionB}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.topic} · ${_dateLabel(r.decidedAt)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.muted,
                    size: 20,
                  ),
                  onPressed: () => _remove(r.id),
                  tooltip: '삭제',
                ),
              ],
            ),
            Text('선택: $chosenText', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(r.summary, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '결정 지수 ${r.index}점',
                  style: theme.textTheme.bodySmall,
                ),
                if (r.followUp != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '결과: ${r.followUp}',
                    style: const TextStyle(
                      color: AppTheme.vermilionSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
