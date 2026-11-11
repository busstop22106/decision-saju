// 가족 보관함 로컬 저장 — SharedPreferences에 JSON으로 저장한다.
// 구성원 최대 3명 (무료 범위). 평생 패스 구매 시 6명까지 확장된다.
// 파싱에 실패한 항목은 건너뛴다.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class FamilyStore {
  static const String key = 'family_members_v1';
  static const int maxMembers = 3;

  /// 평생 패스 구매 시 가족 보관함 상한 (무료 3명 → 6명).
  static const int maxMembersUnlocked = 6;

  static Future<List<FamilyMember>> load({
    int maxMembers = FamilyStore.maxMembers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(FamilyMember.tryFromJson)
          .whereType<FamilyMember>()
          .take(maxMembers)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> save(
    List<FamilyMember> members, {
    int maxMembers = FamilyStore.maxMembers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = members.take(maxMembers).toList();
    return prefs.setString(
      key,
      jsonEncode(trimmed.map((m) => m.toJson()).toList()),
    );
  }

  /// 구성원을 추가한다. 상한에 이미 찼으면 그대로 돌려준다.
  static Future<List<FamilyMember>> add(
    List<FamilyMember> current,
    FamilyMember member, {
    int maxMembers = FamilyStore.maxMembers,
  }) async {
    if (current.length >= maxMembers) return current;
    final next = [...current, member];
    await save(next, maxMembers: maxMembers);
    return next;
  }

  static Future<List<FamilyMember>> remove(
    List<FamilyMember> current,
    String id, {
    int maxMembers = FamilyStore.maxMembers,
  }) async {
    final next = current.where((m) => m.id != id).toList();
    await save(next, maxMembers: maxMembers);
    return next;
  }
}
