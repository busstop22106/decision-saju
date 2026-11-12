// 질문 목록 — 카테고리 → 질문 → 공감 문구 + 리포트 만들기.
//
// 앱의 결정 리포트 진입점이다. 기존 A/B 폼(DecisionFormScreen)은 제거되고,
// 이 화면이 질문 흐름의 시작점이 된다.

import 'package:flutter/material.dart';

import '../data/popular_questions.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import 'question_report_form_screen.dart';

class QuestionBrowserScreen extends StatefulWidget {
  final List<FamilyMember> members;
  final Future<void> Function(FamilyMember) onAddMember;

  const QuestionBrowserScreen({
    super.key,
    required this.members,
    required this.onAddMember,
  });

  @override
  State<QuestionBrowserScreen> createState() => _QuestionBrowserScreenState();
}

class _QuestionBrowserScreenState extends State<QuestionBrowserScreen> {
  String _categoryId = questionCategories.first.id;
  String? _expandedId;

  void _openForm(PopularQuestion question) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionReportFormScreen(
          question: question,
          members: widget.members,
          onAddMember: widget.onAddMember,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = questionsForCategory(_categoryId);
    return Scaffold(
      appBar: AppBar(title: const Text('결정 리포트')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '궁금한 질문을 골라보세요',
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '가장 많이 물어보는 질문 139개를 모았어요. 질문을 고르면 내 사주로 답하는 리포트를 만들 수 있어요.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in questionCategories) ...[
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _categoryId == c.id,
                    onSelected: (_) {
                      setState(() {
                        _categoryId = c.id;
                        _expandedId = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                for (final q in questions) ...[
                  Card(
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardRadius),
                      onTap: () {
                        setState(() {
                          _expandedId = _expandedId == q.id ? null : q.id;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    q.text,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _expandedId == q.id
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: AppTheme.vermilion,
                                ),
                              ],
                            ),
                            if (q.kind == QuestionKind.timing) ...[
                              const SizedBox(height: 6),
                              Text(
                                '날짜를 골라 비교해요',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if (_expandedId == q.id) ...[
                              const SizedBox(height: 12),
                              Text(
                                q.empathy,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _openForm(q),
                                  child: const Text('리포트 만들기'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
