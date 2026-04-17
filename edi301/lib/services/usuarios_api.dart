// lib/services/usuarios_api.dart
import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

class UsuariosApi {
  final ApiHttp _http = ApiHttp();

  /// Busca usuarios activos por nombre, matrícula o num_empleado
  Future<List<Map<String, dynamic>>> buscarPorIdent(String q) async {
    if (q.trim().isEmpty) return [];
    final res = await _http.getJson(
      '/api/usuarios/buscar-por-ident',
      query: {'q': q.trim()},
    );
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Lista todos los usuarios con rol Admin
  Future<List<Map<String, dynamic>>> listAdmins() async {
    final res = await _http.getJson('/api/usuarios/admins');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    final data = jsonDecode(res.body);
    final list = data is List
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Lista todos los roles disponibles
  Future<List<Map<String, dynamic>>> listRoles() async {
    final res = await _http.getJson('/api/usuarios/roles');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    final data = jsonDecode(res.body);
    final list = data is List
        ? data
        : (data is Map && data['data'] is List ? data['data'] as List : []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Cambia el rol de un usuario (id_rol = 1 por defecto → Admin)
  Future<Map<String, dynamic>> cambiarRol(int idUsuario, {int idRol = 1}) async {
    final res = await _http.patchJson(
      '/api/usuarios/cambiar-rol',
      data: {'id_usuario': idUsuario, 'id_rol': idRol},
    );
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;
    }
    throw Exception('Respuesta inválida del servidor');
  }
}
