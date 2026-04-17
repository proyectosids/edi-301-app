// lib/src/pages/Admin/assign_admin_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:edi301/services/usuarios_api.dart';
import 'package:edi301/core/api_error.dart';

class AssignAdminPage extends StatefulWidget {
  const AssignAdminPage({super.key});

  @override
  State<AssignAdminPage> createState() => _AssignAdminPageState();
}

class _AssignAdminPageState extends State<AssignAdminPage>
    with SingleTickerProviderStateMixin {
  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  late TabController _tabController;
  final UsuariosApi _api = UsuariosApi();

  // ── Tab "Buscar" ──────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;

  // ── Tab "Admins actuales" ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _admins = [];
  bool _loadingAdmins = false;

  // ── Roles (para el diálogo de revocación) ────────────────────────────────
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _admins.isEmpty) _loadAdmins();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search helpers ─────────────────────────────────────────────────────────
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final rows = await _api.buscarPorIdent(q);
      if (mounted) setState(() => _searchResults = rows);
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Admins loader ──────────────────────────────────────────────────────────
  Future<void> _loadAdmins() async {
    setState(() => _loadingAdmins = true);
    try {
      final rows = await _api.listAdmins();
      if (mounted) setState(() => _admins = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAdmins = false);
    }
  }

  // ── Assign admin ────────────────────────────────────────────────────────────
  Future<void> _confirmAndAssign(Map<String, dynamic> user) async {
    final nombre = '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}'.trim();
    final rolActual = user['nombre_rol'] ?? 'Desconocido';
    final idUsuario = user['id_usuario'] as int?;
    if (idUsuario == null) return;

    if (rolActual == 'Admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nombre ya es Administrador.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Asignar como Administrador?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  const TextSpan(text: 'Usuario: '),
                  TextSpan(
                    text: nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Rol actual: $rolActual',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            _warningBox(
              'Este usuario tendrá acceso completo al Panel de Administrador.',
              Colors.orange,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _api.cambiarRol(idUsuario); // id_rol = 1 por defecto
      if (!mounted) return;

      setState(() {
        final idx = _searchResults.indexWhere((u) => u['id_usuario'] == idUsuario);
        if (idx != -1) {
          _searchResults[idx] = {..._searchResults[idx], 'nombre_rol': 'Admin'};
        }
        // Añadir a la lista de admins si ya fue cargada
        if (_admins.isNotEmpty) {
          _admins.add({...user, 'nombre_rol': 'Admin'});
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $nombre ahora es Administrador.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  // ── Revoke admin ────────────────────────────────────────────────────────────
  Future<void> _confirmAndRevoke(Map<String, dynamic> user) async {
    final nombre = '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}'.trim();
    final idUsuario = user['id_usuario'] as int?;
    if (idUsuario == null) return;

    // Cargar roles si no los tenemos aún
    if (_roles.isEmpty) {
      try {
        _roles = await _api.listRoles();
      } catch (_) {}
    }

    // Roles disponibles (excluir Admin)
    final rolesDisponibles = _roles.where((r) => r['nombre_rol'] != 'Admin').toList();

    if (rolesDisponibles.isEmpty || !mounted) return;

    // Diálogo para elegir nuevo rol
    final nuevoRolId = await showDialog<int>(
      context: context,
      builder: (ctx) => _RolePickerDialog(
        userName: nombre,
        roles: rolesDisponibles,
        navy: _navy,
      ),
    );
    if (nuevoRolId == null || !mounted) return;

    final nuevoRolNombre = rolesDisponibles
        .firstWhere((r) => r['id_rol'] == nuevoRolId,
            orElse: () => {'nombre_rol': 'otro rol'})['nombre_rol'];

    // Confirmación final
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Revocar rol de Administrador?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(text: '$nombre '),
                  const TextSpan(text: 'dejará de ser Administrador y pasará al rol '),
                  TextSpan(
                    text: nuevoRolNombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _warningBox(
              'Perderá acceso al Panel de Administrador de inmediato.',
              Colors.red,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _api.cambiarRol(idUsuario, idRol: nuevoRolId);
      if (!mounted) return;

      setState(() {
        _admins.removeWhere((u) => u['id_usuario'] == idUsuario);
        // Actualizar en resultados de búsqueda si aparece
        final idx = _searchResults.indexWhere((u) => u['id_usuario'] == idUsuario);
        if (idx != -1) {
          _searchResults[idx] = {
            ..._searchResults[idx],
            'nombre_rol': nuevoRolNombre,
            'id_rol': nuevoRolId,
          };
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $nombre ya no es Administrador.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Administradores'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: _gold,
          tabs: const [
            Tab(icon: Icon(Icons.person_search), text: 'Asignar admin'),
            Tab(icon: Icon(Icons.admin_panel_settings), text: 'Admins actuales'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildAdminsTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Buscar y asignar ────────────────────────────────────────────────
  Widget _buildSearchTab() {
    return Column(
      children: [
        Container(
          color: _navy,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, matrícula o núm. empleado…',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon:
                  Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: Colors.white.withOpacity(0.8)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _searching
              ? const Center(child: CircularProgressIndicator())
              : _searchCtrl.text.isEmpty
                  ? _buildSearchHint()
                  : _searchResults.isEmpty
                      ? const Center(
                          child: Text('Sin resultados',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) =>
                              _buildUserTile(_searchResults[i],
                                  onAction: () =>
                                      _confirmAndAssign(_searchResults[i])),
                        ),
        ),
      ],
    );
  }

  // ── Tab 2: Admins actuales ─────────────────────────────────────────────────
  Widget _buildAdminsTab() {
    return RefreshIndicator(
      onRefresh: _loadAdmins,
      child: _loadingAdmins
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.admin_panel_settings,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No hay administradores registrados.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Desliza hacia abajo para recargar.',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _admins.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => _buildAdminTile(_admins[i]),
                ),
    );
  }

  // ── Tiles ──────────────────────────────────────────────────────────────────
  Widget _buildUserTile(
    Map<String, dynamic> user, {
    required VoidCallback onAction,
  }) {
    final nombre = '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}'.trim();
    final rolActual = (user['nombre_rol'] ?? '').toString();
    final esAdmin = rolActual == 'Admin';
    final matricula = user['matricula'];
    final numEmpleado = user['num_empleado'];
    final ident = matricula != null
        ? 'Matrícula: $matricula'
        : numEmpleado != null
            ? 'Empleado: $numEmpleado'
            : user['correo'] ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: esAdmin ? _gold : _navy,
        child: Icon(
          esAdmin ? Icons.verified_user : Icons.person,
          color: Colors.white,
          size: 22,
        ),
      ),
      title: Text(nombre,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ident, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          _rolBadge(rolActual, esAdmin),
        ],
      ),
      isThreeLine: true,
      trailing: esAdmin
          ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
          : ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Asignar\nAdmin',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11)),
            ),
    );
  }

  Widget _buildAdminTile(Map<String, dynamic> user) {
    final nombre = '${user['nombre'] ?? ''} ${user['apellido'] ?? ''}'.trim();
    final numEmpleado = user['num_empleado'];
    final ident = numEmpleado != null
        ? 'Empleado: $numEmpleado'
        : user['correo'] ?? '';

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: _gold,
        child: Icon(Icons.verified_user, color: Colors.white, size: 22),
      ),
      title: Text(nombre,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ident, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          _rolBadge('Admin', true),
        ],
      ),
      isThreeLine: true,
      trailing: OutlinedButton(
        onPressed: () => _confirmAndRevoke(user),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Revocar',
            style: TextStyle(fontSize: 11)),
      ),
    );
  }

  // ── Utils ──────────────────────────────────────────────────────────────────
  Widget _rolBadge(String rol, bool esAdmin) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: esAdmin ? Colors.amber.shade100 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        rol,
        style: TextStyle(
          fontSize: 11,
          color: esAdmin ? Colors.orange.shade800 : Colors.blue.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_accounts_rounded,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Busca un usuario para asignarle\nel rol de Administrador.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  static Widget _warningBox(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Diálogo selector de rol ────────────────────────────────────────────────
class _RolePickerDialog extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> roles;
  final Color navy;

  const _RolePickerDialog({
    required this.userName,
    required this.roles,
    required this.navy,
  });

  @override
  State<_RolePickerDialog> createState() => _RolePickerDialogState();
}

class _RolePickerDialogState extends State<_RolePickerDialog> {
  int? _selectedRolId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Seleccionar nuevo rol'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Elige el rol al que regresará ${widget.userName}:',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          ...widget.roles.map((r) {
            final id = r['id_rol'] as int;
            final nombre = r['nombre_rol'].toString();
            return RadioListTile<int>(
              dense: true,
              activeColor: widget.navy,
              title: Text(nombre),
              value: id,
              groupValue: _selectedRolId,
              onChanged: (v) => setState(() => _selectedRolId = v),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _selectedRolId == null
              ? null
              : () => Navigator.pop(context, _selectedRolId),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
