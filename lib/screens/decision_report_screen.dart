// 결정 리포트 — 주제·A/B 입력 → 결제 전 고지 → 리포트 화면
//
// 결제(인앱결제) 연결은 플랜 8번 항목에서 한다. 지금은 결제 버튼을 누르면
// "결제 연동 전 미리보기" 안내와 함께 리포트를 보여준다.

import 'package:flutter/material.dart';

import '../engine/compat.dart';
import '../engine/decision.dart';
import '../models.dart';
import '../services/decision_store.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_member_sheet.dart';
import '../widgets/report_share_card.dart';
import 'lucky_days_screen.dart';

const List<String> _topics = ['이직', '이사', '결혼', '개업', '출산', '기타'];

class DecisionFormScreen extends StatefulWidget {
  final List<FamilyMember> members;
  final Future<void> Function(FamilyMember) onAddMember;

  const DecisionFormScreen({
    super.key,
    required this.members,
    required this.onAddMember,
  });

  @override
  State<DecisionFormScreen> createState() => _DecisionFormScreenState();
}

class _DecisionFormScreenState extends State<DecisionFormScreen> {
  late List<FamilyMember> _members;
  int _memberIndex = 0;
  String _topic = '이직';
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  DateTime _dateA = DateTime.now();
  DateTime _dateB = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _members = List.of(widget.members);
  }

  @override
  void dispose() {
    _optionAController.dispose();
    _optionBController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isA) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isA ? _dateA : _dateB,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isA) {
        _dateA = picked;
      } else {
        _dateB = picked;
      }
    });
  }

  String _dateLabel(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

  Future<void> _openAddMember() async {
    var added = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddMemberSheet(
        onSave: (member) async {
          await widget.onAddMember(member);
          added = true;
          if (!mounted) return;
          setState(() {
            _members = [..._members, member];
            _memberIndex = _members.length - 1;
          });
        },
      ),
    );
    if (added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가족 구성원을 추가했어요.')),
      );
    }
  }

  void _showNotice() {
    final a = _optionAController.text.trim();
    final b = _optionBController.text.trim();
    if (a.isEmpty || b.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A안과 B안을 모두 적어주세요.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결정 리포트 만들기'),
        content: const Text(
          '이 리포트에 포함되는 것\n'
          '· A/B 양자택일 결론 1줄 + 결정 지수\n'
          '· 근거 3줄 (용신·일진·대운)\n'
          '· 30일 길일 3개\n'
          '· 오늘 피할 것 1개\n'
          '· 결정 기록 + 30일 뒤 되물음\n\n'
          '가격 4,900원 · 일회성 · 구독 없음 · 추가 결제 없음\n\n'
          '사주는 참고용이에요. 결과를 보장하지 않으며, 계산 오류가 있으면 환불해 드려요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DecisionReportScreen(
                    member: _members[_memberIndex],
                    topic: _topic,
                    optionA: a,
                    optionB: b,
                    dateA: _dateA,
                    dateB: _dateB,
                  ),
                ),
              );
            },
            child: const Text('4,900원 결제하고 보기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('결정 리포트 만들기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_members.isEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '먼저 내 사주를 알려주세요.',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '가족 보관함에 나를 추가하면, 내 사주 흐름에 맞는 리포트를 만들 수 있어요.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openAddMember,
                        child: const Text('가족 구성원 추가하기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text('누구의 결정인가요?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < _members.length; i++)
                  ChoiceChip(
                    label: Text('${_members[i].name} · ${_members[i].relation}'),
                    selected: _memberIndex == i,
                    onSelected: (_) => setState(() => _memberIndex = i),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('무엇을 결정하나요?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in _topics)
                  ChoiceChip(
                    label: Text(t),
                    selected: _topic == t,
                    onSelected: (_) => setState(() => _topic = t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('두 가지 선택지를 적어주세요', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _optionAController,
              decoration: const InputDecoration(labelText: 'A안 (예: 지금 회사에 남기)'),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text('A안 날짜 — ${_dateLabel(_dateA)}'),
              onTap: () => _pickDate(true),
            ),
            TextField(
              controller: _optionBController,
              decoration: const InputDecoration(labelText: 'B안 (예: 다른 회사로 옮기기)'),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text('B안 날짜 — ${_dateLabel(_dateB)}'),
              onTap: () => _pickDate(false),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showNotice,
                child: const Text('리포트 만들기'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '날짜가 다르면 사주 흐름이 달라져요. A안은 보통 "지금", B안은 "조금 뒤"로 잡으면 비교가 쉬워요.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// 결정 리포트 결과 화면 — 결론·결정 지수 먼저, 근거 3줄, 길일 3개, 오늘 피할 것.
class DecisionReportScreen extends StatefulWidget {
  final FamilyMember member;
  final String topic;
  final String optionA;
  final String optionB;
  final DateTime dateA;
  final DateTime dateB;

  const DecisionReportScreen({
    super.key,
    required this.member,
    required this.topic,
    required this.optionA,
    required this.optionB,
    required this.dateA,
    required this.dateB,
  });

  @override
  State<DecisionReportScreen> createState() => _DecisionReportScreenState();
}

class _DecisionReportScreenState extends State<DecisionReportScreen> {
  bool _saved = false;
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
    String chosen,
    String summary,
    int index,
  ) async {
    final store = await DecisionStore.load();
    final record = DecisionRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      topic: widget.topic,
      optionA: widget.optionA,
      optionB: widget.optionB,
      chosen: chosen,
      decidedAt: DateTime.now(),
      summary: summary,
      index: index,
    );
    await store.add(record);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('결정 기록에 저장했어요. 30일 뒤에 다시 물어볼게요.')),
    );
  }

  String _dateLabel(DateTime d) => '${d.month}월 ${d.day}일';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final saju = sajuOfBirth(widget.member.birth, widget.member.birthHour);
    final index = decisionIndex(saju, now);
    final comparison = compareOptions(saju, widget.dateA, widget.dateB);
    final lucky = luckyDays(saju, now);
    final evidence = evidenceLines(_baby, saju, now);
    final avoid = avoidLine(saju, now);

    final String conclusion;
    if (comparison.recommendation == 'A') {
      conclusion = '사주 흐름상 A안(${widget.optionA})이 유리해요.';
    } else if (comparison.recommendation == 'B') {
      conclusion = '사주 흐름상 B안(${widget.optionB})이 유리해요.';
    } else {
      conclusion = '두 선택지의 흐름 차이가 크지 않아요. 현실 조건을 더 따져보세요.';
    }

    return Scaffold(
      appBar: AppBar(title: Text('${widget.topic} 결정 리포트')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 결제 연동 전 미리보기 안내 (플랜 8번에서 인앱결제 연결 후 제거)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              '미리보기 — 결제 연동 전이에요. 인앱결제는 8번 항목에서 연결합니다.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          // 결론 카드 — 결정 지수 + 결론 먼저
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$index',
                        style: const TextStyle(
                          color: AppTheme.vermilion,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/ 100 · ${scoreLabel(index)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '오늘의 결정 지수 — ${widget.member.name}님의 ${widget.topic} 결정',
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
                  const SizedBox(height: 12),
                  _scoreBar('A안 · ${widget.optionA}', comparison.scoreA),
                  const SizedBox(height: 8),
                  _scoreBar('B안 · ${widget.optionB}', comparison.scoreB),
                  const SizedBox(height: 8),
                  Text(comparison.reason, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '근거 3줄'),
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
                  const SizedBox(height: 12),
                  Text(
                    '같은 계산에서 나온 결과입니다.',
                    style: theme.textTheme.bodySmall,
                  ),
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saved
                  ? null
                  : () => _saveRecord(
                        comparison.recommendation,
                        conclusion,
                        index,
                      ),
              child: Text(_saved ? '결정 기록에 저장했어요' : '결정 기록에 저장하기'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '저장하면 30일 뒤 "그 결정, 어떻게 됐어요?"라고 다시 물어봐요.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, '공유하기'),
          RepaintBoundary(
            key: _shareKey,
            child: ReportShareCard(
              memberName: widget.member.name,
              topic: widget.topic,
              index: index,
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
                    '[결정사주] ${widget.member.name}님의 ${widget.topic} 결정 리포트 — 오늘의 결정 지수 $index점. $conclusion',
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
