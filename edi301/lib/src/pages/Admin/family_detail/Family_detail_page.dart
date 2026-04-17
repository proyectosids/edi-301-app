import 'package:edi301/services/search_api.dart' show UserMini;
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/services/members_api.dart';
import 'package:edi301/services/publicaciones_api.dart';
import 'package:edi301/src/pages/Admin/add_alumns/add_alumns_controller.dart';
import 'package:edi301/src/pages/Admin/reportes/reporte_familia_individual_service.dart';
import 'package:edi301/src/pages/Admin/family_detail/edit_family_page.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

class FamilyDetailPage extends StatefulWidget {
  const FamilyDetailPage({super.key});

  @override
  State<FamilyDetailPage> createState() => _FamilyDetailPageState();
}

class _FamilyDetailPageState extends State<FamilyDetailPage>
    with SingleTickerProviderStateMixin {
  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final SocketService _socketService = SocketService();
  final _membersApi = MembersApi();
  final _pubApi = PublicacionesApi();
  final _reporteService = ReporteFamiliaIndividualService();
  final _familiaApi = FamiliaApi();

  bool _realtimeSetup = false;
  int? _rtFamilyId;
  Family? _family;
  bool _isLoading = true;
  String? _error;

  // Publicaciones
  List<dynamic> _posts = [];
  bool _postsLoading = false;

  // Tab controller
  late TabController _tabController;

  // PDF export state
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      final args = ModalRoute.of(context)!.settings.arguments;
      int? familyId;
      if (args is Family) {
        familyId = args.id;
      } else if (args is int) {
        familyId = args;
      }
      if (familyId != null) {
        final int fid = familyId;
        if (!_realtimeSetup || _rtFamilyId != familyId) {
          _socketService.initSocket();
          _socketService.joinFamilyRoom(fid);
          for (final ev in [
            'miembro_agregado',
            'miembro_eliminado',
            'miembros_actualizados',
            'nuevos_alumnos_asignados',
          ]) {
            _socketService.socket.off(ev);
            _socketService.socket.on(ev, (_) {
              if (mounted) _fetchFamilyDetails(fid);
            });
          }
          _realtimeSetup = true;
          _rtFamilyId = fid;
        }
        _fetchFamilyDetails(fid);
      } else {
        setState(() {
          _isLoading = false;
          _error = 'ID de familia no encontrado.';
        });
      }
    }
  }

  Future<void> _fetchFamilyDetails(int familyId) async {
    try {
      final api = FamiliaApi();
      final familyData = await api.getById(familyId);
      if (mounted) {
        setState(() {
          _family = Family.fromJson(familyData!);
          _isLoading = false;
        });
      }
      await _fetchPosts(familyId);
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _fetchPosts(int familyId) async {
    setState(() => _postsLoading = true);
    try {
      final res = await _pubApi.getPostsFamilia(familyId, limit: 100);
      final data = res['data'] as List? ?? [];
      if (mounted) setState(() => _posts = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_family == null || _exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      await _reporteService.generarYAbrir(_family!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar el PDF. Inténtalo de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<bool> _showDeleteDialog(String memberName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Quitar a $memberName de esta familia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDeleteMember(FamilyMember member) async {
    final confirmed = await _showDeleteDialog(member.fullName);
    if (!confirmed || !mounted) return;
    try {
      await _membersApi.removeMember(member.idMiembro);
      setState(() {
        if (member.tipoMiembro == 'HIJO') {
          _family!.householdChildren.removeWhere(
            (m) => m.idMiembro == member.idMiembro,
          );
        } else {
          _family!.assignedStudents.removeWhere(
            (m) => m.idMiembro == member.idMiembro,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Miembro quitado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  // ── URL helper ───────────────────────────────────────────────────────────────
  String _absUrl(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '';
    var s = raw.trim();
    if (s.startsWith('http')) return s;
    if (!s.startsWith('/')) s = '/$s';
    return '${ApiHttp.baseUrl}$s';
  }

  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error!, textAlign: TextAlign.center)),
      );
    }

    final fam = _family!;

    return Scaffold(
      appBar: AppBar(
        title: Text(fam.familyName),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [
          // PDF export button
          _exportingPdf
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Exportar reporte PDF',
                  onPressed: _exportPdf,
                ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Integrantes'),
            Tab(icon: Icon(Icons.photo_library), text: 'Publicaciones'),
            Tab(icon: Icon(Icons.image), text: 'Fotos'),
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildIntegrantesTab(fam),
              _buildPublicacionesTab(),
              _buildFotosTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Acciones de familia (desactivar, eliminar, editar) ─────────────────────

  Future<void> _handleDeactivate() async {
    final fam = _family!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Desactivar familia?'),
        content: Text(
            'La familia "${fam.familyName}" quedará inactiva pero sus datos se conservarán.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _familiaApi.deactivateFamily(fam.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Familia desactivada.'),
            backgroundColor: Colors.orange),
      );
      Navigator.pop(context, true); // Volver al listado
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _handlePermanentDelete() async {
    final fam = _family!;
    // Doble confirmación para una acción irreversible
    final first = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar permanentemente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Eliminar la familia "${fam.familyName}" de forma permanente?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción no se puede deshacer. Se borrarán todos los miembros y registros relacionados.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // Segunda confirmación
    final second = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirma la eliminación'),
        content: const Text(
            '¿Seguro? Esta es una acción irreversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    try {
      await _familiaApi.permanentDeleteFamily(fam.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Familia eliminada permanentemente.'),
            backgroundColor: Colors.red),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _handleEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditFamilyPage(family: _family!),
      ),
    );
    if (updated == true && mounted) {
      setState(() => _isLoading = true);
      await _fetchFamilyDetails(_family!.id!);
    }
  }

  // ── Tab 1: Integrantes (original content) ──────────────────────────────────
  Widget _buildIntegrantesTab(Family fam) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(f: fam),
        const SizedBox(height: 16),
        _Section(
          title: 'Hijos en casa',
          items: fam.householdChildren,
          emptyText: 'Sin hijos registrados.',
          leadingIcon: Icons.family_restroom,
          buildTrailing: (child) => IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _handleDeleteMember(child),
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Alumnos asignados',
          items: fam.assignedStudents,
          emptyText: 'Sin alumnos asignados.',
          leadingIcon: Icons.school,
          buildTrailing: (student) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.pushNamed(
                  context,
                  'student_detail',
                  arguments: student.idUsuario,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _handleDeleteMember(student),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Agregar alumnos a esta familia'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () async {
            final bool? didAdd = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => _AddAlumnsSheet(family: fam),
            );
            if (didAdd == true && mounted) {
              setState(() => _isLoading = true);
              await _fetchFamilyDetails(fam.id!);
            }
          },
        ),

        // ── Admin actions ──────────────────────────────────────────────────
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),

        // Editar
        OutlinedButton.icon(
          icon: const Icon(Icons.edit, color: _primary),
          label: const Text('Editar familia',
              style: TextStyle(color: _primary)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _handleEdit,
        ),

        const SizedBox(height: 8),

        // Desactivar
        OutlinedButton.icon(
          icon: const Icon(Icons.visibility_off, color: Colors.orange),
          label: const Text('Desactivar familia',
              style: TextStyle(color: Colors.orange)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.orange),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _handleDeactivate,
        ),

        const SizedBox(height: 8),

        // Eliminar permanentemente
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          label: const Text('Eliminar permanentemente',
              style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _handlePermanentDelete,
        ),
      ],
    );
  }

  // ── Tab 2: Publicaciones ───────────────────────────────────────────────────
  Widget _buildPublicacionesTab() {
    if (_postsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No hay publicaciones de esta familia.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _posts.length,
      itemBuilder: (_, i) => _PostCard(post: _posts[i], absUrl: _absUrl),
    );
  }

  // ── Tab 3: Fotos (publicaciones con imagen) ────────────────────────────────
  Widget _buildFotosTab() {
    if (_postsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final fotos = _posts.where((p) {
      final img = (p['url_imagen'] ?? '').toString();
      return img.isNotEmpty && img != 'null';
    }).toList();

    if (fotos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No hay fotos publicadas.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: fotos.length,
      itemBuilder: (_, i) {
        final post = fotos[i];
        final imgUrl = _absUrl((post['url_imagen'] ?? '').toString());
        final autor = '${post['nombre'] ?? ''} ${post['apellido'] ?? ''}'
            .trim();
        final fecha = _formatDate(post['created_at']);
        return GestureDetector(
          onTap: () => _showImageDetail(
            context,
            imgUrl,
            autor,
            fecha,
            (post['mensaje'] ?? '').toString(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      autor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  void _showImageDetail(
    BuildContext context,
    String url,
    String autor,
    String fecha,
    String mensaje,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white, size: 60),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (autor.isNotEmpty)
                    Text(
                      autor,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (fecha.isNotEmpty)
                    Text(
                      fecha,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  if (mensaje.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      mensaje,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets (unchanged from original) ─────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.f});
  final Family f;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.familyName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Padre: ${f.fatherName ?? "No asignado"}'),
            Text('Madre: ${f.motherName ?? "No asignada"}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.home, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Residencia: ${f.residence}',
                  style: TextStyle(
                    color: f.residence == 'Interna' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (f.descripcion != null && f.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                f.descripcion!,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.emptyText,
    required this.buildTrailing,
    required this.leadingIcon,
  });
  final String title;
  final List<FamilyMember> items;
  final String emptyText;
  final Widget Function(FamilyMember) buildTrailing;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                emptyText,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          else
            ...items.map(
              (e) => ListTile(
                dense: true,
                leading: Icon(leadingIcon),
                title: Text(e.fullName),
                trailing: buildTrailing(e),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Post card widget ───────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.absUrl});
  final dynamic post;
  final String Function(String?) absUrl;

  @override
  Widget build(BuildContext context) {
    final autor = '${post['nombre'] ?? ''} ${post['apellido'] ?? ''}'.trim();
    final mensaje = (post['mensaje'] ?? '').toString();
    final imgUrl = absUrl((post['url_imagen'] ?? '').toString());
    final hasImg = imgUrl.isNotEmpty;
    final fecha = _fmt(post['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImg)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                imgUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: Color.fromRGBO(19, 67, 107, 1),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        autor.isEmpty ? 'Desconocido' : autor,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      fecha,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                if (mensaje.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(mensaje, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}

// ── Add alumns sheet (unchanged) ───────────────────────────────────────────────
class _AddAlumnsSheet extends StatefulWidget {
  final Family family;
  const _AddAlumnsSheet({required this.family});
  @override
  State<_AddAlumnsSheet> createState() => _AddAlumnsSheetState();
}

class _AddAlumnsSheetState extends State<_AddAlumnsSheet> {
  final _controller = AddAlumnsController();
  final _alumnSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.init(context);
    _controller.selectFamily(widget.family);
  }

  @override
  void dispose() {
    _controller.dispose();
    _alumnSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asignar alumnos a:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            widget.family.familyName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color.fromRGBO(19, 67, 107, 1),
            ),
          ),
          const SizedBox(height: 20),
          _buildAlumnSelector(),
          const SizedBox(height: 20),
          _buildSelectedAlumnsList(),
          const SizedBox(height: 30),
          _buildSaveButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAlumnSelector() {
    return Column(
      children: [
        TextField(
          controller: _alumnSearchCtrl,
          decoration: InputDecoration(
            labelText: 'Buscar alumno por matrícula o nombre',
            prefixIcon: const Icon(Icons.person_search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: _controller.searchAlumns,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: _controller.alumnSearchResults,
          builder: (context, results, _) {
            if (results.isEmpty) return const SizedBox.shrink();
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: Card(
                elevation: 2,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final a = results[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school)),
                      title: Text('${a.nombre} ${a.apellido}'),
                      subtitle: Text('Matrícula: ${a.matricula ?? 'N/A'}'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.green,
                        ),
                        onPressed: () {
                          _controller.addAlumn(a);
                          _alumnSearchCtrl.clear();
                          _controller.searchAlumns('');
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSelectedAlumnsList() {
    return ValueListenableBuilder<List<UserMini>>(
      valueListenable: _controller.selectedAlumns,
      builder: (_, alumns, __) {
        if (alumns.isEmpty) {
          return const Center(
            child: Text(
              'Ningún alumno añadido todavía.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return SizedBox(
          height: 100,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: alumns
                  .map(
                    (a) => Chip(
                      label: Text('${a.nombre} ${a.apellido}'),
                      avatar: const Icon(Icons.school),
                      onDeleted: () => _controller.removeAlumn(a),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (_, loading, __) => ElevatedButton.icon(
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(loading ? 'GUARDANDO...' : 'GUARDAR ASIGNACIONES'),
          onPressed: loading ? null : _controller.saveAssignments,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
