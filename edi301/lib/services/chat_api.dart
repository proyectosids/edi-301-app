import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';

class ChatApi {
  final ApiHttp _http = ApiHttp();

  Future<List<dynamic>> getMyChats() async {
    final res = await _http.getJson('/api/chat');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  Future<List<dynamic>> getMessages(
    int idSala, {
    int limit = 100,
    int? beforeId,
  }) async {
    final res = await _http.getJson(
      '/api/chat/$idSala/messages',
      query: {'limit': limit, if (beforeId != null) 'before_id': beforeId},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  Future<bool> sendMessage(int idSala, String mensaje) async {
    final res = await _http.postJson(
      '/api/chat/message',
      data: {'id_sala': idSala, 'mensaje': mensaje},
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<int?> initPrivateChat(int targetUserId) async {
    final res = await _http.postJson(
      '/api/chat/private',
      data: {'targetUserId': targetUserId},
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body);
      return body['id_sala'];
    }
    return null;
  }

  /// Marca todos los mensajes de una sala como leídos para el usuario actual.
  Future<void> markAsRead(int idSala) async {
    try {
      await _http.patchJson('/api/chat/$idSala/leer');
    } catch (_) {}
  }

  /// Devuelve la lista de usuarios con rol Admin.
  Future<List<dynamic>> getAdmins() async {
    try {
      final res = await _http.getJson('/api/usuarios/admins');
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  /// Devuelve el total de mensajes no leídos en todos los chats del usuario.
  Future<int> totalUnread() async {
    try {
      final res = await _http.getJson('/api/chat/unread-total');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded is Map && decoded['data'] != null
            ? decoded['data']
            : decoded;
        return (data['total'] ?? 0) as int;
      }
    } catch (_) {}
    return 0;
  }
}
