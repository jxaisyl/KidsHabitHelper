import 'package:drift/drift.dart';
import '../database/app_database.dart';

class RuleRepository {
  final AppDatabase _db;
  RuleRepository(this._db);

  Stream<List<Rule>> watchAll() => _db.watchAllRules();

  Future<int> add(String name, int minutesChange, String icon) {
    return _db.insertRule(RulesCompanion.insert(
      name: name,
      minutesChange: minutesChange,
      icon: Value(icon),
    ));
  }

  Future<void> update(Rule rule) {
    return _db.updateRule(rule);
  }

  Future<void> delete(int id) async {
    await _db.deleteRule(id);
  }
}
