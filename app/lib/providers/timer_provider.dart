import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/active_timer.dart';

/// 计时器持久化接口（解耦 SharedPreferences，便于测试）
abstract class TimerStorage {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> json);
  Future<void> clear();
}

/// 定时通知调度接口（解耦 flutter_local_notifications，便于测试）
abstract class NotificationScheduler {
  Future<void> scheduleAt(DateTime time, String title, String body);
  Future<void> cancel();
}

/// 提示音接口（解耦 audioplayers，便于测试）
abstract class TimerSound {
  Future<void> playLoop();
  Future<void> stop();
}

class TimerNotifier extends Notifier<ActiveTimer?> {
  final TimerStorage storage;
  final NotificationScheduler scheduler;
  final TimerSound sound;
  final DateTime Function() now;
  Timer? _ticker;

  TimerNotifier({
    required this.storage,
    required this.scheduler,
    required this.sound,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  @override
  ActiveTimer? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  void startTimer({
    required ({int id, String name, String avatar}) child,
    required ({int id, String name, String icon, int minutesChange}) rule,
    required int durationSec,
  }) {
    final t = ActiveTimer(
      childId: child.id,
      childName: child.name,
      childAvatar: child.avatar,
      ruleId: rule.id,
      ruleName: rule.name,
      ruleIcon: rule.icon,
      minutesChange: rule.minutesChange,
      startAt: now(),
      durationSec: durationSec,
      status: TimerStatus.running,
    );
    state = t;
    storage.save(t.toJson());
    scheduler.scheduleAt(t.fireAt, '计时结束：${rule.name}', '给 ${child.name} 打卡');
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void tick() {
    if (state == null || state!.status != TimerStatus.running) return;
    final remain = state!.remainingSecondsAt(now());
    if (remain <= 0) {
      state = state!.copyWith(status: TimerStatus.ended);
      sound.playLoop();
      _ticker?.cancel();
    }
  }

  Future<void> restore() async {
    final json = await storage.load();
    if (json == null) return;
    final t = ActiveTimer.fromJson(json);
    final remain = t.remainingSecondsAt(now());
    if (t.status == TimerStatus.running && remain <= 0) {
      state = t.copyWith(status: TimerStatus.ended);
      await sound.playLoop();
    } else {
      state = t;
      if (t.status == TimerStatus.running) _startTicker();
    }
  }

  /// 确认打卡后由 UI 调用，清除状态
  Future<void> clearAfterConfirm() async {
    _ticker?.cancel();
    await sound.stop();
    await scheduler.cancel();
    await storage.clear();
    state = null;
  }

  Future<void> cancel() async {
    _ticker?.cancel();
    await sound.stop();
    await scheduler.cancel();
    await storage.clear();
    state = null;
  }
}

/// 生产环境在 main.dart 用 overrideWith 注入真实服务实现（见 timer_services.dart）。
/// 默认工厂抛异常以防止无注入时使用。
final timerProvider =
    NotifierProvider<TimerNotifier, ActiveTimer?>(() {
  throw UnimplementedError('在 main.dart 中用 overrideWith 注入 TimerNotifier');
});
