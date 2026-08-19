// lib/services/notificaciones_api.dart
import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

class NotificacionItem {
  final int id;
  final String titulo;
  final String cuerpo;
  final String tipo;
  final int? idReferencia;
  final bool leido;
  final DateTime fechaCreacion;

  NotificacionItem({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    required this.tipo,
    this.idReferencia,
    required this.leido,
    required this.fechaCreacion,
  });

  factory NotificacionItem.fromJson(Map<String, dynamic> j) {
    return NotificacionItem(
      id: j['id'] ?? 0,
      titulo: j['titulo'] ?? '',
      cuerpo: j['cuerpo'] ?? '',
      tipo: j['tipo'] ?? 'GENERAL',
      idReferencia: j['id_referencia'] as int?,
      leido: (j['leido'] == true || j['leido'] == 1),
      fechaCreacion: j['fecha_creacion'] != null
          ? DateTime.tryParse(j['fecha_creacion'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotificacionItem copyWith({bool? leido}) {
    return NotificacionItem(
      id: id,
      titulo: titulo,
      cuerpo: cuerpo,
      tipo: tipo,
      idReferencia: idReferencia,
      leido: leido ?? this.leido,
      fechaCreacion: fechaCreacion,
    );
  }
}

class NotificacionesApi {
  final ApiHttp _http = ApiHttp();

  /// Lista todas las notificaciones del usuario autenticado.
  Future<List<NotificacionItem>> list({int page = 1, int limit = 100}) async {
    final res = await _http.getJson(
      '/api/notificaciones',
      query: {'page': page, 'limit': limit},
    );
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));

    final decoded = jsonDecode(res.body);
    final List<dynamic> raw = decoded is List
        ? decoded
        : (decoded is Map && decoded['data'] is List ? decoded['data'] : []);

    return raw
        .map(
          (j) => NotificacionItem.fromJson(Map<String, dynamic>.from(j as Map)),
        )
        .toList();
  }

  /// Devuelve la cantidad de notificaciones no leídas.
  Future<int> unreadCount() async {
    final res = await _http.getJson('/api/notificaciones/no-leidas');
    if (res.statusCode >= 400) return 0;
    final decoded = jsonDecode(res.body);
    final data = decoded is Map && decoded['data'] != null
        ? decoded['data']
        : decoded;
    return (data['total'] ?? 0) as int;
  }

  /// Marca una notificación como leída.
  Future<void> markRead(int id) async {
    final res = await _http.patchJson('/api/notificaciones/$id/leer');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  /// Marca todas las notificaciones del usuario como leídas.
  Future<void> markAllRead() async {
    final res = await _http.patchJson('/api/notificaciones/leer-todas');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  /// Elimina una notificación por ID.
  Future<void> remove(int id) async {
    final res = await _http.deleteJson('/api/notificaciones/$id');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }

  /// Elimina todas las notificaciones del usuario.
  Future<void> removeAll() async {
    final res = await _http.deleteJson('/api/notificaciones/todas');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));
  }
}
