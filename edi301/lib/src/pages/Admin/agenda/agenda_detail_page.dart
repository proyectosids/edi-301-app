// lib/src/pages/Admin/agenda/agenda_detail_page.dart
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/eventos_api.dart';

class AgendaDetailPage extends StatelessWidget {
  const AgendaDetailPage({super.key});

  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  void _delete(BuildContext context, Evento evento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "${evento.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiHttp().deleteJson('/api/agenda/${evento.idActividad}');
        if (context.mounted) Navigator.pop(context, true);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _edit(BuildContext context, Evento evento) async {
    final result = await Navigator.pushNamed(
      context,
      'crear_evento',
      arguments: {
        'id_evento': evento.idActividad,
        'titulo': evento.titulo,
        'mensaje': evento.descripcion,
        'fecha_evento': evento.fechaEvento.toIso8601String(),
        'dias_anticipacion': evento.diasAnticipacion ?? 3,
      },
    );
    if (result == true && context.mounted) Navigator.pop(context, true);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatHora(String? h) {
    if (h == null || h.isEmpty) return 'Todo el día';
    return h.length > 5 ? h.substring(0, 5) : h;
  }

  bool _isUpcoming(DateTime d) {
    final n = DateTime.now();
    return d.isAfter(DateTime(n.year, n.month, n.day));
  }

  @override
  Widget build(BuildContext context) {
    final evento = ModalRoute.of(context)!.settings.arguments as Evento;
    final hasImage =
        evento.imagen != null &&
        evento.imagen!.isNotEmpty &&
        evento.imagen!.startsWith('http');
    final upcoming = _isUpcoming(evento.fechaEvento);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: ResponsiveContent(
          child: CustomScrollView(
            slivers: [
              // ── Hero image + app bar ───────────────────────────────────
              SliverAppBar(
                expandedHeight: hasImage ? 240 : 120,
                pinned: true,
                backgroundColor: _navy,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(context, evento),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, evento),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: hasImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              evento.imagen!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: _navy),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    _navy.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_navy, Color.fromRGBO(30, 85, 135, 1)],
                            ),
                          ),
                        ),
                ),
              ),

              // ── Body ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: upcoming
                                  ? _navy.withOpacity(0.1)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              upcoming ? 'PRÓXIMO' : 'PASADO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: upcoming ? _navy : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Title
                      Text(
                        evento.titulo,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Info cards
                      _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Fecha',
                            value: _formatDate(evento.fechaEvento),
                            iconColor: _navy,
                          ),
                          const Divider(height: 1),
                          _InfoRow(
                            icon: Icons.access_time_rounded,
                            label: 'Hora',
                            value: _formatHora(evento.horaEvento),
                            iconColor: _navy,
                          ),
                          if (evento.diasAnticipacion != null) ...[
                            const Divider(height: 1),
                            _InfoRow(
                              icon: Icons.notifications_active_rounded,
                              label: 'Aviso anticipado',
                              value: '${evento.diasAnticipacion} días antes',
                              iconColor: _gold,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Description
                      if (evento.descripcion != null &&
                          evento.descripcion!.isNotEmpty)
                        _InfoCard(
                          children: [
                            _InfoRow(
                              icon: Icons.description_outlined,
                              label: 'Descripción',
                              value: evento.descripcion!,
                              iconColor: Colors.grey.shade600,
                              multiline: true,
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar'),
                              onPressed: () => _delete(context, evento),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _navy,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                              onPressed: () => _edit(context, evento),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool multiline;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
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
