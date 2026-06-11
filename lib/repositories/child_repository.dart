import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ChildRepository {
  final AppDatabase _db;
  ChildRepository(this._db);

  Stream<List<ChildrenData>> watchAll() => _db.watchAllChildren();

  Future<int> add(String name, String avatar) {
    return _db.insertChild(
        ChildrenCompanion.insert(name: name, avatar: Value(avatar)));
  }

  Future<void> update(ChildrenData child) {
    return _db.updateChild(child);
  }

  Future<void> delete(int id) async {
    await _db.deleteChild(id);
  }
}
