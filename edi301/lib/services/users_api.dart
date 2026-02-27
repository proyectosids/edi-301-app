import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client_http.dart';
import '../models/user.dart';
import 'package:edi301/models/family_model.dart' as fm;

class UsersApi {
  final ApiHttp _http = ApiHttp();

  Future<List<User>> getCumpleanerosHoy() async {
    try {
      final res = await _http.getJson('/api/usuarios/cumpleanos');

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);

        return data.map((x) => User.fromJson(x)).toList();
      }
    } catch (e) {
      print('Error obteniendo cumpleaños: $e');
    }
    return [];
  }

  Future<bool> updateFcmToken(int idUsuario, String fcmToken) async {
    try {
      final response = await _http.putJson(
        '/api/usuarios/update-token',
        data: {'id_usuario': idUsuario, 'fcm_token': fcmToken},
      );

      if (response.statusCode != 200) {
        print(
          "❌ Error del servidor: ${response.statusCode} - ${response.body}",
        );
      }
      return response.statusCode == 200;
    } catch (e) {
      print("Error actualizando FCM Token: $e");
      return false;
    }
  }

  Future<void> deleteSoft(int id) async {
    final res = await _http.deleteJson('/api/usuarios/$id');
    if (res.statusCode >= 400) {
      throw Exception('No se pudo eliminar: ${res.statusCode} ${res.body}');
    }
  }

  Future<List<fm.Family>> familiasByDocumento({
    int? matricula,
    int? numEmpleado,
  }) async {
    final res = await _http.getJson(
      '/api/usuarios/familias/by-doc/search',
      query: {
        if (matricula != null) 'matricula': matricula,
        if (numEmpleado != null) 'numEmpleado': numEmpleado,
      },
    );

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map((e) => fm.Family.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map && data.values.length == 1 && data.values.first is List) {
      return (data.values.first as List)
          .map((e) => fm.Family.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return <fm.Family>[];
  }

  Future<User> registerAlumno({
    required int matricula,
    required String nombre,
    required String apellido,
    required String email,
    required String contrasena,
    String? estado,
  }) async {
    final payload = {
      "TipoUsuario": "ALUMNO",
      "Matricula": matricula,
      "Nombre": nombre,
      "Apellido": apellido,
      "E_mail": email,
      "Contrasena": contrasena,
      "Estado": estado,
    };
    final res = await _http.postJson('/api/usuarios/register', data: payload);
    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }
    final id = (jsonDecode(res.body) as Map)['IdUsuario'] as int;
    return getById(id);
  }

  Future<User> registerEmpleado({
    required int numEmpleado,
    required String nombre,
    required String apellido,
    required String email,
    required String contrasena,
    String? estado,
  }) async {
    final payload = {
      "TipoUsuario": "EMPLEADO",
      "NumEmpleado": numEmpleado,
      "Nombre": nombre,
      "Apellido": apellido,
      "E_mail": email,
      "Contrasena": contrasena,
      "Estado": estado,
    };
    final r = await _http.postJson('/api/usuarios/register', data: payload);
    if (r.statusCode >= 400) {
      throw Exception('Error ${r.statusCode}: ${r.body}');
    }
    final id = (jsonDecode(r.body) as Map)['IdUsuario'] as int;
    return getById(id);
  }

  Future<User> registerExterno({
    required String nombre,
    required String apellido,
    required String email,
    required String contrasena,
    required int idRol,
  }) async {
    final payload = {
      "nombre": nombre,
      "apellido": apellido,
      "correo": email,
      "contrasena": contrasena,
      "tipo_usuario": "EXTERNO",
      "id_rol": idRol,
      "matricula": null,
      "num_empleado": null,
    };

    final res = await _http.postJson('/api/usuarios', data: payload);

    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final id = data['id_usuario'] ?? data['IdUsuario'] as int;

    return getById(id);
  }

  Future<User> login(String email, String password) async {
    final r = await _http.postJson(
      '/api/usuarios/login',
      data: {"E_mail": email, "Contrasena": password},
    );
    if (r.statusCode >= 400) {
      throw Exception('Error ${r.statusCode}: ${r.body}');
    }
    final Map<String, dynamic> data =
        jsonDecode(r.body) as Map<String, dynamic>;

    final user = User.fromJson(data);

    final token = (data['session_token'] ?? data['token'] ?? '').toString();
    if (token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', token);
      await prefs.setString('user', jsonEncode(data));
    }
    return user;
  }

  Future<User> getById(int id) async {
    final r = await _http.getJson('/api/usuarios/$id');
    if (r.statusCode >= 400) {
      throw Exception('Error ${r.statusCode}: ${r.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(r.body) as Map<String, dynamic>;

    return User.fromJson(data);
  }

  Future<List<fm.Family>> getAvailableFamilies() async {
    final res = await _http.getJson('/api/familias/available');
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((f) => fm.Family.fromJson(f)).toList();
    }
    return [];
  }

  Future<List<User>> search({String? q, String? tipo}) async {
    final r = await _http.getJson(
      '/api/usuarios',
      query: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (tipo != null && tipo.isNotEmpty) 'tipo': tipo,
      },
    );
    if (r.statusCode >= 400) {
      throw Exception('Error ${r.statusCode}: ${r.body}');
    }
    final decoded = jsonDecode(r.body);
    if (decoded is List) {
      return decoded
          .map<User>((e) => User.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (decoded is Map &&
        decoded.values.length == 1 &&
        decoded.values.first is List) {
      final list = decoded.values.first as List;
      return list
          .map<User>((e) => User.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return <User>[];
  }

  Future<User> update(
    int id, {
    String? nombre,
    String? apellido,
    String? estado,
    bool? esActivo,
    bool? esAdmin,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      if (nombre != null) "Nombre": nombre,
      if (apellido != null) "Apellido": apellido,
      if (estado != null) "Estado": estado,
      if (esActivo != null) "es_Activo": esActivo,
      if (esAdmin != null) "es_Admin": esAdmin,
    };

    final r = await _http.patchJson('/api/usuarios/$id', data: payload);
    if (r.statusCode >= 400) {
      throw Exception('Error ${r.statusCode}: ${r.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(r.body) as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<bool> resetPassword(String email, String newPassword) async {
    try {
      final res = await _http.postJson(
        '/api/auth/reset-password',
        data: {'correo': email, 'nuevaContrasena': newPassword},
      );
      return res.statusCode == 200;
    } catch (e) {
      print('Error en resetPassword: $e');
      return false;
    }
  }
}
