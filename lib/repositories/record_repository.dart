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
      minutesChange: minutesChange,
      note: Value(note),
    ));
  }

  Stream<List<Record>> watchForChild(int childId) =>
      _db.watchRecordsForChild(childId);

  Future<int> getBalance(int childId) => _db.getBalance(childId);

  Future<List<({DateTime date, int balance})>> getDailyBalances(
          int childId, int days) =>
      _db.getDailyBalances(childId, days);

  Future<List<({String ruleName, String icon, int totalChange})>>
      getSummaryByRule(int childId) => _db.getSummaryByRule(childId);
}
