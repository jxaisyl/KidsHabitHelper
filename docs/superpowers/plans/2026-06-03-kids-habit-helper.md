# KidsHabitHelper 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flutter Android App，帮助家长通过积分制管理小孩电子设备使用时长，支持多小孩管理和数据可视化。

**Architecture:** 三层架构 — Flutter UI 层通过 Riverpod 状态管理连接 Service 层，Service 层通过 Repository 访问 drift (SQLite) 本地数据库。底部 Tab 导航三个主页面。

**Tech Stack:** Flutter 3.x, drift (SQLite ORM), flutter_riverpod, go_router, fl_chart

---

## File Structure

```
lib/
├── main.dart                          # 入口，ProviderScope + MaterialApp.router
├── database/
│   ├── tables.dart                    # drift 表定义 (Children, Rules, Records)
│   └── app_database.dart             # drift 数据库类 + 查询方法
├── repositories/
│   ├── child_repository.dart         # 小孩 CRUD
│   ├── rule_repository.dart          # 规则 CRUD
│   └── record_repository.dart        # 记录 CRUD + 余额计算
├── providers/
│   ├── database_provider.dart        # 数据库单例 provider
│   ├── child_provider.dart           # 小孩相关 providers
│   ├── rule_provider.dart            # 规则相关 providers
│   └── record_provider.dart          # 记录 + 统计 providers
├── pages/
│   ├── home_page.dart                # 首页 — 小孩列表
│   ├── child_detail_page.dart        # 小孩详情 — 余额 + 打卡 + 记录
│   ├── statistics_page.dart          # 统计 — 图表
│   ├── settings_page.dart            # 设置 — 管理小孩和规则
│   └── child_form_page.dart          # 小孩新增/编辑表单
│   └── rule_form_page.dart           # 规则新增/编辑表单
├── widgets/
│   ├── child_card.dart               # 小孩卡片组件
│   ├── rule_chip.dart                # 规则标签组件
│   ├── record_list_tile.dart         # 记录列表项组件
│   └── balance_trend_chart.dart      # 余额趋势折线图
└── router.dart                       # go_router 路由配置

test/
├── database/
│   └── app_database_test.dart        # 数据库 CRUD 测试
└── repositories/
    └── record_repository_test.dart    # 余额计算 + 统计查询测试
```

---

### Task 1: 项目脚手架

**Files:**
- Create: `pubspec.yaml` (via flutter create)
- Create: `lib/main.dart`

- [ ] **Step 1: 创建 Flutter 项目**

```bash
cd D:/KidsHabitHelper
flutter create --org com.kidshabit --project-name kids_habit_helper --platforms android .
```

- [ ] **Step 2: 配置 pubspec.yaml 依赖**

替换 `pubspec.yaml` 为：

```yaml
name: kids_habit_helper
description: 小孩习惯养成可视化 App
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.8.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.3.1
  drift: ^2.33.0
  drift_flutter: ^0.3.1
  path_provider: ^2.1.5
  path: ^1.9.0
  fl_chart: ^0.70.2
  go_router: ^17.2.3
  intl: ^0.20.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  drift_dev: ^2.33.0
  build_runner: ^2.15.0
```

- [ ] **Step 3: 安装依赖**

```bash
flutter pub get
```

Expected: `Got dependencies!`

- [ ] **Step 4: 创建目录结构**

```bash
mkdir -p lib/database lib/repositories lib/providers lib/pages lib/widgets
mkdir -p test/database test/repositories
```

- [ ] **Step 5: 写最小 main.dart 占位**

```dart
// lib/main.dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('KidsHabitHelper')),
    ),
  ));
}
```

- [ ] **Step 6: 验证项目可运行**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 7: 初始化 git 并提交**

```bash
git init
echo ".superpowers/" >> .gitignore
git add .
git commit -m "chore: scaffold Flutter project with dependencies"
```

---

### Task 2: 数据库层 — 表定义 + 数据库类

**Files:**
- Create: `lib/database/tables.dart`
- Create: `lib/database/app_database.dart`

- [ ] **Step 1: 定义 drift 表**

