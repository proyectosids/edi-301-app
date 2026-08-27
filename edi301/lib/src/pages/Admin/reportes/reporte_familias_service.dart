// lib/src/pages/Admin/reportes/reporte_familias_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:edi301/core/api_client_http.dart';
import 'package:open_file/open_file.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/models/family_model.dart';

class FamiliaReporteGeneral {
  final int idFamilia;
  final String nombreFamilia;
  final String? papaNombre;
  final String? mamaNombre;
  final int totalMiembros;

  FamiliaReporteGeneral.fromJson(Map<String, dynamic> j)
    : idFamilia = int.tryParse('${j['id_familia']}') ?? 0,
      nombreFamilia = (j['nombre_familia'] ?? 'Sin nombre').toString(),
      papaNombre = j['papa_nombre']?.toString(),
      mamaNombre = j['mama_nombre']?.toString(),
      totalMiembros = int.tryParse('${j['total_miembros']}') ?? 0;

  String get responsable {
    if (papaNombre != null) return papaNombre!;
    if (mamaNombre != null) return mamaNombre!;
    return 'No asignado';
  }
}

class ReporteFamiliasService {
  final ApiHttp _http = ApiHttp();
  final FamiliaApi _familiaApi = FamiliaApi();
  pw.Font? _font;

  Future<pw.Font> _getFont() async {
    if (_font == null) {
      try {
        final fontData = await rootBundle.load(
          "assets/fonts/OpenSans-Regular.ttf",
        );
        _font = pw.Font.ttf(fontData);
      } catch (e) {
        throw Exception('Error al cargar la fuente: $e. ');
      }
    }
    return _font!;
  }

  Future<List<FamiliaReporteGeneral>> _fetchReporteGeneralData() async {
    final res = await _http.getJson('/api/familias/reporte-completo');
    if (res.statusCode >= 400) {
      throw Exception('Error al obtener datos: ${res.body}');
    }
    final decoded = jsonDecode(res.body);
    final list = decoded is List
        ? decoded
        : decoded is Map && decoded['data'] is List
        ? decoded['data'] as List
        : <dynamic>[];
    return list
        .whereType<Map>()
        .map(
          (json) =>
              FamiliaReporteGeneral.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
  }

  Future<Family> _fetchReporteIndividualData(int familiaId) async {
    final data = await _familiaApi.getById(familiaId);
    if (data == null) {
      throw Exception('No se encontró la familia con ID $familiaId');
    }
    return Family.fromJson(data);
  }

  Future<String> generarReporteGeneral({Set<int>? familyIds}) async {
    final allFamilies = await _fetchReporteGeneralData();
    final familias = familyIds == null
        ? allFamilies
        : allFamilies
              .where((family) => familyIds.contains(family.idFamilia))
              .toList();
    final pdf = pw.Document();
    final font = await _getFont();
    final theme = pw.ThemeData.withFont(base: font);

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader('Listas de familias EDI 301'),
        // Las filas se entregan como widgets independientes: así MultiPage
        // puede repartirlas entre páginas aun cuando haya muchas familias.
        build: (context) => _buildGeneralWidgets(familias),
      ),
    );

    return _saveAndOpenFile(pdf, 'reporte_general_familias.pdf');
  }

  Future<String> generarReporteIndividual(int familiaId) async {
    final familia = await _fetchReporteIndividualData(familiaId);
    final pdf = pw.Document();
    final font = await _getFont();
    final theme = pw.ThemeData.withFont(base: font);

    final hijosCasa = familia.householdChildren;
    final alumnosAsignados = familia.assignedStudents;
    final ninos = familia.hogarChildren;

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader(familia.familyName),
          _buildTablePadres(familia),
          pw.SizedBox(height: 20),
          _buildTableMiembros('Hijos en casa', hijosCasa),
          pw.SizedBox(height: 20),
          _buildTableMiembros(
            'Hijos EDI (Alumnos Asignados)',
            alumnosAsignados,
          ),
          if (ninos.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildTableNinosHogar(ninos),
          ],
        ],
      ),
    );

    return _saveAndOpenFile(
      pdf,
      'reporte_${familia.familyName.replaceAll(' ', '_')}.pdf',
    );
  }

  Future<String> _saveAndOpenFile(pw.Document pdf, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
    return file.path;
  }

  pw.Widget _buildHeader(String title) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
      ),
    );
  }

  List<pw.Widget> _buildGeneralWidgets(List<FamiliaReporteGeneral> familias) {
    final totalIntegrantes = familias.fold<int>(
      0,
      (sum, f) => sum + f.totalMiembros,
    );

    return [
      _buildGeneralHeaderRow(),
      ...familias.map(_buildGeneralRow),
      pw.SizedBox(height: 8),
      pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            border: pw.Border.all(color: PdfColors.grey600, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'Total de integrantes: ',
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.TextSpan(
                  text: '$totalIntegrantes',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  pw.Widget _buildGeneralHeaderRow() => _generalRow(const [
    'Nombre de la familia',
    'Responsable',
    'Número de integrantes',
    'Recibió',
  ], header: true);

  pw.Widget _buildGeneralRow(FamiliaReporteGeneral familia) => _generalRow([
    familia.nombreFamilia,
    familia.responsable,
    familia.totalMiembros.toString(),
    '',
  ]);

  pw.Widget _generalRow(List<String> values, {bool header = false}) {
    const widths = [4, 3, 2, 2];
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: header ? PdfColors.grey300 : null,
        border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
      ),
      child: pw.Row(
        children: List.generate(values.length, (index) {
          return pw.Expanded(
            flex: widths[index],
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                values[index],
                textAlign: index >= 2 ? pw.TextAlign.center : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: header ? 9 : 8,
                  fontWeight: header
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  pw.Widget _buildTablePadres(Family familia) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
      columnWidths: {
        0: const pw.FixedColumnWidth(100),
        1: const pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'Rol',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'Nombre',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        _buildPadreRow('Padre', familia.fatherName),
        _buildPadreRow('Madre', familia.motherName),
      ],
    );
  }

  pw.TableRow _buildPadreRow(String rol, String? nombre) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(rol)),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(nombre ?? 'No asignado'),
        ),
      ],
    );
  }

  pw.Widget _buildTableNinosHogar(List<HogarChild> ninos) {
    final headers = ['Nombre', 'Apellido', 'Fecha de nacimiento'];

    final data = ninos
        .map((h) => [h.nombre, h.apellido, h.fechaNacimiento ?? 'N/A'])
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Niños del hogar sin cuenta',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        pw.SizedBox(height: 5),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 25,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.center,
          },
        ),
      ],
    );
  }

  pw.Widget _buildTableMiembros(String title, List<FamilyMember> miembros) {
    final headers = [
      'Matricula',
      'Nombre',
      'Apellido',
      'Cumpleaños',
      'Telefono',
      'Carrera',
    ];

    final data = miembros.map((m) {
      final names = m.fullName.split(' ');
      final nombre = names.isNotEmpty ? names.first : '';
      final apellido = names.length > 1 ? names.sublist(1).join(' ') : '';

      return [
        m.matricula?.toString() ?? 'N/A',
        nombre,
        apellido,
        m.fechaNacimiento ?? 'N/A',
        m.telefono ?? 'N/A',
        m.carrera ?? 'N/A',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
        ),
        pw.SizedBox(height: 5),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellHeight: 25,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.centerLeft,
          },
        ),
      ],
    );
  }
}
