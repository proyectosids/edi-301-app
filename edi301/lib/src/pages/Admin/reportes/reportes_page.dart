import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_controller.dart';
import 'package:edi301/src/pages/Admin/reportes/reporte_familias_service.dart';
import 'package:html_unescape/html_unescape.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  // Usamos el mismo controlador renovado
  final GetFamilyController _controller = GetFamilyController();
  final ReporteFamiliasService _reportService = ReporteFamiliasService();

  // Controlador de texto local para la búsqueda
  final TextEditingController _searchCtrl = TextEditingController();
  final unescape = HtmlUnescape();

  bool _isLoadingGeneral = false;
  final Map<int, bool> _loadingIndividual = {};

  @override
  void initState() {
    super.initState();
    // Inicializamos el controlador después del primer frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _controller.init(context);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    // No necesitamos dispose del controller si no tiene streams abiertos manualmente,
    // pero si tuviera, aquí iría.
    super.dispose();
  }

  Future<void> _generarReporteGeneral() async {
    setState(() => _isLoadingGeneral = true);
    try {
      // ignore: unused_local_variable
      final path = await _reportService.generarReporteGeneral();
      if (mounted) {
        _snack('Reporte general guardado y abierto.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _snack('Error al generar reporte general: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGeneral = false);
      }
    }
  }

  Future<void> _generarReporteIndividual(int familiaId) async {
    setState(() => _loadingIndividual[familiaId] = true);
    try {
      // ignore: unused_local_variable
      final path = await _reportService.generarReporteIndividual(familiaId);
      if (mounted) {
        _snack('Reporte individual guardado y abierto.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _snack('Error al generar reporte individual: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingIndividual[familiaId] = false);
      }
    }
  }

  void _snack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Reportes PDF'),
        backgroundColor: primary,
      ),
      body: ResponsiveContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                icon: _isLoadingGeneral
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_for_offline),
                label: Text(
                  _isLoadingGeneral
                      ? 'GENERANDO...'
                      : 'GENERAR REPORTE GENERAL',
                ),
                onPressed: _isLoadingGeneral ? null : _generarReporteGeneral,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),

            const Divider(thickness: 2),

            _textFieldSearch(),

            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _controller.isLoading,
                builder: (context, loading, _) {
                  if (loading)
                    return const Center(child: CircularProgressIndicator());

                  return ValueListenableBuilder<List<dynamic>>(
                    valueListenable: _controller.families,
                    builder: (_, families, __) {
                      if (families.isEmpty) {
                        return const Center(
                          child: Text('No se encontraron familias.'),
                        );
                      }
                      return _buildFamilyCards(families);
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

  Widget _textFieldSearch() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      child: TextField(
        controller: _searchCtrl,

        onChanged: _controller.onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Buscar familia por nombre o padres...',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Color.fromRGBO(245, 188, 6, 1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(
              color: Color.fromRGBO(245, 188, 6, 1),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color.fromRGBO(19, 67, 107, 1),
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyCards(List<dynamic> families) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      shrinkWrap: true,
      itemCount: families.length,
      itemBuilder: (context, index) {
        final f = families[index];
        final int id = f['id_familia'] ?? 0;
        final bool isLoading = _loadingIndividual[id] ?? false;

        return Card(
          color: const Color.fromARGB(255, 255, 205, 40),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            title: Text(
              (f['nombre_familia'] ?? 'Sin Nombre').toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              unescape.convert(
                (f['padres'] ?? 'Sin padres asignados').toString(),
              ),
              style: const TextStyle(color: Colors.black87),
            ),
            isThreeLine: true,
            trailing: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.black54,
                      size: 30,
                    ),
                    tooltip: 'Generar PDF Individual',
                    onPressed: () {
                      if (id > 0) {
                        _generarReporteIndividual(id);
                      } else {
                        _snack('Error: Esta familia no tiene un ID válido.');
                      }
                    },
                  ),
          ),
        );
      },
    );
  }
}
