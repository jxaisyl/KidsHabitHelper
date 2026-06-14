import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/active_timer.dart';
import '../providers/timer_provider.dart';
import '../providers/child_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/record_provider.dart';

class TimerPage extends ConsumerStatefulWidget {
  final int childId;
  const TimerPage({super.key, required this.childId});

  @override
  ConsumerState<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends ConsumerState<TimerPage> {
  int _hours = 0;
  int _minutes = 25;
  int _seconds = 0;
  int? _selectedRuleId;
  // 每秒触发 setState 让倒计时显示实时更新；provider 的 tick() 只处理结束转换
  Timer? _uiTicker;
  // 防止 ended 确认框在重建时被多次弹出
  bool _confirmShown = false;

  @override
  void initState() {
    super.initState();
    // 启动时恢复（若已有计时器，UI 进入运行态）
    Future.microtask(() => ref.read(timerProvider.notifier).restore());
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final childAsync = ref.watch(childrenProvider);
    final rulesAsync = ref.watch(rulesProvider);

    final child = childAsync.whenOrNull<ChildrenData?>(
      data: (list) => list.where((c) => c.id == widget.childId).firstOrNull,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('计时器')),
      body: timer == null
          ? _buildSetup(context, child, rulesAsync)
          : _buildRunning(context, timer),
    );
  }

  Widget _buildSetup(BuildContext context, ChildrenData? child, AsyncValue<List<Rule>> rulesAsync) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _timeSpinner('时', _hours, 23, (v) => setState(() => _hours = v)),
                _timeSpinner('分', _minutes, 59, (v) => setState(() => _minutes = v)),
                _timeSpinner('秒', _seconds, 59, (v) => setState(() => _seconds = v)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('选择规则', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        rulesAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('加载失败: $e'),
          data: (rules) => Column(
            children: rules.map((r) {
              final selected = r.id == _selectedRuleId;
              return Card(
                color: selected ? Colors.teal.shade50 : null,
                child: ListTile(
                  leading: Text(r.icon, style: const TextStyle(fontSize: 24)),
                  title: Text(r.name),
                  trailing: Text('${r.minutesChange >= 0 ? '+' : ''}${r.minutesChange}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => setState(() => _selectedRuleId = r.id),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _selectedRuleId == null ? null : _onStart,
          child: const Text('开始计时'),
        ),
      ],
    );
  }

  Widget _timeSpinner(String label, int value, int max, ValueChanged<int> onChange) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
            icon: const Icon(Icons.arrow_drop_up),
            onPressed: value < max ? () => onChange(value + 1) : null),
        Text('$value', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
        IconButton(
            icon: const Icon(Icons.arrow_drop_down),
            onPressed: value > 0 ? () => onChange(value - 1) : null),
      ],
    );
  }

  Future<void> _onStart() async {
    final child = ref.read(childrenProvider).whenOrNull<List<ChildrenData>>(
          data: (list) => list,
        )?.where((c) => c.id == widget.childId).firstOrNull;
    final rule = ref.read(rulesProvider).whenOrNull<List<Rule>>(
          data: (rules) => rules,
        )?.where((r) => r.id == _selectedRuleId).firstOrNull;
    if (child == null || rule == null) return;

    final total = _hours * 3600 + _minutes * 60 + _seconds;
    if (total < 1 || total > 86400) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('时长需在 1 秒 ~ 24 小时之间')));
      return;
    }

    await ref.read(timerProvider.notifier).startTimer(
          child: (id: child.id, name: child.name, avatar: child.avatar),
          rule: (id: rule.id, name: rule.name, icon: rule.icon, minutesChange: rule.minutesChange),
          durationSec: total,
        );
  }

  Widget _buildRunning(BuildContext context, ActiveTimer timer) {
    // 运行态：启动每秒 setState 计时器；非运行态：停止
    if (timer.status == TimerStatus.running) {
      _uiTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _uiTicker?.cancel();
      _uiTicker = null;
    }
    // ended 状态时弹确认框（只触发一次）
    if (timer.status == TimerStatus.ended && !_confirmShown) {
      _confirmShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConfirm(context, timer));
    }
    final remain = timer.remainingSecondsAt(DateTime.now());
    final h = (remain ~/ 3600).toString().padLeft(2, '0');
    final m = ((remain % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (remain % 60).toString().padLeft(2, '0');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$h:$m:$s',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          const SizedBox(height: 16),
          Text('${timer.ruleIcon} ${timer.ruleName}  ${timer.minutesChange >= 0 ? '+' : ''}${timer.minutesChange} 分钟',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 32),
          if (timer.status == TimerStatus.running)
            OutlinedButton(
              onPressed: () => ref.read(timerProvider.notifier).cancel(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('取消计时'),
            ),
        ],
      ),
    );
  }

  void _showConfirm(BuildContext context, ActiveTimer timer) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('计时结束！'),
        content: Text('${timer.ruleIcon} ${timer.ruleName}  '
            '${timer.minutesChange >= 0 ? '+' : ''}${timer.minutesChange} 分钟\n→ 给 ${timer.childName}'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(timerProvider.notifier).cancel();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(recordRepositoryProvider).add(
                childId: timer.childId,
                ruleId: timer.ruleId,
                minutesChange: timer.minutesChange,
                note: '计时器打卡',
              );
              ref.invalidate(balanceProvider(timer.childId));
              await ref.read(timerProvider.notifier).clearAfterConfirm();
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('确认打卡'),
          ),
        ],
      ),
    );
  }
}
