// 30일 뒤 되물음 알림 — 순수 Dart 로직만 모은다.
// 실제 알림 예약/취소는 services/notification_service.dart가 맡는다.
//
// 알림은 3단계로 울린다. D+30 한 번만으로는 실제 결정 시점과 어긋나고,
// 한 달간 앱을 안 켠 상태에서는 오픈율이 급락하기 때문이다.
//  1. 길일 당일 오전 8시 — "오늘은 길일이에요" (리마인드)
//  2. 길일로부터 3일 뒤 오전 8시 — "어떻게 됐어요?" (결과 기록)
//  3. 결정일로부터 30일 뒤 — "30일 전 결정, 어떻게 됐어요?" (장기 되물음)

/// 되물음 알림을 울릴 시간 — 결정한 날로부터 정확히 30일 뒤.
/// DecisionRecord.followUpDue(결정일 + 30일)와 같은 기준이다.
DateTime followUpNotificationTime(DateTime decidedAt) =>
    decidedAt.add(const Duration(days: 30));

/// 기록 id에서 안정적인 알림 id를 만든다.
/// 같은 기록은 항상 같은 알림 id라서, 답을 하거나 지울 때 정확히 취소할 수 있다.
int followUpNotificationId(String recordId) =>
    recordId.hashCode & 0x7FFFFFFF;

/// 길일 당일 리마인드 알림 id (D-Day).
int luckyDayNotificationId(String recordId) =>
    '$recordId:lucky-day'.hashCode & 0x7FFFFFFF;

/// 길일 3일 뒤 되물음 알림 id (D+3).
int earlyFollowUpNotificationId(String recordId) =>
    '$recordId:early-follow-up'.hashCode & 0x7FFFFFFF;

/// 길일 당일 오전 8시.
DateTime luckyDayNotificationTime(DateTime luckyDay) =>
    DateTime(luckyDay.year, luckyDay.month, luckyDay.day, 8);

/// 길일로부터 3일 뒤 오전 8시.
DateTime earlyFollowUpNotificationTime(DateTime luckyDay) =>
    DateTime(luckyDay.year, luckyDay.month, luckyDay.day, 8)
        .add(const Duration(days: 3));

/// 알림 제목 — 주제(예: 이직)가 들어가면 "그 이직 결정, 어떻게 됐어요?"
String followUpNotificationTitle(String topic) {
  final label = topic == '기타' ? '결정' : '$topic 결정';
  return '그 $label, 어떻게 됐어요?';
}

/// 알림 본문.
String followUpNotificationBody(String topic) {
  final label = topic == '기타' ? '결정' : '$topic 결정';
  return '30일 전에 내린 $label을 돌아볼 시간이에요. 결과를 기록해 보세요.';
}

/// 길일 당일 리마인드 제목.
String luckyDayNotificationTitle() => '오늘은 길일이에요';

/// 길일 당일 리마인드 본문.
String luckyDayNotificationBody(String topic) {
  final label = topic == '기타' ? '결정' : '$topic 결정';
  return '오늘은 결정 리포트에서 안내한 길일이에요. $label을 앞두고 있다면 오늘을 참고해 보세요.';
}

/// 길일 3일 뒤 되물음 제목.
String earlyFollowUpNotificationTitle(String topic) {
  final label = topic == '기타' ? '결정' : '$topic 결정';
  return '그 $label, 어떻게 됐어요?';
}

/// 길일 3일 뒤 되물음 본문.
String earlyFollowUpNotificationBody(String topic) {
  final label = topic == '기타' ? '결정' : '$topic 결정';
  return '길일이 지난 지 3일이 됐어요. $label의 결과를 10초 만에 기록해 보세요.';
}
