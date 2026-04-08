// lib/src/pages/Admin/agenda/agenda_page.dart
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/eventos_api.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/core/api_client_http.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});
  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _navyL = Color.fromRGBO(30, 85, 135, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final SocketService _socketService = SocketService();
  final EventosApi _api = EventosApi();
  late Future<List<Evento>> _future;

  final _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  void initState() {
    super.initState();
    _socketService.initSocket();
    _socketService.joinInstitucionalRoom();
    for (final ev in [
      'evento_creado',
      'evento_actualizado',
      'evento_eliminado',
    ]) {
      _socketService.socket.off(ev);
      _socketService.socket.on(ev, (_) {
        if (mounted) _load();
      });
    }
    _load();
  }

  void _load() => setState(() {
    _future = _api.listar();
  });

  @override
  void dispose() {
    if (_socketService.isReady) {
      for (final ev in [
        'evento_creado',
        'evento_actualizado',
        'evento_eliminado',
      ]) {
        _socketService.socket.off(ev);
      }
    }
    super.dispose();
  }

  // ── Categorize events ─────────────────────────────────────────────────────
  Map<String, List<Evento>> _categorize(List<Evento> eventos) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = <Evento>[];
    final past = <Evento>[];

    for (final e in eventos) {
      final d = DateTime(
        e.fechaEvento.year,
        e.fechaEvento.month,
        e.fechaEvento.day,
      );
      if (d.isBefore(today)) {
        past.add(e);
      } else {
        upcoming.add(e);
      }
    }

    upcoming.sort((a, b) => a.fechaEvento.compareTo(b.fechaEvento));
    past.sort((a, b) => b.fechaEvento.compareTo(a.fechaEvento));

    return {'upcoming': upcoming, 'past': past};
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  static const _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  String _mesAnio(DateTime d) => '${_meses[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: ResponsiveContent(
          child: FutureBuilder<List<Evento>>(
            future: _future,
            builder: (context, snapshot) {
              return CustomScrollView(
                slivers: [
                  // ── Sliver App Bar ────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 130,
                    pinned: true,
                    backgroundColor: _navy,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_navy, _navyL],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Mi Agenda',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _mesAnio(DateTime.now()),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () async {
                          final r =
                              await Navigator.pushNamed(context, 'crear_evento')
                                  as bool?;
                          if (r == true) _load();
                        },
                      ),
                    ],
                  ),

                  // ── Content ───────────────────────────────────────────────
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      child: Center(child: Text('Error: ${snapshot.error}')),
                    )
                  else
                    ..._buildContent(snapshot.data ?? []),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nuevo evento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final r = await Navigator.pushNamed(context, 'crear_evento') as bool?;
          if (r == true) _load();
        },
      ),
    );
  }

  List<Widget> _buildContent(List<Evento> eventos) {
    if (eventos.isEmpty) {
      return [
        const SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_outlined, size: 72, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No hay eventos programados.',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final cats = _categorize(eventos);
    final upcoming = cats['upcoming']!;
    final past = cats['past']!;

    return [
      if (upcoming.isNotEmpty) ...[
        _sectionHeader('Próximos eventos', upcoming.length),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _EventCard(
                evento: upcoming[i],
                isToday: _isToday(upcoming[i].fechaEvento),
                months: _months,
                onTap: () => _goToDetail(upcoming[i]),
              ),
              childCount: upcoming.length,
            ),
          ),
        ),
      ],
      if (past.isNotEmpty) ...[
        _sectionHeader('Eventos pasados', past.length),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _EventCard(
                evento: past[i],
                isToday: false,
                isPast: true,
                months: _months,
                onTap: () => _goToDetail(past[i]),
              ),
              childCount: past.length,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _sectionHeader(String title, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(19, 67, 107, 1),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(19, 67, 107, 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(19, 67, 107, 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToDetail(Evento evento) async {
    final r = await Navigator.pushNamed(
      context,
      'agenda_detail',
      arguments: evento,
    );
    if (r == true) _load();
  }
}

// ── Event Card ────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Evento evento;
  final bool isToday;
  final bool isPast;
  final List<String> months;
  final VoidCallback onTap;

  const _EventCard({
    required this.evento,
    required this.isToday,
    required this.months,
    required this.onTap,
    this.isPast = false,
  });

  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  @override
  Widget build(BuildContext context) {
    final hasImage =
        evento.imagen != null &&
        evento.imagen!.isNotEmpty &&
        evento.imagen!.startsWith('http');

    final hora = evento.horaEvento != null && evento.horaEvento!.isNotEmpty
        ? evento.horaEvento!.length > 5
              ? evento.horaEvento!.substring(0, 5)
              : evento.horaEvento!
        : 'Todo el día';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isToday
              ? Border.all(color: _gold, width: 2)
              : isPast
              ? Border.all(color: Colors.grey.shade200)
              : null,
          boxShadow: [
            BoxShadow(
              color: isPast
                  ? Colors.black.withOpacity(0.04)
                  : _navy.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Date badge ──────────────────────────────────────────────────
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isPast
                      ? Colors.grey.shade100
                      : isToday
                      ? _gold
                      : _navy,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      evento.fechaEvento.day.toString(),
                      style: TextStyle(
                        color: isPast ? Colors.grey : Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      months[evento.fechaEvento.month - 1],
                      style: TextStyle(
                        color: isPast
                            ? Colors.grey
                            : isToday
                            ? _navy
                            : Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Info ─────────────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'HOY',
                            style: TextStyle(
                              color: Color(0xFFB8860B),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      Text(
                        evento.titulo,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isPast ? Colors.grey.shade500 : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: isPast
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hora,
                            style: TextStyle(
                              fontSize: 12,
                              color: isPast
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (evento.diasAnticipacion != null) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.notifications_outlined,
                              size: 13,
                              color: isPast
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${evento.diasAnticipacion}d antes',
                              style: TextStyle(
                                fontSize: 12,
                                color: isPast
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Thumbnail ────────────────────────────────────────────────────
              if (hasImage)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Image.network(
                    evento.imagen!,
                    width: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
            ],
          ),
        ), // IntrinsicHeight
      ), // Container
    );
  }
}
