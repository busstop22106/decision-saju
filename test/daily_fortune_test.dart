import 'package:decision_saju/engine/compat.dart';
import 'package:decision_saju/engine/daily_fortune.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('같은 사람·같은 날짜에는 같은 3줄이 나온다', () {
    final saju = sajuOfBirth(DateTime(1987, 5, 15), 10);
    final a = dailyFortune(saju, DateTime(2026, 11, 9));
    final b = dailyFortune(saju, DateTime(2026, 11, 9));
    expect(a.lines, b.lines);
    expect(a.lines.length, 3);
    for (final line in a.lines) {
      expect(line.isNotEmpty, true);
    }
  });

  test('시간 모름(시주 없음)으로도 3줄이 나온다', () {
    final saju = sajuOfBirth(DateTime(1990, 5, 15), null);
    final fortune = dailyFortune(saju, DateTime(2026, 11, 9));
    expect(fortune.lines.length, 3);
    for (final line in fortune.lines) {
      expect(line.isNotEmpty, true);
    }
  });

  test('용신이 있으면 결정 줄에서 용신 오행이 언급된다', () {
    final saju = sajuOfBirth(DateTime(1987, 5, 15), 10);
    final fortune = dailyFortune(saju, DateTime(2026, 11, 9));
    if (saju.yongsin != null) {
      expect(fortune.decision.contains(saju.yongsin!), true);
    }
  });

  test('날짜가 바뀌면 문구가 순환할 수 있다', () {
    // 결정적 생성이 깨지지 않는지 — 서로 다른 날짜도 3줄 구조를 유지한다
    final saju = sajuOfBirth(DateTime(1987, 5, 15), 10);
    for (var d = 1; d <= 7; d++) {
      final fortune = dailyFortune(saju, DateTime(2026, 11, d));
      expect(fortune.lines.length, 3);
    }
  });
}
