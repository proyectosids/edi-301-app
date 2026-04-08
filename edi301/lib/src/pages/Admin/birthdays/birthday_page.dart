import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edi301/services/users_api.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:http/http.dart' as http;

// ─── Modelo ligero para cumpleañeros ─────────────────────────────────────────
class _Cumpleanero {
  final int idUsuario;
  final String nombre;
  final String apellido;
  final String? fotoPerfil;
  final String? fechaNacimiento;
  final int? diasRestantes; // para próximos
  final int? diasCumplidos; // para pasados

  _Cumpleanero.fromJson(Map<String, dynamic> j)
    : idUsuario = j['id_usuario'] ?? 0,
      nombre = j['nombre'] ?? '',
      apellido = j['apellido'] ?? '',
      fotoPerfil = j['url_foto_perfil'] ?? j['foto_perfil'],
      fechaNacimiento = j['fecha_nacimiento'],
      diasRestantes = j['dias_para_cumple'] as int?,
      diasCumplidos = j['dias_cumplidos'] as int?;

  String get nombreCompleto => '$nombre $apellido'.trim();
}

// ─── BirthdaysPage ────────────────────────────────────────────────────────────
class BirthdaysPage extends StatefulWidget {
  const BirthdaysPage({super.key});
  @override
  State<BirthdaysPage> createState() => _BirthdaysPageState();
}

class _BirthdaysPageState extends State<BirthdaysPage>
    with SingleTickerProviderStateMixin {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final ApiHttp _http = ApiHttp();
  late TabController _tab;

  // Data per tab
  List<_Cumpleanero> _pasados = [];
  List<_Cumpleanero> _hoy = [];
  List<_Cumpleanero> _proximos = [];

  bool _loadingPasados = true;
  bool _loadingHoy = true;
  bool _loadingProximos = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1);
    _cargar('pasados');
    _cargar('hoy');
    _cargar('proximos');
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargar(String rango) async {
    try {
      final res = await _http.getJson(
        '/api/usuarios/cumpleanos',
        query: {'rango': rango},
      );
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((j) => _Cumpleanero.fromJson(j))
            .toList();
        if (!mounted) return;
        setState(() {
          if (rango == 'pasados') {
            _pasados = list;
            _loadingPasados = false;
          }
          if (rango == 'hoy') {
            _hoy = list;
            _loadingHoy = false;
          }
          if (rango == 'proximos') {
            _proximos = list;
            _loadingProximos = false;
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (rango == 'pasados') _loadingPasados = false;
        if (rango == 'hoy') _loadingHoy = false;
        if (rango == 'proximos') _loadingProximos = false;
      });
    }
  }

  void _irAlChat(_Cumpleanero u) {
    Navigator.pushNamed(
      context,
      'chat',
      arguments: {
        'id_usuario': u.idUsuario,
        'nombre': u.nombreCompleto,
        'foto_perfil': u.fotoPerfil,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cumpleaños 🎂'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Foto de felicitación',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _ImagenFelicitacionPage(),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Pasados', icon: Icon(Icons.history, size: 18)),
            Tab(text: 'Hoy', icon: Icon(Icons.cake, size: 18)),
            Tab(text: 'Próximos', icon: Icon(Icons.upcoming, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildTab(_pasados, _loadingPasados, 'pasados'),
          _buildTab(_hoy, _loadingHoy, 'hoy'),
          _buildTab(_proximos, _loadingProximos, 'proximos'),
        ],
      ),
    );
  }

  Widget _buildTab(List<_Cumpleanero> lista, bool loading, String rango) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cake_outlined,
              size: 72,
              color: rango == 'hoy' ? Colors.pink[200] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              rango == 'pasados'
                  ? 'Sin cumpleaños recientes.'
                  : rango == 'hoy'
                  ? 'Hoy no hay cumpleaños. 🎈'
                  : 'No hay próximos cumpleaños.',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(rango),
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: lista.length,
        itemBuilder: (_, i) => _buildCard(lista[i], rango),
      ),
    );
  }

  Widget _buildCard(_Cumpleanero u, String rango) {
    final isHoy = rango == 'hoy';
    final isPasado = rango == 'pasados';
    final isProximo = rango == 'proximos';

    Color borderColor;
    Color bgColor;
    String badge;

    if (isHoy) {
      borderColor = Colors.pinkAccent;
      bgColor = Colors.pink.shade50;
      badge = '🎉 ¡Hoy es su cumpleaños!';
    } else if (isPasado) {
      borderColor = Colors.grey.shade400;
      bgColor = Colors.grey.shade50;
      final dias = u.diasCumplidos ?? 0;
      badge = dias == 1 ? 'Cumpleaños ayer 🎂' : 'Hace $dias días 🎂';
    } else {
      borderColor = Colors.blue.shade300;
      bgColor = Colors.blue.shade50;
      final dias = u.diasRestantes ?? 0;
      badge = dias == 1 ? '¡Mañana es su cumpleaños! 🎈' : 'En $dias días 🎈';
    }

    final fotoUrl = u.fotoPerfil != null
        ? (u.fotoPerfil!.startsWith('http')
              ? u.fotoPerfil!
              : '${ApiHttp.baseUrl}${u.fotoPerfil}')
        : null;

    return Card(
      elevation: isHoy ? 5 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isHoy ? 2 : 1),
      ),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: borderColor.withOpacity(0.2),
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              child: fotoUrl == null
                  ? Text(
                      u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 24, color: borderColor),
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.nombreCompleto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge,
                    style: TextStyle(
                      fontSize: 12,
                      color: borderColor,
                      fontWeight: isHoy ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Chat button (only for today)
            if (isHoy)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.pink),
                tooltip: 'Enviar felicitación',
                onPressed: () => _irAlChat(u),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Pantalla de configuración de imagen de felicitación ─────────────────────
class _ImagenFelicitacionPage extends StatefulWidget {
  const _ImagenFelicitacionPage();
  @override
  State<_ImagenFelicitacionPage> createState() =>
      _ImagenFelicitacionPageState();
}

class _ImagenFelicitacionPageState extends State<_ImagenFelicitacionPage> {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final ApiHttp _http = ApiHttp();
  String? _imagenActual;
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _cargarImagenActual();
  }

  Future<void> _cargarImagenActual() async {
    try {
      final res = await _http.getJson('/api/usuarios/cumpleanos/imagen');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _imagenActual = data['imagen'];
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      // Upload image to backend
      // Un solo request: sube imagen y actualiza config
      final streamedResponse = await _http.multipart(
        '/api/usuarios/cumpleanos/imagen',
        method: 'POST',
        files: [await http.MultipartFile.fromPath('imagen', picked.path)],
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final nuevaUrl = (data['url'] ?? data['imagen'] ?? '').toString();
        if (nuevaUrl.isNotEmpty) setState(() => _imagenActual = nuevaUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Imagen actualizada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foto de Felicitación'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Description
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Esta imagen se usará automáticamente en las publicaciones de felicitación que genera el sistema cuando es el cumpleaños de un integrante.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Current image preview
                  const Text(
                    'Imagen actual:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.grey.shade100,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imagenActual != null && _imagenActual!.isNotEmpty
                        ? Image.network(
                            _imagenActual!.startsWith('http')
                                ? _imagenActual!
                                : '${ApiHttp.baseUrl}$_imagenActual',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 60,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 56,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Sin imagen configurada',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),

                  // Change button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.photo_library,
                              color: Colors.white,
                            ),
                      label: Text(
                        _uploading ? 'Subiendo...' : 'Cambiar imagen',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _uploading ? null : _seleccionarImagen,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
