import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/record_repository.dart';
import 'database_provider.dart';
import 'sync_provider.dart';

final recordRepositoryProvider = Provider<RecordRepository>((ref) {
  return RecordRepository(
    ref.watch(databaseProvider),
    ref.watch(syncServiceProvider),
  );
});

final recordsForChildProvider =
    StreamProvider.family<List<Record>, int>((ref, childId) {
  return ref.watch(recordRepositoryProvider).watchForChild(childId);
});

final balanceProvider = FutureProvider.family<int, int>((ref, childId) {
  return ref.watch(recordRepositoryProvider).getBalance(childId);
});

final dailyBalancesProvider =
    FutureProvider.family<List<({DateTime date, int balance})>,
        ({int childId, int days})>((ref, params) {
  return ref
      .watch(recordRepositoryProvider)
      .getDailyBalances(params.childId, params.days);
});

final summaryByRuleProvider = FutureProvider.family<
    List<({String ruleName, String icon, int totalChange})>,
    int>((ref, childId) {
  return ref.watch(recordRepositoryProvider).getSummaryByRule(childId);
});
