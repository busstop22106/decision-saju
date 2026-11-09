// 가족 구성원 추가 시트 — 이름·관계·성별·생년월일·출생 시간 입력

import 'package:flutter/material.dart';

import '../models.dart';

class AddMemberSheet extends StatefulWidget {
  final void Function(FamilyMember member) onSave;

  const AddMemberSheet({super.key, required this.onSave});

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  final _nameController = TextEditingController();
  String _relation = '나';
  Gender _gender = Gender.boy;
  DateTime? _birth;
  bool _timeUnknown = true;
  int _hour = 12;

  static const _relations = [
    '나',
    '아빠',
    '엄마',
    '배우자',
    '자녀',
    '형제자매',
    '조부모',
    '기타',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birth = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _birth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 생년월일을 입력해주세요.')),
      );
      return;
    }
    widget.onSave(
      FamilyMember(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        relation: _relation,
        gender: _gender,
        birth: _birth!,
        birthHour: _timeUnknown ? null : _hour,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '구성원 추가',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '이름 (예: 나, 진욱)',
              hintText: '화면에 표시될 이름',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _relation,
            decoration: const InputDecoration(labelText: '관계'),
            items: _relations
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _relation = v);
            },
          ),
          const SizedBox(height: 14),
          const Text('성별', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('남성'),
                selected: _gender == Gender.boy,
                onSelected: (_) => setState(() => _gender = Gender.boy),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('여성'),
                selected: _gender == Gender.girl,
                onSelected: (_) => setState(() => _gender = Gender.girl),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickBirth,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              _birth == null
                  ? '생년월일 선택'
                  : '${_birth!.year}년 ${_birth!.month}월 ${_birth!.day}일',
            ),
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            value: _timeUnknown,
            onChanged: (v) {
              if (v != null) setState(() => _timeUnknown = v);
            },
            title: const Text('출생 시간을 몰라요', style: TextStyle(fontSize: 14)),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (!_timeUnknown)
            Row(
              children: [
                const Text('출생 시간', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _hour,
                  items: List.generate(
                    24,
                    (h) => DropdownMenuItem(value: h, child: Text('$h시')),
                  ),
                  onChanged: (h) {
                    if (h != null) setState(() => _hour = h);
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}
