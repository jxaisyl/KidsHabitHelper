import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../data/remote/sync_service.dart';

class RuleRepository {
  final AppDatabase _db;
  final SyncService? _sync;
  RuleRepository(this._db, [this._sync]);

  Stream<List<Rule>> watchAll() => _db.watchAllRules();

  Future<int> add(String name, int minutesChange, String icon) async {
    final id = await _db.insertRule(RulesCompanion.insert(
      name: name,
      minutesChange: minutesChange,
      icon: Value(icon),
    ));
    if (_sync != null) {
      final rule = Rule(
          id: id,
          name: name,
          minutesChange: minutesChange,
          icon: icon);
      _sync.pushRule(rule);
    }
    return id;
  }

  Future<void> update(Rule rule) async {
    await _db.updateRule(rule);
    if (_sync != null) _sync.pushRule(rule);
  }

  Future<void> delete(int id) async {
    if (_sync != null) _sync.deleteRuleRemote(id);
    await _db.deleteRule(id);
  }
}
