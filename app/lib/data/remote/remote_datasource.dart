/// 远程数据源抽象接口，由具体后端实现（CloudBase、Firestore 等）
abstract class RemoteDatasource {
  // Children
  Future<void> pushChild(Map<String, dynamic> data, String remoteId);
  Future<void> deleteChild(String remoteId);
  Future<List<Map<String, dynamic>>> pullChildren(DateTime? since);

  // Rules
  Future<void> pushRule(Map<String, dynamic> data, String remoteId);
  Future<void> deleteRule(String remoteId);
  Future<List<Map<String, dynamic>>> pullRules(DateTime? since);

  // Records
  Future<void> pushRecord(Map<String, dynamic> data, String remoteId);
  Future<void> deleteRecord(String remoteId);
  Future<List<Map<String, dynamic>>> pullRecords(DateTime? since);

  // Sync meta
  Future<DateTime?> getLastSync();
  Future<void> updateLastSync();
}
