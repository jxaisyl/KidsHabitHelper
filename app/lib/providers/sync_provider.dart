import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/remote/cloudbase_datasource.dart';
import '../data/remote/sync_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final syncServiceProvider = Provider<SyncService?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;

  final db = ref.watch(databaseProvider);
  final userToken = ref.watch(authServiceProvider).currentToken ?? uid;
  final datasource = CloudBaseDatasource(wxAppId, wxAppSecret, wxCloudEnvId, userToken);
  final service = SyncService(db, datasource);

  ref.onDispose(() => service.dispose());
  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus?>((ref) {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return Stream.value(null);
  return service.statusStream;
});

/// 登录后自动执行首次同步
final initialSyncProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return;

  await service.initialSync();
});
