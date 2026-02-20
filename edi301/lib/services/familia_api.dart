// lib/services/familia_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/models/family_model.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class FamiliaApi {
  final ApiHttp _http = ApiHttp();
  final String _baseUrl = ApiHttp.baseUrl;

  String _normalizeResidence(String r) {
    final s = r.trim().toUpperCase();
    if (s.startsWith('INT')) return 'INTERNA';
    if (s.startsWith('EXT')) return 'EXTERNA';
    return 'INTERNA';
  }

  Future<Family> createFamily({
    required String nombreFamilia,
    required String residencia,
    String? direccion,
    int? papaId,
    int? mamaId,
    List<int>? hijos,
  }) async {
    final payload = <String, dynamic>{
      'nombre_familia': nombreFamilia,
      'residencia': _normalizeResidence(residencia),
      if (direccion != null && direccion.trim().isNotEmpty)
        'direccion': direccion.trim(),
      if (papaId != null) 'papa_id': papaId,
      if (mamaId != null) 'mama_id': mamaId,
      if (hijos != null && hijos.isNotEmpty) 'hijos': hijos,
    };

    final res = await _http.postJson('/api/familias', data: payload);
    debugPrint('POST /api/familias -> ${res.statusCode} :: ${res.body}');
    if (res.statusCode >= 400) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded.containsKey('error')) {
          throw Exception(decoded['error']);
        }
      } catch (_) {}
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      final Map<String, dynamic> m = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;
      return Family.fromJson(m);
    }
    throw Exception('Respuesta inválida del servidor al crear familia');
  }

  Future<List<Map<String, dynamic>>> buscarFamiliasPorNombre(String q) async {
    final res = await _http.getJson('/api/familias/search', query: {'name': q});
    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (data is Map && data.values.isNotEmpty && data.values.first is List) {
      final list = data.values.first as List;
      return list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> getById(int id, {String? authToken}) async {
    try {
      if (authToken == null) {
        final res = await _http.getJson('/api/familias/$id');
        if (res.statusCode >= 400) {
          throw Exception('Error ${res.statusCode}: ${res.body}');
        }
        final data = jsonDecode(res.body);
        if (data is Map) return Map<String, dynamic>.from(data);
        return null;
      }

      final Uri url = Uri.parse('$_baseUrl/api/familias/$id');
      final request = http.Request('GET', url);

      request.headers['Authorization'] = 'Bearer $authToken';
      request.headers['Content-Type'] = 'application/json';

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 400) {
        throw Exception('Error ${response.statusCode}: $responseBody');
      }

      final data = jsonDecode(responseBody);
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (e) {
      print('Error en getById: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getByIdent(int ident) async {
    final res = await _http.getJson('/api/familias/por-ident/$ident');
    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<bool> updateFamilyFotos({
    required int familyId,
    File? profileImage,
    File? coverImage,
    String? authToken,
  }) async {
    if (profileImage == null && coverImage == null) {
      return false;
    }

    final Uri url = Uri.parse('$_baseUrl/api/familias/$familyId/fotos');
    final request = http.MultipartRequest('PATCH', url);
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }
    if (profileImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto_perfil', profileImage.path),
      );
    }

    if (coverImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto_portada', coverImage.path),
      );
    }

    final response = await request.send();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    } else {
      final responseBody = await response.stream.bytesToString();
      throw Exception('Error ${response.statusCode}: $responseBody');
    }
  }

  Future<bool> updateDescripcion({
    required int familyId,
    required String descripcion,
    String? authToken,
  }) async {
    try {
      final Uri url = Uri.parse('$_baseUrl/api/familias/$familyId/descripcion');
      final request = http.Request('PATCH', url);
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'descripcion': descripcion});

      final response = await request.send();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final responseBody = await response.stream.bytesToString();
        throw Exception('Error ${response.statusCode}: $responseBody');
      }
    } catch (e) {
      print('Error al actualizar descripción: $e');
      rethrow;
    }
  }

  Future<List<dynamic>?> getAvailable() async {
    final res = await _http.getJson('/api/familias/available');
    print('DEBUG BODY: ${res.body}');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
    }
    return [];
  }
}
