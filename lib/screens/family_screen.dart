// 가족 보관함 — 구성원 최대 3명 저장 + 쌍별 띠 궁합 요약

import 'package:flutter/material.dart';

import '../engine/compat.dart';
import '../engine/saju.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/add_member_sheet.dart';
import '../services/family_store.dart';

class FamilyScreen extends StatelessWidget {
  final List<FamilyMember> members;
  final Future<void> Function(FamilyMember member) onAdd;
  final Future<void> Function(String id) onRemove;

  const FamilyScreen({
    super.key,
    required this.members,
    required this.onAdd,
    required this.onRemove,
  });

  Future<void> _confirmRemove(BuildContext context, FamilyMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${m.name}님을 삭제할까요?'),
        content: const Text('저장된 구성원 정보가 삭제돼요.'),
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
    if (ok == true) {
      await onRemove(m.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${m.name}님을 삭제했어요.')),
        );
      }
    }
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddMemberSheet(
          onSave: (member) async {
            await onAdd(member);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final full = members.length >= FamilyStore.maxMembers;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '가족 보관함 ${members.length}/${FamilyStore.maxMembers}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (members.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '가족 구성원을 저장하면 만세력과 오늘 운세, 궁합 요약을 바로 볼 수 있어요.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else ...[
            ...members.map((m) => _memberCard(context, m)),
            const SizedBox(height: 20),
            Text('궁합 요약', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _compatCard(theme),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  full ? null : () => _openAddSheet(context),
              icon: const Icon(Icons.person_add_outlined),
              label: Text(full ? '무료 보관함은 3명까지예요' : '구성원 추가'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(BuildContext context, FamilyMember m) {
    final saju = sajuOfBirth(m.birth, m.birthHour);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person, color: AppTheme.vermilion, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m.name} · ${m.relation} · ${m.gender.label}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m.birth.year}년 ${m.birth.month}월 ${m.birth.day}일'
                      '${m.timeUnknown ? ' · 시간 모름' : ' · ${m.birthHour}시'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${saju.dayMaster}일생 · 용신 ${saju.yongsin == null ? '—' : elementNames[saju.yongsin] ?? saju.yongsin!}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _confirmRemove(context, m),
                icon: const Icon(Icons.delete_outline, color: AppTheme.muted),
                tooltip: '삭제',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compatCard(ThemeData theme) {
    if (members.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            '구성원을 2명 이상 추가하면 쌍별 띠 궁합을 보여드려요.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < members.length; i++) {
      for (var j = i + 1; j < members.length; j++) {
        final a = members[i];
        final b = members[j];
        final aBranch = sajuOfBirth(a.birth, a.birthHour).year.branch;
        final bBranch = sajuOfBirth(b.birth, b.birthHour).year.branch;
        final label = zodiacLabel(aBranch, bBranch);
        final aZodiac = zodiacNames[aBranch] ?? '';
        final bZodiac = zodiacNames[bBranch] ?? '';
        rows.add(
          Padding(
            padding: EdgeInsets.only(bottom: i == members.length - 2 &&
                    j == members.length - 1
                ? 0
                : 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${a.name}($aZodiac) × ${b.name}($bZodiac)',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.vermilionSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }
}
