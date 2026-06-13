import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/child_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../data/remote/sync_service.dart';
import 'child_form_page.dart';
import 'rule_form_page.dart';
import 'auth/login_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final rulesAsync = ref.watch(rulesProvider);
    final authState = ref.watch(authStateProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final isLoggedIn = authState.whenOrNull(
          data: (loggedIn) => loggedIn,
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 小孩管理
          _SectionHeader(
            title: '小孩管理',
            onAdd: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChildFormPage()),
            ),
          ),
          childrenAsync.when(
            loading: () => const ListTile(title: Text('加载中...')),
            error: (e, _) => ListTile(title: Text('错误: $e')),
            data: (children) {
              if (children.isEmpty) {
                return const ListTile(title: Text('暂无小孩'));
              }
              return Column(
                children: children.map((child) {
                  return ListTile(
                    leading: Text(child.avatar,
                        style: const TextStyle(fontSize: 28)),
                    title: Text(child.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChildFormPage(child: child),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.red),
                          onPressed: () => _confirmDelete(
                            context,
                            '删除 ${child.name}？',
                            () => ref
                                .read(childRepositoryProvider)
                                .delete(child.id),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),

          // 规则管理
          _SectionHeader(
            title: '规则管理',
            onAdd: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RuleFormPage()),
            ),
          ),
          rulesAsync.when(
            loading: () => const ListTile(title: Text('加载中...')),
            error: (e, _) => ListTile(title: Text('错误: $e')),
            data: (rules) {
              if (rules.isEmpty) {
                return const ListTile(title: Text('暂无规则'));
              }
              return Column(
                children: rules.map((rule) {
                  final isPositive = rule.minutesChange > 0;
                  return ListTile(
                    leading: Text(rule.icon,
                        style: const TextStyle(fontSize: 28)),
                    title: Text(rule.name),
                    subtitle: Text(
                      '${isPositive ? '+' : ''}${rule.minutesChange} 分钟',
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RuleFormPage(rule: rule),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.red),
                          onPressed: () => _confirmDelete(
                            context,
                            '删除规则「${rule.name}」？',
                            () => ref
                                .read(ruleRepositoryProvider)
                                .delete(rule.id),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),

          // 云同步
          _SectionHeader(
            title: '云同步',
            onAdd: null,
          ),
          if (isLoggedIn) ...[
            ListTile(
              leading: Icon(Icons.cloud_done,
                  color: _syncColor(syncStatus)),
              title: const Text('已登录'),
              subtitle: Text(
                  '同步状态: ${_syncStatusText(syncStatus)}'),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('立即同步'),
              onTap: () {
                ref.read(syncServiceProvider)?.initialSync();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('退出登录',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                await ref.read(authServiceProvider).signOut();
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('未登录'),
              subtitle: const Text('登录后可启用云同步'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const LoginPage()),
                );
              },
            ),
          ],
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('关于'),
            subtitle: Text('习惯养成助手 v1.0.0'),
          ),
        ],
      ),
    );
  }

  Color _syncColor(AsyncValue<SyncStatus?> syncStatus) {
    final status = syncStatus.whenOrNull(data: (s) => s);
    switch (status) {
      case SyncStatus.syncing:
        return Colors.orange;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.idle:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _syncStatusText(AsyncValue<SyncStatus?> syncStatus) {
    final status = syncStatus.whenOrNull(data: (s) => s);
    switch (status) {
      case SyncStatus.syncing:
        return '同步中...';
      case SyncStatus.error:
        return '同步失败';
      case SyncStatus.idle:
        return '已同步';
      default:
        return '未连接';
    }
  }

  void _confirmDelete(
      BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('删除',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;

  const _SectionHeader({required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16)),
      trailing: onAdd != null
          ? IconButton(icon: const Icon(Icons.add), onPressed: onAdd)
          : null,
    );
  }
}
