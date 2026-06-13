import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../data/remote/sync_service.dart';

class ChildRepository {
  final AppDatabase _db;
  final SyncService? _sync;
  ChildRepository(this._db, [this._sync]);

  Stream<List<ChildrenData>> watchAll() => _db.watchAllChildren();

  Future<int> add(String name, String avatar) async {
    final id = await _db.insertChild(
        ChildrenCompanion.insert(name: name, avatar: Value(avatar)));
    if (_sync != null) {
      final child = ChildrenData(
          id: id, name: name, avatar: avatar, createdAt: DateTime.now());
      _sync.pushChild(child);
    }
    return id;
  }

  Future<void> update(ChildrenData child) async {
    await _db.updateChild(child);
    if (_sync != null) _sync.pushChild(child);
  }

  Future<void> delete(int id) async {
    if (_sync != null) _sync.deleteChildRemote(id);
    await _db.deleteChild(id);
  }
}