```dart
// lib/database/tables.dart
import 'package:drift/drift.dart';

class Children extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get avatar => text().withDefault(const Constant('👦'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get minutesChange => integer()();
  TextColumn get icon => text().withDefault(const Constant('✅'))();
}

class Records extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get childId => integer().references(Children, #id)();
  IntColumn get ruleId => integer().references(Rules, #id)();
  IntColumn get minutesChange => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 2: 创建 AppDatabase 类**

```dart
// lib/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Children, Rules, Records])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

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
    final rows = await (selectOnly(records)
          ..addColumns([records.minutesChange.sum()])
          ..where(records.childId.equals(childId)))
        .getSingle();
    return rows.read(records.minutesChange.sum()) ?? 0;
  }

  /// 按天聚合余额（用于趋势图）
  Future<List<{DateTime date, int balance}>> getDailyBalances(
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
      final day = DateTime(
          r.createdAt.year, r.createdAt.month, r.createdAt.day);
      dailyChanges[day] = (dailyChanges[day] ?? 0) + r.minutesChange;
    }

    // 生成每天累计余额
    final result = <{DateTime date, int balance}>[];
    var cumulative = 0;
    for (int i = 0; i < days; i++) {
      final day = startDate.add(Duration(days: i));
      cumulative += dailyChanges[day] ?? 0;
      result.add((date: day, balance: cumulative));
    }
    return result;
  }

  /// 按规则分类汇总收支
  Future<List<{String ruleName, String icon, int totalChange}>>>
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
```

- [ ] **Step 3: 运行代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `Succeeded after ...` 并生成 `lib/database/app_database.g.dart`

- [ ] **Step 4: 验证编译通过**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: 提交**

```bash
git add lib/database/
git commit -m "feat: add drift database tables and query methods"
```

---

### Task 3: 数据库单元测试

**Files:**
- Create: `test/database/app_database_test.dart`

- [ ] **Step 1: 编写数据库 CRUD 测试**

```dart
// test/database/app_database_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kids_habit_helper/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Children CRUD', () {
    test('insert and watch child', () async {
      await db.insertChild(ChildrenCompanion.insert(name: '小明'));
      final children = await db.watchAllChildren().first;
      expect(children.length, 1);
      expect(children.first.name, '小明');
      expect(children.first.avatar, '👦'); // default value
    });

    test('delete child', () async {
      final id = await db.insertChild(ChildrenCompanion.insert(name: '小红'));
      await db.deleteChild(id);
      final children = await db.watchAllChildren().first;
      expect(children.length, 0);
    });
  });

  group('Rules CRUD', () {
    test('insert and watch rule', () async {
      await db.insertRule(RulesCompanion.insert(
        name: '做家务',
        minutesChange: Value(30),
      ));
      final rules = await db.watchAllRules().first;
      expect(rules.length, 1);
      expect(rules.first.name, '做家务');
      expect(rules.first.minutesChange, 30);
    });
  });

  group('Records and Balance', () {
    late int childId;
    late int ruleId1;
    late int ruleId2;

    setUp(() async {
      childId = await db.insertChild(ChildrenCompanion.insert(name: '小明'));
      ruleId1 = await db.insertRule(RulesCompanion.insert(
        name: '做家务',
        minutesChange: Value(30),
      ));
      ruleId2 = await db.insertRule(RulesCompanion.insert(
        name: '超时',
        minutesChange: Value(-30),
      ));
    });

    test('insert record and calculate balance', () async {
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: Value(30),
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: Value(30),
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId2,
        minutesChange: Value(-30),
      ));

      final balance = await db.getBalance(childId);
      expect(balance, 30); // 30 + 30 - 30 = 30
    });

    test('watch records for child ordered by time desc', () async {
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: Value(30),
      ));

      final records = await db.watchRecordsForChild(childId).first;
      expect(records.length, 1);
      expect(records.first.minutesChange, 30);
    });

    test('daily balances aggregation', () async {
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: Value(30),
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId2,
        minutesChange: Value(-10),
      ));

      final dailyBalances = await db.getDailyBalances(childId, 7);
      expect(dailyBalances.length, 7);
      expect(dailyBalances.last.balance, 20); // 30 - 10
    });

    test('summary by rule', () async {
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: Value(30),
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: Value(30),
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId2,
        minutesChange: Value(-30),
      ));

      final summary = await db.getSummaryByRule(childId);
      expect(summary.length, 2);

      final housework =
          summary.firstWhere((s) => s.ruleName == '做家务');
      expect(housework.totalChange, 60);

      final overtime =
          summary.firstWhere((s) => s.ruleName == '超时');
      expect(overtime.totalChange, -30);
    });
  });
}
```

注意：`AppDatabase` 需要添加一个命名构造函数以支持内存数据库测试：

```dart
// 在 lib/database/app_database.dart 的 AppDatabase 类中添加：
AppDatabase.forTesting(QueryExecutor executor) : super(executor);
```

- [ ] **Step 2: 运行测试确认通过**

```bash
flutter test test/database/app_database_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 3: 提交**

