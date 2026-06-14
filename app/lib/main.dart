import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'providers/auth_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/timer_services.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  // 初始化本地通知（计时器用）
  final notifications = FlutterLocalNotificationsPlugin();
  const init = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await notifications.initialize(init);
  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        'timer_channel',
        '计时器',
        importance: Importance.high,
      ));

  // 计时器服务依赖注入
  final storage = PrefsTimerStorage();
  final scheduler = LocalNotificationScheduler();
  final sound = AudioPlayerSound();

  runApp(ProviderScope(
    overrides: [
      timerProvider.overrideWith(() => TimerNotifier(
            storage: storage,
            scheduler: scheduler,
            sound: sound,
          )),
    ],
    child: const KidsHabitHelperApp(),
  ));
}

class KidsHabitHelperApp extends ConsumerStatefulWidget {
  const KidsHabitHelperApp({super.key});

  @override
  ConsumerState<KidsHabitHelperApp> createState() => _KidsHabitHelperAppState();
}

class _KidsHabitHelperAppState extends ConsumerState<KidsHabitHelperApp> {
  @override
  void initState() {
    super.initState();
    // 恢复会话
    ref.read(authServiceProvider).restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    final router = createRouter(ref);
    return MaterialApp.router(
      title: '习惯养成助手',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
