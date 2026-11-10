// 용어 해설 목록 화면 — 모든 용어를 한 줄 해설과 함께 보여준다.

import 'package:flutter/material.dart';

import '../data/glossary.dart';
import '../theme/app_theme.dart';

class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('용어 한 줄 해설')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            '사주 용어가 어렵다면, 여기서 한 줄로 확인하세요.',
            style: TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < glossary.length; i++) ...[
                    Text(
                      glossary[i].$1,
                      style: const TextStyle(
                        color: AppTheme.vermilion,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      glossary[i].$2,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    if (i < glossary.length - 1) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 용어 한 줄 해설을 다이얼로그로 보여준다. 용어가 없으면 아무 일도 안 한다.
void showGlossaryTerm(BuildContext context, String term) {
  final desc = glossaryOf(term);
  if (desc == null) return;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(term),
      content: Text(desc, style: const TextStyle(fontSize: 15, height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}
