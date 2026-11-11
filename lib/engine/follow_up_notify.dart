// 30일 뒤 되물음 알림 — 순수 Dart 로직만 모은다.
// 실제 알림 예약/취소는 services/notification_service.dart가 맡는다.

/// 되물음 알림을 울릴 시간 — 결정한 날로부터 정확히 30일 뒤.
/// DecisionRecord.followUpDue(결정일 + 30일)와 같은 기준이다.
DateTime followUpNotificationTime(DateTime decidedAt) =>
    decidedAt.add(const Duration(days: 30));

/// 기록 id에서 안정적인 알림 id를 만든다.
/// 같은 기록은 항상 같은 알림 id라서, 답을 하거나 지울 때 정확히 취소할 수 있다.
int followUpNotificationId(String recordId) =>
    recordId.hashCode & 0x7FFFFFFF;

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
