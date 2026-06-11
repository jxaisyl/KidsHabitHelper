import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/rule_repository.dart';
import 'database_provider.dart';

final ruleRepositoryProvider = Provider<RuleRepository>((ref) {
  return RuleRepository(ref.watch(databaseProvider));
});

final rulesProvider = StreamProvider<List<Rule>>((ref) {
  return ref.watch(ruleRepositoryProvider).watchAll();
});
