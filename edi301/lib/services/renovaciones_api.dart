import 'dart:convert';
import '../core/api_client_http.dart';
import '../core/api_error.dart';

/// API para el flujo de renovación de pertenencia a familia por ciclo escolar.
class RenovacionesApi {
  final ApiHttp _http = ApiHttp();

  /// ¿La ventana de renovación está abierta? (cualquier usuario autenticado).
  Future<bool> isVentanaAbierta() async {
    final res = await _http.getJson('/api/renovaciones/estado');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final data = jsonDecode(res.body);
    if (data is Map && data['renovacion_abierta'] != null) {
      return data['renovacion_abierta'] == true;
    }
    return false;
  }

  /// Alumno: solicita renovar su pertenencia a la familia actual.
  Future<int> solicitar() async {
    final res = await _http.postJson('/api/renovaciones/solicitar');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final data = jsonDecode(res.body);
    if (data is Map && data['id_solicitud'] != null) {
      return (data['id_solicitud'] as num).toInt();
    }
    return 0;
  }

  /// Padre/tutor/admin: lista las solicitudes pendientes de una familia.
  Future<List<Map<String, dynamic>>> pendientesFamilia(int idFamilia) async {
    final res =
        await _http.getJson('/api/renovaciones/familia/$idFamilia/pendientes');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// Padre/tutor: lista pendientes de TODAS las familias donde es padre/tutor.
  /// Útil cuando el usuario pertenece a más de una familia.
  Future<List<Map<String, dynamic>>> misPendientes() async {
    final res = await _http.getJson('/api/renovaciones/mis-pendientes');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  /// Padre/tutor: responde una solicitud (aceptar o rechazar).
  Future<void> responder(int idSolicitud, bool aceptar) async {
    final res = await _http.postJson(
      '/api/renovaciones/$idSolicitud/responder',
      data: {'accion': aceptar ? 'aceptar' : 'rechazar'},
    );
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  // ── ADMIN ───────────────────────────────────────────────────────────────

  /// Admin: abre o cierra la ventana de renovación.
  Future<void> setVentana(bool abrir) async {
    final res = await _http.postJson(
      '/api/renovaciones/admin/ventana',
      data: {'abrir': abrir},
    );
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  /// Admin: panel de control con totales y lista de solicitudes.
  Future<Map<String, dynamic>> adminDashboard() async {
    final res = await _http.getJson('/api/renovaciones/admin');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final data = jsonDecode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// Admin: ejecuta el "vaciar familias".
  Future<int> vaciarFamilias() async {
    final res = await _http.postJson('/api/renovaciones/admin/vaciar');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
    final data = jsonDecode(res.body);
    if (data is Map && data['alumnos_removidos'] != null) {
      return (data['alumnos_removidos'] as num).toInt();
    }
    return 0;
  }
}
