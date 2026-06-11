import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/child_provider.dart';
import '../providers/record_provider.dart';
import '../database/app_database.dart';
import 'child_form_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('习惯养成助手')),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (children) {
          if (children.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('还没有小孩，点击 + 添加'),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => _addChild(context),
                    child: const Text('添加小孩'),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index];
              return _ChildCard(child: child);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addChild(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addChild(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChildFormPage()),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  final ChildrenData child;

  const _ChildCard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider(child.id));
    final balance = balanceAsync.whenOrNull(data: (b) => b) ?? 0;
    final isPositive = balance >= 0;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => context.push('/child/${child.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(child.avatar, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(child.name,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '$balance 分钟',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
