// 정책 화면 — 재미·참고용 고지, 환불정책, 개인정보처리방침, 이용약관.

import 'package:flutter/material.dart';

import '../data/policies.dart';

class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('정책')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < policies.length; i++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      policies[i].$1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      policies[i].$2,
                      style: const TextStyle(fontSize: 14, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
            // 마지막 항목 뒤에는 간격을 두지 않는다.
            // 두면 하단 패딩 24와 합쳐져 36이 된다.
            if (i < policies.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
