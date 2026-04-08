import 'dart:async';
import 'dart:convert';
import 'package:edi301/services/estados_api.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/src/pages/Perfil/perfil_widgets.dart';
import 'package:edi301/auth/token_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:edi301/tools/media_picker.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  bool _isAlumno = false;
  int? _userId;

  final EstadosApi _estadosApi = EstadosApi();
  final ApiHttp _http = ApiHttp();
  final TokenStorage _storage = TokenStorage();

  Map<String, dynamic> data = {
    'name': '—',
    'matricula': '—',
    'numEmpleado': '—',
    'docLabel': 'Matrícula',
    'docValue': '—',
    'phone': '—',
    'email': '—',
    'residence': '—',
    'family': '—',
    'address': '—',
    'birthday': '—',
    'avatarUrl': '',
    'status': 'Activo',
    'grade': '—',
  };

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String _formatFecha(String? raw) {
    if (raw == null || raw.isEmpty || raw == '—') return '—';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw.split('T')[0];
    }
  }

  String s(String k, [String d = '—']) {
    final v = data[k];
    if (v == null) return d;
    final t = v.toString().trim();
    return t.isEmpty ? d : t;
  }

  bool get isInternal => s('residence').toLowerCase().startsWith('intern');

  Color _statusColor(String st) {
    final low = st.toLowerCase();
    if (low.contains('inac') || low.contains('baja') || low.contains('suspend'))
      return Colors.red;
    if (low.contains('pend') || low.contains('proce')) return Colors.orange;
    return Colors.green;
  }

  // ── Profile photo upload ─────────────────────────────────────────────────
  Future<void> _pickAndUploadProfile() async {
    if (_userId == null || _userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar el usuario')),
      );
      return;
    }
    final XFile? image = await MediaPicker.pickImage(context);
    if (image == null) return;
    setState(() => _loading = true);
    try {
      final stream = await _http.multipart(
        '/api/usuarios/$_userId',
        method: 'PUT',
        files: [await http.MultipartFile.fromPath('foto', image.path)],
        fields: {'nombre': data['name'].toString().split(' ')[0]},
      );
      if (stream.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchFromServer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al subir la imagen'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────
  Future<void> _hydrateFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user');
      if (raw == null) return;
      final u = jsonDecode(raw) as Map<String, dynamic>;
      final tipo = (u['tipo_usuario'] ?? u['TipoUsuario'] ?? '').toString();

      int id = 0;
      for (final k in ['id_usuario', 'IdUsuario', 'id']) {
        if (u[k] != null) {
          id = int.tryParse(u[k].toString()) ?? 0;
          break;
        }
      }

      String nombre = (u['nombre'] ?? u['Nombre'] ?? '').toString();
      String apellido = (u['apellido'] ?? u['Apellido'] ?? '').toString();
      String avatar = (u['foto_perfil'] ?? u['FotoPerfil'] ?? '').toString();
      if (avatar.isNotEmpty && !avatar.startsWith('http')) {
        avatar = '${ApiHttp.baseUrl}$avatar';
      }

      final isAlumno = tipo.toUpperCase() == 'ALUMNO';
      final matricula = (u['matricula'] ?? u['Matricula'])?.toString();
      final numEmpleado =
          (u['num_empleado'] ?? u['numEmpleado'] ?? u['NumEmpleado'])
              ?.toString();

      setState(() {
        _isAlumno = isAlumno;
        _userId = id;
        data = {
          ...data,
          'name': '$nombre $apellido'.trim().isEmpty
              ? '—'
              : '$nombre $apellido'.trim(),
          'email': (u['correo'] ?? u['E_mail'] ?? '—').toString(),
          'matricula': matricula ?? '—',
          'numEmpleado': numEmpleado ?? '—',
          'docLabel': isAlumno ? 'Matrícula' : 'No. Empleado',
          'docValue': isAlumno ? (matricula ?? '—') : (numEmpleado ?? '—'),
          'phone': (u['telefono'] ?? '—').toString(),
          'residence': (u['residencia'] ?? '—').toString(),
          'address': (u['direccion'] ?? '—').toString(),
          'birthday': _formatFecha(
            u['fecha_nacimiento'] ?? u['Fecha_Nacimiento'],
          ),
          'avatarUrl': avatar.isNotEmpty ? avatar : data['avatarUrl'],
          'status': (u['estado'] ?? 'Activo').toString(),
          'grade': (u['carrera'] ?? '—').toString(),
          'family': (u['nombre_familia'] ?? '—').toString(),
        };
      });
    } catch (_) {}
  }

  Future<void> _fetchFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user');
      if (raw == null) return;
      final uLocal = jsonDecode(raw) as Map<String, dynamic>;
      final id = uLocal['IdUsuario'] ?? uLocal['id_usuario'] ?? _userId;
      if (id == null) return;

      final res = await _http.getJson('/api/usuarios/$id');
      if (res.statusCode >= 400) return;
      final x = jsonDecode(res.body) as Map<String, dynamic>;

      String nombre = (x['nombre'] ?? x['Nombre'] ?? uLocal['nombre'] ?? '')
          .toString();
      String apellido =
          (x['apellido'] ?? x['Apellido'] ?? uLocal['apellido'] ?? '')
              .toString();
      String avatar = (x['foto_perfil'] ?? x['FotoPerfil'] ?? '').toString();
      if (avatar.isNotEmpty && !avatar.startsWith('http')) {
        avatar = '${ApiHttp.baseUrl}$avatar';
      }

      final tipo = (x['tipo_usuario'] ?? x['TipoUsuario'] ?? '')
          .toString()
          .toUpperCase();
      final isAlumno = tipo == 'ALUMNO';
      final matricula = (x['matricula'] ?? x['Matricula'] ?? data['matricula'])
          ?.toString();
      final numEmpleado =
          (x['num_empleado'] ??
                  x['numEmpleado'] ??
                  x['NumEmpleado'] ??
                  data['numEmpleado'])
              ?.toString();

      setState(() {
        _isAlumno = isAlumno;
        data = {
          ...data,
          'name': '$nombre $apellido'.trim().isNotEmpty
              ? '$nombre $apellido'.trim()
              : data['name'],
          'email': (x['correo'] ?? x['E_mail'] ?? data['email']).toString(),
          'matricula': matricula ?? '—',
          'numEmpleado': numEmpleado ?? '—',
          'docLabel': isAlumno ? 'Matrícula' : 'No. Empleado',
          'docValue': isAlumno ? (matricula ?? '—') : (numEmpleado ?? '—'),
          'phone': (x['telefono'] ?? data['phone']).toString(),
          'residence': (x['residencia'] ?? data['residence']).toString(),
          'address': (x['direccion'] ?? data['address']).toString(),
          'birthday': _formatFecha(
            x['fecha_nacimiento'] ?? x['Fecha_Nacimiento'] ?? data['birthday'],
          ),
          'avatarUrl': avatar.isNotEmpty ? avatar : data['avatarUrl'],
          'status': (x['estado'] ?? data['status']).toString(),
          'statusColorHex': (x['color_estado'] ?? '#13436B').toString(),
          'grade': (x['carrera'] ?? data['grade']).toString(),
          'family': (x['nombre_familia'] ?? data['family']).toString(),
        };
      });
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    await _hydrateFromLocal();
    await _fetchFromServer();
    if (mounted) setState(() => _loading = false);
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _http.postJson('/api/auth/logout');
    } catch (_) {}
    await _storage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('login', (_) => false);
    }
  }

  // ── Estado selector ──────────────────────────────────────────────────────
  void _showEstadoSelector() async {
    if (!_isAlumno || _userId == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final catalogo = await _estadosApi.getCatalogo();
    if (!mounted) return;
    Navigator.pop(context);
    if (catalogo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los estados')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Actualizar mi estado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: catalogo.length,
              itemBuilder: (_, i) {
                final item = catalogo[i];
                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 16,
                    color: hexToColor(item['color'] ?? '#000000'),
                  ),
                  title: Text(item['descripcion']),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _updateEstado(item['id_cat_estado']);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEstado(int idCatEstado) async {
    setState(() => _loading = true);
    final ok = await _estadosApi.updateEstado(_userId!, idCatEstado);
    if (ok) {
      await _fetchFromServer();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado'),
            backgroundColor: Colors.green,
          ),
        );
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar estado'),
            backgroundColor: Colors.red,
          ),
        );
    }
    setState(() => _loading = false);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              title: const Text(
                'Mi Perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: _primary,
              automaticallyImplyLeading: false,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  tooltip: 'Cerrar sesión',
                  onPressed: _handleLogout,
                ),
              ],
            ),

            // ── Content ──────────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Header card
                    HeaderCard(
                      name: s('name'),
                      family: s('family'),
                      residence: s('residence'),
                      status: s('status', 'Activo'),
                      avatarUrl: s('avatarUrl'),
                      primary: _primary,
                      statusColor: data['statusColorHex'] != null
                          ? hexToColor(data['statusColorHex'])
                          : _statusColor(s('status', 'Activo')),
                      onEditAvatar: _pickAndUploadProfile,
                      onTapStatus: _isAlumno ? _showEstadoSelector : null,
                    ),
                    const SizedBox(height: 16),

                    // Academic info
                    SectionCard(
                      title: 'Información Académica',
                      primary: _primary,
                      icon: Icons.school_rounded,
                      children: [
                        InfoRow(
                          icon: Icons.badge_outlined,
                          label: s('docLabel'),
                          value: s('docValue'),
                          accent: _primary,
                        ),
                        InfoRow(
                          icon: Icons.menu_book_rounded,
                          label: 'Programa',
                          value: s('grade'),
                          accent: _primary,
                        ),
                        InfoRow(
                          icon: Icons.cake_rounded,
                          label: 'Cumpleaños',
                          value: s('birthday'),
                          accent: const Color(0xFFE91E63),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Contact info
                    SectionCard(
                      title: 'Contacto',
                      primary: _primary,
                      icon: Icons.contact_phone_rounded,
                      children: [
                        InfoRow(
                          icon: Icons.call_rounded,
                          label: 'Teléfono',
                          value: s('phone'),
                          accent: const Color(0xFF2E7D32),
                        ),
                        InfoRow(
                          icon: Icons.mail_rounded,
                          label: 'Correo',
                          value: s('email'),
                          accent: _primary,
                        ),
                        if (!isInternal)
                          InfoRow(
                            icon: Icons.home_rounded,
                            label: 'Dirección',
                            value: s('address'),
                            accent: const Color(0xFF5D4037),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Logout button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _handleLogout,
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