```bash
git add test/ lib/database/app_database.dart
git commit -m "test: add database CRUD and balance calculation tests"
```

---

### Task 4: Repository 层 + Providers

**Files:**
- Create: `lib/repositories/child_repository.dart`
- Create: `lib/repositories/rule_repository.dart`
- Create: `lib/repositories/record_repository.dart`
- Create: `lib/providers/database_provider.dart`
- Create: `lib/providers/child_provider.dart`
- Create: `lib/providers/rule_provider.dart`
- Create: `lib/providers/record_provider.dart`

- [ ] **Step 1: 创建 ChildRepository**

```dart
// lib/repositories/child_repository.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ChildRepository {
  final AppDatabase _db;
  ChildRepository(this._db);

  Stream<List<Child>> watchAll() => _db.watchAllChildren();

  Future<int> add(String name, String avatar) {
    return _db.insertChild(
        ChildrenCompanion.insert(name: name, avatar: Value(avatar)));
  }

  Future<void> update(Child child) {
    return _db.updateChild(ChildrenCompanion(
      id: Value(child.id),
      name: Value(child.name),
      avatar: Value(child.avatar),
      createdAt: Value(child.createdAt),
    ));
  }

  Future<void> delete(int id) async {
    await _db.deleteChild(id);
  }
}
```

- [ ] **Step 2: 创建 RuleRepository**

```dart
// lib/repositories/rule_repository.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';

class RuleRepository {
  final AppDatabase _db;
  RuleRepository(this._db);

  Stream<List<Rule>> watchAll() => _db.watchAllRules();

  Future<int> add(String name, int minutesChange, String icon) {
    return _db.insertRule(RulesCompanion.insert(
      name: name,
      minutesChange: Value(minutesChange),
      icon: Value(icon),
    ));
  }

  Future<void> update(Rule rule) {
    return _db.updateRule(RulesCompanion(
      id: Value(rule.id),
      name: Value(rule.name),
      minutesChange: Value(rule.minutesChange),
      icon: Value(rule.icon),
    ));
  }

  Future<void> delete(int id) async {
    await _db.deleteRule(id);
  }
}
```

- [ ] **Step 3: 创建 RecordRepository**

```dart
// lib/repositories/record_repository.dart
import 'package:drift/drift.dart';
import '../database/app_database.dart';

class RecordRepository {
  final AppDatabase _db;
  RecordRepository(this._db);

  Future<int> add({
    required int childId,
    required int ruleId,
    required int minutesChange,
    String? note,
  }) {
    return _db.insertRecord(RecordsCompanion.insert(
      childId: childId,
      ruleId: ruleId,
      minutesChange: Value(minutesChange),
      note: Value(note),
    ));
  }

  Stream<List<Record>> watchForChild(int childId) =>
      _db.watchRecordsForChild(childId);

  Future<int> getBalance(int childId) => _db.getBalance(childId);

  Future<List<{DateTime date, int balance}>> getDailyBalances(
          int childId, int days) =>
      _db.getDailyBalances(childId, days);

  Future<List<{String ruleName, String icon, int totalChange}>> getSummaryByRule(
          int childId) =>
      _db.getSummaryByRule(childId);
}
```

- [ ] **Step 4: 创建 database provider**

```dart
// lib/providers/database_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
```

- [ ] **Step 5: 创建 child providers**

```dart
// lib/providers/child_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/child_repository.dart';
import 'database_provider.dart';

final childRepositoryProvider = Provider<ChildRepository>((ref) {
  return ChildRepository(ref.watch(databaseProvider));
});

final childrenProvider = StreamProvider<List<Child>>((ref) {
  return ref.watch(childRepositoryProvider).watchAll();
});
```

- [ ] **Step 6: 创建 rule providers**

```dart
// lib/providers/rule_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/rule_repository.dart';
import 'database_provider.dart';

final ruleRepositoryProvider = Provider<RuleRepository>((ref) {
  return RuleRepository(ref.watch(databaseProvider));
});

final rulesProvider = StreamProvider<List<Rule>>((ref) {
  return ref.watch(ruleRepositoryProvider).watchAll();
});
```

