// 결정 일지 — 저장된 결정 목록 + 30일 뒤 되물음
//
// 결정사주의 핵심 차별점(검증 루프)의 화면이다. 30일이 지난 결정은
// 맨 위에 "어떻게 됐어요?" 되물음과 함께 보여준다.

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/decision_store.dart';
import '../services/notification_service.dart';
import '../services/review_prompt.dart';
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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = await DecisionStore.load();
      if (!mounted) return;
      setState(() {
        _store = store;
        _records = store.loadAll();
      });
    } catch (_) {
      // 로드 실패 시 빈 목록으로 보여준다. (스토어 내부에서도
      // 파싱 실패를 걸러내지만, 여기서도 로딩이 영원히 안 끝나지 않게 한다.)
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _answer(String id, String answer) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _store?.answerFollowUp(id, answer);
      try {
        await followUpNotifications.cancelFollowUp(id);
      } catch (_) {
        // 알림 취소 실패가 답 저장을 막으면 안 된다.
      }
      await _load();
      if (!mounted) return;
      // 잘 된 결정이면 한 번만 스토어 별점을 부탁한다.
      // 평생 패스 모델에서는 되물음 루프의 목적이 재구매가 아니라 리뷰·공유다.
      final showReview = await ReviewPrompt.shouldShow(answer);
      if (!mounted) return;
      if (showReview) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('결정이 잘 됐다니 다행이에요. 스토어 별점이 큰 힘이 돼요.'),
            action: SnackBarAction(
              label: '별점 남기기',
              onPressed: () => reviewPrompt.prompt(),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록했어요. 다음 결정에도 참고할게요.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
    try {
      await _store?.remove(id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제에 실패했어요. 다시 시도해 주세요.')),
      );
      return;
    }
    try {
      await followUpNotifications.cancelFollowUp(id);
    } catch (_) {
      // 알림 취소 실패가 삭제를 막으면 안 된다.
    }
    if (!mounted) return;
    await _load();
  }

  String _dateLabel(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

  /// 선택한 안 표시 문구. '비슷함'·'A'·'B' 외의 값은 '선택 없음'으로 보인다.
  String _chosenText(DecisionRecord r) {
    if (r.chosen == '비슷함') return '비슷함';
    if (r.chosen == 'A') return 'A안: ${r.optionA}';
    if (r.chosen == 'B') return 'B안: ${r.optionB}';
    return '선택 없음';
  }

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
            const SizedBox(height: 6),
            Text('선택: ${_chosenText(r)}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(r.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final answer in ['잘 됐어요', '아직 몰라요', '안 됐어요'])
                  OutlinedButton(
                    onPressed:
                        _isSubmitting ? null : () => _answer(r.id, answer),
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
    final chosenText = _chosenText(r);
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
                  Flexible(
                    child: Text(
                      '결과: ${r.followUp}',
                      style: const TextStyle(
                        color: AppTheme.vermilionSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
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
