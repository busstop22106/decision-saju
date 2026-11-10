// 공유용 결정 리포트 카드 — 이미지(PNG)로 저장·공유되는 부분.
//
// 리포트 화면 하단에 그대로 보이고, RepaintBoundary로 감싸 캡처한다.
// 결론·결정 지수·길일 3개만 담아 한 장으로 읽히게 만든다.

import 'package:flutter/material.dart';

import '../engine/decision.dart';
import '../theme/app_theme.dart';

class ReportShareCard extends StatelessWidget {
  final String memberName;
  final String topic;
  final int index;
  final String conclusion;
  final List<LuckyDay> luckyDays;

  const ReportShareCard({
    super.key,
    required this.memberName,
    required this.topic,
    required this.index,
    required this.conclusion,
    required this.luckyDays,
  });

  String _dateLabel(DateTime d) => '${d.month}월 ${d.day}일';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Text(
                '결정사주',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$topic 결정 리포트',
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 8),
          Text(
            conclusion,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$memberName님의 $topic 결정',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text(
            '30일 길일 3개',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final day in luckyDays)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· ${_dateLabel(day.date)} (${day.score}점) — ${day.reason}',
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            '사주는 참고용이에요. 결정사주에서 만든 리포트입니다.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