- [ ] **Step 7: 创建 record providers**

```dart
// lib/providers/record_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/record_repository.dart';
import 'database_provider.dart';

final recordRepositoryProvider = Provider<RecordRepository>((ref) {
  return RecordRepository(ref.watch(databaseProvider));
});

final recordsForChildProvider =
    StreamProvider.family<List<Record>, int>((ref, childId) {
  return ref.watch(recordRepositoryProvider).watchForChild(childId);
});

final balanceProvider = FutureProvider.family<int, int>((ref, childId) {
  return ref.watch(recordRepositoryProvider).getBalance(childId);
});

final dailyBalancesProvider =
    FutureProvider.family<List<{DateTime date, int balance}>,
        ({int childId, int days})>((ref, params) {
  return ref
      .watch(recordRepositoryProvider)
      .getDailyBalances(params.childId, params.days);
});

final summaryByRuleProvider =
    FutureProvider.family<
        List<{String ruleName, String icon, int totalChange}>,
        int>((ref, childId) {
  return ref.watch(recordRepositoryProvider).getSummaryByRule(childId);
});
```

- [ ] **Step 8: 验证编译通过**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 9: 提交**

```bash
git add lib/repositories/ lib/providers/
git commit -m "feat: add repositories and Riverpod providers"
```

---

### Task 5: App Shell — 路由 + 主题 + 底部导航

**Files:**
- Create: `lib/router.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 创建路由配置**

```dart
// lib/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/statistics_page.dart';
import 'pages/settings_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
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

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 更新 main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';

void main() {
  runApp(const ProviderScope(child: KidsHabitHelperApp()));
}

class KidsHabitHelperApp extends ConsumerWidget {
  const KidsHabitHelperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '习惯养成助手',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
```

- [ ] **Step 3: 创建三个页面占位**

```dart
// lib/pages/home_page.dart
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('首页')),
    );
  }
}
```

```dart
// lib/pages/statistics_page.dart
import 'package:flutter/material.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('统计')),
    );
  }
}
```

```dart
// lib/pages/settings_page.dart
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('设置')),
    );
  }
}
```

- [ ] **Step 4: 验证编译通过**

```bash
flutter analyze
```

- [ ] **Step 5: 提交**

```bash
git add lib/main.dart lib/router.dart lib/pages/
git commit -m "feat: add app shell with router, theme, and bottom navigation"
```

---

### Task 6: 首页 — 小孩列表

**Files:**
- Create: `lib/widgets/child_card.dart`
- Modify: `lib/pages/home_page.dart`

- [ ] **Step 1: 创建 ChildCard 组件**

```dart
// lib/widgets/child_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../database/app_database.dart';

class ChildCard extends StatelessWidget {
  final Child child;
  final int balance;

  const ChildCard({super.key, required this.child, required this.balance});

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/child/${child.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
```

- [ ] **Step 2: 实现首页**

```dart
// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/child_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/child_card.dart';
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
              final balanceAsync =
                  ref.watch(balanceProvider(child.id));
              final balance =
                  balanceAsync.whenOrNull(data: (b) => b) ?? 0;
              return ChildCard(child: child, balance: balance);
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
```

- [ ] **Step 3: 创建 ChildFormPage 占位**

```dart
// lib/pages/child_form_page.dart
import 'package:flutter/material.dart';

class ChildFormPage extends StatelessWidget {
  const ChildFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('添加小孩')),
    );
  }
}
```

- [ ] **Step 4: 验证编译通过**

```bash
flutter analyze
```

- [ ] **Step 5: 提交**

```bash
git add lib/pages/home_page.dart lib/widgets/child_card.dart lib/pages/child_form_page.dart
git commit -m "feat: implement home page with child grid list"
```

---

### Task 7: 小孩管理 — 新增/编辑表单

**Files:**
- Modify: `lib/pages/child_form_page.dart`

- [ ] **Step 1: 实现 ChildFormPage**

```dart
// lib/pages/child_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/child_provider.dart';

const _avatarOptions = ['👦', '👧', '🧒', '👶', '🧒', '👦🏽', '👧🏽', '🐱', '🐶', '🦊'];

class ChildFormPage extends ConsumerStatefulWidget {
  final Child? child;

  const ChildFormPage({super.key, this.child});

