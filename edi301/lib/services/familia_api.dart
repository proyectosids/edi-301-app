// lib/services/familia_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';
import 'package:edi301/models/family_model.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class FamiliaApi {
  final ApiHttp _http = ApiHttp();
  final String _baseUrl = ApiHttp.baseUrl;
  static List<dynamic>? _availableCache;
  static String? _availableEtag;

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
    List<int>? tios,
  }) async {
    final payload = <String, dynamic>{
      'nombre_familia': nombreFamilia,
      'residencia': _normalizeResidence(residencia),
      if (direccion != null && direccion.trim().isNotEmpty)
        'direccion': direccion.trim(),
      if (papaId != null) 'papa_id': papaId,
      if (mamaId != null) 'mama_id': mamaId,
      if (hijos != null && hijos.isNotEmpty) 'hijos': hijos,
      if (tios != null && tios.isNotEmpty) 'tios': tios,
    };

    final res = await _http.postJson('/api/familias', data: payload);
    debugPrint('POST /api/familias -> ${res.statusCode} :: ${res.body}');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      final Map<String, dynamic> m = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;
      return Family.fromJson(m);
    }
    throw Exception('Respuesta inválida del servidor al crear familia.');
  }

  Future<List<Map<String, dynamic>>> buscarFamiliasPorNombre(String q) async {
    final res = await _http.getJson('/api/familias/search', query: {'name': q});
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
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
          throw Exception(parseHttpError(res));
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
        throw Exception(parseStreamError(response.statusCode, responseBody));
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
      throw Exception(parseHttpError(res));
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
      throw Exception(parseStreamError(response.statusCode, responseBody));
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
        throw Exception(parseStreamError(response.statusCode, responseBody));
      }
    } catch (e) {
      print('Error al actualizar descripción: $e');
      rethrow;
    }
  }

  Future<List<dynamic>?> getAvailable() async {
    try {
      final res = await _http.getJson(
        '/api/familias/available',
        headers: {if (_availableEtag != null) 'If-None-Match': _availableEtag!},
      );
      if (res.statusCode == 304 && _availableCache != null) {
        return List<dynamic>.from(_availableCache!);
      }
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? List<dynamic>.from(decoded)
            : decoded is Map && decoded['data'] is List
            ? List<dynamic>.from(decoded['data'])
            : <dynamic>[];
        _availableCache = list;
        _availableEtag = res.headers['etag'];
        return List<dynamic>.from(list);
      }
      if (_availableCache != null) return List<dynamic>.from(_availableCache!);
      throw Exception(parseHttpError(res));
    } catch (_) {
      if (_availableCache != null) return List<dynamic>.from(_availableCache!);
      rethrow;
    }
  }

  /// Lista familias desactivadas (activo = 0)
  Future<List<dynamic>> getInactive() async {
    final res = await _http.getJson('/api/familias/inactivas');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['data'] is List)
      return decoded['data'] as List;
    return [];
  }

  /// Reactiva una familia desactivada
  Future<void> reactivateFamily(int id) async {
    final res = await _http.patchJson('/api/familias/$id/reactivar');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  /// Desactiva (soft-delete) una familia
  Future<void> deactivateFamily(int id) async {
    final res = await _http.deleteJson('/api/familias/$id');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  // ── Hijos del hogar sin cuenta ─────────────────────────────────────────────

  /// Crea un hijo del hogar (sin cuenta) para la familia dada.
  /// [fechaNacimiento] en formato "yyyy-MM-dd".
  Future<HogarChild> createHogarChild({
    required int idFamilia,
    required String nombre,
    required String apellido,
    String? fechaNacimiento,
  }) async {
    final payload = <String, dynamic>{
      'id_familia': idFamilia,
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      if (fechaNacimiento != null && fechaNacimiento.isNotEmpty)
        'fecha_nacimiento': fechaNacimiento,
    };
    final res = await _http.postJson('/api/hijos-hogar', data: payload);
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final decoded = jsonDecode(res.body);
    final data = decoded is Map && decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'])
        : Map<String, dynamic>.from(decoded as Map);
    return HogarChild.fromJson(data);
  }

  /// Elimina (soft-delete) un hijo del hogar.
  Future<void> deleteHogarChild(int idHijo) async {
    final res = await _http.deleteJson('/api/hijos-hogar/$idHijo');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  // ── Familia permanente ──────────────────────────────────────────────────────

  /// Elimina permanentemente una familia y todos sus miembros
  Future<void> permanentDeleteFamily(int id) async {
    final res = await _http.deleteJson('/api/familias/$id/permanent');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  // ── Familia manual ────────────────────────────────────────────────────────
  /// Crea una familia sin que los padres estén registrados (los nombres se
  /// guardan en columnas pendientes). Devuelve la familia creada.
  /// Debe enviarse al menos uno: papá o mamá.
  Future<Map<String, dynamic>> createFamilyManual({
    String? papaNombre,
    String? papaApellido,
    String? mamaNombre,
    String? mamaApellido,
    required String residencia,
    String? direccion,
    String? descripcion,
    String? nombreFamilia,
  }) async {
    final payload = <String, dynamic>{
      'residencia': _normalizeResidence(residencia),
      if (papaNombre != null && papaNombre.trim().isNotEmpty)
        'papa_nombre': papaNombre.trim(),
      if (papaApellido != null && papaApellido.trim().isNotEmpty)
        'papa_apellido': papaApellido.trim(),
      if (mamaNombre != null && mamaNombre.trim().isNotEmpty)
        'mama_nombre': mamaNombre.trim(),
      if (mamaApellido != null && mamaApellido.trim().isNotEmpty)
        'mama_apellido': mamaApellido.trim(),
      if (direccion != null && direccion.trim().isNotEmpty)
        'direccion': direccion.trim(),
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
      if (nombreFamilia != null && nombreFamilia.trim().isNotEmpty)
        'nombre_familia': nombreFamilia.trim(),
    };
    final res = await _http.postJson('/api/familias/manual', data: payload);
    debugPrint('POST /api/familias/manual -> ${res.statusCode} :: ${res.body}');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;
    }
    throw Exception('Respuesta inválida del servidor al crear familia manual.');
  }

  /// Devuelve las familias activas con slot PAPA/MAMA pendiente que matcheen
  /// el nombre+apellido del usuario indicado.
  Future<List<Map<String, dynamic>>> getCandidatesForUser(int idUsuario) async {
    final res = await _http.getJson('/api/familias/candidatos/$idUsuario');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final decoded = jsonDecode(res.body);
    final list = decoded is Map && decoded['data'] is List
        ? decoded['data'] as List
        : (decoded is List ? decoded : <dynamic>[]);
    return list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Vincula un usuario al slot PAPA o MAMA de una familia pendiente.
  /// [rol] debe ser 'PAPA' o 'MAMA'.
  Future<Map<String, dynamic>> linkUserToFamily({
    required int idFamilia,
    required int idUsuario,
    required String rol,
  }) async {
    final res = await _http.postJson(
      '/api/familias/$idFamilia/vincular',
      data: {'id_usuario': idUsuario, 'rol': rol},
    );
    debugPrint(
      'POST /api/familias/$idFamilia/vincular -> ${res.statusCode} :: ${res.body}',
    );
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;
    }
    throw Exception('Respuesta inválida del servidor al vincular usuario.');
  }

  /// Lista todas las familias con padres pendientes de vincular (panel admin).
  Future<List<Map<String, dynamic>>> getFamiliasPendientes() async {
    final res = await _http.getJson('/api/familias/pendientes');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final decoded = jsonDecode(res.body);
    final list = decoded is Map && decoded['data'] is List
        ? decoded['data'] as List
        : (decoded is List ? decoded : <dynamic>[]);
    return list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Edita campos de una familia (padre, madre, nombre, residencia, hijos)
  Future<Map<String, dynamic>?> updateFamily({
    required int id,
    String? nombreFamilia,
    String? residencia,
    String? direccion,
    int? papaId,
    int? mamaId,
  }) async {
    final payload = <String, dynamic>{
      if (nombreFamilia != null) 'nombre_familia': nombreFamilia,
      if (residencia != null) 'residencia': _normalizeResidence(residencia),
      if (direccion != null) 'direccion': direccion,
      if (papaId != null) 'papa_id': papaId,
      if (mamaId != null) 'mama_id': mamaId,
    };
    final res = await _http.putJson('/api/familias/$id', data: payload);
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;
    }
    return null;
  }
}
