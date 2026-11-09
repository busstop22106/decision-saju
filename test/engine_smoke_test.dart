import 'package:decision_saju/engine/saju.dart';
import 'package:decision_saju/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 작명별에서 가져온 만세력 엔진이 이 프로젝트에서도 그대로 동작하는지 확인한다.
void main() {
  test('computeSaju returns four pillars for a known birth', () {
    final result = computeSaju(
      BabyInfo(
        surname: '김',
        surnameStrokes: 8,
        gender: Gender.boy,
        birth: DateTime(1990, 5, 15),
        birthHour: 10,
        birthMinute: 30,
      ),
    );

    expect(result.year.label, isNotEmpty);
    expect(result.month.label, isNotEmpty);
    expect(result.day.label, isNotEmpty);
    expect(result.hour, isNotNull);
    expect(result.hour!.label, isNotEmpty);
    expect(result.dayMaster, isNotEmpty);
    expect(result.dayElement, isNotEmpty);
    // 오행 분포는 천간 4 + 지지 본기 4 = 8자 카운트다.
    expect(
      result.elementCounts.values.fold<int>(0, (a, b) => a + b),
      8,
    );
  });

  test('computeSaju without birth time has no hour pillar', () {
    final result = computeSaju(
      BabyInfo(
        surname: '김',
        surnameStrokes: 8,
        gender: Gender.girl,
        birth: DateTime(1990, 5, 15),
      ),
    );

    expect(result.hour, isNull);
    expect(result.day.label, isNotEmpty);
  });
}
