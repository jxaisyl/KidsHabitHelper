import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/cloudbase_auth_service.dart';

/// 微信云开发配置
const wxAppId = 'wx96ca310e00f3f1f0';
const wxAppSecret = '63279c5965704e90eb44d585ea6093a0';
const wxCloudEnvId = 'cloudbase-d7gdlreoq9bfaba40';

final authServiceProvider = Provider<CloudBaseAuthService>((ref) {
  final service = CloudBaseAuthService(wxAppId, wxAppSecret, wxCloudEnvId);
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
