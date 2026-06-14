import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/app_database.dart';
import '../providers/child_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/record_provider.dart';

class ChildDetailPage extends ConsumerWidget {
  final int childId;

  const ChildDetailPage({super.key, required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final balanceAsync = ref.watch(balanceProvider(childId));
    final rulesAsync = ref.watch(rulesProvider);
    final recordsAsync = ref.watch(recordsForChildProvider(childId));

    final child = childrenAsync.whenOrNull<ChildrenData?>(
      data: (list) => list.where((c) => c.id == childId).firstOrNull,
    );
    final balance = balanceAsync.whenOrNull(data: (b) => b) ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(child?.name ?? '')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 余额卡片
          Card(
            color: balance >= 0
                ? Colors.green.shade50
                : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('当前余额', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    '$balance 分钟',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: balance >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 快捷打卡
          const Text('快捷打卡',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          rulesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const Text('加载规则失败'),
            data: (rules) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rules.map((rule) {
                final isPositive = rule.minutesChange > 0;
                return ActionChip(
                  avatar:
                      Text(rule.icon, style: const TextStyle(fontSize: 16)),
                  label: Text(
                      '${rule.name} ${isPositive ? '+' : ''}${rule.minutesChange}'),
                  backgroundColor:
                      isPositive ? Colors.green.shade50 : Colors.red.shade50,
                  side: BorderSide(
                    color: isPositive
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                  onPressed: () => _record(ref, rule),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => context.go('/child/$childId/timer'),
            icon: const Icon(Icons.timer),
            label: const Text('计时器'),
          ),
          const SizedBox(height: 24),

          // 最近记录
          const Text('最近记录',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          recordsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('错误: $e'),
            data: (records) {
              if (records.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无记录', textAlign: TextAlign.center),
                );
              }
              final rulesMap = <int, Rule>{};
              rulesAsync.whenOrNull(data: (rules) {
                for (final r in rules) {
                  rulesMap[r.id] = r;
                }
              });
              return Column(
                children: records.take(20).map((record) {
                  final rule = rulesMap[record.ruleId];
                  final isPositive = record.minutesChange > 0;
                  return ListTile(
                    leading: Text(rule?.icon ?? '📋',
                        style: const TextStyle(fontSize: 24)),
                    title: Text(rule?.name ?? ''),
                    subtitle: Text(
                      '${record.createdAt.month}/${record.createdAt.day} '
                      '${record.createdAt.hour}:${record.createdAt.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: Text(
                      '${isPositive ? '+' : ''}${record.minutesChange} 分钟',
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _record(WidgetRef ref, Rule rule) async {
    final repo = ref.read(recordRepositoryProvider);
    await repo.add(
      childId: childId,
      ruleId: rule.id,
      minutesChange: rule.minutesChange,
    );
    ref.invalidate(balanceProvider(childId));
  }
}
