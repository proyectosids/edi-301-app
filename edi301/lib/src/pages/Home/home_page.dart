import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/src/pages/Home/home_controller.dart';
import 'package:edi301/src/pages/News/news_page.dart';
import 'package:edi301/src/pages/Family/familiy_page.dart';
import 'package:edi301/src/pages/Search/search_page.dart';
import 'package:edi301/src/pages/Perfil/perfil_page.dart';
import 'package:edi301/src/pages/Admin/admin_page.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_page.dart';
import 'package:edi301/src/pages/Chat/my_chats_page.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();
  int _selectedIndex = 0;
  String _userRole = '';
  List<Map<String, dynamic>> _menuOptions = [];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context);
      _verificarYMostrarEncuesta();
    });
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    String rol = '';
    if (userStr != null) {
      final user = jsonDecode(userStr);
      rol = user['nombre_rol'] ?? user['rol'] ?? '';
    }

    if (mounted) {
      setState(() {
        _userRole = rol;
        _menuOptions = _getMenuOptions(rol);
      });
    }
  }

  Future<void> _verificarYMostrarEncuesta() async {
    final prefs = await SharedPreferences.getInstance();

    final yaMostrada = prefs.getBool('encuesta_mostrada') ?? false;
    if (yaMostrada) return;

    int openCount = prefs.getInt('app_open_count') ?? 0;
    openCount++; // Aumentamos 1 en este inicio

    await prefs.setInt('app_open_count', openCount);

    if (openCount >= 3) {
      if (mounted) {
        _mostrarDialogoEncuesta(context);
      }
    }
  }

  void _mostrarDialogoEncuesta(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.assignment, color: Color.fromRGBO(19, 67, 107, 1)),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  '¡Tu opinión nos importa!',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: const Text(
            'Ayúdanos a mejorar respondiendo esta breve encuesta. No te tomará más de 2 minutos.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('app_open_count', 0);

                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text(
                'Más tarde',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('encuesta_mostrada', true);

                if (context.mounted) Navigator.of(context).pop();

                final Uri url = Uri.parse(
                  'https://docs.google.com/forms/d/e/1FAIpQLSfmPuyryfjKzi372NfoNHPHrwyduHVrILEfvNG8g9JLEVxS5w/viewform?usp=header',
                );

                try {
                  // Mode.externalApplication forzará a abrir Chrome/Safari
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Error al abrir la encuesta: $e');
                }
              },
              child: const Text(
                'Responder',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _getPageFromRoute(String route) {
    switch (route) {
      case 'news':
        return const NewsPage();
      case 'chat':
        return const MyChatsPage();
      case 'family':
        return const FamiliyPage();
      case 'search':
        return const SearchPage();
      case 'agenda':
        return const AgendaPage();
      case 'admin':
        return const AdminPage();
      case 'perfil':
        return const PerfilPage();
      default:
        return const Center(child: Text("Página no encontrada"));
    }
  }

  List<Map<String, dynamic>> _getMenuOptions(String rol) {
    final allOptions = [
      {'ruta': 'news', 'icon': Icons.newspaper, 'label': 'Noticias'},
      {'ruta': 'chat', 'icon': Icons.chat_bubble, 'label': 'Mensajes'},
      {'ruta': 'family', 'icon': Icons.family_restroom, 'label': 'Familia'},
      {'ruta': 'search', 'icon': Icons.person_search, 'label': 'Buscar'},
      {'ruta': 'agenda', 'icon': Icons.calendar_month, 'label': 'Agenda'},
      {'ruta': 'admin', 'icon': Icons.admin_panel_settings, 'label': 'Admin'},
      {'ruta': 'perfil', 'icon': Icons.person, 'label': 'Perfil'},
    ];

    if (rol == 'Admin') {
      return allOptions;
    } else if ([
      'Padre',
      'Madre',
      'Tutor',
      'PapaEDI',
      'MamaEDI',
      'Hijo',
      'HijoEDI',
      'Alumno',
      'Estudiante',
    ].contains(rol)) {
      return allOptions
          .where(
            (op) => ['news', 'chat', 'family', 'perfil'].contains(op['ruta']),
          )
          .toList();
    }

    return [];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_menuOptions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_selectedIndex >= _menuOptions.length) _selectedIndex = 0;

    final currentRoute = _menuOptions[_selectedIndex]['ruta'];
    final currentPage = _getPageFromRoute(currentRoute);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Scaffold(
            body: currentPage,
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
              selectedItemColor: const Color.fromRGBO(245, 188, 6, 1),
              unselectedItemColor: Colors.white,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: _menuOptions.map((op) {
                return BottomNavigationBarItem(
                  icon: Icon(op['icon'] as IconData),
                  label: op['label'] as String,
                );
              }).toList(),
            ),
          );
        } else {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  selectedLabelTextStyle: const TextStyle(
                    color: Color.fromRGBO(245, 188, 6, 1),
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: Colors.white,
                  ),
                  selectedIconTheme: const IconThemeData(
                    color: Color.fromRGBO(245, 188, 6, 1),
                  ),
                  unselectedIconTheme: const IconThemeData(color: Colors.white),
                  destinations: _menuOptions.map((op) {
                    return NavigationRailDestination(
                      icon: Icon(op['icon'] as IconData),
                      label: Text(op['label'] as String),
                    );
                  }).toList(),
                ),
                Expanded(child: currentPage),
              ],
            ),
          );
        }
      },
    );
  }
}
