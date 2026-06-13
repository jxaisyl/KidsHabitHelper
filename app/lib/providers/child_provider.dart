import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/child_repository.dart';
import 'database_provider.dart';
import 'sync_provider.dart';

final childRepositoryProvider = Provider<ChildRepository>((ref) {
  return ChildRepository(
    ref.watch(databaseProvider),
    ref.watch(syncServiceProvider),
  );
});

final childrenProvider = StreamProvider<List<ChildrenData>>((ref) {
  return ref.watch(childRepositoryProvider).watchAll();
});
