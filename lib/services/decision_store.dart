// 결정 기록 로컬 저장 — SharedPreferences에 JSON 리스트로 보관한다.
// 결정사주의 핵심 차별점(결정 기록 + 30일 뒤 되물음)의 저장소다.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class DecisionStore {
  static const String _key = 'decision_records_v1';

  final SharedPreferences _prefs;

  DecisionStore(this._prefs);

  static Future<DecisionStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DecisionStore(prefs);
  }

  List<DecisionRecord> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(DecisionRecord.tryFromJson)
          .whereType<DecisionRecord>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> _save(List<DecisionRecord> records) async {
    return _prefs.setString(
      _key,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  /// 새 결정을 맨 앞에 추가한다.
  Future<bool> add(DecisionRecord record) async {
    final records = loadAll();
    records.insert(0, record);
    return _save(records);
  }

  /// 되물음 답을 기록한다.
  Future<bool> answerFollowUp(String id, String answer) async {
    final records = loadAll();
    final idx = records.indexWhere((r) => r.id == id);
    if (idx < 0) return false;
    records[idx] = records[idx].copyWith(
      followUp: answer,
      followUpAt: DateTime.now(),
    );
    return _save(records);
  }

  Future<bool> remove(String id) async {
    final records = loadAll()..removeWhere((r) => r.id == id);
    return _save(records);
  }

  /// 30일이 지나 되물어야 할 결정들.
  List<DecisionRecord> dueFollowUps() =>
      loadAll().where((r) => r.followUpDue).toList();
}
