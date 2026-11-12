// 질문 리포트 만들기 — 질문 + 누구의 사주인지 + (날짜형이면 날짜) →
// 결제 전 미리보기 모달 → 인앱결제 → 리포트 화면.
//
// 인앱결제: lib/services/payment_service.dart (상품 ID decision_report_4900,
// Play Console에서 직접 등록해야 함). 결제 성공 시에만 리포트를 연다.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/popular_questions.dart';
import '../engine/compat.dart';
import '../engine/decision_options.dart';
import '../engine/question_report.dart';
import '../engine/saju.dart';
import '../models.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_member_sheet.dart';
import 'decision_report_screen.dart';
import 'policies_screen.dart';

class QuestionReportFormScreen extends StatefulWidget {
  final PopularQuestion question;
  final List<FamilyMember> members;
  final Future<void> Function(FamilyMember) onAddMember;

  const QuestionReportFormScreen({
    super.key,
    required this.question,
    required this.members,
    required this.onAddMember,
  });

  @override
  State<QuestionReportFormScreen> createState() =>
      _QuestionReportFormScreenState();
}

class _QuestionReportFormScreenState extends State<QuestionReportFormScreen> {
  late List<FamilyMember> _members;
  int _memberIndex = 0;
  DateTime _dateA = DateTime.now();
  DateTime _dateB = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _members = List.of(widget.members);
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

  QuestionReport _buildReport() {
    final member = _members[_memberIndex];
    final saju = sajuOfBirth(member.birth, member.birthHour);
    return buildQuestionReport(
      baby: _babyFor(member),
      saju: saju,
      question: widget.question,
      now: DateTime.now(),
      dateA: widget.question.kind == QuestionKind.timing ? _dateA : null,
      dateB: widget.question.kind == QuestionKind.timing ? _dateB : null,
    );
  }

  void _showNotice() async {
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
    // 결정 지수 + 용신 1줄은 무료로, 근거·길일 날짜·가족 공통 길일은 결제 뒤에.
    final member = _members[_memberIndex];
    final saju = sajuOfBirth(member.birth, member.birthHour);
    final report = _buildReport();
    final yongsinLine = saju.yongsin != null
        ? '용신은 ${elementNames[saju.yongsin]} 기운이에요.'
        : '부족한 오행은 ${lackingElements(saju.elementCounts).map((e) => elementNames[e]).join('·')}이에요.';
    final previewLines = report.isComparison
        ? '· A안 (${report.optionALabel}) 결정 지수 ${report.scoreA}점\n'
            '· B안 (${report.optionBLabel}) 결정 지수 ${report.scoreB}점\n'
        : '· 이 질문의 결정 지수 ${report.displayIndex}점\n'
            '· ${report.conclusion}\n';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결정 리포트 만들기'),
        content: Text(
          '지금 계산해 본 결과\n'
          '$previewLines'
          '· $yongsinLine\n\n'
          '결제하면 확인할 수 있어요\n'
          '· 결론 1줄 + 결정 지수\n'
          '· 근거 (용신·일진·대운${report.isComparison ? '·이번 달 운세' : ''})\n'
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DecisionReportScreen(
          member: _members[_memberIndex],
          family: _members,
          question: widget.question,
          dateA: widget.question.kind == QuestionKind.timing ? _dateA : null,
          dateB: widget.question.kind == QuestionKind.timing ? _dateB : null,
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
    final question = widget.question;
    final topic = engineTopicForQuestion(question);
    final config = topic == null ? null : configForTopic(topic);
    return Scaffold(
      appBar: AppBar(title: const Text('결정 리포트 만들기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(question.empathy, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
            if (question.kind == QuestionKind.timing) ...[
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
              Text(
                '두 날짜 중 더 좋은 날을 비교해요. 날짜가 다르면 사주 흐름이 달라져요.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
            ],
            if (config != null &&
                config.mode == DecisionMode.choice) ...[
              Text('두 가지 선택지', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _optionCard('A안', config.optionA),
              const SizedBox(height: 8),
              _optionCard('B안', config.optionB),
              const SizedBox(height: 8),
              Text(config.hint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 20),
            ],
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
