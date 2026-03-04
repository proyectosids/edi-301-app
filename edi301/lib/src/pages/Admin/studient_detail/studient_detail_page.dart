import 'dart:convert';
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:edi301/tools/fullscreen_image_viewer.dart';

class StudentDetailPage extends StatefulWidget {
  const StudentDetailPage({super.key});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  final ApiHttp _http = ApiHttp();
  Map<String, dynamic> _data = {};
  bool _isLoading = true;
  String? _error;
  int? _studentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      final args = ModalRoute.of(context)!.settings.arguments;

      if (args is int) {
        _studentId = args;
        _fetchStudentDetails(args);
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Error: No se recibió un ID de estudiante válido.';
        });
      }
    }
  }

  Future<void> _fetchStudentDetails(int id) async {
    try {
      final res = await _http.getJson('/api/usuarios/$id');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final backendData = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _data = backendData;
          _isLoading = false;
        });
      } else {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al cargar datos: ${e.toString()}';
        });
      }
    }
  }

  String _absUrl(String raw) {
    if (raw.isEmpty || raw == 'null') return '';
    var s = raw.trim();

    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    s = s.replaceAll('\\', '/');

    final idxPublic = s.indexOf('public/uploads/');
    if (idxPublic != -1) {
      s = s.substring(idxPublic + 'public'.length); // deja "/uploads/.."
    }

    final idxUploads = s.indexOf('/uploads/');
    if (idxUploads != -1) {
      s = s.substring(idxUploads);
    } else if (s.startsWith('uploads/')) {
      s = '/$s';
    } else if (!s.startsWith('/')) {
      s = '/$s';
    }

    return '${ApiHttp.baseUrl}$s';
  }

  String _formatFecha(String? fechaRaw) {
    if (fechaRaw == null || fechaRaw.isEmpty || fechaRaw == '—') return '—';
    try {
      DateTime fecha = DateTime.parse(fechaRaw);
      return DateFormat('dd/MM/yyyy').format(fecha);
    } catch (e) {
      return fechaRaw.split('T')[0];
    }
  }

  String s(String key, [String d = '—']) {
    final v = _data[key];
    if (v == null) return d;
    final t = v.toString().trim();
    return t.isEmpty ? d : t;
  }

  Color statusColor(String st) {
    final low = st.toLowerCase();
    if (low.contains('inac') ||
        low.contains('baja') ||
        low.contains('suspend')) {
      return Colors.red;
    }
    if (low.contains('pend') || low.contains('proce')) {
      return Colors.orange;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primary,
        title: const Text('Detalle del alumno'),
      ),
      body: ResponsiveContent(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : _buildContent(context, theme, primary),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Color primary) {
    final name = ('${s('nombre')} ${s('apellido')}').trim();
    final phone = s('telefono');
    final matricula = s('matricula');
    final birthday = _formatFecha(s('fecha_nacimiento'));
    final status = s('estado', 'Activo');
    final grade = s('carrera');
    final email = s('correo');
    final rawAddr = s('direccion');
    final docLabel = 'Matrícula';
    final docValue = matricula;
    final familyName = s('nombre_familia');
    final residence = s('residencia', 'Externa');
    final bool isInternal = residence.toLowerCase().startsWith('intern');
    final bool showAddress = !isInternal && rawAddr != '—';
    final fotoRaw = s('foto_perfil', '');
    final fotoAbs = _absUrl(fotoRaw);
    final ImageProvider avatarProvider = fotoAbs.isNotEmpty
        ? NetworkImage(fotoAbs)
        : const AssetImage('assets/img/7141724.png');

    final bool hasPhoto = fotoAbs.isNotEmpty;

    final heroTag = 'student_avatar_${_studentId}_${fotoAbs.hashCode}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: hasPhoto
                        ? () {
                            FullScreenImageViewer.open(
                              context,
                              imageProvider: avatarProvider,
                              heroTag: heroTag,
                            );
                          }
                        : null,
                    child: Hero(
                      tag: heroTag,
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: primary.withOpacity(.12),
                        backgroundImage: avatarProvider,
                        child: hasPhoto
                            ? null
                            : const Icon(Icons.person, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: [
                            Chip(
                              label: Text(status),
                              backgroundColor: statusColor(
                                status,
                              ).withOpacity(.15),
                              labelStyle: TextStyle(
                                color: statusColor(status),
                                fontWeight: FontWeight.w600,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text('Residencia: $residence'),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (familyName != '—')
                              Chip(
                                label: Text(' $familyName'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Contacto',
            primary: primary,
            children: [
              _InfoTile(Icons.badge_outlined, docLabel, docValue),
              _InfoTile(Icons.call_outlined, 'Teléfono', phone),
              _InfoTile(Icons.mail_outline, 'Correo', email),
              if (showAddress)
                _InfoTile(Icons.home_outlined, 'Dirección', rawAddr),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Académico',
            primary: primary,
            children: [
              _InfoTile(Icons.cake_outlined, 'Cumpleaños', birthday),
              _InfoTile(Icons.school_outlined, 'Programa', grade),
              _InfoTile(Icons.family_restroom, 'Familia', familyName),
            ],
          ),
          const SizedBox(height: 12),

          const SizedBox(height: 8),
          if (_studentId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text('Ver familia'),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color primary;
  const _SectionCard({
    required this.title,
    required this.children,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile(this.icon, this.label, this.value, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: content,
            )
          : content,
    );
  }
}
