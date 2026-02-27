import 'dart:convert';
import 'dart:io';

import 'package:edi301/Login/forgot_password/forgot_password_page.dart';
import 'package:edi301/src/pages/Admin/add_tutor/add_tutor_page.dart';
import 'package:edi301/src/pages/Admin/birthdays/birthday_page.dart';
import 'package:edi301/src/pages/Notifications/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:edi301/tools/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_detail_page.dart';
import 'package:edi301/Login/login_page.dart';
import 'package:edi301/Register/register_page.dart';
import 'package:edi301/src/pages/Home/home_page.dart';
import 'package:edi301/src/pages/News/news_page.dart';
import 'package:edi301/src/pages/Family/familiy_page.dart';
import 'package:edi301/src/pages/Search/search_page.dart';
import 'package:edi301/src/pages/Admin/admin_page.dart';
import 'package:edi301/src/pages/Perfil/perfil_page.dart';
import 'package:edi301/src/pages/Family/Edit/edit_page.dart';
import 'package:edi301/src/pages/Admin/add_family/add_family_page.dart';
import 'package:edi301/src/pages/Admin/add_alumns/add_alumns_page.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_page.dart';
import 'package:edi301/src/pages/Admin/family_detail/Family_detail_page.dart';
import 'package:edi301/src/pages/Admin/studient_detail/studient_detail_page.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_page.dart';
import 'package:edi301/src/pages/Admin/agenda/crear_evento_page.dart';
import 'package:edi301/src/pages/Admin/reportes/reportes_page.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/services/users_api.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Notificación en Background recibida: ${message.messageId}");
}

/// Sincroniza token al backend si hay usuario logueado.
/// Guarda el último token enviado para evitar spam de requests.
Future<void> _syncFcmIfLoggedIn() async {
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('user');
  if (userJson == null || userJson.isEmpty) return;

  final user = jsonDecode(userJson) as Map<String, dynamic>;
  final idUsuario = user['id_usuario'] ?? user['IdUsuario'];
  if (idUsuario == null) return;

  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null || fcmToken.isEmpty) return;

  final lastSent = prefs.getString('last_fcm_token_sent');
  if (lastSent == fcmToken) {
    // ya está sincronizado
    return;
  }

  final ok = await UsersApi().updateFcmToken(
    int.parse(idUsuario.toString()),
    fcmToken,
  );
  if (ok) {
    await prefs.setString('last_fcm_token_sent', fcmToken);
    print("✅ FCM token sincronizado en arranque");
  } else {
    print("❌ No se pudo sincronizar FCM token en arranque");
  }
}

/// Escucha refresh de token y lo manda al backend.
Future<void> _listenFcmRefresh() async {
  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('user');
  if (userJson == null || userJson.isEmpty) return;

  final user = jsonDecode(userJson) as Map<String, dynamic>;
  final idUsuario = user['id_usuario'] ?? user['IdUsuario'];
  if (idUsuario == null) return;

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    if (newToken.isEmpty) return;

    final lastSent = prefs.getString('last_fcm_token_sent');
    if (lastSent == newToken) return;

    final ok = await UsersApi().updateFcmToken(
      int.parse(idUsuario.toString()),
      newToken,
    );
    if (ok) {
      await prefs.setString('last_fcm_token_sent', newToken);
      print("✅ FCM token actualizado por refresh");
    } else {
      print("❌ Falló update FCM token por refresh");
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  SocketService().initSocket();

  final notiService = NotificationService();
  await notiService.init();
  await notiService.requestPermissions();

  // Foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Mensaje recibido en foreground: ${message.notification?.title}');

    final notification = message.notification;
    if (notification != null) {
      notiService.showNotification(
        id: notification.hashCode,
        title: notification.title ?? 'Sin título',
        body: notification.body ?? '',
        payload: message.data['tipo'] ?? 'GENERAL',
      );
    }
  });

  // ✅ Importante: sincronizar token si ya está logueado (entra directo a home)
  await _syncFcmIfLoggedIn();
  await _listenFcmRefresh();

  final prefs = await SharedPreferences.getInstance();
  final userJson = prefs.getString('user');

  final String initialRoute = (userJson != null && userJson.isNotEmpty)
      ? 'home'
      : 'login';

  HttpOverrides.global = MyHttpOverrides();

  runApp(MyApp(initialRoute: initialRoute));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EDI 301',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        useMaterial3: false,
      ),
      initialRoute: initialRoute,
      routes: <String, WidgetBuilder>{
        'login': (context) => const LoginPage(),
        'register': (context) => const RegisterPage(),
        'home': (context) => const HomePage(),
        'family': (context) => const FamiliyPage(),
        'edit': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final familyId = args is int ? args : 0;
          return EditPage(familyId: familyId);
        },
        'news': (context) => const NewsPage(),
        'search': (context) => const SearchPage(),
        'admin': (context) => const AdminPage(),
        'perfil': (context) => const PerfilPage(),
        'add_family': (context) => const AddFamilyPage(),
        'add_alumns': (context) => const AddAlumnsPage(),
        'get_family': (context) => const GetFamilyPage(),
        'family_detail': (_) => const FamilyDetailPage(),
        'student_detail': (_) => const StudentDetailPage(),
        'agenda': (context) => const AgendaPage(),
        'crear_evento': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final Map<String, dynamic>? evento = (args is Map<String, dynamic>)
              ? args
              : null;
          return CreateEventPage(eventoExistente: evento);
        },
        'agenda_detail': (context) => const AgendaDetailPage(),
        'reportes': (context) => const ReportesPage(),
        'notifications': (_) => const NotificationsPage(),
        'cumpleaños': (context) => const BirthdaysPage(),
        'add_tutor': (BuildContext context) => const AddTutorPage(),
        'forgot_password': (BuildContext context) => const ForgotPasswordPage(),
      },
    );
  }
}
