import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_controller.dart';
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:html_unescape/html_unescape.dart';

class GetFamilyPage extends StatefulWidget {
  const GetFamilyPage({super.key});

  @override
  State<GetFamilyPage> createState() => _GetFamilyPageState();
}

class _GetFamilyPageState extends State<GetFamilyPage> {
  final GetFamilyController _controller = GetFamilyController();
  final unescape = HtmlUnescape();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context);
    });
  }

  String _absUrl(String raw) {
    if (raw.isEmpty || raw == 'null') return '';
    var s = raw.trim();
    if (s.startsWith('http')) return s;
    s = s.replaceAll('\\', '/');

    final idxPublic = s.indexOf('public/uploads/');
    if (idxPublic != -1) {
      s = s.substring(idxPublic + 'public'.length);
    } else if (s.startsWith('uploads/')) {
      s = '/$s';
    } else if (!s.startsWith('/')) {
      s = '/$s';
    }
    return '${ApiHttp.baseUrl}$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consultar Familias"),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        elevation: 0,
      ),
      body: ResponsiveContent(
        child: Column(
          children: [
            // BARRA DE BÚSQUEDA
            Container(
              padding: const EdgeInsets.all(15),
              color: const Color.fromRGBO(19, 67, 107, 1),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _controller.onSearchChanged,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Buscar por apellido o padres...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            // LISTA DE FAMILIAS
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _controller.isLoading,
                builder: (context, loading, _) {
                  if (loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ValueListenableBuilder<List<dynamic>>(
                    valueListenable: _controller.families,
                    builder: (context, list, _) {
                      if (list.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.family_restroom_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "No se encontraron familias",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final f = list[index];
                          return _buildFamilyCard(f);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCard(dynamic f) {
    final int numAlumnos = f['num_alumnos'] ?? 0;
    final bool estaLleno = numAlumnos >= 10;

    final portadaRaw = (f['portada'] ?? f['foto_portada_url'] ?? '').toString();
    final portadaAbs = _absUrl(portadaRaw);

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
                      ? Image.network(
                          portadaAbs,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 50,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color.fromRGBO(19, 67, 107, 0.2),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 50,
                          ),
                        ),
                ),
                if (estaLleno)
                  Container(
                    height: 150,
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "CASA LLENA",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(12.0),
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
                            color: Color.fromRGBO(19, 67, 107, 1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: estaLleno
                              ? Colors.red[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: estaLleno ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$numAlumnos / 10",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: estaLleno
                                    ? Colors.red[800]
                                    : Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Padres
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          unescape.convert(
                            (f['padres'] ?? 'Sin padres asignados').toString(),
                          ),
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Descripción
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
                          color: Colors.grey[600],
                        ),
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
