import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/child_provider.dart';
import '../providers/record_provider.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  int? _selectedChildId;
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (children) {
          if (children.isEmpty) {
            return const Center(child: Text('请先添加小孩'));
          }

          final selectedId = _selectedChildId ?? children.first.id;
          if (_selectedChildId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedChildId = selectedId);
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 小孩选择
              DropdownButtonFormField<int>(
                value: selectedId,
                decoration: const InputDecoration(
                  labelText: '选择小孩',
                  border: OutlineInputBorder(),
                ),
                items: children.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.avatar} ${c.name}'),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(() => _selectedChildId = id);
                  }
                },
              ),
              const SizedBox(height: 16),

              // 时间范围选择
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7天')),
                  ButtonSegment(value: 30, label: Text('30天')),
                ],
                selected: {_days},
                onSelectionChanged: (v) =>
                    setState(() => _days = v.first),
              ),
              const SizedBox(height: 24),

              // 余额趋势
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('余额趋势',
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      _buildTrendChart(selectedId),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 规则分类汇总
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('分类汇总',
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      _buildRuleSummary(selectedId),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrendChart(int childId) {
    final balancesAsync = ref.watch(
        dailyBalancesProvider((childId: childId, days: _days)));
    return balancesAsync.when(
      loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(
          height: 200, child: Center(child: Text('错误: $e'))),
      data: (data) {
        if (data.isEmpty) {
          return const SizedBox(
              height: 200, child: Center(child: Text('暂无数据')));
        }
        final maxY =
            data.map((d) => d.balance).reduce((a, b) => a > b ? a : b);
        final minY =
            data.map((d) => d.balance).reduce((a, b) => a < b ? a : b);
        final chartMaxY = (maxY > 0 ? maxY : 0) + 10;
        final chartMinY = (minY < 0 ? minY : 0) - 10;

        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: data.length > 7 ? 7 : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox();
                      }
                      final date = data[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${date.month}/${date.day}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}分',
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: chartMinY.toDouble(),
              maxY: chartMaxY.toDouble(),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (int i = 0; i < data.length; i++)
                      FlSpot(i.toDouble(), data[i].balance.toDouble()),
                  ],
                  isCurved: true,
                  color: Colors.teal,
                  barWidth: 3,
                  dotData: FlDotData(show: data.length <= 14),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.teal.withValues(alpha: 0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((spot) {
                    return LineTooltipItem(
                      '${spot.y.toInt()} 分钟',
                      const TextStyle(
                          color: Colors.white, fontSize: 14),
                    );
                  }).toList(),
                ),
              ),
            ),
            duration: const Duration(milliseconds: 250),
          ),
        );
      },
    );
  }

  Widget _buildRuleSummary(int childId) {
    final summaryAsync = ref.watch(summaryByRuleProvider(childId));
    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('错误: $e'),
      data: (summary) {
        if (summary.isEmpty) {
          return const Text('暂无数据');
        }
        return Column(
          children: summary.map((item) {
            final isPositive = item.totalChange > 0;
            return ListTile(
              leading: Text(item.icon,
                  style: const TextStyle(fontSize: 24)),
              title: Text(item.ruleName),
              trailing: Text(
                '${isPositive ? '+' : ''}${item.totalChange} 分钟',
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
