// 스토어 별점 안내 테스트 — "잘 됐어요" 답을 했을 때 한 번만 보여준다.

import 'package:decision_saju/services/review_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReviewPrompt.shouldShow', () {
    test('"잘 됐어요" 답이면 처음 한 번만 안내한다', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ReviewPrompt.shouldShow('잘 됐어요'), true);
      await ReviewPrompt.markShown();
      expect(await ReviewPrompt.shouldShow('잘 됐어요'), false);
    });

    test('"아직 몰라요"·"안 됐어요" 답이면 안내하지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ReviewPrompt.shouldShow('아직 몰라요'), false);
      expect(await ReviewPrompt.shouldShow('안 됐어요'), false);
    });

    test('이미 안내한 적이 있으면 다시 안내하지 않는다', () async {
      SharedPreferences.setMockInitialValues({reviewPromptShownKey: true});
      expect(await ReviewPrompt.shouldShow('잘 됐어요'), false);
    });
  });
}
