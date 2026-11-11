// 스토어 별점 안내 — 되물음에 "잘 됐어요"라고 답한 뒤 한 번만 띄운다.
//
// 되물음 루프의 목적이 재구매가 아니라 스토어 리뷰·공유 바이럴이 된 뒤로
// (2026-11-11 결제 모델을 평생 패스로 바꿈), 잘 된 결정을 기록한 순간이
// 별점을 부탁하기 가장 좋은 타이밍이다. 안내 자체는 스낵바로만 띄우고,
// 사용자가 "별점 남기기"를 눌렀을 때만 인앱 리뷰를 시도한다.
// 인앱 리뷰가 안 뜨는 환경이면 스토어 페이지로 연다. 최대 1회만 안내한다.

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// 별점 안내를 이미 보여준 적 있는지 저장하는 키.
const String reviewPromptShownKey = 'review_prompt_shown_v1';

class ReviewPrompt {
  ReviewPrompt([InAppReview? review])
    : _review = review ?? InAppReview.instance;

  final InAppReview _review;

  /// 지금 별점 안내를 보여줘도 되는지.
  /// "잘 됐어요" 답을 했고, 아직 안내를 보여준 적이 없어야 한다.
  static Future<bool> shouldShow(String answer) async {
    if (answer != '잘 됐어요') return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(reviewPromptShownKey) != true;
  }

  /// 안내를 보여줬다고 기록한다 (성공 여부와 무관하게 1회만).
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(reviewPromptShownKey, true);
  }

  /// 별점 남기기 — 인앱 리뷰를 먼저 시도하고, 안 되면 스토어 페이지를 연다.
  Future<void> prompt() async {
    await markShown();
    if (await _review.isAvailable()) {
      await _review.requestReview();
      return;
    }
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.decisionsaju.decision_saju',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 앱 전역에서 쓰는 기본 인스턴스.
final reviewPrompt = ReviewPrompt();
