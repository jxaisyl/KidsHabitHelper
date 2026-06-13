import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/cloudbase_auth_service.dart';

/// 云函数 API 基地址
const cloudBaseApiBase = 'https://cloudbase-d7gdlreoq9bfaba40.service.tcloudbase.com';

final authServiceProvider = Provider<CloudBaseAuthService>((ref) {
  final service = CloudBaseAuthService(cloudBaseApiBase);
  ref.onDispose(() => service.dispose());
  return service;
});

/// 认证状态：true=已登录，false=未登录
final authStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateStream;
});

/// 当前用户 ID（token）
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authServiceProvider).currentUid;
});
