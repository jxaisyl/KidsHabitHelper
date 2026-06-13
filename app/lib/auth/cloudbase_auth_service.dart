import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 通过微信云开发 invokecloudfunction API 实现的认证服务
class CloudBaseAuthService {
  final String _appid;
  final String _secret;
  final String _envId;

  String? _accessToken;
  DateTime? _tokenExpiry;
  String? _userToken; // 用户登录后的 token（即 users 集合的 _id）
  String? _uid;
  final _controller = StreamController<bool>.broadcast();

  CloudBaseAuthService(this._appid, this._secret, this._envId);

  Stream<bool> get authStateStream => _controller.stream;
  String? get currentToken => _userToken;
  String? get currentUid => _uid;

  /// 获取微信 access_token（带缓存）
  Future<String> _getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final response = await http.get(Uri.parse(
      'https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=$_appid&secret=$_secret',
    ));

    if (response.statusCode != 200) {
      throw AuthException('获取 access_token 失败');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['errcode'] != null && data['errcode'] != 0) {
      throw AuthException('微信 API 错误: ${data['errmsg']}');
    }

    _accessToken = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int? ?? 7200;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300));
    return _accessToken!;
  }

  /// 调用云函数
  Future<Map<String, dynamic>> _callFunction(String name, Map<String, dynamic> data) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      'https://api.weixin.qq.com/tcb/invokecloudfunction?access_token=$token&env=$_envId&name=$name',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw AuthException('云函数调用失败: HTTP ${response.statusCode}');
    }

    final resp = jsonDecode(response.body) as Map<String, dynamic>;
    if (resp['errcode'] != null && resp['errcode'] != 0) {
      throw AuthException('云函数错误: ${resp['errmsg']}');
    }

    // resp_data 是 JSON 字符串
    final respData = resp['resp_data'] as String;
    return jsonDecode(respData) as Map<String, dynamic>;
  }

  /// 启动时从本地恢复登录状态
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userToken = prefs.getString('cloudbase_token');
    _uid = prefs.getString('cloudbase_uid');
    _controller.add(_userToken != null);
  }

  Future<String> signIn(String email, String password) async {
    final result = await _callFunction('login', {
      'email': email,
      'password': password,
    });

    if (result.containsKey('error')) {
      throw AuthException(_translateError(result['error'] as String));
    }

    _userToken = result['token'] as String?;
    _uid = result['uid'] as String?;
    if (_userToken == null) throw AuthException('登录返回数据异常');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cloudbase_token', _userToken!);
    await prefs.setString('cloudbase_uid', _uid ?? '');
    _controller.add(true);
    return _userToken!;
  }

  Future<String> signUp(String email, String password) async {
    final result = await _callFunction('register', {
      'email': email,
      'password': password,
    });

    if (result.containsKey('error')) {
      throw AuthException(_translateError(result['error'] as String));
    }

    _userToken = result['token'] as String?;
    _uid = result['uid'] as String?;
    if (_userToken == null) throw AuthException('注册返回数据异常');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cloudbase_token', _userToken!);
    await prefs.setString('cloudbase_uid', _uid ?? '');
    _controller.add(true);
    return _userToken!;
  }

  Future<void> signOut() async {
    _userToken = null;
    _uid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cloudbase_token');
    await prefs.remove('cloudbase_uid');
    _controller.add(false);
  }

  void dispose() {
    _controller.close();
  }

  String _translateError(String error) {
    switch (error) {
      case 'user-not-found': return '用户不存在';
      case 'wrong-password': return '邮箱或密码错误';
      case 'email-already-in-use': return '该邮箱已被注册';
      case 'weak-password': return '密码强度太弱';
      default: return error;
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
