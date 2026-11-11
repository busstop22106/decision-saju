// 30일 뒤 되물음 로컬 푸시 알림 테스트.
// 순수 로직(시간·알림 id·문구)과 서비스(예약·취소 호출)를 검증한다.
// 실제 플러그인 호출은 FakeScheduler로 대신한다.

import 'package:decision_saju/engine/follow_up_notify.dart';
import 'package:decision_saju/models.dart';
import 'package:decision_saju/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

DecisionRecord record(String id, DateTime decidedAt, {String topic = '이직'}) {
  return DecisionRecord(
    id: id,
    topic: topic,
    optionA: '지금 회사에 남기',
    optionB: '다른 회사로 옮기기',
    chosen: 'A',
    decidedAt: decidedAt,
    summary: 'A안이 유리해요.',
    index: 72,
  );
}

class FakeScheduler implements FollowUpScheduler {
  int initializeCalls = 0;
  final scheduled = <ScheduledCall>[];
  final cancelled = <int>[];

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String payload,
  }) async {
    scheduled.add(
      ScheduledCall(
        id: id,
        title: title,
        body: body,
        scheduledAt: scheduledAt,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}

class ScheduledCall {
  const ScheduledCall({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });
  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
}

void main() {
  group('follow_up_notify 순수 로직', () {
    test('알림 시간은 결정한 날로부터 정확히 30일 뒤다', () {
      final decidedAt = DateTime(2026, 11, 11, 22, 30);
      expect(
        followUpNotificationTime(decidedAt),
        DateTime(2026, 12, 11, 22, 30),
      );
    });

    test('알림 id는 같은 기록이면 항상 같고, 0 이상이며, 기록마다 다르다', () {
      final id1 = followUpNotificationId('record-1');
      final id2 = followUpNotificationId('record-1');
      final id3 = followUpNotificationId('record-2');
      expect(id1, id2);
      expect(id1, greaterThanOrEqualTo(0));
      expect(id1, isNot(id3));
    });

    test('제목·본문에 주제가 들어가고, 기타 주제는 "결정"으로 바뀐다', () {
      expect(
        followUpNotificationTitle('이직'),
        '그 이직 결정, 어떻게 됐어요?',
      );
      expect(
        followUpNotificationBody('이직'),
        contains('이직 결정'),
      );
      expect(followUpNotificationTitle('기타'), '그 결정, 어떻게 됐어요?');
      expect(followUpNotificationBody('기타'), contains('결정'));
      expect(followUpNotificationBody('기타'), isNot(contains('기타')));
    });
  });

  group('NotificationService 예약·취소', () {
    test('결정을 저장하면 30일 뒤 알림이 1건 예약된다', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);
      final now = DateTime.now();
      final rec = record('r1', now);

      await service.scheduleFollowUp(rec);

      expect(fake.scheduled.length, 1);
      final call = fake.scheduled.first;
      expect(call.id, followUpNotificationId('r1'));
      expect(call.title, '그 이직 결정, 어떻게 됐어요?');
      expect(call.scheduledAt, followUpNotificationTime(now));
      expect(call.payload, 'r1');
    });

    test('이미 30일이 지난 기록은 예약하지 않는다', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);
      final old = record(
        'old',
        DateTime.now().subtract(const Duration(days: 31)),
      );

      await service.scheduleFollowUp(old);

      expect(fake.scheduled, isEmpty);
    });

    test('되물음에 답하거나 기록을 지우면 예약된 알림이 취소된다', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      await service.cancelFollowUp('r1');

      expect(fake.cancelled, [followUpNotificationId('r1')]);
    });

    test('initialize를 부르면 스케줄러 초기화가 1번 돈다', () async {
      final fake = FakeScheduler();
      final service = NotificationService(scheduler: fake);

      await service.initialize();

      expect(fake.initializeCalls, 1);
    });
  });
}
