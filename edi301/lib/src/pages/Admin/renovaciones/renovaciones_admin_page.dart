import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edi301/services/renovaciones_api.dart';

/// Panel admin para el ciclo de renovación de familias.
///
/// Contiene:
///   • Toggle de la ventana de renovación.
///   • Resumen del progreso (total alumnos vs. renovados).
///   • Lista de solicitudes con su estatus.
///   • Botón "Vaciar familias" con confirmación doble.
class RenovacionesAdminPage extends StatefulWidget {
  const RenovacionesAdminPage({super.key});

  @override
  State<RenovacionesAdminPage> createState() => _RenovacionesAdminPageState();
}

class _RenovacionesAdminPageState extends State<RenovacionesAdminPage> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final RenovacionesApi _api = RenovacionesApi();

  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool _ventanaAbierta = false;
  int _totalAlumnos = 0;
  int _alumnosRenovados = 0;
  List<Map<String, dynamic>> _solicitudes = const [];

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
      final ventana = await _api.isVentanaAbierta();
      final dash = await _api.adminDashboard();
      setState(() {
        _ventanaAbierta = ventana;
        _totalAlumnos = (dash['total_alumnos'] as num?)?.toInt() ?? 0;
        _alumnosRenovados =
            (dash['alumnos_renovados'] as num?)?.toInt() ?? 0;
        _solicitudes = (dash['solicitudes'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _toggleVentana(bool abrir) async {
    setState(() => _busy = true);
    try {
      await _api.setVentana(abrir);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(abrir
            ? 'Ventana de renovación ABIERTA'
            : 'Ventana de renovación CERRADA'),
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _vaciarFamilias() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final canConfirm =
              controller.text.trim().toUpperCase() == 'VACIAR';
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Vaciar familias'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esto removerá a todos los alumnos NO renovados '
                  '(${_totalAlumnos - _alumnosRenovados} alumnos serán removidos).',
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  'Los alumnos renovados ($_alumnosRenovados) se quedan en su '
                  'familia y su flag se resetea para el próximo ciclo.',
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Esta acción NO se puede deshacer. Para confirmar escribe VACIAR:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    hintText: 'VACIAR',
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed:
                    canConfirm ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Vaciar'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final removidos = await _api.vaciarFamilias();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Familias vaciadas. Alumnos removidos: $removidos'),
        backgroundColor: Colors.green,
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo vaciar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtDate(String? iso) {
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildToggleCard(),
                    const SizedBox(height: 12),
                    _buildStatsCard(),
                    const SizedBox(height: 12),
                    _buildVaciarButton(),
                    const SizedBox(height: 18),
                    Text('Solicitudes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        )),
                    const SizedBox(height: 8),
                    if (_solicitudes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          'No hay solicitudes registradas.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      ..._solicitudes.map(_buildSolicitudTile),
                  ],
                ),
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
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        value: _ventanaAbierta,
        onChanged: _busy ? null : _toggleVentana,
        activeColor: _gold,
        contentPadding: EdgeInsets.zero,
        title: Text(
          _ventanaAbierta
              ? 'Ventana de renovación ABIERTA'
              : 'Ventana de renovación cerrada',
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Los alumnos verán el botón "Renovar mi familia" cuando esté abierta.',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final pendientes = _totalAlumnos - _alumnosRenovados;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _statBox('Total', '$_totalAlumnos', Colors.grey.shade700),
          const SizedBox(width: 8),
          _statBox('Renovados', '$_alumnosRenovados', Colors.green.shade700),
          const SizedBox(width: 8),
          _statBox('Por vaciar', '$pendientes', Colors.red.shade700),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              )),
          Text(label, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _buildVaciarButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.delete_sweep_rounded),
        label: Text(
          _busy ? 'Procesando...' : 'Vaciar familias',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: _busy ? null : _vaciarFamilias,
      ),
    );
  }

  Widget _buildSolicitudTile(Map<String, dynamic> s) {
    final estado = (s['estado'] ?? '').toString();
    Color color;
    IconData icon;
    switch (estado.toLowerCase()) {
      case 'aceptada':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case 'rechazada':
        color = Colors.red;
        icon = Icons.cancel_rounded;
        break;
      default:
        color = Colors.orange;
        icon = Icons.hourglass_empty_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s['nombre'] ?? ''} ${s['apellido'] ?? ''}'.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if ((s['nombre_familia'] ?? '').toString().isNotEmpty)
                  Text(
                    'Familia: ${s['nombre_familia']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                Text(
                  'Solicitado: ${_fmtDate(s['fecha_solicitud']?.toString())}',
                  style:
                      TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(estado,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ],
      ),
    );
  }
}
