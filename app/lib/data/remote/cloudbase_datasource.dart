import 'dart:convert';
import 'package:http/http.dart' as http;
import 'remote_datasource.dart';

/// 通过微信云开发云函数 HTTP API 实现的远程数据源
/// API 规范见 shared/data-schema.md
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
    return _upsert('children', remoteId, data);
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
    return _upsert('rules', remoteId, data);
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
    return _upsert('records', remoteId, data);
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
    final uri = Uri.parse('$_apiBase/sync').replace(
      queryParameters: {'collection': 'meta'},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ts = data['lastSyncTimestamp'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }

  @override
  Future<void> updateLastSync() async {
    final response = await http.post(
      Uri.parse('$_apiBase/sync'),
      headers: _headers,
      body: jsonEncode({
        'collection': 'meta',
        'lastSyncTimestamp': DateTime.now().toIso8601String(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
  }

  // --- Helpers ---

  /// POST /sync {collection, action: "upsert", data: {id, ...fields}}
  Future<void> _upsert(String collection, String remoteId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_apiBase/sync'),
      headers: _headers,
      body: jsonEncode({
        'collection': collection,
        'action': 'upsert',
        'data': {'id': remoteId, ...data},
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
  }

  /// DELETE /sync?collection=xxx&id=yyy
  Future<void> _delete(String collection, String id) async {
    final uri = Uri.parse('$_apiBase/sync').replace(
      queryParameters: {'collection': collection, 'id': id},
    );
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
  }

  /// GET /sync?collection=xxx&since=yyy
  Future<List<Map<String, dynamic>>> _pull(String collection, DateTime? since) async {
    final params = <String, String>{'collection': collection};
    if (since != null) {
      params['since'] = since.toIso8601String();
    }
    final uri = Uri.parse('$_apiBase/sync').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list.cast<Map<String, dynamic>>();
  }
}
