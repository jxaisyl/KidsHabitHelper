import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 通过微信云开发云函数 HTTP API 实现的认证服务
class CloudBaseAuthService {
  final String _apiBase;
  String? _token;
  String? _uid;
  final _controller = StreamController<bool>.broadcast();

  CloudBaseAuthService(this._apiBase);

  /// 认证状态流：true=已登录，false=未登录
  Stream<bool> get authStateStream => _controller.stream;

  /// 当前用户 token（即 userId/openid）
  String? get currentToken => _token;
  String? get currentUid => _uid;

  /// 启动时从本地恢复登录状态
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('cloudbase_token');
    _uid = prefs.getString('cloudbase_uid');
    _controller.add(_token != null);
  }

  Future<String> signIn(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_apiBase/login'),
      body: {'email': email, 'password': password},
    );
    if (response.statusCode != 200) {
      throw AuthException(_parseError(response.body, '登录失败'));
    }
    final body = response.body;
    // 云函数返回 JSON: {"token": "...", "uid": "..."}
    // 简单解析（避免引入 dart:convert 之外的依赖）
    _token = _extractField(body, 'token');
    _uid = _extractField(body, 'uid');
    if (_token == null) throw AuthException('登录返回数据异常');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cloudbase_token', _token!);
    await prefs.setString('cloudbase_uid', _uid ?? '');
    _controller.add(true);
    return _token!;
  }

  Future<String> signUp(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_apiBase/register'),
      body: {'email': email, 'password': password},
    );
    if (response.statusCode != 200) {
      throw AuthException(_parseError(response.body, '注册失败'));
    }
    final body = response.body;
    _token = _extractField(body, 'token');
    _uid = _extractField(body, 'uid');
    if (_token == null) throw AuthException('注册返回数据异常');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cloudbase_token', _token!);
    await prefs.setString('cloudbase_uid', _uid ?? '');
    _controller.add(true);
    return _token!;
  }

  Future<void> signOut() async {
    _token = null;
    _uid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cloudbase_token');
    await prefs.remove('cloudbase_uid');
    _controller.add(false);
  }

  void dispose() {
    _controller.close();
  }

  /// 简单的 JSON 字段提取，避免完整 JSON 解析
  String? _extractField(String json, String key) {
    final pattern = '"$key":"';
    final start = json.indexOf(pattern);
    if (start < 0) return null;
    final valueStart = start + pattern.length;
    final valueEnd = json.indexOf('"', valueStart);
    if (valueEnd < 0) return null;
    return json.substring(valueStart, valueEnd);
  }

  String _parseError(String body, String fallback) {
    final msg = _extractField(body, 'error') ?? _extractField(body, 'message');
    if (msg != null) {
      if (msg.contains('user-not-found')) return '用户不存在';
      if (msg.contains('wrong-password') || msg.contains('invalid-credential')) return '邮箱或密码错误';
      if (msg.contains('email-already-in-use')) return '该邮箱已被注册';
      if (msg.contains('weak-password')) return '密码强度太弱';
      if (msg.contains('too-many-requests')) return '请求过于频繁，请稍后再试';
      return msg;
    }
    return fallback;
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
