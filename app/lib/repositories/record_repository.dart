import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../data/remote/sync_service.dart';

class RecordRepository {
  final AppDatabase _db;
  final SyncService? _sync;
  RecordRepository(this._db, [this._sync]);

  Future<int> add({
    required int childId,
    required int ruleId,
    required int minutesChange,
    String? note,
  }) async {
    final id = await _db.insertRecord(RecordsCompanion.insert(
      childId: childId,
      ruleId: ruleId,
      minutesChange: minutesChange,
      note: Value(note),
    ));
    if (_sync != null) {
      // Fetch the full record to push
      final records = await (_db.select(_db.records)
            ..where((t) => t.id.equals(id)))
          .get();
      if (records.isNotEmpty) _sync.pushRecord(records.first);
    }
    return id;
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
