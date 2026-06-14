import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kids_habit_helper/models/active_timer.dart';
import 'package:kids_habit_helper/providers/timer_provider.dart';

void main() {
  group('TimerNotifier', () {
    test('startTimer 设置 running 状态', () {
      final container = _container(now: () => DateTime(2026, 6, 14, 10, 0, 0));
      final notifier = container.read(timerProvider.notifier);
      notifier.startTimer(child: _child(), rule: _rule(), durationSec: 1800);
      final state = container.read(timerProvider);
      expect(state, isNotNull);
      expect(state!.status, TimerStatus.running);
      expect(state.durationSec, 1800);
    });

    test('tick 到 0 时进入 ended', () {
      final start = DateTime(2026, 6, 14, 10, 0, 0);
      final sound = _FakeSound();
      var callCount = 0;
      final container = ProviderContainer(overrides: [
        timerProvider.overrideWith(() => TimerNotifier(
              storage: _FakeStorage(),
              scheduler: _FakeScheduler(),
              sound: sound,
              now: () {
                callCount++;
                return callCount == 1
                    ? start
                    : start.add(const Duration(seconds: 1801));
              },
            )),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(timerProvider.notifier);
      notifier.startTimer(child: _child(), rule: _rule(), durationSec: 1800);
      notifier.tick();
      expect(container.read(timerProvider)!.status, TimerStatus.ended);
      expect(sound.played, true);
    });

    test('cancel 清除状态', () async {
      final scheduler = _FakeScheduler();
      final container = ProviderContainer(overrides: [
        timerProvider.overrideWith(() => TimerNotifier(
              storage: _FakeStorage(),
              scheduler: scheduler,
              sound: _FakeSound(),
              now: () => DateTime(2026, 6, 14, 10, 0, 0),
            )),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(timerProvider.notifier);
      notifier.startTimer(child: _child(), rule: _rule(), durationSec: 1800);
      await notifier.cancel();
      expect(container.read(timerProvider), isNull);
      expect(scheduler.cancelled, true);
    });

    test('restore 从存储恢复未到期计时器', () async {
      final container = _container(
        saved: {
          'childId': 1,
          'childName': '小明',
          'childAvatar': '👦',
          'ruleId': 2,
          'ruleName': '作业',
          'ruleIcon': '📖',
          'minutesChange': 30,
          'startAt': DateTime(2026, 6, 14, 10, 0, 0).toIso8601String(),
          'durationSec': 1800,
          'status': 'running',
        },
        now: () => DateTime(2026, 6, 14, 10, 5, 0),
      );
      final notifier = container.read(timerProvider.notifier);
      await notifier.restore();
      final state = container.read(timerProvider);
      expect(state, isNotNull);
      expect(state!.remainingSecondsAt(DateTime(2026, 6, 14, 10, 5, 0)), 1500);
    });

    test('restore 到期则进入 ended', () async {
      final sound = _FakeSound();
      final container = ProviderContainer(overrides: [
        timerProvider.overrideWith(() => TimerNotifier(
              storage: _FakeStorage(saved: {
                'childId': 1,
                'childName': '小明',
                'childAvatar': '👦',
                'ruleId': 2,
                'ruleName': '作业',
                'ruleIcon': '📖',
                'minutesChange': 30,
                'startAt': DateTime(2026, 6, 14, 10, 0, 0).toIso8601String(),
                'durationSec': 60,
                'status': 'running',
              }),
              scheduler: _FakeScheduler(),
              sound: sound,
              now: () => DateTime(2026, 6, 14, 11, 0, 0),
            )),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(timerProvider.notifier);
      await notifier.restore();
      expect(container.read(timerProvider)!.status, TimerStatus.ended);
      expect(sound.played, true);
    });
  });
}

ProviderContainer _container({
  Map<String, dynamic>? saved,
  required DateTime Function() now,
}) {
  final container = ProviderContainer(overrides: [
    timerProvider.overrideWith(() => TimerNotifier(
          storage: _FakeStorage(saved: saved),
          scheduler: _FakeScheduler(),
          sound: _FakeSound(),
          now: now,
        )),
  ]);
  addTearDown(container.dispose);
  return container;
}

class _FakeStorage implements TimerStorage {
  Map<String, dynamic>? saved;
  _FakeStorage({this.saved});
  @override
  Future<Map<String, dynamic>?> load() async => saved;
  @override
  Future<void> save(Map<String, dynamic> json) async {
    saved = json;
  }
  @override
  Future<void> clear() async {
    saved = null;
  }
}

class _FakeScheduler implements NotificationScheduler {
  bool scheduled = false;
  bool cancelled = false;
  @override
  Future<void> scheduleAt(DateTime time, String title, String body) async {
    scheduled = true;
  }
  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

class _FakeSound implements TimerSound {
  bool played = false;
  @override
  Future<void> playLoop() async {
    played = true;
  }
  @override
  Future<void> stop() async {}
}

({int id, String name, String avatar}) _child() =>
    (id: 1, name: '小明', avatar: '👦');
({int id, String name, String icon, int minutesChange}) _rule() =>
    (id: 2, name: '作业', icon: '📖', minutesChange: 30);
