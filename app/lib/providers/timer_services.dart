import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'timer_provider.dart';

class PrefsTimerStorage implements TimerStorage {
  static const _key = 'active_timer';

  @override
  Future<Map<String, dynamic>?> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_key);
    if (s == null) return null;
    final decoded = jsonDecode(s);
    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
  }

  @override
  Future<void> save(Map<String, dynamic> json) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(json));
  }

  @override
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}

class LocalNotificationScheduler implements NotificationScheduler {
  final FlutterLocalNotificationsPlugin plugin;
  static const _channelId = 'timer_channel';
  static const _notifyId = 1001;
  bool _initialized = false;

  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(init);
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      '计时器',
      importance: Importance.high,
    ));
    _initialized = true;
  }

  @override
  Future<void> scheduleAt(DateTime time, String title, String body) async {
    await ensureInitialized();
    await plugin.zonedSchedule(
      _notifyId,
      title,
      body,
      _toTz(time),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '计时器',
          importance: Importance.high,
          priority: Priority.high,
          sound: const RawResourceAndroidNotificationSound('alert'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel() => plugin.cancel(_notifyId);
}

bool _tzInitialized = false;
tz.TZDateTime _toTz(DateTime time) {
  if (!_tzInitialized) {
    tzdata.initializeTimeZones();
    _tzInitialized = true;
  }
  return tz.TZDateTime.from(time, tz.local);
}

class AudioPlayerSound implements TimerSound {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playLoop() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alert.wav'));
  }

  @override
  Future<void> stop() => _player.stop();
}
