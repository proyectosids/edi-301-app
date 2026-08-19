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
import 'package:edi301/src/pages/Family/chat_family_page.dart';
import 'package:edi301/src/pages/Encuestas/encuestas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();
  final PageController _pageCtrl = PageController();

  int _selectedIndex = 0;
  String _userRole = '';
  List<Map<String, dynamic>> _menuOptions = [];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
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

  /* Future<void> _verificarYMostrarEncuesta() async {
    final prefs = await SharedPreferences.getInstance();
    final yaMostrada = prefs.getBool('encuesta_mostrada') ?? false;
    if (yaMostrada) return;
    int openCount = prefs.getInt('app_open_count') ?? 0;
    openCount++;
    await prefs.setInt('app_open_count', openCount);
    if (openCount >= 2 && mounted) _mostrarDialogoEncuesta(context);
  } */

  /* void _mostrarDialogoEncuesta(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              if (ctx.mounted) Navigator.of(ctx).pop();
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
              if (ctx.mounted) Navigator.of(ctx).pop();
              final uri = Uri.parse(
                'https://docs.google.com/forms/d/e/1FAIpQLSfmPuyryfjKzi372NfoNHPHrwyduHVrILEfvNG8g9JLEVxS5w/viewform?usp=sharing&ouid=101381466647283644158',
              );
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      ),
    );
  } */

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
      case 'encuestas':
        return const EncuestasPage();
      default:
        return const Center(child: Text('Página no encontrada'));
    }
  }

  List<Map<String, dynamic>> _getMenuOptions(String rol) {
    final all = [
      {'ruta': 'news', 'icon': Icons.newspaper, 'label': 'Noticias'},
      {'ruta': 'chat', 'icon': Icons.chat_bubble, 'label': 'Mensajes'},
      {'ruta': 'family', 'icon': Icons.family_restroom, 'label': 'Familia'},
      {'ruta': 'search', 'icon': Icons.person_search, 'label': 'Buscar'},
      {'ruta': 'agenda', 'icon': Icons.calendar_month, 'label': 'Agenda'},
      {'ruta': 'encuestas', 'icon': Icons.poll, 'label': 'Encuestas'},
      {'ruta': 'admin', 'icon': Icons.admin_panel_settings, 'label': 'Admin'},
      {'ruta': 'perfil', 'icon': Icons.person, 'label': 'Perfil'},
    ];

    if (rol == 'Admin') return all;

    if ([
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
      return all
          .where(
            (op) => ['news', 'chat', 'family', 'perfil'].contains(op['ruta']),
          )
          .toList();
    }

    return [];
  }

  // ── Navigation: keeps PageView and BottomNav in sync ─────────────────────
  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Ícono con punto dorado si hay mensajes no leídos (chat privado o familiar).
  Widget _buildNavIcon(
    String ruta,
    IconData icon,
    int unreadChats,
    int unreadFamily,
  ) {
    final hasUnread =
        (ruta == 'chat' && unreadChats > 0) ||
        (ruta == 'family' && unreadFamily > 0);
    if (!hasUnread) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(245, 188, 6, 1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color.fromRGBO(19, 67, 107, 1),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_menuOptions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_selectedIndex >= _menuOptions.length) _selectedIndex = 0;

    return ValueListenableBuilder<int>(
      valueListenable: MyChatsPage.totalUnread,
      builder: (context, unreadChats, _) {
        return ValueListenableBuilder<int>(
          valueListenable: ChatFamilyPage.familyUnread,
          builder: (context, unreadFamily, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                // ── Mobile: PageView + BottomNavigationBar ────────────────
                if (constraints.maxWidth < 640) {
                  return Scaffold(
                    body: SafeArea(
                      child: PageView(
                        controller: _pageCtrl,
                        onPageChanged: _onPageChanged,
                        children: _menuOptions
                            .map(
                              (op) => _getPageFromRoute(op['ruta'] as String),
                            )
                            .toList(),
                      ),
                    ),
                    bottomNavigationBar: BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                      selectedItemColor: const Color.fromRGBO(245, 188, 6, 1),
                      unselectedItemColor: Colors.white,
                      currentIndex: _selectedIndex,
                      onTap: _onNavTap,
                      items: _menuOptions.map((op) {
                        final ruta = op['ruta'] as String;
                        return BottomNavigationBarItem(
                          icon: _buildNavIcon(
                            ruta,
                            op['icon'] as IconData,
                            unreadChats,
                            unreadFamily,
                          ),
                          label: op['label'] as String,
                        );
                      }).toList(),
                    ),
                  );
                }

                // ── Tablet/Desktop: NavigationRail ────────────────────────
                final currentPage = _getPageFromRoute(
                  _menuOptions[_selectedIndex]['ruta'] as String,
                );

                return Scaffold(
                  body: Row(
                    children: [
                      NavigationRail(
                        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onNavTap,
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
                        unselectedIconTheme: const IconThemeData(
                          color: Colors.white,
                        ),
                        destinations: _menuOptions.map((op) {
                          final ruta = op['ruta'] as String;
                          return NavigationRailDestination(
                            icon: _buildNavIcon(
                              ruta,
                              op['icon'] as IconData,
                              unreadChats,
                              unreadFamily,
                            ),
                            label: Text(op['label'] as String),
                          );
                        }).toList(),
                      ),
                      Expanded(child: currentPage),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
