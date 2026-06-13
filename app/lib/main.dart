import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KidsHabitHelperApp()));
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