  @override
  ConsumerState<ChildFormPage> createState() => _ChildFormPageState();
}

class _ChildFormPageState extends ConsumerState<ChildFormPage> {
  late final _nameController = TextEditingController(text: widget.child?.name);
  late String _selectedAvatar = widget.child?.avatar ?? '👦';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.child != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑小孩' : '添加小孩'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '姓名',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入姓名' : null,
            ),
            const SizedBox(height: 24),
            Text('选择头像', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _avatarOptions.map((avatar) {
                final selected = avatar == _selectedAvatar;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = avatar),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.teal : Colors.grey.shade300,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(avatar, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(childRepositoryProvider);
    if (widget.child != null) {
      await repo.update(Child(
        id: widget.child!.id,
        name: _nameController.text.trim(),
        avatar: _selectedAvatar,
        createdAt: widget.child!.createdAt,
      ));
    } else {
      await repo.add(_nameController.text.trim(), _selectedAvatar);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 2: 验证编译通过**

```bash
flutter analyze
```

- [ ] **Step 3: 提交**

```bash
git add lib/pages/child_form_page.dart
git commit -m "feat: implement child add/edit form with avatar selection"
```

---

### Task 8: 小孩详情页 — 余额 + 快捷打卡 + 记录

**Files:**
- Create: `lib/pages/child_detail_page.dart`
- Create: `lib/widgets/rule_chip.dart`
- Create: `lib/widgets/record_list_tile.dart`
- Modify: `lib/router.dart` (添加 child detail 路由)

- [ ] **Step 1: 添加路由**

在 `lib/router.dart` 的第一个 StatefulShellBranch 中，在 `'/'` 路由内添加子路由：

```dart
// 在 router.dart 第一个 branch 的 '/' 路由中添加 routes:
GoRoute(
  path: '/child/:id',
  name: 'childDetail',
  builder: (context, state) {
    final childId = int.parse(state.pathParameters['id']!);
    return ChildDetailPage(childId: childId);
  },
),
```

同时在顶部添加导入：
```dart
import 'pages/child_detail_page.dart';
```

- [ ] **Step 2: 创建 RuleChip 组件**

```dart
// lib/widgets/rule_chip.dart
import 'package:flutter/material.dart';
import '../database/app_database.dart';

class RuleChip extends StatelessWidget {
  final Rule rule;
  final VoidCallback onTap;

  const RuleChip({super.key, required this.rule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPositive = rule.minutesChange > 0;
    return ActionChip(
      avatar: Text(rule.icon, style: const TextStyle(fontSize: 16)),
      label: Text('${rule.name} ${isPositive ? '+' : ''}${rule.minutesChange}'),
      backgroundColor: isPositive ? Colors.green.shade50 : Colors.red.shade50,
      side: BorderSide(
        color: isPositive ? Colors.green.shade200 : Colors.red.shade200,
      ),
      onPressed: onTap,
    );
  }
}
```

- [ ] **Step 3: 创建 RecordListTile 组件**

```dart
// lib/widgets/record_list_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class RecordListTile extends StatelessWidget {
  final Record record;
  final String ruleName;
  final String ruleIcon;

  const RecordListTile({
    super.key,
    required this.record,
    required this.ruleName,
    required this.ruleIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = record.minutesChange > 0;
    final timeFormat = DateFormat('MM/dd HH:mm');

    return ListTile(
      leading: Text(ruleIcon, style: const TextStyle(fontSize: 24)),
      title: Text(ruleName),
      subtitle: Text(timeFormat.format(record.createdAt)),
      trailing: Text(
        '${isPositive ? '+' : ''}${record.minutesChange} 分钟',
        style: TextStyle(
          color: isPositive ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 实现 ChildDetailPage**

```dart
// lib/pages/child_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/child_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/rule_chip.dart';
import '../widgets/record_list_tile.dart';

class ChildDetailPage extends ConsumerWidget {
  final int childId;

  const ChildDetailPage({super.key, required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final child = children.whenOrNull<Child?>(
      data: (list) => list.where((c) => c.id == childId).firstOrNull,
    );
    final balanceAsync = ref.watch(balanceProvider(childId));
    final rulesAsync = ref.watch(rulesProvider);
    final recordsAsync = ref.watch(recordsForChildProvider(childId));

    final balance = balanceAsync.whenOrNull(data: (b) => b) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(child?.name ?? ''),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 余额卡片
          Card(
            color: balance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
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
          const Text('快捷打卡', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          rulesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const Text('加载规则失败'),
            data: (rules) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rules.map((rule) {
                return RuleChip(
                  rule: rule,
                  onTap: () => _record(ref, rule),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // 最近记录
          const Text('最近记录', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('错误: $e'),
            data: (records) {
              if (records.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('暂无记录', textAlign: TextAlign.center),
                );
              }
              // 需要规则名称映射
              final rulesMap = <int, Rule>{};
              rulesAsync.whenOrNull(data: (rules) {
                for (final r in rules) {
                  rulesMap[r.id] = r;
                }
              });
              return Column(
                children: records.take(20).map((record) {
                  final rule = rulesMap[record.ruleId];
                  return RecordListTile(
                    record: record,
                    ruleName: rule?.name ?? '',
                    ruleIcon: rule?.icon ?? '📋',
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
    // 刷新余额
    ref.invalidate(balanceProvider(childId));
  }
}
```

- [ ] **Step 5: 更新 ChildCard 导航到 push 而非 go**

修改 `lib/widgets/child_card.dart`，使用 `context.push` 以支持返回：

```dart
// 在 child_card.dart 中，将 onTap 改为:
onTap: () => context.push('/child/${child.id}'),
```

- [ ] **Step 6: 验证编译通过**

```bash
flutter analyze
```

- [ ] **Step 7: 提交**

```bash
git add lib/pages/child_detail_page.dart lib/widgets/rule_chip.dart lib/widgets/record_list_tile.dart lib/router.dart lib/widgets/child_card.dart
git commit -m "feat: implement child detail page with check-in and records"
```

---

### Task 9: 规则管理 — 设置页 + 规则表单

**Files:**
- Create: `lib/pages/rule_form_page.dart`
- Modify: `lib/pages/settings_page.dart`

- [ ] **Step 1: 创建 RuleFormPage**

```dart
// lib/pages/rule_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/rule_provider.dart';

const _iconOptions = ['✅', '🧹', '📖', '📱', '💯', '🎹', '🏃', '🎨', '⭐', '💤', '🎮', '🍽️'];

class RuleFormPage extends ConsumerStatefulWidget {
  final Rule? rule;

  const RuleFormPage({super.key, this.rule});

  @override
  ConsumerState<RuleFormPage> createState() => _RuleFormPageState();
}

class _RuleFormPageState extends ConsumerState<RuleFormPage> {
  late final _nameController = TextEditingController(text: widget.rule?.name);
  late final _minutesController = TextEditingController(
    text: widget.rule != null
        ? widget.rule!.minutesChange.abs().toString()
        : '',
  );
  late bool _isNegative =
      widget.rule?.minutesChange != null && widget.rule!.minutesChange < 0;
  late String _selectedIcon = widget.rule?.icon ?? '✅';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.rule != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑规则' : '添加规则')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '规则名称',
                border: OutlineInputBorder(),
                hintText: '如：做家务、阅读、超时使用',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minutesController,
                    decoration: const InputDecoration(
                      labelText: '分钟数',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入分钟数';
                      if (int.tryParse(v) == null) return '请输入有效数字';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('+增加')),
                    ButtonSegment(value: true, label: Text('-扣减')),
                  ],
                  selected: {_isNegative},
                  onSelectionChanged: (v) =>
                      setState(() => _isNegative = v.first),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('选择图标', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _iconOptions.map((icon) {
                final selected = icon == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            selected ? Colors.teal : Colors.grey.shade300,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child:
                        Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final minutes = int.parse(_minutesController.text);
    final actualMinutes = _isNegative ? -minutes : minutes;
    final repo = ref.read(ruleRepositoryProvider);

    if (widget.rule != null) {
      await repo.update(Rule(
        id: widget.rule!.id,
        name: _nameController.text.trim(),
        minutesChange: actualMinutes,
        icon: _selectedIcon,
      ));
    } else {
      await repo.add(_nameController.text.trim(), actualMinutes, _selectedIcon);
    }
    if (mounted) Navigator.of(context).pop();
  }
}
```

- [ ] **Step 2: 实现 SettingsPage**

```dart
// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/child_provider.dart';
import '../providers/rule_provider.dart';
import '../pages/child_form_page.dart';
import '../pages/rule_form_page.dart';
import '../database/app_database.dart';

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
                    leading: Text(child.avatar, style: const TextStyle(fontSize: 28)),
                    title: Text(child.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChildFormPage(child: child),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _confirmDelete(
                            context,
                            '删除 ${child.name}？',
                            () => ref.read(childRepositoryProvider).delete(child.id),
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
                    leading: Text(rule.icon, style: const TextStyle(fontSize: 28)),
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
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _confirmDelete(
                            context,
                            '删除规则「${rule.name}」？',
                            () => ref.read(ruleRepositoryProvider).delete(rule.id),
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

  void _confirmDelete(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
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
      title: Text(title, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 16)),
      trailing: IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
    );
  }
}
```

- [ ] **Step 3: 验证编译通过**

```bash
flutter analyze
```

- [ ] **Step 4: 提交**

```bash
git add lib/pages/settings_page.dart lib/pages/rule_form_page.dart
git commit -m "feat: implement settings page with child and rule management"
```

---

### Task 10: 统计页面 — 图表

**Files:**
- Create: `lib/widgets/balance_trend_chart.dart`
- Modify: `lib/pages/statistics_page.dart`

- [ ] **Step 1: 创建余额趋势折线图组件**

```dart
// lib/widgets/balance_trend_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BalanceTrendChart extends StatelessWidget {
  final List<{DateTime date, int balance}> data;

  const BalanceTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('暂无数据')),
      );
    }

    final maxY = data.map((d) => d.balance).reduce((a, b) => a > b ? a : b);
    final minY = data.map((d) => d.balance).reduce((a, b) => a < b ? a : b);
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
                getTitlesWidget: (value, meta) =>
                    Text('${value.toInt()}分', style: const TextStyle(fontSize: 10)),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              dotData: FlDotData(
                show: data.length <= 14,
              ),
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
                  const TextStyle(color: Colors.white, fontSize: 14),
                );
              }).toList(),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }
}
```

- [ ] **Step 2: 实现统计页面**

```dart
// lib/pages/statistics_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/child_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/balance_trend_chart.dart';

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

          // 自动选中第一个
          final selectedId = _selectedChildId ?? children.first.id;
          if (_selectedChildId == null) {
            _selectedChildId = selectedId;
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
                onSelectionChanged: (v) => setState(() => _days = v.first),
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
                          style: Theme.of(context).textTheme.titleMedium),
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
                          style: Theme.of(context).textTheme.titleMedium),
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
    final balancesAsync =
        ref.watch(dailyBalancesProvider((childId: childId, days: _days)));
    return balancesAsync.when(
      loading: () => const SizedBox(
        height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(
        height: 200, child: Center(child: Text('错误: $e'))),
      data: (data) => BalanceTrendChart(data: data),
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
              leading: Text(item.icon, style: const TextStyle(fontSize: 24)),
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
```

- [ ] **Step 3: 验证编译通过**

```bash
flutter analyze
```

- [ ] **Step 4: 提交**

```bash
git add lib/pages/statistics_page.dart lib/widgets/balance_trend_chart.dart
git commit -m "feat: implement statistics page with trend chart and rule summary"
```

---

### Task 11: 端到端测试 + 收尾

**Files:**
- Create: `test/app_test.dart`
- Modify: `lib/main.dart` (如有需要)

- [ ] **Step 1: 编写端到端 Widget 测试**

```dart
// test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kids_habit_helper/database/app_database.dart';
import 'package:kids_habit_helper/main.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('App smoke test - renders bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: KidsHabitHelperApp(),
    ));
    await tester.pumpAndSettle();

    // 验证底部导航存在
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('Home page shows empty state', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: KidsHabitHelperApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('还没有小孩，点击 + 添加'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行全部测试**

```bash
flutter test
```

Expected: `All tests passed!`

- [ ] **Step 3: 运行完整静态分析**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: 构建 Android APK**

```bash
flutter build apk --debug
```

Expected: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 5: 最终提交**

```bash
git add .
git commit -m "feat: complete KidsHabitHelper v1.0 - habit tracking with visualization"
```

---

## 自检结果

- **Spec 覆盖:** 所有设计文档中的需求都有对应 Task（数据模型 Task 2-3, UI 所有页面 Task 5-10, 端到端 Task 11）
- **占位符:** 无 TBD/TODO，所有步骤包含完整代码
- **类型一致性:** Child/Rule/Record 类型、字段名、方法签名在所有 Task 中保持一致
