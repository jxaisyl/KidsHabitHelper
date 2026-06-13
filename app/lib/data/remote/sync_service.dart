import 'dart:async';
import 'package:drift/drift.dart';
import '../../database/app_database.dart';
import 'remote_datasource.dart';

enum SyncStatus { idle, syncing, error, offline }

class SyncService {
  final AppDatabase _db;
  final RemoteDatasource _remote;
  final _statusController = StreamController<SyncStatus>.broadcast();

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncService(this._db, this._remote);

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }

  /// 首次登录同步：先拉取云端数据到本地，再把本地独有数据推送到云端
  Future<void> initialSync() async {
    _setStatus(SyncStatus.syncing);
    try {
      await _pullFromRemote();
      await _pushLocalToRemote();
      await _remote.updateLastSync();
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _setStatus(SyncStatus.error);
    }
  }

  /// 从云端拉取所有数据写入本地（不覆盖已存在的）
  Future<void> _pullFromRemote() async {
    final remoteChildren = await _remote.pullChildren(null);
    for (final data in remoteChildren) {
      final localId = data['localId'] as int?;
      if (localId == null) continue;
      final existing = await (_db.select(_db.children)
            ..where((t) => t.id.equals(localId)))
          .getSingleOrNull();
      if (existing == null) {
        await _db.into(_db.children).insert(
          ChildrenCompanion.insert(
            name: data['name'] as String,
            avatar: Value(data['avatar'] as String),
          ),
        );
      }
      await _upsertIdMapping(localId, data['id'] as String, 'child');
    }

    final remoteRules = await _remote.pullRules(null);
    for (final data in remoteRules) {
      final localId = data['localId'] as int?;
      if (localId == null) continue;
      final existing = await (_db.select(_db.rules)
            ..where((t) => t.id.equals(localId)))
          .getSingleOrNull();
      if (existing == null) {
        await _db.insertRule(RulesCompanion.insert(
          name: data['name'] as String,
          minutesChange: data['minutesChange'] as int,
          icon: Value(data['icon'] as String),
        ));
      }
      await _upsertIdMapping(localId, data['id'] as String, 'rule');
    }

    final remoteRecords = await _remote.pullRecords(null);
    for (final data in remoteRecords) {
      final localId = data['localId'] as int?;
      if (localId == null) continue;
      final existing = await (_db.select(_db.records)
            ..where((t) => t.id.equals(localId)))
          .getSingleOrNull();
      if (existing == null) {
        final childLocalId =
            await _findLocalIdByRemote(data['childId'] as String, 'child');
        final ruleLocalId =
            await _findLocalIdByRemote(data['ruleId'] as String, 'rule');
        if (childLocalId != null && ruleLocalId != null) {
          await _db.insertRecord(RecordsCompanion.insert(
            childId: childLocalId,
            ruleId: ruleLocalId,
            minutesChange: data['minutesChange'] as int,
            note: Value(data['note'] as String?),
          ));
        }
      }
      await _upsertIdMapping(localId, data['id'] as String, 'record');
    }
  }

  /// 推送本地所有数据到云端
  Future<void> _pushLocalToRemote() async {
    final children = await _db.watchAllChildren().first;
    for (final child in children) {
      final remoteId = await _getOrCreateRemoteId(child.id, 'child');
      await _remote.pushChild({
        'name': child.name,
        'avatar': child.avatar,
        'createdAt': child.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'localId': child.id,
      }, remoteId);
    }

    final rules = await _db.watchAllRules().first;
    for (final rule in rules) {
      final remoteId = await _getOrCreateRemoteId(rule.id, 'rule');
      await _remote.pushRule({
        'name': rule.name,
        'minutesChange': rule.minutesChange,
        'icon': rule.icon,
        'updatedAt': DateTime.now().toIso8601String(),
        'localId': rule.id,
      }, remoteId);
    }

    final records = await (_db.select(_db.records)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    for (final record in records) {
      final remoteId = await _getOrCreateRemoteId(record.id, 'record');
      final childRemoteId =
          await _getRemoteId(record.childId, 'child') ?? '';
      final ruleRemoteId =
          await _getRemoteId(record.ruleId, 'rule') ?? '';
      await _remote.pushRecord({
        'childId': childRemoteId,
        'ruleId': ruleRemoteId,
        'minutesChange': record.minutesChange,
        'note': record.note,
        'createdAt': record.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'localId': record.id,
      }, remoteId);
    }
  }

  /// Pull remote data into local DB (for periodic sync)
  Future<void> pull() async {
    _setStatus(SyncStatus.syncing);
    try {
      await _pullFromRemote();
      await _remote.updateLastSync();
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _setStatus(SyncStatus.error);
    }
  }

  /// Push a single entity change
  Future<void> pushChild(ChildrenData child) async {
    try {
      final remoteId = await _getOrCreateRemoteId(child.id, 'child');
      await _remote.pushChild({
        'name': child.name,
        'avatar': child.avatar,
        'createdAt': child.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'localId': child.id,
      }, remoteId);
    } catch (_) {
      _setStatus(SyncStatus.error);
    }
  }

  Future<void> deleteChildRemote(int localId) async {
    try {
      final remoteId = await _getRemoteId(localId, 'child');
      if (remoteId != null) await _remote.deleteChild(remoteId);
    } catch (_) {}
  }

  Future<void> pushRule(Rule rule) async {
    try {
      final remoteId = await _getOrCreateRemoteId(rule.id, 'rule');
      await _remote.pushRule({
        'name': rule.name,
        'minutesChange': rule.minutesChange,
        'icon': rule.icon,
        'updatedAt': DateTime.now().toIso8601String(),
        'localId': rule.id,
      }, remoteId);
    } catch (_) {
      _setStatus(SyncStatus.error);
    }
  }

  Future<void> deleteRuleRemote(int localId) async {
    try {
      final remoteId = await _getRemoteId(localId, 'rule');
      if (remoteId != null) await _remote.deleteRule(remoteId);
    } catch (_) {}
  }

  Future<void> pushRecord(Record record) async {
    try {
      final remoteId = await _getOrCreateRemoteId(record.id, 'record');
      final childRemoteId =
          await _getRemoteId(record.childId, 'child') ?? '';
      final ruleRemoteId =
          await _getRemoteId(record.ruleId, 'rule') ?? '';
      await _remote.pushRecord({
        'childId': childRemoteId,
        'ruleId': ruleRemoteId,
        'minutesChange': record.minutesChange,
        'note': record.note,
        'createdAt': record.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'localId': record.id,
      }, remoteId);
    } catch (_) {
      _setStatus(SyncStatus.error);
    }
  }

  // --- ID Mapping helpers ---

  final _idMap = <String, String>{};

  Future<String> _getOrCreateRemoteId(
      int localId, String entityType) async {
    final key = '${entityType}_$localId';
    if (_idMap.containsKey(key)) return _idMap[key]!;
    final remoteId =
        '${entityType}_${localId}_${DateTime.now().millisecondsSinceEpoch}';
    _idMap[key] = remoteId;
    return remoteId;
  }

  Future<String?> _getRemoteId(int localId, String entityType) async {
    return _idMap['${entityType}_$localId'];
  }

  Future<void> _upsertIdMapping(
      int localId, String remoteId, String entityType) async {
    _idMap['${entityType}_$localId'] = remoteId;
  }

  Future<int?> _findLocalIdByRemote(
      String remoteId, String entityType) async {
    for (final entry in _idMap.entries) {
      if (entry.key.startsWith('${entityType}_') &&
          entry.value == remoteId) {
        return int.parse(entry.key.split('_').last);
      }
    }
    return null;
  }

  void dispose() {
    _statusController.close();
  }
}
