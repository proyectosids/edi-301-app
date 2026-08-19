import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

class EncuestasApi {
  final _http = ApiHttp();
  Future<List<dynamic>> list() async {
    final r = await _http.getJson('/api/encuestas');
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
    return jsonDecode(r.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> get(int id) async {
    final r = await _http.getJson('/api/encuestas/$id');
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<void> submit(int id, List<Map<String, dynamic>> answers) async {
    final r = await _http.postJson(
      '/api/encuestas/$id/respuestas',
      data: {'respuestas': answers},
    );
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
  }

  Future<void> create(Map<String, dynamic> data) async {
    final r = await _http.postJson('/api/encuestas', data: data);
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    final r = await _http.putJson('/api/encuestas/$id', data: data);
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
  }

  Future<void> close(int id) async {
    final r = await _http.patchJson('/api/encuestas/$id/cerrar');
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
  }

  Future<Map<String, dynamic>> results(int id) async {
    final r = await _http.getJson('/api/encuestas/$id/resultados');
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }
}
