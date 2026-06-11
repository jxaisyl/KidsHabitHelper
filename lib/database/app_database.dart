import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Children, Rules, Records])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
      );

  // --- Child queries ---
  Stream<List<Child>> watchAllChildren() => select(children).watch();

  Future<int> insertChild(ChildrenCompanion entry) =>
      into(children).insert(entry);

  Future<bool> updateChild(ChildrenCompanion entry) =>
      update(children).replace(Child(
        id: entry.id.value,
        name: entry.name.value,
        avatar: entry.avatar.value,
        createdAt: entry.createdAt.value,
      ));

  Future<int> deleteChild(int id) =>
      (delete(children)..where((t) => t.id.equals(id))).go();

  // --- Rule queries ---
  Stream<List<Rule>> watchAllRules() => select(rules).watch();

  Future<int> insertRule(RulesCompanion entry) => into(rules).insert(entry);

  Future<bool> updateRule(RulesCompanion entry) =>
      update(rules).replace(Rule(
        id: entry.id.value,
        name: entry.name.value,
        minutesChange: entry.minutesChange.value,
        icon: entry.icon.value,
      ));

  Future<int> deleteRule(int id) =>
      (delete(rules)..where((t) => t.id.equals(id))).go();

  // --- Record queries ---
  Future<int> insertRecord(RecordsCompanion entry) =>
      into(records).insert(entry);

  Stream<List<Record>> watchRecordsForChild(int childId) {
    return (select(records)
          ..where((t) => t.childId.equals(childId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// 计算小孩当前余额
  Future<int> getBalance(int childId) async {
    final query = selectOnly(records)
      ..addColumns([records.minutesChange.sum()])
      ..where(records.childId.equals(childId));
    final row = await query.getSingle();
    return row.read(records.minutesChange.sum()) ?? 0;
  }

  /// 按天聚合余额（用于趋势图）
  Future<List<({DateTime date, int balance})>> getDailyBalances(
      int childId, int days) async {
    final allRecords = await (select(records)
          ..where((t) => t.childId.equals(childId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    // 按天聚合变化量
    final dailyChanges = <DateTime, int>{};
    for (final r in allRecords) {
      final day =
          DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day);
      dailyChanges[day] = (dailyChanges[day] ?? 0) + r.minutesChange;
    }

    // 生成每天累计余额
    final result = <({DateTime date, int balance})>[];
    var cumulative = 0;
    for (int i = 0; i < days; i++) {
      final day = startDate.add(Duration(days: i));
      cumulative += dailyChanges[day] ?? 0;
      result.add((date: day, balance: cumulative));
    }
    return result;
  }

  /// 按规则分类汇总收支
  Future<List<({String ruleName, String icon, int totalChange})>>
      getSummaryByRule(int childId) async {
    final query = selectOnly(records).join([
      innerJoin(rules, rules.id.equalsExp(records.ruleId)),
    ])
      ..where(records.childId.equals(childId))
      ..addColumns([
        rules.name,
        rules.icon,
        records.minutesChange.sum(),
      ])
      ..groupBy([rules.id]);

    final rows = await query.get();
    return rows.map((row) {
      return (
        ruleName: row.read(rules.name)!,
        icon: row.read(rules.icon)!,
        totalChange: row.read(records.minutesChange.sum()) ?? 0,
      );
    }).toList();
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'kids_habit_helper.db');
}
