import 'package:decision_saju/models.dart';
import 'package:decision_saju/services/family_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  FamilyMember member(String id, String name) => FamilyMember(
        id: id,
        name: name,
        relation: '나',
        gender: Gender.boy,
        birth: DateTime(1987, 5, 15),
        birthHour: 10,
      );

  test('저장 후 불러오면 같은 구성원이 나온다', () async {
    await FamilyStore.save([member('1', '진욱')]);
    final loaded = await FamilyStore.load();
    expect(loaded.length, 1);
    expect(loaded.first.name, '진욱');
    expect(loaded.first.birth, DateTime(1987, 5, 15));
    expect(loaded.first.birthHour, 10);
  });

  test('3명을 넘기면 3명까지만 저장된다', () async {
    await FamilyStore.save([
      member('1', 'a'),
      member('2', 'b'),
      member('3', 'c'),
      member('4', 'd'),
    ]);
    expect((await FamilyStore.load()).length, 3);
  });

  test('add는 3명이 차면 그대로 돌려준다', () async {
    final three = [member('1', 'a'), member('2', 'b'), member('3', 'c')];
    await FamilyStore.save(three);
    final next = await FamilyStore.add(three, member('4', 'd'));
    expect(next.length, 3);
  });

  test('삭제하면 해당 구성원이 빠진다', () async {
    await FamilyStore.save([member('1', 'a'), member('2', 'b')]);
    final current = await FamilyStore.load();
    final next = await FamilyStore.remove(current, '1');
    expect(next.length, 1);
    expect(next.first.id, '2');
    expect((await FamilyStore.load()).length, 1);
  });

  test('손상된 항목은 건너뛰고 나머지만 불러온다', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      FamilyStore.key,
      '[{"id":"1","name":"a","relation":"나","gender":"boy",'
      '"birth":"1987-05-15T00:00:00.000","birthHour":10},'
      '{"id":"","name":""}]',
    );
    final loaded = await FamilyStore.load();
    expect(loaded.length, 1);
    expect(loaded.first.name, 'a');
  });

  test('GenderX 라벨은 성인 표기다', () {
    expect(Gender.boy.label, '남성');
    expect(Gender.girl.label, '여성');
  });
}
