import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/statistics_page.dart';
import 'pages/settings_page.dart';
import 'pages/child_detail_page.dart';
import 'pages/timer_page.dart';
import 'pages/auth/login_page.dart';
import 'providers/auth_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(WidgetRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthNotifier(authState),
    redirect: (context, state) {
      final isLoggedIn = authState.whenOrNull(
            data: (loggedIn) => loggedIn,
          ) ??
          false;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomePage(),
              routes: [
                GoRoute(
                  path: 'child/:id',
                  name: 'childDetail',
                  pageBuilder: (context, state) {
                    final childId =
                        int.parse(state.pathParameters['id']!);
                    return MaterialPage(
                        child: ChildDetailPage(childId: childId));
                  },
                  routes: [
                    GoRoute(
                      path: 'timer',
                      name: 'timer',
                      pageBuilder: (context, state) {
                        final childId =
                            int.parse(state.pathParameters['id']!);
                        return MaterialPage(
                            child: TimerPage(childId: childId));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/statistics',
              name: 'statistics',
              builder: (context, state) => const StatisticsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ]),
        ],
      ),
    ],
  );
}

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(AsyncValue authState) {
    authState.when(
      loading: () {},
      error: (_, __) {},
      data: (_) => notifyListeners(),
    );
  }
}

class ScaffoldWithNavBar extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(index,
              initialLocation:
                  index == navigationShell.currentIndex);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: '统计'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
