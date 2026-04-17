// lib/services/members_api.dart
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

class MembersApi {
  final ApiHttp _http = ApiHttp();

  Future<void> addMember({
    required int idFamilia,
    required int idUsuario,
    required String tipoMiembro,
  }) async {
    final type = tipoMiembro.trim().toUpperCase();
    const allowed = {'PADRE', 'MADRE', 'HIJO'};
    if (!allowed.contains(type)) {
      throw Exception('Tipo de miembro inválido: "$tipoMiembro".');
    }
    final payload = {
      'id_familia': idFamilia,
      'id_usuario': idUsuario,
      'tipo_miembro': type,
    };
    final res = await _http.postJson('/api/miembros', data: payload);
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }

  Future<void> addMembersBulk({
    required int idFamilia,
    required List<int> idUsuarios,
  }) async {
    final payload = {'id_familia': idFamilia, 'id_usuarios': idUsuarios};
    final res = await _http.postJson('/api/miembros/bulk', data: payload);
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }

  Future<void> removeMember(int idMiembro) async {
    final res = await _http.deleteJson('/api/miembros/$idMiembro');
    if (res.statusCode >= 400) {
      throw Exception(parseHttpError(res));
    }
  }
}
