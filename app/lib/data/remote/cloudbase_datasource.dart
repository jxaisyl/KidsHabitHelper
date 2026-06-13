import 'dart:convert';
import 'package:http/http.dart' as http;
import 'remote_datasource.dart';

/// 通过微信云开发 invokecloudfunction API 实现的远程数据源
class CloudBaseDatasource implements RemoteDatasource {
  final String _appid;
  final String _secret;
  final String _envId;
  final String _userToken;

  String? _accessToken;
  DateTime? _tokenExpiry;

  CloudBaseDatasource(this._appid, this._secret, this._envId, this._userToken);

  Future<String> _getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final response = await http.get(Uri.parse(
      'https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=$_appid&secret=$_secret',
    ));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int? ?? 7200;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300));
    return _accessToken!;
  }

  Future<dynamic> _callFunction(String name, Map<String, dynamic> eventData) async {
    final token = await _getAccessToken();
    final uri = Uri.parse(
      'https://api.weixin.qq.com/tcb/invokecloudfunction?access_token=$token&env=$_envId&name=$name',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(eventData),
    );

    final resp = jsonDecode(response.body) as Map<String, dynamic>;
    final respData = resp['resp_data'] as String;
    return jsonDecode(respData);
  }

  // --- Children ---
  @override
  Future<void> pushChild(Map<String, dynamic> data, String remoteId) {
    return _push('children', remoteId, data);
  }

  @override
  Future<void> deleteChild(String remoteId) {
    return _delete('children', remoteId);
  }

  @override
  Future<List<Map<String, dynamic>>> pullChildren(DateTime? since) {
    return _pull('children', since);
  }

  // --- Rules ---
  @override
  Future<void> pushRule(Map<String, dynamic> data, String remoteId) {
    return _push('rules', remoteId, data);
  }

  @override
  Future<void> deleteRule(String remoteId) {
    return _delete('rules', remoteId);
  }

  @override
  Future<List<Map<String, dynamic>>> pullRules(DateTime? since) {
    return _pull('rules', since);
  }

  // --- Records ---
  @override
  Future<void> pushRecord(Map<String, dynamic> data, String remoteId) {
    return _push('records', remoteId, data);
  }

  @override
  Future<void> deleteRecord(String remoteId) {
    return _delete('records', remoteId);
  }

  @override
  Future<List<Map<String, dynamic>>> pullRecords(DateTime? since) {
    return _pull('records', since);
  }

  // --- Sync meta ---
  @override
  Future<DateTime?> getLastSync() async {
    final result = await _callFunction('sync', {
      'token': _userToken,
      'action': 'pull',
      'collection': 'meta',
    });
    final map = result as Map<String, dynamic>;
    final ts = map['lastSyncTimestamp'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }

  @override
  Future<void> updateLastSync() async {
    await _callFunction('sync', {
      'token': _userToken,
      'action': 'push',
      'collection': 'meta',
      'lastSyncTimestamp': DateTime.now().toIso8601String(),
    });
  }

  // --- Helpers ---

  Future<void> _push(String collection, String remoteId, Map<String, dynamic> data) async {
    await _callFunction('sync', {
      'token': _userToken,
      'action': 'push',
      'collection': collection,
      'data': {'id': remoteId, ...data},
    });
  }

  Future<void> _delete(String collection, String id) async {
    await _callFunction('sync', {
      'token': _userToken,
      'action': 'delete',
      'collection': collection,
      'id': id,
    });
  }

  Future<List<Map<String, dynamic>>> _pull(String collection, DateTime? since) async {
    final args = <String, dynamic>{
      'token': _userToken,
      'action': 'pull',
      'collection': collection,
    };
    if (since != null) {
      args['since'] = since.toIso8601String();
    }
    final result = await _callFunction('sync', args);
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    // 如果返回的是 Map（可能是错误），返回空列表
    return [];
  }
}
