import 'dart:convert';
import 'dart:ui';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/services/notificaciones_api.dart';
import 'package:edi301/services/publicaciones_api.dart';
import 'package:edi301/src/pages/Admin/agenda/crear_evento_page.dart';
import 'package:edi301/src/pages/Notifications/notificaciones_historial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/src/pages/News/news_controller.dart';
import 'package:edi301/src/pages/News/create_postpage.dart';
import 'package:edi301/tools/fullscreen_image_viewer.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final SocketService _socketService = SocketService();
  TapDownDetails? _lastDoubleTapDownDetails;

  final HomeController _controller = HomeController();
  final PublicacionesApi _api = PublicacionesApi();
  final ApiHttp _http = ApiHttp();

  final NotificacionesApi _notiApi = NotificacionesApi();
  int _unreadCount = 0;

  final Map<int, GlobalKey> _likeButtonKeys = {};
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _currentPage = 1;
  final int _pageSize = 50;

  String _userRole = '';
  int _userId = 0;
  int? _familiaId;

  List<dynamic> _posts = [];

  GlobalKey _getLikeButtonKey(int postId) {
    return _likeButtonKeys.putIfAbsent(postId, () => GlobalKey());
  }

  @override
  void initState() {
    super.initState();
    _initData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 250) {
        _loadMoreFeed();
      }
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _animateHeartOverlayToLike({
    required int index,
    required TapDownDetails details,
  }) async {
    final post = _posts[index];
    final postId = post['id_post'];

    final likeKey = _getLikeButtonKey(postId);
    final likeContext = likeKey.currentContext;

    if (likeContext == null) {
      _toggleLike(index);
      return;
    }

    final overlay = Overlay.of(context);
    final likeBox = likeContext.findRenderObject() as RenderBox;

    final start = details.globalPosition;
    final end = likeBox.localToGlobal(
      Offset(likeBox.size.width / 2, likeBox.size.height / 2),
    );

    final animation = ValueNotifier<double>(0.0);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          child: ValueListenableBuilder<double>(
            valueListenable: animation,
            builder: (context, t, _) {
              final curved = Curves.easeInOutCubic.transform(t);

              final dx = lerpDouble(start.dx, end.dx, curved)!;
              final dy = lerpDouble(start.dy, end.dy, curved)!;

              final scale = lerpDouble(1.35, 0.55, curved)!;
              final opacity = lerpDouble(1.0, 0.75, curved)!;

              return Stack(
                children: [
                  Positioned(
                    left: dx - 22,
                    top: dy - 22,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;
    overlay.insert(entry);

    final isLiked = post['is_liked'] == 1 || post['is_liked'] == true;
    if (!isLiked) {
      _toggleLike(index);
    }

    const totalDuration = Duration(milliseconds: 900);
    const frameMs = 16;
    final totalFrames = totalDuration.inMilliseconds ~/ frameMs;

    for (int i = 0; i <= totalFrames; i++) {
      if (!mounted) break;
      animation.value = i / totalFrames;
      await Future.delayed(const Duration(milliseconds: frameMs));
    }

    await Future.delayed(const Duration(milliseconds: 120));

    animation.dispose();
    if (entry.mounted) {
      entry.remove();
    }
  }

  Future<void> _initData() async {
    await _loadUserData();
    _setupRealtime();
    await _loadFeed();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notiApi.unreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      if (mounted) {
        setState(() {
          _userRole = user['nombre_rol'] ?? user['rol'] ?? '';
          _userId = user['id_usuario'] ?? 0;
          final fId = user['id_familia'] ?? user['FamiliaID'];
          if (fId != null) _familiaId = int.tryParse(fId.toString());
        });
      }
    }
  }

  void _setupRealtime() {
    _socketService.initSocket();

    if (_userId > 0) {
      _socketService.joinUserRoom(_userId);
    }
    _socketService.joinInstitucionalRoom();

    if (_familiaId != null) {
      _socketService.joinFamilyRoom(_familiaId!);
    }

    _socketService.socket.off('feed_actualizado');
    _socketService.socket.on('feed_actualizado', (_) {
      if (mounted) _loadFeed();
    });

    _socketService.socket.off('post_creado');
    _socketService.socket.on('post_creado', (_) {
      if (mounted) _loadFeed();
    });

    _socketService.socket.off('post_eliminado');
    _socketService.socket.on('post_eliminado', (_) {
      if (mounted) _loadFeed();
    });

    _socketService.socket.off('post_estado_actualizado');
    _socketService.socket.on('post_estado_actualizado', (_) {
      if (mounted) _loadFeed();
    });

    _socketService.socket.off('evento_creado');
    _socketService.socket.on('evento_creado', (_) {
      if (mounted) _loadFeed();
    });

    _socketService.socket.off('evento_actualizado');
    _socketService.socket.on('evento_actualizado', (_) {
      if (mounted) _loadFeed();
    });

    _socketService.socket.off('evento_eliminado');
    _socketService.socket.on('evento_eliminado', (_) {
      if (mounted) _loadFeed();
    });
  }

  Future<void> _loadFeed() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _currentPage = 1;
          _hasMore = true;
        });
      }

      final resp = await _api.getGlobalFeed(
        page: _currentPage,
        limit: _pageSize,
      );

      final data = List<dynamic>.from(resp['data'] ?? []);

      if (mounted) {
        setState(() {
          _posts = data;
          _hasMore = resp['hasMore'] == true;
          _currentPage = 2;
          _loading = false;
        });
      }
    } catch (e) {
      print("Error cargando feed: $e");
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_loading || _isLoadingMore || !_hasMore) return;

    try {
      if (mounted) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      final resp = await _api.getGlobalFeed(
        page: _currentPage,
        limit: _pageSize,
      );

      final data = List<dynamic>.from(resp['data'] ?? []);

      if (mounted) {
        setState(() {
          _posts.addAll(data);
          _hasMore = resp['hasMore'] == true;
          if (data.isNotEmpty) {
            _currentPage++;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print("Error cargando más feed: $e");
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  String _fixUrl(String? url) {
    if (url == null || url.isEmpty || url == 'null') return '';

    if (url.startsWith('http')) {
      if (url.contains('localhost')) {
        return url.replaceFirst('http://localhost:3000', ApiHttp.baseUrl);
      }
      return url;
    }

    final path = url.startsWith('/') ? url : '/$url';
    return '${ApiHttp.baseUrl}$path';
  }

  /// Parsea un timestamp del servidor como UTC y lo convierte a hora local.
  /// El backend puede devolver strings con o sin "Z"; si no tiene indicador
  /// de zona horaria lo tratamos como UTC para que la conversión sea correcta.
  static DateTime _parseServerDate(String s) {
    final str = (s.endsWith('Z') || s.contains('+') || s.contains('-', 11))
        ? s
        : '${s}Z';
    return DateTime.tryParse(str)?.toLocal() ?? DateTime.now();
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';

    final date = _parseServerDate(dateStr);
    final diff = DateTime.now().difference(date);

    if (diff.inDays > 7) {
      return "${date.day}/${date.month}/${date.year}";
    } else if (diff.inDays >= 1) {
      return "Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}";
    } else if (diff.inHours >= 1) {
      return "Hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}";
    } else if (diff.inMinutes >= 1) {
      return "Hace ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minuto' : 'minutos'}";
    } else {
      return "Hace un momento";
    }
  }

  void _toggleLike(int index) async {
    final post = _posts[index];
    final isLiked = post['is_liked'] == 1 || post['is_liked'] == true;
    final postId = post['id_post'];
    final likesCount =
        int.tryParse(post['likes_count']?.toString() ?? '0') ?? 0;

    setState(() {
      _posts[index]['is_liked'] = isLiked ? 0 : 1;
      _posts[index]['likes_count'] = isLiked ? likesCount - 1 : likesCount + 1;
    });

    try {
      await _http.postJson('/api/publicaciones/$postId/like');
    } catch (e) {
      setState(() {
        _posts[index]['is_liked'] = isLiked ? 1 : 0;
        _posts[index]['likes_count'] = likesCount;
      });
    }
  }

  void _deletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar publicación"),
        content: const Text("¿Estás seguro? No podrás recuperarla."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _http.deleteJson('/api/publicaciones/$postId');
      _loadFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerOffset = ((_isAlumnoRole && !_hasFamiliaAsignada) ? 1 : 0);
    final showLoaderItem = _hasMore && _posts.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Noticias', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          if ([
            'Admin',
            'Padre',
            'Madre',
            'Tutor',
            'PapaEDI',
            'MamaEDI',
            'ALUMNO',
            'HijoEDI',
          ].contains(_userRole))
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded),
                  tooltip: 'Notificaciones',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificacionesHistorialPage(),
                      ),
                    );
                    // Al volver, actualizar el contador
                    _loadUnreadCount();
                    _loadFeed();
                  },
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(245, 188, 6, 1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color.fromRGBO(19, 67, 107, 1),
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFeed,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 80),
                itemCount:
                    (_posts.isEmpty ? 1 : _posts.length) +
                    bannerOffset +
                    (showLoaderItem ? 1 : 0),
                itemBuilder: (context, index) {
                  if ((_isAlumnoRole && !_hasFamiliaAsignada) && index == 0) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Para crear publicaciones necesitas tener una familia asignada.",
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (_posts.isEmpty) return _buildEmptyState();

                  if (showLoaderItem && index == _posts.length + bannerOffset) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final realIndex = index - bannerOffset;
                  final item = _posts[realIndex];

                  if (item['tipo'] == 'EVENTO') return _buildEventCard(item);
                  return _buildPostCard(item, realIndex);
                },
              ),
            ),
      floatingActionButton: _shouldShowFab()
          ? FloatingActionButton(
              backgroundColor: _canCreatePost
                  ? const Color.fromRGBO(245, 188, 6, 1)
                  : Colors.grey,
              child: const Icon(Icons.add, color: Colors.black),
              onPressed: !_canCreatePost
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePostPage(
                            idUsuario: _userId,
                            idFamilia: _familiaId,
                          ),
                        ),
                      ).then((_) => _loadFeed());
                    },
            )
          : null,
    );
  }

  bool get _isAlumnoRole {
    final r = _userRole.trim().toUpperCase();
    return ['ALUMNO', 'HIJOEDI', 'HIJO', 'ESTUDIANTE'].contains(r);
  }

  bool get _hasFamiliaAsignada {
    return _familiaId != null && _familiaId! > 0;
  }

  bool get _canCreatePost {
    if (_isAlumnoRole && !_hasFamiliaAsignada) return false;
    return true;
  }

  void _deleteEvent(int idEvento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Evento"),
        content: const Text(
          "¿Estás seguro de eliminar este evento de la agenda?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _http.deleteJson('/api/agenda/$idEvento');
        _loadFeed();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al eliminar: $e")));
      }
    }
  }

  Widget _buildEventCard(Map<String, dynamic> evento) {
    final fecha = DateTime.tryParse(evento['fecha_evento'].toString());
    final fechaStr = fecha != null ? "${fecha.day}/${fecha.month}" : "";
    final esAdmin = ['Admin'].contains(_userRole);
    final imagenUrl = evento['imagen'] ?? evento['url_imagen'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color.fromRGBO(245, 188, 6, 1), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(245, 188, 6, 1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Colors.black),
                const SizedBox(width: 10),
                const Text(
                  "EVENTO PRÓXIMO",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  fechaStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (esAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        _deleteEvent(evento['id_evento']);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          "Eliminar",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (imagenUrl != null && imagenUrl.toString().isNotEmpty)
            GestureDetector(
              onTap: () {},
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(_fixUrl(imagenUrl)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evento['titulo'] ?? 'Evento Escolar',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(19, 67, 107, 1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  evento['mensaje'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.25),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              "Aún no hay noticias.",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ── Resuelve el tema visual especial de un post según tipo y emojis ───────
  // Prioridad descendente: Emergencia > Cumpleaños > Logro > Espiritual >
  //                        Salida > Deporte > Arte > Comunicado
  _PostTheme? _resolvePostTheme(Map<String, dynamic> post) {
    final tipo = (post['tipo'] ?? '').toString().toUpperCase();
    final msg  = (post['mensaje'] ?? '').toString();

    bool has(String e) => msg.contains(e);
    bool hasAny(List<String> list) => list.any((e) => msg.contains(e));

    // 1 · EMERGENCIA
    if (hasAny(['⚠️', '❗', '🚨', '🆘'])) {
      return const _PostTheme(
        bgColor:      Color(0xFFFFEBEE),
        borderColor:  Color(0xFFD32F2F),
        bannerColor:  Color(0xFFD32F2F),
        bannerText:   '⚠️  AVISO URGENTE  ⚠️',
        avatarColor:  Color(0xFFD32F2F),
        trailingIcon: Icons.warning_rounded,
        iconColor:    Color(0xFFD32F2F),
      );
    }

    // 2 · CUMPLEAÑOS
    if (tipo == 'CUMPLEAÑOS' || (has('🎂') && has('🎉'))) {
      return const _PostTheme(
        bgColor:      Color(0xFFFFF8E1),
        borderColor:  Colors.orangeAccent,
        bannerColor:  Colors.deepOrange,
        bannerText:   '🎉  ¡CELEBRACIÓN ESPECIAL!  🎉',
        avatarColor:  Colors.orange,
        trailingIcon: Icons.cake,
        iconColor:    Colors.pink,
      );
    }

    // 3 · LOGRO / RECONOCIMIENTO
    if (has('🏆') || has('🥇') || (has('⭐') && has('🎊'))) {
      return const _PostTheme(
        bgColor:      Color(0xFFFFFDE7),
        borderColor:  Colors.amber,
        bannerColor:  Color(0xFFF9A825),
        bannerText:   '🏆  ¡LOGRO ESPECIAL!',
        avatarColor:  Colors.amber,
        trailingIcon: Icons.emoji_events,
        iconColor:    Colors.amber,
      );
    }

    // 4 · ESPIRITUAL / FE
    if (has('🙏') && hasAny(['📖', '✝️', '🕊️', '⛪', '🕌', '🛐'])) {
      return const _PostTheme(
        bgColor:      Color(0xFFF3E5F5),
        borderColor:  Color(0xFF7B1FA2),
        bannerColor:  Color(0xFF7B1FA2),
        bannerText:   '🙏  MOMENTO ESPIRITUAL',
        avatarColor:  Color(0xFF7B1FA2),
        trailingIcon: Icons.self_improvement,
        iconColor:    Color(0xFF7B1FA2),
      );
    }

    // 5 · SALIDA / PASEO / VIAJE
    if (hasAny(['🚌', '🗺️', '✈️', '🧳', '🏕️', '🌍'])) {
      return const _PostTheme(
        bgColor:      Color(0xFFE0F7FA),
        borderColor:  Color(0xFF00838F),
        bannerColor:  Color(0xFF00838F),
        bannerText:   '🗺️  SALIDA ESPECIAL',
        avatarColor:  Color(0xFF00838F),
        trailingIcon: Icons.explore,
        iconColor:    Color(0xFF00838F),
      );
    }

    // 6 · DEPORTE / ACTIVIDAD FÍSICA
    if (hasAny(['⚽', '🏀', '🏈', '🏃', '🏋️', '🤸', '🎽', '🧗'])) {
      return const _PostTheme(
        bgColor:      Color(0xFFE8F5E9),
        borderColor:  Color(0xFF2E7D32),
        bannerColor:  Color(0xFF2E7D32),
        bannerText:   '⚽  ACTIVIDAD DEPORTIVA',
        avatarColor:  Color(0xFF388E3C),
        trailingIcon: Icons.directions_run,
        iconColor:    Color(0xFF2E7D32),
      );
    }

    // 7 · ARTE / MÚSICA / TALENTO
    if (hasAny(['🎨', '🎵', '🎭', '🎤', '🎸', '🎬', '🖼️', '🎻'])) {
      return const _PostTheme(
        bgColor:      Color(0xFFFCE4EC),
        borderColor:  Color(0xFFC2185B),
        bannerColor:  Color(0xFFC2185B),
        bannerText:   '🎨  EXPRESIÓN ARTÍSTICA',
        avatarColor:  Color(0xFFE91E63),
        trailingIcon: Icons.palette,
        iconColor:    Color(0xFFC2185B),
      );
    }

    // 8 · COMUNICADO OFICIAL
    if (hasAny(['📢', '📣'])) {
      return const _PostTheme(
        bgColor:      Color(0xFFE3F2FD),
        borderColor:  Color(0xFF1565C0),
        bannerColor:  Color(0xFF1565C0),
        bannerText:   '📢  COMUNICADO OFICIAL',
        avatarColor:  Color(0xFF1976D2),
        trailingIcon: Icons.campaign,
        iconColor:    Color(0xFF1565C0),
      );
    }

    return null; // post normal, sin tema especial
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final nombreUsuario = "${post['nombre']} ${post['apellido'] ?? ''}";
    final nombreFamilia = post['nombre_familia'];
    final mensaje = post['mensaje'] ?? '';
    final urlImagen = post['url_imagen'];
    final tiempo = _timeAgo(post['created_at']);
    final esMiPost = post['id_usuario'] == _userId;

    final likesCount = int.tryParse(post['likes_count'].toString()) ?? 0;
    final comentariosCount =
        int.tryParse(post['comentarios_count'].toString()) ?? 0;

    final isLiked = post['is_liked'] == 1 || post['is_liked'] == true;

    final theme = _resolvePostTheme(post);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: theme != null ? 6 : 2,
      color: theme?.bgColor ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: theme != null
            ? BorderSide(color: theme.borderColor, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (theme != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: theme.bannerColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Text(
                theme.bannerText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor:
                  theme?.avatarColor ?? Colors.blue[100]!,
              backgroundImage: post['foto_perfil'] != null
                  ? NetworkImage(_fixUrl(post['foto_perfil']))
                  : null,
              child: post['foto_perfil'] == null
                  ? Text(
                      nombreUsuario.isNotEmpty ? nombreUsuario[0] : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(
              nombreUsuario,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (nombreFamilia != null &&
                    nombreFamilia.toString().isNotEmpty)
                  Text(
                    "Con la $nombreFamilia",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                if (tiempo.isNotEmpty)
                  Text(
                    tiempo,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            trailing: esMiPost
                ? PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'delete') _deletePost(post['id_post']);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text("Eliminar"),
                          ],
                        ),
                      ),
                    ],
                  )
                : (theme != null
                      ? Icon(theme.trailingIcon, color: theme.iconColor)
                      : null),
          ),
          if (urlImagen != null &&
              urlImagen.toString().isNotEmpty &&
              urlImagen != 'null')
            GestureDetector(
              onTap: () {
                final imageUrl = _fixUrl(urlImagen);
                FullScreenImageViewer.open(
                  context,
                  imageProvider: NetworkImage(imageUrl),
                  heroTag: 'post_image_${post['id_post']}',
                );
              },
              onDoubleTapDown: (details) {
                _lastDoubleTapDownDetails = details;
              },
              onDoubleTap: () {
                final details = _lastDoubleTapDownDetails;
                if (details != null) {
                  _animateHeartOverlayToLike(index: index, details: details);
                } else {
                  _toggleLike(index);
                }
              },
              child: Hero(
                tag: 'post_image_${post['id_post']}',
                child: Image.network(
                  _fixUrl(urlImagen),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print("Error cargando imagen: $error");
                    return Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 50,
                          ),
                          Text(
                            "Imagen no disponible",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          if (mensaje.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10,
              ),
              child: Text(mensaje, style: const TextStyle(fontSize: 15)),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                TextButton.icon(
                  key: _getLikeButtonKey(post['id_post']),
                  onPressed: () => _toggleLike(index),
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey[600],
                  ),
                  label: Text(
                    likesCount > 0 ? "$likesCount Likes" : "Me gusta",
                    style: TextStyle(
                      color: isLiked ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                TextButton.icon(
                  onPressed: () => _showCommentsModal(context, post['id_post']),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.grey[600],
                  ),
                  label: Text(
                    comentariosCount > 0
                        ? "$comentariosCount Comentarios"
                        : "Comentar",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentsModal(BuildContext context, int postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsSheet(
        postId: postId,
        http: _http,
        currentUserId: _userId,
        currentUserRole: _userRole,
        fixUrl: _fixUrl,
      ),
    );
  }

  bool _shouldShowFab() {
    return true;
  }
}

class CommentsSheet extends StatefulWidget {
  final int postId;
  final ApiHttp http;
  final int currentUserId;
  final String currentUserRole;
  final Function(String?) fixUrl;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.http,
    required this.currentUserId,
    required this.currentUserRole,
    required this.fixUrl,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  List<dynamic> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final res = await widget.http.getJson(
        '/api/publicaciones/${widget.postId}/comentarios',
      );
      if (mounted) {
        setState(() {
          _comments = jsonDecode(res.body);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    try {
      await widget.http.postJson(
        '/api/publicaciones/${widget.postId}/comentarios',
        data: {'contenido': text},
      );
      _loadComments();
    } catch (e) {
      print("Error enviando comentario: $e");
    }
  }

  void _deleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar comentario"),
        content: const Text("¿Deseas borrar este comentario?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.http.deleteJson(
          '/api/publicaciones/comentarios/$commentId',
        );
        _loadComments();
      } catch (e) {
        print("Error al borrar: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const Text(
            "Comentarios",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                ? const Center(child: Text("Sé el primero en comentar 👇"))
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (ctx, i) {
                      final c = _comments[i];
                      final nombre = "${c['nombre']} ${c['apellido'] ?? ''}";
                      final soyDueno =
                          (c['id_usuario'] as int?) == widget.currentUserId;
                      final soyAdmin = widget.currentUserRole == 'Admin';
                      final puedoBorrar = soyDueno || soyAdmin;
                      final fotoUrl = widget.fixUrl(c['foto_perfil']);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: c['foto_perfil'] != null
                              ? NetworkImage(fotoUrl)
                              : null,
                          child: c['foto_perfil'] == null
                              ? Text(nombre[0])
                              : null,
                        ),
                        title: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c['contenido'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        trailing: puedoBorrar
                            ? IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    _deleteComment(c['id_comentario']),
                              )
                            : null,
                        onLongPress: puedoBorrar
                            ? () => _deleteComment(c['id_comentario'])
                            : null,
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
              left: 10,
              right: 10,
              top: 5,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(
                      hintText: "Escribe un comentario...",
                      fillColor: Colors.grey[200],
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tema visual para posts especiales
// ─────────────────────────────────────────────────────────────────────────────
class _PostTheme {
  final Color bgColor;        // Fondo de la tarjeta
  final Color borderColor;    // Borde de la tarjeta
  final Color bannerColor;    // Fondo del banner superior
  final String bannerText;    // Texto del banner superior
  final Color avatarColor;    // Color del avatar (sin foto)
  final IconData trailingIcon;// Ícono que aparece arriba a la derecha
  final Color iconColor;      // Color de ese ícono

  const _PostTheme({
    required this.bgColor,
    required this.borderColor,
    required this.bannerColor,
    required this.bannerText,
    required this.avatarColor,
    required this.trailingIcon,
    required this.iconColor,
  });
}
