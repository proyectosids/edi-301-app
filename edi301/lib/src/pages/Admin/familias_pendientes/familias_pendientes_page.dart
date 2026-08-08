// lib/src/pages/Admin/familias_pendientes/familias_pendientes_page.dart
//
// Lista familias que se crearon manualmente y todavía tienen al menos un
// slot de padre/madre sin vincular a un usuario real. El admin puede:
//   1. Esperar a que el usuario se registre y la app vincule automáticamente.
//   2. Vincular manualmente un usuario ya existente (botón "Vincular usuario").
import 'package:flutter/material.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/services/search_api.dart';
import 'package:edi301/core/api_error.dart';

class FamiliasPendientesPage extends StatefulWidget {
  const FamiliasPendientesPage({super.key});

  @override
  State<FamiliasPendientesPage> createState() => _FamiliasPendientesPageState();
}

class _FamiliasPendientesPageState extends State<FamiliasPendientesPage> {
  final FamiliaApi _api = FamiliaApi();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getFamiliasPendientes();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getFamiliasPendientes();
    });
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familias pendientes'),
        backgroundColor: primary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _reload),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: ${friendlyError(snap.error)}'),
                  ),
                ],
              );
            }
            final familias = snap.data ?? const <Map<String, dynamic>>[];
            if (familias.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay familias con vinculación pendiente.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: familias.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _FamiliaPendienteCard(
                familia: familias[i],
                onChanged: _reload,
                api: _api,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FamiliaPendienteCard extends StatelessWidget {
  final Map<String, dynamic> familia;
  final VoidCallback onChanged;
  final FamiliaApi api;

  const _FamiliaPendienteCard({
    required this.familia,
    required this.onChanged,
    required this.api,
  });

  Widget _slotTile({
    required BuildContext context,
    required String rol, // 'PAPA' o 'MAMA'
    required String? nombrePendiente,
    required String? apellidoPendiente,
    required String? nombreReal,
    required bool yaVinculado,
  }) {
    final etiqueta = rol == 'PAPA' ? 'Padre' : 'Madre';
    if (yaVinculado) {
      return ListTile(
        leading: Icon(Icons.check_circle, color: Colors.green.shade600),
        title: Text('$etiqueta: ${nombreReal ?? "—"}'),
        subtitle: const Text('Vinculado'),
        dense: true,
      );
    }
    final pendienteCompleto = [nombrePendiente ?? '', apellidoPendiente ?? '']
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
    if (pendienteCompleto.isEmpty) {
      // Slot no existe — no hay dato pendiente para este rol
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: Icon(Icons.hourglass_top, color: Colors.amber.shade800),
      title: Text('$etiqueta (pendiente): $pendienteCompleto'),
      subtitle: const Text('Aún no se vincula a un usuario real'),
      trailing: TextButton.icon(
        icon: const Icon(Icons.link),
        label: const Text('Vincular'),
        onPressed: () => _abrirBuscador(context, rol),
      ),
      dense: true,
    );
  }

  Future<void> _abrirBuscador(BuildContext context, String rol) async {
    final idFamilia = familia['id_familia'];
    if (idFamilia == null) return;

    final usuario = await showDialog<UserMini>(
      context: context,
      builder: (_) => _BuscarUsuarioDialog(rol: rol),
    );
    if (usuario == null) return;

    try {
      await api.linkUserToFamily(
        idFamilia: idFamilia is int ? idFamilia : int.parse(idFamilia.toString()),
        idUsuario: usuario.id,
        rol: rol,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${usuario.nombre} ${usuario.apellido} vinculado correctamente.')),
        );
      }
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = (familia['nombre_familia'] ?? '').toString();
    final residencia = (familia['residencia'] ?? '').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom, color: Color.fromRGBO(19, 67, 107, 1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (residencia.isNotEmpty)
                  Chip(label: Text(residencia, style: const TextStyle(fontSize: 11))),
              ],
            ),
            const Divider(),
            _slotTile(
              context: context,
              rol: 'PAPA',
              nombrePendiente:   familia['papa_nombre_pendiente']?.toString(),
              apellidoPendiente: familia['papa_apellido_pendiente']?.toString(),
              nombreReal:        familia['papa_nombre_real']?.toString(),
              yaVinculado:       familia['papa_id'] != null,
            ),
            _slotTile(
              context: context,
              rol: 'MAMA',
              nombrePendiente:   familia['mama_nombre_pendiente']?.toString(),
              apellidoPendiente: familia['mama_apellido_pendiente']?.toString(),
              nombreReal:        familia['mama_nombre_real']?.toString(),
              yaVinculado:       familia['mama_id'] != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BuscarUsuarioDialog extends StatefulWidget {
  final String rol; // 'PAPA' | 'MAMA' (solo informativo en el título)
  const _BuscarUsuarioDialog({required this.rol});

  @override
  State<_BuscarUsuarioDialog> createState() => _BuscarUsuarioDialogState();
}

class _BuscarUsuarioDialogState extends State<_BuscarUsuarioDialog> {
  final TextEditingController _ctrl = TextEditingController();
  final SearchApi _searchApi = SearchApi();
  List<UserMini> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _buscar(String q) async {
    q = q.trim();
    if (q.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _searchApi.searchAll(q);
      final merged = <int, UserMini>{};
      for (final u in res.empleados) merged[u.id] = u;
      for (final u in res.externos) merged[u.id] = u;
      _results = merged.values.toList();
    } catch (_) {
      _results = const [];
    } finally {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Vincular ${widget.rol == "PAPA" ? "padre" : "madre"}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre, matrícula o núm. empleado',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _buscar,
            ),
            const SizedBox(height: 8),
            if (_searching) const LinearProgressIndicator(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final u = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text('${u.nombre} ${u.apellido}'),
                    subtitle: Text(u.email ?? u.tipo),
                    onTap: () => Navigator.of(context).pop(u),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
