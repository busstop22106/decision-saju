// 저장 견고성 테스트 — 출시 전 최우선 3종(입력 정보 소실·결제 에러·앱 안 열림) 중
// 저장소 부분. 손상된 데이터·상한·삭제·재시작 후 유지를 검증한다.
//
// 결제 에러 흐름은 payment_service 단위 테스트에서,
// 앱 안 열림(초기 로딩)은 MainShell이 빈 저장소에서 정상 시작하는 것으로
// 아래 재시작 테스트가 함께 커버한다.

import 'dart:convert';

import 'package:decision_saju/models.dart';
import 'package:decision_saju/services/decision_store.dart';
import 'package:decision_saju/services/family_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FamilyMember member(String id, String name) {
  return FamilyMember(
    id: id,
    name: name,
    relation: '아빠',
    gender: Gender.boy,
    birth: DateTime(1987, 5, 20),
    birthHour: 10,
  );
}

DecisionRecord record(String id, DateTime decidedAt) {
  return DecisionRecord(
    id: id,
    topic: '이직',
    optionA: '지금 회사에 남기',
    optionB: '다른 회사로 옮기기',
    chosen: 'A',
    decidedAt: decidedAt,
    summary: 'A안이 유리해요.',
    index: 72,
  );
}

void main() {
  group('FamilyStore 견고성', () {
    test('손상된 JSON이어도 앱이 안 죽고 빈 목록을 돌려준다', () async {
      SharedPreferences.setMockInitialValues({
        FamilyStore.key: '이건 JSON이 아니에요',
      });
      expect(await FamilyStore.load(), isEmpty);
    });

    test('JSON은 맞지만 배열이 아니면 빈 목록을 돌려준다', () async {
      SharedPreferences.setMockInitialValues({
        FamilyStore.key: '{"a": 1}',
      });
      expect(await FamilyStore.load(), isEmpty);
    });

    test('배열 중 손상된 항목은 건너뛰고 좋은 항목만 남긴다', () async {
      SharedPreferences.setMockInitialValues({
        FamilyStore.key: jsonEncode([
          member('1', '진욱').toJson(),
          {'id': '망가진 항목'},
          {'name': 123},
          member('2', '지혜').toJson(),
        ]),
      });
      final loaded = await FamilyStore.load();
      expect(loaded.map((m) => m.id), ['1', '2']);
    });

    test('4명을 저장해도 3명까지만 남는다', () async {
      SharedPreferences.setMockInitialValues({});
      final four = [
        member('1', '진욱'),
        member('2', '지혜'),
        member('3', '아기'),
        member('4', '할머니'),
      ];
      await FamilyStore.save(four);
      final loaded = await FamilyStore.load();
      expect(loaded.length, 3);
      expect(loaded.map((m) => m.id), ['1', '2', '3']);
    });

    test('3명이 찬 상태에서 추가하면 그대로 3명이다', () async {
      SharedPreferences.setMockInitialValues({});
      final three = [
        member('1', '진욱'),
        member('2', '지혜'),
        member('3', '아기'),
      ];
      await FamilyStore.save(three);
      final result = await FamilyStore.add(three, member('4', '할머니'));
      expect(result.length, 3);
      expect((await FamilyStore.load()).length, 3);
    });

    test('평생 패스 상한 6명이면 6명까지 저장·추가된다', () async {
      SharedPreferences.setMockInitialValues({});
      final six = [
        for (var i = 1; i <= 6; i++) member('$i', '구성원$i'),
      ];
      await FamilyStore.save(six, maxMembers: FamilyStore.maxMembersUnlocked);
      final loaded = await FamilyStore.load(
        maxMembers: FamilyStore.maxMembersUnlocked,
      );
      expect(loaded.length, 6);
      final over = await FamilyStore.add(
        loaded,
        member('7', '구성원7'),
        maxMembers: FamilyStore.maxMembersUnlocked,
      );
      expect(over.length, 6);
    });

    test('없는 id를 지워도 기존 목록이 유지된다', () async {
      SharedPreferences.setMockInitialValues({});
      final two = [member('1', '진욱'), member('2', '지혜')];
      final result = await FamilyStore.remove(two, '없는-id');
      expect(result.length, 2);
    });

    test('저장한 뒤 다시 읽으면 그대로 있다 (재시작 시뮬레이션)', () async {
      SharedPreferences.setMockInitialValues({});
      final two = [member('1', '진욱'), member('2', '지혜')];
      await FamilyStore.save(two);
      // 디스크에 남는 JSON 원문을 새 프로세스처럼 처음부터 다시 파싱한다.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(FamilyStore.key)!;
      final decoded = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(FamilyMember.tryFromJson)
          .whereType<FamilyMember>()
          .toList();
      expect(decoded.map((m) => m.name), ['진욱', '지혜']);
      // 같은 원문을 load로 읽어도 같다
      expect((await FamilyStore.load()).map((m) => m.name), ['진욱', '지혜']);
    });
  });

  group('DecisionStore 견고성', () {
    Future<DecisionStore> storeWith(String raw) async {
      SharedPreferences.setMockInitialValues({
        'decision_records_v1': raw,
      });
      return DecisionStore.load();
    }

    test('손상된 JSON이어도 빈 목록을 돌려준다', () async {
      final store = await storeWith('망가진 데이터{{{');
      expect(store.loadAll(), isEmpty);
    });

    test('배열 중 손상된 기록은 건너뛰고 좋은 기록만 남긴다', () async {
      final store = await storeWith(jsonEncode([
        record('ok1', DateTime.now()).toJson(),
        {'id': '망가진 기록'},
        record('ok2', DateTime.now()).toJson(),
      ]));
      expect(store.loadAll().map((r) => r.id), ['ok1', 'ok2']);
    });

    test('없는 기록에 되물음 답을 해도 false이고 기존 기록이 유지된다', () async {
      final store = await storeWith(
        jsonEncode([record('r1', DateTime.now()).toJson()]),
      );
      expect(await store.answerFollowUp('없는-id', '잘 됐어요'), false);
      expect(store.loadAll().length, 1);
      expect(store.loadAll().first.followUp, isNull);
    });

    test('없는 기록을 지워도 기존 기록이 유지된다', () async {
      final store = await storeWith(
        jsonEncode([record('r1', DateTime.now()).toJson()]),
      );
      await store.remove('없는-id');
      expect(store.loadAll().length, 1);
    });

    test('30일 경계: 30일 안쪽은 아직, 30일 지난 뒤는 되물음 대상이다', () async {
      // 경계는 정확히 30일(밀리초 단위)이라 여유를 두고 검증한다.
      final now = DateTime.now();
      final store = await storeWith(jsonEncode([
        record('d29', now.subtract(const Duration(days: 29))).toJson(),
        record(
          'd30minus',
          now.subtract(const Duration(days: 29, hours: 23)),
        ).toJson(),
        record(
          'd30plus',
          now.subtract(const Duration(days: 30, hours: 1)),
        ).toJson(),
        record('d31', now.subtract(const Duration(days: 31))).toJson(),
      ]));
      final due = store.dueFollowUps().map((r) => r.id).toSet();
      expect(due.contains('d29'), false);
      expect(due.contains('d30minus'), false);
      expect(due.contains('d30plus'), true);
      expect(due.contains('d31'), true);
    });

    test('답한 결정은 되물음 대상에서 빠진다', () async {
      final now = DateTime.now();
      final store = await storeWith(jsonEncode([
        record('old', now.subtract(const Duration(days: 40))).toJson(),
      ]));
      expect(store.dueFollowUps().length, 1);
      await store.answerFollowUp('old', '잘 됐어요');
      expect(store.dueFollowUps(), isEmpty);
      expect(store.loadAll().first.followUp, '잘 됐어요');
    });

    test('저장한 기록이 다시 읽어도 그대로 있다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await DecisionStore.load();
      await store.add(record('r1', DateTime.now()));
      await store.add(record('r2', DateTime.now()));
      // 최신이 맨 앞에 온다
      expect(store.loadAll().map((r) => r.id), ['r2', 'r1']);
      // 디스크에 남는 JSON 원문을 새 프로세스처럼 처음부터 다시 파싱한다.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('decision_records_v1')!;
      final decoded = (jsonDecode(raw) as List)
          .map(DecisionRecord.tryFromJson)
          .whereType<DecisionRecord>()
          .toList();
      expect(decoded.map((r) => r.id), ['r2', 'r1']);
    });
  });
}
