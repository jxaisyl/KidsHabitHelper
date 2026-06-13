import 'dart:convert';
import 'package:http/http.dart' as http;
import 'remote_datasource.dart';

/// 通过微信云开发云函数 HTTP API 实现的远程数据源
class CloudBaseDatasource implements RemoteDatasource {
  final String _apiBase;
  final String _token;

  CloudBaseDatasource(this._apiBase, this._token);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  // --- Children ---
  @override
  Future<void> pushChild(Map<String, dynamic> data, String remoteId) {
    return _post('/sync/children', {'id': remoteId, ...data});
  }

  @override
  Future<void> deleteChild(String remoteId) {
    return _delete('/sync/children/$remoteId');
  }

  @override
  Future<List<Map<String, dynamic>>> pullChildren(DateTime? since) {
    return _pull('/sync/children', since);
  }

  // --- Rules ---
  @override
  Future<void> pushRule(Map<String, dynamic> data, String remoteId) {
    return _post('/sync/rules', {'id': remoteId, ...data});
  }

  @override
  Future<void> deleteRule(String remoteId) {
    return _delete('/sync/rules/$remoteId');
  }

  @override
  Future<List<Map<String, dynamic>>> pullRules(DateTime? since) {
    return _pull('/sync/rules', since);
  }

  // --- Records ---
  @override
  Future<void> pushRecord(Map<String, dynamic> data, String remoteId) {
    return _post('/sync/records', {'id': remoteId, ...data});
  }

  @override
  Future<void> deleteRecord(String remoteId) {
    return _delete('/sync/records/$remoteId');
  }

  @override
  Future<List<Map<String, dynamic>>> pullRecords(DateTime? since) {
    return _pull('/sync/records', since);
  }

  // --- Sync meta ---
  @override
  Future<DateTime?> getLastSync() async {
    final response = await http.get(
      Uri.parse('$_apiBase/sync/meta'),
      headers: _headers,
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ts = data['lastSyncTimestamp'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }

  @override
  Future<void> updateLastSync() {
    return _post('/sync/meta', {
      'lastSyncTimestamp': DateTime.now().toIso8601String(),
    });
  }

  // --- Helpers ---
  Future<void> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$_apiBase$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
  }

  Future<void> _delete(String path) async {
    final response = await http.delete(
      Uri.parse('$_apiBase$path'),
      headers: _headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> _pull(String path, DateTime? since) async {
    final uri = Uri.parse('$_apiBase$path').replace(
      queryParameters: since != null ? {'since': since.toIso8601String()} : null,
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list.cast<Map<String, dynamic>>();
  }
}
