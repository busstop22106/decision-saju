// 만세력 — 구성원 선택 또는 직접 입력으로 사주팔자를 보여준다

import 'package:flutter/material.dart';

import '../engine/compat.dart';
import '../engine/saju.dart';
import '../models.dart';
import '../theme/app_theme.dart';

/// 오행별 점 색상 (다크 배경에서 잘 보이는 색)
const Map<String, Color> _elementDotColors = {
  '목': Colors.green,
  '화': Colors.red,
  '토': Colors.amber,
  '금': Colors.white,
  '수': Colors.lightBlue,
};

class SajuScreen extends StatefulWidget {
  final List<FamilyMember> members;

  const SajuScreen({super.key, required this.members});

  @override
  State<SajuScreen> createState() => _SajuScreenState();
}

class _SajuScreenState extends State<SajuScreen> {
  String? _selectedMemberId;
  DateTime? _adhocBirth;
  bool _adhocTimeUnknown = true;
  int _adhocHour = 12;

  /// 현재 보여줄 사주. 선택이 없으면 null.
  SajuResult? get _currentSaju {
    if (_selectedMemberId != null) {
      final member = widget.members
          .where((m) => m.id == _selectedMemberId)
          .firstOrNull;
      if (member != null) {
        return sajuOfBirth(member.birth, member.birthHour);
      }
    }
    if (_adhocBirth != null) {
      return sajuOfBirth(
        _adhocBirth!,
        _adhocTimeUnknown ? null : _adhocHour,
      );
    }
    return null;
  }

  String get _currentLabel {
    if (_selectedMemberId != null) {
      final member = widget.members
          .where((m) => m.id == _selectedMemberId)
          .firstOrNull;
      if (member != null) return '${member.name}님의 사주';
    }
    if (_adhocBirth != null) return '직접 입력한 사주';
    return '';
  }

  Future<void> _pickAdhocBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _adhocBirth = picked;
        _selectedMemberId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saju = _currentSaju;

    return Scaffold(
      appBar: AppBar(title: const Text('만세력')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.members.isNotEmpty) ...[
            Text('구성원', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.members.map((m) {
                final selected = _selectedMemberId == m.id;
                return ChoiceChip(
                  label: Text('${m.name} · ${m.relation}'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedMemberId = selected ? null : m.id;
                      if (!selected) _adhocBirth = null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            onPressed: _pickAdhocBirth,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              _adhocBirth == null
                  ? '생년월일 직접 입력하기'
                  : '직접 입력: ${_adhocBirth!.year}년 ${_adhocBirth!.month}월 ${_adhocBirth!.day}일',
            ),
          ),
          if (_adhocBirth != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('출생 시간', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('시간 모름'),
                  selected: _adhocTimeUnknown,
                  onSelected: (_) =>
                      setState(() => _adhocTimeUnknown = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('시간 입력'),
                  selected: !_adhocTimeUnknown,
                  onSelected: (_) =>
                      setState(() => _adhocTimeUnknown = false),
                ),
                if (!_adhocTimeUnknown) ...[
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _adhocHour,
                    dropdownColor: AppTheme.card,
                    items: List.generate(
                      24,
                      (h) => DropdownMenuItem(
                        value: h,
                        child: Text('$h시'),
                      ),
                    ),
                    onChanged: (h) {
                      if (h != null) setState(() => _adhocHour = h);
                    },
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (saju == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '구성원을 선택하거나 생년월일을 직접 입력하면 사주팔자를 보여드려요.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else ...[
            Text(_currentLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _pillarsCard(saju, theme),
            const SizedBox(height: 12),
            _detailsCard(saju, theme),
            const SizedBox(height: 12),
            Text(
              saju.notes.join('\n'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _pillarsCard(SajuResult saju, ThemeData theme) {
    final pillars = <({String title, SajuPillar? pillar})>[
      (title: '년주', pillar: saju.year),
      (title: '월주', pillar: saju.month),
      (title: '일주', pillar: saju.day),
      (title: '시주', pillar: saju.hour),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: pillars.map((p) {
            final pillar = p.pillar;
            final element =
                pillar == null ? null : stemElement(pillar.stem);
            return Expanded(
              child: Column(
                children: [
                  Text(p.title, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: element == null
                          ? AppTheme.muted
                          : _elementDotColors[element],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pillar?.label ?? '—',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    element == null
                        ? '시간 미입력'
                        : elementNames[element] ?? element,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _detailsCard(SajuResult saju, ThemeData theme) {
    final lacking = lackingElements(saju.elementCounts);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _detailRow(
              '일간',
              '${saju.dayMaster} (${elementNames[saju.dayElement] ?? saju.dayElement})',
              theme,
            ),
            _detailRow('신강 / 신약', saju.strongBody ? '신강' : '신약', theme),
            _detailRow(
              '용신',
              saju.yongsin == null
                  ? '—'
                  : elementNames[saju.yongsin] ?? saju.yongsin!,
              theme,
            ),
            _detailRow(
              '희신',
              saju.huishin == null
                  ? '—'
                  : elementNames[saju.huishin] ?? saju.huishin!,
              theme,
            ),
            _detailRow(
              '부족한 오행',
              lacking.map((e) => elementNames[e] ?? e).join(', '),
              theme,
              last: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
