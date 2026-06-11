import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/child_provider.dart';
import '../providers/rule_provider.dart';
import 'child_form_page.dart';
import 'rule_form_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final rulesAsync = ref.watch(rulesProvider);

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
                              builder: (_) =>
                                  RuleFormPage(rule: rule),
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
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('关于'),
            subtitle: Text('习惯养成助手 v1.0.0'),
          ),
        ],
      ),
    );
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
  final VoidCallback onAdd;

  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16)),
      trailing:
          IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
    );
  }
}
