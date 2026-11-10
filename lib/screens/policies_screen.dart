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
          for (final (title, body) in policies) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: const TextStyle(fontSize: 14, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
