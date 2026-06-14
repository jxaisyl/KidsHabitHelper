import 'package:flutter_test/flutter_test.dart';
import 'package:kids_habit_helper/models/active_timer.dart';

void main() {
  group('ActiveTimer', () {
    test('remainingSecondsAt 计算剩余', () {
      final t = ActiveTimer(
        childId: 1,
        childName: '小明',
        childAvatar: '👦',
        ruleId: 2,
        ruleName: '完成作业',
        ruleIcon: '📖',
        minutesChange: 30,
        startAt: DateTime(2026, 6, 14, 10, 0, 0),
        durationSec: 1800,
      );
      // 10 分钟后，应剩 1200 秒
      final remain = t.remainingSecondsAt(DateTime(2026, 6, 14, 10, 10, 0));
      expect(remain, 1200);
    });

    test('remainingSecondsAt 不为负', () {
      final t = ActiveTimer(
        childId: 1, childName: 'a', childAvatar: 'b',
        ruleId: 2, ruleName: 'r', ruleIcon: 'i', minutesChange: 1,
        startAt: DateTime(2026, 6, 14, 10, 0, 0),
        durationSec: 60,
      );
      expect(t.remainingSecondsAt(DateTime(2026, 6, 14, 11, 0, 0)), 0);
    });

    test('fireAt = startAt + duration', () {
      final t = ActiveTimer(
        childId: 1, childName: 'a', childAvatar: 'b',
        ruleId: 2, ruleName: 'r', ruleIcon: 'i', minutesChange: 1,
        startAt: DateTime(2026, 6, 14, 10, 0, 0),
        durationSec: 90,
      );
      expect(t.fireAt, DateTime(2026, 6, 14, 10, 1, 30));
    });

    test('toJson / fromJson 往返', () {
      final t = ActiveTimer(
        childId: 1, childName: '小明', childAvatar: '👦',
        ruleId: 2, ruleName: '作业', ruleIcon: '📖', minutesChange: 30,
        startAt: DateTime.utc(2026, 6, 14, 10, 0, 0),
        durationSec: 1800,
        status: TimerStatus.running,
      );
      final json = t.toJson();
      final restored = ActiveTimer.fromJson(json);
      expect(restored.childId, 1);
      expect(restored.childName, '小明');
      expect(restored.durationSec, 1800);
      expect(restored.status, TimerStatus.running);
      expect(restored.startAt, DateTime.utc(2026, 6, 14, 10, 0, 0));
    });
  });
}
