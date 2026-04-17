import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_controller.dart';
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:edi301/core/api_error.dart';

class GetFamilyPage extends StatefulWidget {
  const GetFamilyPage({super.key});

  @override
  State<GetFamilyPage> createState() => _GetFamilyPageState();
}

class _GetFamilyPageState extends State<GetFamilyPage> {
  static const _navy = Color.fromRGBO(19, 67, 107, 1);

  final GetFamilyController _controller = GetFamilyController();
  final FamiliaApi _familiaApi = FamiliaApi();
  final unescape = HtmlUnescape();
  final TextEditingController _searchCtrl = TextEditingController();

  // Toggle activas / inactivas
  bool _showInactive = false;
  List<dynamic> _inactiveFamilies = [];
  List<dynamic> _filteredInactive = [];
  bool _loadingInactive = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context);
    });
  }

  Future<void> _loadInactive() async {
    setState(() => _loadingInactive = true);
    try {
      final data = await _familiaApi.getInactive();
      setState(() {
        _inactiveFamilies = data;
        _filteredInactive = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('No se pudieron cargar las familias inactivas. ${friendlyError(e)}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingInactive = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_showInactive) {
      final q = query.toLowerCase();
      setState(() {
        _filteredInactive = q.isEmpty
            ? _inactiveFamilies
            : _inactiveFamilies.where((f) {
                final nombre =
                    (f['nombre_familia'] ?? '').toString().toLowerCase();
                final padres = (f['padres'] ?? '').toString().toLowerCase();
                return nombre.contains(q) || padres.contains(q);
              }).toList();
      });
    } else {
      _controller.onSearchChanged(query);
    }
  }

  Future<void> _reactivate(dynamic f) async {
    final id = f['id_familia'] as int;
    final nombre = (f['nombre_familia'] ?? 'esta familia').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Reactivar familia?'),
        content: Text('La familia "$nombre" volverá a estar activa y visible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _familiaApi.reactivateFamily(id);
      if (!mounted) return;
      setState(() {
        _inactiveFamilies.removeWhere((x) => x['id_familia'] == id);
        _filteredInactive.removeWhere((x) => x['id_familia'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('✅ "$nombre" reactivada correctamente.'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(friendlyError(e)), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  String _absUrl(String raw) {
    if (raw.isEmpty || raw == 'null') return '';
    var s = raw.trim();
    if (s.startsWith('http')) return s;
    s = s.replaceAll('\\', '/');
    final idxPublic = s.indexOf('public/uploads/');
    if (idxPublic != -1) s = s.substring(idxPublic + 'public'.length);
    else if (s.startsWith('uploads/')) s = '/$s';
    else if (!s.startsWith('/')) s = '/$s';
    return '${ApiHttp.baseUrl}$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultar Familias'),
        backgroundColor: _navy,
        elevation: 0,
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            children: [
              // ── Barra de búsqueda + toggle ───────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 0),
                color: _navy,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Buscar por apellido o padres...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Toggle Activas / Inactivas
                    Row(
                      children: [
                        _ToggleChip(
                          label: 'Activas',
                          icon: Icons.check_circle_outline,
                          selected: !_showInactive,
                          onTap: () {
                            if (_showInactive) {
                              _searchCtrl.clear();
                              setState(() => _showInactive = false);
                              // Recargar lista activa por si hubo reactivaciones
                              _controller.loadFamilies();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _ToggleChip(
                          label: 'Inactivas',
                          icon: Icons.visibility_off_outlined,
                          selected: _showInactive,
                          selectedColor: Colors.orange,
                          onTap: () {
                            if (!_showInactive) {
                              _searchCtrl.clear();
                              setState(() => _showInactive = true);
                              _loadInactive();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),

              // ── Lista ─────────────────────────────────────────────────────
              Expanded(
                child: _showInactive
                    ? _buildInactiveList()
                    : _buildActiveList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lista de familias activas (original) ──────────────────────────────────
  Widget _buildActiveList() {
    return RefreshIndicator(
      onRefresh: _controller.loadFamilies,
      child: ValueListenableBuilder<bool>(
        valueListenable: _controller.isLoading,
        builder: (_, loading, __) {
          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<dynamic>>(
            valueListenable: _controller.families,
            builder: (_, list, __) {
              if (list.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.family_restroom_outlined,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('No se encontraron familias',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) => _buildFamilyCard(list[i]),
              );
            },
          );
        },
      ),
    );
  }

  // ── Lista de familias inactivas ───────────────────────────────────────────
  Widget _buildInactiveList() {
    if (_loadingInactive) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredInactive.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              _inactiveFamilies.isEmpty
                  ? 'No hay familias desactivadas.'
                  : 'Sin resultados para la búsqueda.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredInactive.length,
      itemBuilder: (_, i) => _buildInactiveFamilyCard(_filteredInactive[i]),
    );
  }

  // ── Card familia activa ───────────────────────────────────────────────────
  Widget _buildFamilyCard(dynamic f) {
    final int numAlumnos = f['num_alumnos'] ?? 0;
    final bool estaLleno = numAlumnos >= 10;
    final portadaAbs = _absUrl(
        (f['portada'] ?? f['foto_portada_url'] ?? '').toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _controller.goToDetail(f),
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: portadaAbs.isNotEmpty
                      ? Image.network(portadaAbs,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey, size: 50)))
                      : Container(
                          color: const Color.fromRGBO(19, 67, 107, 0.2),
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey, size: 50)),
                ),
                if (estaLleno)
                  Container(
                    height: 150,
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('CASA LLENA',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          (f['nombre_familia'] ?? 'Sin Nombre').toString(),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _navy),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: estaLleno
                              ? Colors.red[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person,
                                size: 16,
                                color: estaLleno
                                    ? Colors.red
                                    : Colors.green),
                            const SizedBox(width: 4),
                            Text('$numAlumnos / 10',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: estaLleno
                                        ? Colors.red[800]
                                        : Colors.green[800])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          unescape.convert(
                              (f['padres'] ?? 'Sin padres asignados')
                                  .toString()),
                          style: TextStyle(
                              color: Colors.grey[800], fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (f['descripcion'] != null &&
                      f['descripcion'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        f['descripcion'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600]),
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

  // ── Card familia inactiva ─────────────────────────────────────────────────
  Widget _buildInactiveFamilyCard(dynamic f) {
    final portadaAbs = _absUrl(
        (f['portada'] ?? f['foto_portada_url'] ?? '').toString());
    final numMiembros = f['num_miembros'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      color: Colors.grey[50],
      child: Column(
        children: [
          // Foto de portada con overlay de "INACTIVA"
          Stack(
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                      Colors.grey, BlendMode.saturation),
                  child: portadaAbs.isNotEmpty
                      ? Image.network(portadaAbs,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey, size: 40)))
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey, size: 40)),
                ),
              ),
              Container(
                height: 100,
                color: Colors.black.withOpacity(0.4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('INACTIVA',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (f['nombre_familia'] ?? 'Sin Nombre').toString(),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.people_outline,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              unescape.convert(
                                  (f['padres'] ?? 'Sin padres').toString()),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (numMiembros > 0) ...[
                        const SizedBox(height: 2),
                        Text('$numMiembros miembro(s)',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Reactivar',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _reactivate(f),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle chip widget ──────────────────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color? selectedColor;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected
                    ? (selectedColor != null ? Colors.white : Colors.black87)
                    : Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? (selectedColor != null ? Colors.white : Colors.black87)
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
