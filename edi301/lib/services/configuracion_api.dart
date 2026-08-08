import 'dart:convert';

import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

class ConfiguracionApi {
  final ApiHttp _http = ApiHttp();

  Future<int> getLimiteHijosEdi() async {
    final res = await _http.getJson('/api/configuracion/limite-hijos-edi');
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));

    final decoded = jsonDecode(res.body);
    if (decoded is Map) {
      final limit = int.tryParse('${decoded['limite_hijos_edi']}');
      if (limit != null) return limit;
    }
    throw Exception('Respuesta inválida al consultar la configuración.');
  }

  Future<int> updateLimiteHijosEdi(int limite) async {
    final res = await _http.putJson(
      '/api/configuracion/limite-hijos-edi',
      data: {'limite_hijos_edi': limite},
    );
    if (res.statusCode >= 400) throw Exception(parseHttpError(res));

    final decoded = jsonDecode(res.body);
    if (decoded is Map) {
      final updated = int.tryParse('${decoded['limite_hijos_edi']}');
      if (updated != null) return updated;
    }
    throw Exception('Respuesta inválida al guardar la configuración.');
  }
}
