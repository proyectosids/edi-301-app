import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';

class MensajesApi {
  final ApiHttp _http = ApiHttp();

  Future<List<dynamic>> getMensajesFamilia(
    int idFamilia, {
    int limit = 100,
    int? beforeId,
  }) async {
    try {
      final response = await _http.getJson(
        '/api/mensajes/familia/$idFamilia',
        query: {'limit': limit, if (beforeId != null) 'before_id': beforeId},
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(jsonDecode(response.body));
      } else {
        print("Error Chat ${response.statusCode}: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error excepción chat: $e");
      return [];
    }
  }

  Future<int> getUnreadCount(int idFamilia, String desde) async {
    try {
      final response = await _http.getJson(
        '/api/mensajes/familia/$idFamilia/no-leidos',
        query: {'desde': desde},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['total'] ?? 0) as int;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> enviarMensaje(int idFamilia, String mensaje) async {
    try {
      final response = await _http.postJson(
        '/api/mensajes',
        data: {'id_familia': idFamilia, 'mensaje': mensaje},
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print(
          "Error enviando mensaje ${response.statusCode}: ${response.body}",
        );
        return false;
      }
    } catch (e) {
      print("Error excepción enviando: $e");
      return false;
    }
  }
}
