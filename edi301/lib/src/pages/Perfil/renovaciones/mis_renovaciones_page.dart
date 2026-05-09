import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/renovaciones_api.dart';

/// Pantalla "Renovación de ciclo" del lado del usuario.
///
/// Detecta el rol del usuario logueado y muestra lo apropiado:
///   • Alumno → botón para solicitar renovación si la ventana está abierta.
///   • Padre/Tutor → lista de pendientes de sus familias para aceptar/rechazar.
class MisRenovacionesPage extends StatefulWidget {
  const MisRenovacionesPage({super.key});

  @override
  State<MisRenovacionesPage> createState() => _MisRenovacionesPageState();
}

class _MisRenovacionesPageState extends State<MisRenovacionesPage> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final RenovacionesApi _api = RenovacionesApi();

  bool _loading = true;
  String? _error;

  bool _ventanaAbierta = false;
  bool _esAlumno = false;
  bool _esPadre = false;
  int? _idUsuario;
  int? _idFamilia; // ya no se usa para filtrar, queda informativo
  List<Map<String, dynamic>> _pendientes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Lee el usuario logueado
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null && userJson.isNotEmpty) {
        try {
          final user = jsonDecode(userJson) as Map<String, dynamic>;
          _idUsuario = (user['id_usuario'] ?? user['IdUsuario']) is int
              ? (user['id_usuario'] ?? user['IdUsuario']) as int
              : int.tryParse('${user['id_usuario'] ?? user['IdUsuario']}');
          _idFamilia = (user['id_familia'] is int)
              ? user['id_familia'] as int
              : int.tryParse('${user['id_familia'] ?? ''}');

          final tipo = (user['tipo_usuario'] ?? '').toString().toUpperCase();
          final rol = (user['nombre_rol'] ?? '').toString().toLowerCase();

          _esAlumno = tipo == 'ALUMNO' || rol == 'alumno';
          _esPadre = ['padre', 'madre', 'tutor', 'papaedi', 'mamaedi']
              .any((r) => rol.contains(r));
        } catch (_) {}
      }

      _ventanaAbierta = await _api.isVentanaAbierta();

      // SIEMPRE intentamos cargar pendientes con el endpoint global. Si el
      // usuario es padre/tutor en alguna familia, regresa solicitudes; si no,
      // regresa lista vacía. Esto cubre el caso de varias familias y evita
      // depender de id_familia del JSON local.
      try {
        _pendientes = await _api.misPendientes();
        if (_pendientes.isNotEmpty) {
          // Si tiene pendientes asumimos que es padre/tutor aunque la
          // detección por rol haya fallado.
          _esPadre = true;
        }
      } catch (_) {
        _pendientes = const [];
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _solicitar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Renovar mi familia'),
        content: const Text(
          '¿Quieres solicitar la renovación de tu familia para el próximo '
          'ciclo escolar? Tus padres/tutores recibirán la solicitud y deberán '
          'aceptarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, solicitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _api.solicitar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Solicitud enviada. Tus padres recibirán un aviso.'),
        backgroundColor: Colors.green,
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    }
  }

  Future<void> _responder(int idSolicitud, bool aceptar) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(aceptar ? 'Aceptar renovación' : 'Rechazar renovación'),
        content: Text(aceptar
            ? '¿Confirmas que el alumno conserve su lugar en la familia para el próximo ciclo?'
            : '¿Confirmas que el alumno NO conserve su lugar en la familia para el próximo ciclo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: aceptar ? Colors.green : Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(aceptar ? 'Aceptar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _api.responder(idSolicitud, aceptar);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(aceptar ? 'Renovación aceptada' : 'Renovación rechazada'),
        backgroundColor: aceptar ? Colors.green : Colors.red,
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo: $e')),
      );
    }
  }

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat("d/MM/yyyy HH:mm", 'es').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Renovación de ciclo'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_ventanaAbierta && !_esPadre) {
      return _emptyState(
        icon: Icons.event_busy_rounded,
        title: 'Ventana cerrada',
        subtitle:
            'Por ahora no hay un proceso de renovación activo. Te avisaremos cuando se abra.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_esAlumno) _buildAlumnoSection(),
        if (_esPadre) _buildPadreSection(),
      ],
    );
  }

  Widget _buildAlumnoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.refresh_rounded, color: _primary, size: 44),
          const SizedBox(height: 8),
          const Text(
            '¿Quieres conservar tu lugar en la familia?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Si solicitas la renovación y tus padres/tutores la aceptan, '
            'seguirás siendo parte de tu familia EDI cuando empiece el '
            'próximo ciclo escolar. Si no, te asignaremos a una nueva.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send_rounded),
              label: const Text(
                'Solicitar renovación',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _ventanaAbierta ? _solicitar : null,
            ),
          ),
          if (!_ventanaAbierta) ...[
            const SizedBox(height: 8),
            Text(
              'La ventana de renovación está cerrada actualmente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPadreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Solicitudes de tu familia',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800),
        ),
        const SizedBox(height: 8),
        if (_pendientes.isEmpty)
          _emptyState(
            icon: Icons.inbox_rounded,
            title: 'Sin solicitudes',
            subtitle: 'No hay alumnos solicitando renovar en tu familia.',
          )
        else
          ..._pendientes.map(_pendienteTile),
      ],
    );
  }

  Widget _pendienteTile(Map<String, dynamic> s) {
    final nombre = '${s['nombre'] ?? ''} ${s['apellido'] ?? ''}'.trim();
    final id = (s['id_solicitud'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Solicitado: ${_fmt(s['fecha_solicitud']?.toString())}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rechazar'),
                  onPressed: () => _responder(id, false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.green),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Aceptar'),
                  onPressed: () => _responder(id, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
