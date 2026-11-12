// 결정 리포트 — 주제·A/B 입력 → 결제 전 고지 → 인앱결제 → 리포트 화면
//
// 인앱결제: lib/services/payment_service.dart (상품 ID decision_report_4900,
// Play Console에서 직접 등록해야 함). 결제 성공 시에만 리포트를 연다.

import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/compat.dart';
import '../engine/decision.dart';
import '../engine/decision_options.dart';
import '../engine/saju.dart';
import '../models.dart';
import '../services/decision_store.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_member_sheet.dart';
import '../widgets/report_share_card.dart';
import 'lucky_days_screen.dart';
import 'policies_screen.dart';

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

  BabyInfo _babyFor(FamilyMember m) => BabyInfo(
        surname: '',
        surnameHanja: '',
        surnameStrokes: 0,
        gender: m.gender,
        birth: m.birth,
        birthHour: m.birthHour,
      );

  /// 선택형은 고정 문구, 날짜형(개업·출산)은 날짜 라벨, 기타는 직접 입력한 글자.
  String _optionLabel(bool isA) {
    final config = configForTopic(_topic);
    if (config.mode == DecisionMode.choice) {
      return isA ? config.optionA : config.optionB;
    }
    if (!config.freeText) {
      return _dateLabel(isA ? _dateA : _dateB);
    }
    return (isA ? _optionAController.text : _optionBController.text).trim();
  }

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

  void _showNotice() async {
    final config = configForTopic(_topic);
    // 기타(자유 입력)만 글자를 확인한다. 선택형은 고정 문구, 개업·출산은 날짜다.
    if (config.freeText) {
      final a = _optionAController.text.trim();
      final b = _optionBController.text.trim();
      if (a.isEmpty || b.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A안과 B안을 모두 적어주세요.')),
        );
        return;
      }
    }
    // 평생 패스를 이미 샀으면 결제 없이 바로 리포트를 연다.
    // 로컬 해금 플래그만 본다. 스토어 복원을 여기서 기다리면
    // 미구매자는 매번 빈 응답을 기다리느라 진입이 늦어진다.
    // 복원은 백그라운드로 돌리고, 복원되면 다음 진입부터 바로 열린다.
    final unlocked = await PaymentService.isPassUnlocked();
    if (!unlocked) {
      unawaited(PaymentService().restorePass());
    }
    if (!mounted) return;
    if (unlocked) {
      _openReport();
      return;
    }
    // 결제 전 티저 — 실제 계산 결과를 일부만 미리 보여준다.
    // 결정 지수 2개 + 용신 1줄은 무료로, 길일 날짜·나머지 근거·가족 공통
    // 길일은 결제 뒤에 확인할 수 있다.
    final member = _members[_memberIndex];
    final saju = sajuOfBirth(member.birth, member.birthHour);
    final DecisionComparison preview;
    if (config.mode == DecisionMode.choice) {
      preview = scoreChoiceOptions(
        baby: _babyFor(member),
        saju: saju,
        topic: _topic,
        now: DateTime.now(),
      );
    } else {
      preview = scoreTimingOptions(
        saju: saju,
        topic: _topic,
        dateA: _dateA,
        dateB: _dateB,
      );
    }
    final yongsinLine = saju.yongsin != null
        ? '용신은 ${elementNames[saju.yongsin]} 기운이에요.'
        : '부족한 오행은 ${lackingElements(saju.elementCounts).map((e) => elementNames[e]).join('·')}이에요.';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결정 리포트 만들기'),
        content: Text(
          '지금 계산해 본 결과\n'
          '· A안 (${_optionLabel(true)}) 결정 지수 ${preview.scoreA}점\n'
          '· B안 (${_optionLabel(false)}) 결정 지수 ${preview.scoreB}점\n'
          '· $yongsinLine\n\n'
          '결제하면 확인할 수 있어요\n'
          '· A/B 양자택일 결론 1줄 + 결정 지수\n'
          '· 근거 (용신·일진·대운${config.mode == DecisionMode.choice ? '·이번 달 운세' : ''})\n'
          '· 30일 길일 3개 + 우리 가족 공통 길일\n'
          '· 조심할 날 2개 · 오늘 피할 것 1개\n'
          '· 결정 기록 + 길일 당일·3일 뒤·30일 뒤 되물음\n\n'
          '가격 4,900원 · 한 번만 결제 · 구독 없음\n'
          '결제 후 모든 결정 리포트를 무제한으로 볼 수 있고, '
          '가족 보관함도 6명까지 쓸 수 있어요.\n\n'
          '사주는 참고용이에요. 결과를 보장하지 않으며, 계산 오류가 있으면 환불해 드려요.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PoliciesScreen(),
                ),
              );
            },
            child: const Text('환불정책·약관 보기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _payAndOpenReport();
            },
            child: const Text('4,900원 한 번 결제하고 보기'),
          ),
        ],
      ),
    );
  }

  void _openReport() {
    final config = configForTopic(_topic);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DecisionReportScreen(
          member: _members[_memberIndex],
          family: _members,
          topic: _topic,
          optionA: _optionLabel(true),
          optionB: _optionLabel(false),
          dateA: config.mode == DecisionMode.choice ? null : _dateA,
          dateB: config.mode == DecisionMode.choice ? null : _dateB,
        ),
      ),
    );
  }

  /// 결제 → 성공 시에만 리포트를 연다.
  Future<void> _payAndOpenReport() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        // 결제 중에는 뒤로가기로 닫히지 않게 한다.
        // (다이얼로그만 닫히고 결제 완료 뒤 pop()이 폼 화면을 닫아버린다.)
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('결제 준비 중이에요.'),
            ],
          ),
        ),
      ),
    );
    final result = await PaymentService().buyPass();
    if (!mounted) return;
    Navigator.of(context).pop(); // 로딩 닫기
    switch (result) {
      case PaymentResult.success:
        _openReport();
      case PaymentResult.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결제를 취소했어요.')),
        );
      case PaymentResult.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지금은 스토어 결제를 쓸 수 없어요.')),
        );
      case PaymentResult.productNotFound:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('아직 결제 상품을 준비 중이에요. 잠시 뒤 다시 시도해 주세요.'),
            duration: Duration(seconds: 5),
          ),
        );
      case PaymentResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결제 중 문제가 생겼어요. 다시 시도해 주세요.')),
        );
    }
  }

  Widget _optionCard(String label, String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.vermilion,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
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
            Builder(
              builder: (context) {
                final config = configForTopic(_topic);
                // 선택형(이직·이사·결혼): 고정된 두 선택지를 보여준다. 날짜는 안 받는다.
                if (config.mode == DecisionMode.choice) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('두 가지 선택지', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _optionCard('A안', config.optionA),
                      const SizedBox(height: 8),
                      _optionCard('B안', config.optionB),
                      const SizedBox(height: 8),
                      Text(config.hint, style: theme.textTheme.bodySmall),
                    ],
                  );
                }
                // 날짜형(개업·출산): 날짜만 고른다.
                if (!config.freeText) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('두 날짜를 골라주세요', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today, size: 20),
                        title: Text('A안 날짜 — ${_dateLabel(_dateA)}'),
                        onTap: () => _pickDate(true),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today, size: 20),
                        title: Text('B안 날짜 — ${_dateLabel(_dateB)}'),
                        onTap: () => _pickDate(false),
                      ),
                      const SizedBox(height: 8),
                      Text(config.hint, style: theme.textTheme.bodySmall),
                    ],
                  );
                }
                // 기타: 선택지 글자 + 날짜를 직접 적는다.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('두 가지 선택지를 적어주세요', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _optionAController,
                      decoration: const InputDecoration(labelText: 'A안'),
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
                      decoration: const InputDecoration(labelText: 'B안'),
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today, size: 20),
                      title: Text('B안 날짜 — ${_dateLabel(_dateB)}'),
                      onTap: () => _pickDate(false),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '날짜가 다르면 사주 흐름이 달라져요. A안은 보통 "지금", B안은 "조금 뒤"로 잡으면 비교가 쉬워요.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showNotice,
                child: const Text('리포트 만들기'),
              ),
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

  /// 가족 보관함 전체 (우리 가족 공통 길일 계산용). 없으면 빈 목록.
  final List<FamilyMember> family;
  final String topic;
  final String optionA;
  final String optionB;

  /// 선택형(이직·이사·결혼)은 날짜를 쓰지 않아 null이다.
  final DateTime? dateA;
  final DateTime? dateB;

  const DecisionReportScreen({
    super.key,
    required this.member,
    this.family = const [],
    required this.topic,
    required this.optionA,
    required this.optionB,
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
    String chosen,
    String summary,
    int index, {
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
        topic: widget.topic,
        optionA: widget.optionA,
        optionB: widget.optionB,
        chosen: chosen,
        decidedAt: DateTime.now(),
        summary: summary,
        index: index,
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
    final index = decisionIndex(saju, now);
    final config = configForTopic(widget.topic);
    // 선택형은 사주+이번달 운세로 선택지를 채점하고, 날짜형은 두 날짜를 비교한다.
    final comparison = config.mode == DecisionMode.choice
        ? scoreChoiceOptions(
            baby: _baby,
            saju: saju,
            topic: widget.topic,
            now: now,
          )
        : scoreTimingOptions(
            saju: saju,
            topic: widget.topic,
            dateA: widget.dateA!,
            dateB: widget.dateB!,
          );
    // 선택형은 추천 선택지의 점수를, 날짜형은 오늘의 결정 지수를 크게 보여준다.
    final displayIndex = config.mode == DecisionMode.choice
        ? (comparison.scoreA > comparison.scoreB
            ? comparison.scoreA
            : comparison.scoreB)
        : index;
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
    // 근거: 선택형은 채점 요인, 날짜형은 용신·일진·대운 3줄.
    final evidence = config.mode == DecisionMode.choice
        ? comparison.reasons
        : evidenceLines(_baby, saju, now);
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
                    config.mode == DecisionMode.choice
                        ? '추천 선택지의 결정 지수 — ${widget.member.name}님의 ${widget.topic} 결정'
                        : '오늘의 결정 지수 — ${widget.member.name}님의 ${widget.topic} 결정',
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
          _sectionTitle(
            theme,
            config.mode == DecisionMode.choice ? '이렇게 판단했어요' : '근거 3줄',
          ),
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
                  if (config.mode == DecisionMode.timing) ...[
                    const SizedBox(height: 12),
                    Text(
                      '같은 계산에서 나온 결과입니다.',
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
                        comparison.recommendation,
                        conclusion,
                        displayIndex,
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
              topic: widget.topic,
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
                    '[결정사주] ${widget.member.name}님의 ${widget.topic} 결정 리포트 — 결정 지수 $displayIndex점. $conclusion',
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
