// 30일 뒤 되물음 로컬 푸시 알림.
// 서버(FCM) 없이 폰 자체 알림만으로 동작한다 — 비용·서버·개인정보 유출이 없다.
// 알림 초기화에 실패해도 앱 실행은 막지 않는다 (main.dart에서 try/catch).

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../engine/follow_up_notify.dart';
import '../models.dart';

/// 플랫폼 알림 호출을 추상화한 인터페이스 — 테스트에서 가짜로 교체한다.
abstract class FollowUpScheduler {
  Future<void> initialize();
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  });
  Future<void> cancel(int id);
}

/// 실제 플러그인으로 알림을 예약·취소하는 구현.
class PluginFollowUpScheduler implements FollowUpScheduler {
  PluginFollowUpScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    // Android 13 이상은 알림 권한을 실행 중에 받아야 한다.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'decision_follow_up',
        '결정 되물음',
        channelDescription: '30일 전 결정의 결과를 되묻는 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    // 30일 뒤 알림이라 분 단위 정확도는 필요 없다.
    // inexact로 두면 정밀 알람(SCHEDULE_EXACT_ALARM) 권한이 없어도 동작한다.
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

/// 되물음 알림 예약·취소를 맡는 서비스.
class NotificationService {
  NotificationService({FollowUpScheduler? scheduler})
    : _scheduler = scheduler ?? PluginFollowUpScheduler();

  final FollowUpScheduler _scheduler;

  Future<void> initialize() => _scheduler.initialize();

/// 결정 기록 시 되물음 알림을 예약한다. 최대 3단계다.
///  1. 길일 당일 오전 8시 리마인드 (luckyDay를 넘겼을 때만, 아직 안 지난 경우만)
///  2. 길일 3일 뒤 오전 8시 되물음 (아직 안 지난 경우만)
///  3. 결정일 + 30일 되물음 (이미 30일이 지난 기록이면 예약하지 않는다 —
///     인앱 배너가 대신 알린다).
Future<void> scheduleFollowUp(
  DecisionRecord record, {
  DateTime? luckyDay,
}) async {
  final now = DateTime.now();
  if (luckyDay != null) {
    final dayAt = luckyDayNotificationTime(luckyDay);
    if (dayAt.isAfter(now)) {
      await _scheduler.schedule(
        id: luckyDayNotificationId(record.id),
        title: luckyDayNotificationTitle(),
        body: luckyDayNotificationBody(record.topic),
        scheduledAt: dayAt,
        payload: record.id,
      );
    }
    final earlyAt = earlyFollowUpNotificationTime(luckyDay);
    if (earlyAt.isAfter(now)) {
      await _scheduler.schedule(
        id: earlyFollowUpNotificationId(record.id),
        title: earlyFollowUpNotificationTitle(record.topic),
        body: earlyFollowUpNotificationBody(record.topic),
        scheduledAt: earlyAt,
        payload: record.id,
      );
    }
  }
  final at = followUpNotificationTime(record.decidedAt);
  if (!at.isAfter(now)) return;
  await _scheduler.schedule(
    id: followUpNotificationId(record.id),
    title: followUpNotificationTitle(record.topic),
    body: followUpNotificationBody(record.topic),
    scheduledAt: at,
    payload: record.id,
  );
}

/// 되물음에 답했거나 기록을 지웠으면 예약된 알림을 전부 취소한다.
Future<void> cancelFollowUp(String recordId) async {
  await _scheduler.cancel(luckyDayNotificationId(recordId));
  await _scheduler.cancel(earlyFollowUpNotificationId(recordId));
  await _scheduler.cancel(followUpNotificationId(recordId));
}
}

/// 앱 전역에서 쓰는 기본 인스턴스.
final followUpNotifications = NotificationService();
