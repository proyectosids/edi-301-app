// lib/src/pages/Notifications/notificaciones_historial_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edi301/services/notificaciones_api.dart';
import 'package:edi301/core/api_error.dart';
import 'package:edi301/src/pages/Notifications/notifications_page.dart';
import 'package:edi301/src/pages/Perfil/renovaciones/mis_renovaciones_page.dart';

class NotificacionesHistorialPage extends StatefulWidget {
  const NotificacionesHistorialPage({super.key});

  @override
  State<NotificacionesHistorialPage> createState() =>
      _NotificacionesHistorialPageState();
}

class _NotificacionesHistorialPageState
    extends State<NotificacionesHistorialPage> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final NotificacionesApi _api = NotificacionesApi();
  List<NotificacionItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _api.list();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Marcar una como leída ────────────────────────────────────────────────
  Future<void> _markRead(NotificacionItem item) async {
    if (item.leido) return;
    try {
      await _api.markRead(item.id);
      setState(() {
        final idx = _items.indexWhere((n) => n.id == item.id);
        if (idx != -1) _items[idx] = _items[idx].copyWith(leido: true);
      });
    } catch (_) {}
  }

  // ── Marcar todas como leídas ─────────────────────────────────────────────
  Future<void> _markAllRead() async {
    try {
      await _api.markAllRead();
      setState(() {
        _items = _items.map((n) => n.copyWith(leido: true)).toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas las notificaciones marcadas como leídas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Eliminar una ─────────────────────────────────────────────────────────
  Future<void> _delete(NotificacionItem item) async {
    try {
      await _api.remove(item.id);
      setState(() => _items.removeWhere((n) => n.id == item.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
        // Restaurar ítem si falla (el Dismissible ya lo quitó visualmente)
        _load();
      }
    }
  }

  // ── Eliminar todas ───────────────────────────────────────────────────────
  Future<void> _confirmDeleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar todo'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todas las notificaciones? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.removeAll();
      setState(() => _items.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Icono por tipo de notificación ───────────────────────────────────────
  IconData _iconForTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'FAMILIA_CREADA':
        return Icons.home_rounded;
      case 'ASIGNACION':
        return Icons.group_add_rounded;
      case 'POST_CREADO':
      case 'PUBLICACION':
      case 'NUEVA_PUBLICACION':
        return Icons.article_rounded;
      case 'POST_APROBADO':
        return Icons.check_circle_rounded;
      case 'POST_RECHAZADO':
        return Icons.cancel_rounded;
      case 'SOLICITUD':
        return Icons.pending_actions_rounded;
      case 'CUMPLEANOS':
      case 'CUMPLEAÑOS':
        return Icons.cake_rounded;
      case 'AGENDA':
      case 'EVENTO':
        return Icons.event_rounded;
      case 'MENSAJE':
        return Icons.chat_bubble_rounded;
      case 'LIKE':
        return Icons.favorite_rounded;
      case 'COMENTARIO':
        return Icons.comment_rounded;
      case 'ORACION':
        return Icons.self_improvement_rounded;
      case 'RENOVACION_CICLO':
      case 'RENOVACION_CICLO_RESPUESTA':
        return Icons.refresh_rounded;
      case 'CICLO_CERRADO':
        return Icons.event_busy_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForTipo(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'FAMILIA_CREADA':
        return const Color(0xFF2E7D32);
      case 'ASIGNACION':
        return const Color(0xFF1565C0);
      case 'POST_APROBADO':
        return const Color(0xFF2E7D32);
      case 'POST_RECHAZADO':
        return Colors.red.shade700;
      case 'SOLICITUD':
        return Colors.orange.shade700;
      case 'CUMPLEANOS':
      case 'CUMPLEAÑOS':
        return Colors.pinkAccent;
      case 'AGENDA':
      case 'EVENTO':
        return const Color(0xFF6A1B9A);
      case 'MENSAJE':
        return const Color(0xFF00838F);
      case 'LIKE':
        return Colors.red.shade400;
      case 'COMENTARIO':
        return Colors.blue.shade600;
      case 'ORACION':
        return const Color(0xFF6A1B9A);
      case 'RENOVACION_CICLO':
      case 'RENOVACION_CICLO_RESPUESTA':
        return const Color(0xFF2E7D32);
      case 'CICLO_CERRADO':
        return Colors.grey.shade700;
      default:
        return _primary;
    }
  }

  // ── Acción al tocar una notificación ────────────────────────────────────
  Future<void> _onTapNotificacion(NotificacionItem item) async {
    await _markRead(item);
    if (!mounted) return;

    final tipo = item.tipo.toUpperCase();
    final ref = item.idReferencia;

    switch (tipo) {
      // ── Solicitudes (alta de familia, etc.) ────────────────────────────
      case 'SOLICITUD':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        );
        break;

      // ── Renovación de ciclo ────────────────────────────────────────────
      case 'RENOVACION_CICLO':
      case 'RENOVACION_CICLO_RESPUESTA':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MisRenovacionesPage()),
        );
        break;

      // ── Ciclo cerrado: solo informativa ────────────────────────────────
      case 'CICLO_CERRADO':
        break;

      // ── Posts (like, comentario, nueva publicación, aprobación) ───────
      // El id_referencia es el id_post. Lo pasamos como argumento para que
      // NewsPage pueda (opcionalmente) hacer scroll/highlight al post.
      case 'LIKE':
      case 'COMENTARIO':
      case 'POST_CREADO':
      case 'PUBLICACION':
      case 'NUEVA_PUBLICACION':
      case 'POST_APROBADO':
      case 'POST_RECHAZADO':
      case 'POST_DETALLE':
      case 'CUMPLEANOS':
      case 'CUMPLEAÑOS':
        Navigator.pushNamed(
          context,
          'news',
          arguments: ref != null ? {'highlightPostId': ref} : null,
        );
        break;

      // ── Mensajes de chat ───────────────────────────────────────────────
      // Si el id_referencia es id_familia se puede usar para abrir el chat.
      // Por ahora abrimos la lista de chats; abrir el chat exacto requiere
      // pasar id_sala + nombreChat (mejora futura).
      case 'MENSAJE':
        Navigator.pushNamed(
          context,
          'family',
          arguments: ref != null ? {'openChatForFamilia': ref} : null,
        );
        break;

      // ── Eventos / agenda ───────────────────────────────────────────────
      // El detalle pide el objeto Evento completo, así que abrimos la
      // pantalla general de agenda y desde ahí el usuario abre el evento.
      case 'AGENDA':
      case 'EVENTO':
        Navigator.pushNamed(context, 'agenda');
        break;

      // ── Familia ────────────────────────────────────────────────────────
      case 'FAMILIA_CREADA':
      case 'ASIGNACION':
        Navigator.pushNamed(context, 'family');
        break;

      // ── Recordatorio de oración: solo informativa ──────────────────────
      case 'ORACION':
        break;

      default:
        // Tipos que no conocemos: no navegamos a ningún lado, solo se
        // marca como leído (ya se hizo al inicio del método).
        break;
    }
  }

  // ── Formato de fecha legible ─────────────────────────────────────────────
  String _formatFecha(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer, ${DateFormat('HH:mm').format(dt)}';
    if (diff.inDays < 7) return '${diff.inDays} días atrás';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.leido).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Notificaciones',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [
          if (_items.isNotEmpty) ...[
            // Marcar todo leído
            if (unread > 0)
              IconButton(
                icon: const Icon(Icons.done_all_rounded),
                tooltip: 'Marcar todo como leído',
                onPressed: _markAllRead,
              ),
            // Eliminar todo
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Eliminar todo',
              onPressed: _confirmDeleteAll,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: _primary,
              child: _items.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _buildItem(_items[i]),
                    ),
            ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin notificaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aquí aparecerán todos los avisos que recibas.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItem(NotificacionItem item) {
    final tipoColor = _colorForTipo(item.tipo);
    final tipoIcon = _iconForTipo(item.tipo);
    final isUnread = !item.leido;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _onTapNotificacion(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isUnread ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: isUnread
                ? Border.all(color: tipoColor.withOpacity(0.4), width: 1.5)
                : Border.all(color: Colors.grey.shade200),
            boxShadow: isUnread
                ? [
                    BoxShadow(
                      color: tipoColor.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícono del tipo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tipoColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tipoIcon, color: tipoColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.titulo,
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: isUnread ? Colors.black87 : Colors.black54,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tipoColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.cuerpo,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatFecha(item.fechaCreacion),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
