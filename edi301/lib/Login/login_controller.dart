import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/token_storage.dart';
import '../core/api_client_http.dart';
import '../core/api_error.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:edi301/services/users_api.dart';

class LoginController {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final loading = ValueNotifier<bool>(false);

  final ApiHttp _http = ApiHttp();
  late BuildContext _ctx;

  final TokenStorage _tokenStorage = TokenStorage();
  final UsersApi _usersApi = UsersApi();

  void init(BuildContext context) => _ctx = context;

  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    loading.dispose();
  }

  void goToRegisterPage() {
    Navigator.pushNamed(_ctx, 'register');
  }

  Future<void> goToHomePage() async {
    final login = emailCtrl.text.trim();
    final password = passCtrl.text;

    if (login.isEmpty || password.isEmpty) {
      _snack('Ingresa usuario y contraseña');
      return;
    }

    loading.value = true;

    try {
      final res = await _http.postJson(
        '/api/auth/login',
        data: {'login': login, 'password': password},
      );

      if (res.statusCode == 401 || res.statusCode == 400) {
        throw Exception('Correo o contraseña incorrectos. Verifica tus datos.');
      }
      if (res.statusCode == 403) {
        throw Exception('Tu cuenta está desactivada. Contacta al administrador.');
      }
      if (res.statusCode == 404) {
        throw Exception('No existe una cuenta registrada con ese correo.');
      }
      if (res.statusCode >= 400) {
        throw Exception(parseHttpError(res));
      }

      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;

      final token = (data['session_token'] ?? data['token'] ?? '').toString();
      if (token.isEmpty) throw Exception('No se recibió session_token');

      await _tokenStorage.save(token);

      // Cargar datos extra (familia) si aplica
      final idUsuario = data['id_usuario'] ?? data['IdUsuario'];
      if (idUsuario != null) {
        try {
          final familiaRes = await _http.getJson('/api/usuarios/$idUsuario');
          if (familiaRes.statusCode == 200) {
            final usuarioCompleto =
                jsonDecode(familiaRes.body) as Map<String, dynamic>;
            final idFamilia =
                usuarioCompleto['id_familia'] ?? usuarioCompleto['FamiliaID'];
            if (idFamilia != null) {
              data['id_familia'] = idFamilia;
            }
          }
        } catch (e) {
          print('Error consultando usuario completo: $e');
        }
      }

      // Guardar sesión local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', token);
      await prefs.setString('user', jsonEncode(data));

      // ✅ Registrar token FCM siempre en cada login
      // (no usamos lastSent aquí para garantizar que el backend siempre tenga el token vigente,
      //  especialmente si la DB fue limpiada o el token expiró)
      if (idUsuario != null) {
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            print("🔥 Registrando FCM Token en login: $fcmToken");
            final ok = await _usersApi.updateFcmToken(
              int.parse(idUsuario.toString()),
              fcmToken,
            );
            print("✅ ¿Registro exitoso en servidor?: $ok");
            if (ok) {
              await prefs.setString('last_fcm_token_sent', fcmToken);
            }
          }
        } catch (e) {
          print("No se pudo registrar el token FCM: $e");
        }
      }

      final rol = (data['rol'] ?? data['role'] ?? '').toString();
      final tipoUsuario = (data['TipoUsuario'] ?? data['tipoUsuario'] ?? '')
          .toString();
      final route = _routeForRole(rol, tipoUsuario);

      if (!_ctx.mounted) return;
      FocusScope.of(_ctx).unfocus();
      Navigator.of(_ctx).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      loading.value = false;
    }
  }

  String _routeForRole(String rol, String tipoUsuario) {
    switch (rol) {
      case 'Admin':
      case 'PapaEDI':
      case 'MamaEDI':
      case 'HijoEDI':
      case 'HijoSanguineo':
        return 'home';
      default:
        return 'home';
    }
  }

  void _snack(String msg) {
    if (!_ctx.mounted) return;
    ScaffoldMessenger.of(_ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}
