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
      await db.insertChild(
          ChildrenCompanion.insert(name: '小明', avatar: Value('👦')));
      final children = await db.watchAllChildren().first;
      expect(children.length, 1);
      expect(children.first.name, '小明');
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
        minutesChange: 30,
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
      childId =
          await db.insertChild(ChildrenCompanion.insert(name: '小明'));
      ruleId1 = await db.insertRule(RulesCompanion.insert(
        name: '做家务',
        minutesChange: 30,
      ));
      ruleId2 = await db.insertRule(RulesCompanion.insert(
        name: '超时',
        minutesChange: -30,
      ));
    });

    test('insert record and calculate balance', () async {
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: 30,
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: 30,
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId2,
        minutesChange: -30,
      ));

      final balance = await db.getBalance(childId);
      expect(balance, 30);
    });

    test('watch records for child', () async {
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: 30,
      ));

      final records = await db.watchRecordsForChild(childId).first;
      expect(records.length, 1);
      expect(records.first.minutesChange, 30);
    });

    test('daily balances aggregation', () async {
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: 30,
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId2,
        minutesChange: -10,
      ));

      final dailyBalances = await db.getDailyBalances(childId, 7);
      expect(dailyBalances.length, 7);
      expect(dailyBalances.last.balance, 20);
    });

    test('summary by rule', () async {
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: 30,
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId1,
        minutesChange: 30,
      ));
      await db.insertRecord(RecordsCompanion.insert(
        childId: childId,
        ruleId: ruleId2,
        minutesChange: -30,
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
