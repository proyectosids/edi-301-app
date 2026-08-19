// lib/src/pages/Admin/reportes/reporte_familia_individual_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/publicaciones_api.dart';
import 'package:edi301/services/eventos_api.dart';
import 'package:edi301/core/api_client_http.dart';

String _sanitize(String text) {
  return text
      .replaceAll(RegExp(r'[^\x00-\x7F]+'), '')
      .replaceAll('\n', ' ')
      .trim();
}

class ReporteFamiliaIndividualService {
  pw.Font? _font;
  pw.Font? _fontBold;

  static const PdfColor _navy = PdfColor.fromInt(0xFF13436B);
  static const PdfColor _gold = PdfColor.fromInt(0xFFF5BC06);
  static const PdfColor _grey = PdfColor.fromInt(0xFF666666);
  static const PdfColor _light = PdfColor.fromInt(0xFFF0F4F8);
  static const PdfColor _white = PdfColor.fromInt(0xFFFFFFFF);

  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _timeFmt = DateFormat('HH:mm');

  Future<pw.Font> _getFont() async {
    _font ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/OpenSans-Regular.ttf'),
    );
    return _font!;
  }

  Future<pw.Font> _getBold() async {
    try {
      _fontBold ??= pw.Font.ttf(
        await rootBundle.load('assets/fonts/OpenSans-Bold.ttf'),
      );
    } catch (_) {
      _fontBold = await _getFont();
    }
    return _fontBold!;
  }

  Future<pw.ImageProvider?> _fetchImage(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty || rawUrl == 'null') return null;
    try {
      var url = rawUrl.trim();
      if (!url.startsWith('http')) url = '${ApiHttp.baseUrl}$url';
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return pw.MemoryImage(res.bodyBytes);
    } catch (_) {}
    return null;
  }

  Future<void> generarYAbrir(Family familia) async {
    final font = await _getFont();
    final fontBold = await _getBold();

    final pubApi = PublicacionesApi();
    final eventosApi = EventosApi();

    final results = await Future.wait([
      pubApi.getAllPostsFamilia(familia.id!),
      eventosApi.listarTodos(),
    ]);

    final posts = results[0];
    final eventos = results[1] as List<Evento>;

    final grouped = _groupPostsByEvent(posts, eventos);
    final portadaImg = await _fetchImage(familia.fotoPortadaUrl);
    final perfilImg = await _fetchImage(familia.fotoPerfilUrl);

    final publicacionesWidget = await _publicacionesSection(
      grouped,
      eventos,
      font,
      fontBold,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => _header(familia, portadaImg, perfilImg, fontBold, font),
        footer: (ctx) => _footer(ctx, font),
        build: (ctx) => [
          _familyInfoSection(familia, font, fontBold),
          pw.SizedBox(height: 16),
          _membersSection(familia, font, fontBold),
          pw.SizedBox(height: 20),
          publicacionesWidget,
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final name =
        'Reporte_${familia.familyName.replaceAll(' ', '_')}_'
        '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  Map<String, List<dynamic>> _groupPostsByEvent(
    List<dynamic> posts,
    List<Evento> eventos,
  ) {
    final result = <String, List<dynamic>>{};
    for (final post in posts) {
      final postDate = _parseDate(post['created_at']);
      Evento? matched;
      if (postDate != null) {
        for (final ev in eventos) {
          if (ev.fechaEvento.difference(postDate).inDays.abs() <= 7) {
            matched = ev;
            break;
          }
        }
      }
      final key = matched != null
          ? '${matched.idActividad}::${matched.titulo}'
          : 'general';
      result.putIfAbsent(key, () => []).add(post);
    }
    return result;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return null;
    }
  }

  pw.Widget _header(
    Family familia,
    pw.ImageProvider? portada,
    pw.ImageProvider? perfil,
    pw.Font bold,
    pw.Font font,
  ) {
    return pw.Column(
      children: [
        pw.Container(
          color: _navy,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EDI 301',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 9,
                      color: _gold,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Reporte de Familia',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 14,
                      color: _white,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    familia.familyName,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 11,
                      color: _white,
                    ),
                  ),
                ],
              ),
              perfil != null
                  ? pw.ClipOval(
                      child: pw.Image(
                        perfil,
                        width: 48,
                        height: 48,
                        fit: pw.BoxFit.cover,
                      ),
                    )
                  : pw.Container(
                      width: 48,
                      height: 48,
                      decoration: const pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        color: _gold,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          familia.familyName.isNotEmpty
                              ? familia.familyName[0].toUpperCase()
                              : 'F',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 20,
                            color: _navy,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
        if (portada != null)
          pw.SizedBox(
            height: 60,
            width: 540,
            child: pw.Image(portada, fit: pw.BoxFit.cover),
          ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  pw.Widget _footer(pw.Context ctx, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generado el ${_dateFmt.format(DateTime.now())}',
          style: pw.TextStyle(font: font, fontSize: 8, color: _grey),
        ),
        pw.Text(
          'Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
          style: pw.TextStyle(font: font, fontSize: 8, color: _grey),
        ),
      ],
    );
  }

  pw.Widget _familyInfoSection(Family familia, pw.Font font, pw.Font bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _light,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Información de la Familia',
            style: pw.TextStyle(font: bold, fontSize: 12, color: _navy),
          ),
          pw.Divider(color: _navy, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _infoItem(
                'Padre',
                familia.fatherName ?? 'No asignado',
                font,
                bold,
              ),
              _infoItem(
                'Madre',
                familia.motherName ?? 'No asignada',
                font,
                bold,
              ),
              _infoItem('Residencia', familia.residence, font, bold),
            ],
          ),
          if (familia.descripcion != null &&
              familia.descripcion!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Descripción:',
              style: pw.TextStyle(font: bold, fontSize: 9, color: _navy),
            ),
            pw.Text(
              familia.descripcion!,
              style: pw.TextStyle(font: font, fontSize: 9, color: _grey),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _infoItem(String label, String value, pw.Font font, pw.Font bold) {
    return pw.Container(
      width: 150,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: bold, fontSize: 8, color: _navy),
          ),
          pw.Text(
            _sanitize(value),
            style: pw.TextStyle(font: font, fontSize: 9, color: _grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _membersSection(Family familia, pw.Font font, pw.Font bold) {
    final allMembers = [
      ...familia.householdChildren,
      ...familia.assignedStudents,
    ];
    final hogarKids = familia.hogarChildren;

    if (allMembers.isEmpty && hogarKids.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Integrantes',
          style: pw.TextStyle(font: bold, fontSize: 12, color: _navy),
        ),
        pw.Divider(color: _navy, thickness: 0.5),
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ...allMembers.map(
              (m) => pw.Container(
                width: 120,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _navy, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  '${_sanitize(m.fullName)} (${_sanitize(m.tipoMiembro)})',
                  style: pw.TextStyle(font: font, fontSize: 8),
                  maxLines: 2,
                ),
              ),
            ),
            ...hogarKids.map(
              (h) => pw.Container(
                width: 120,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _gold, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  '${_sanitize(h.fullName)} (Niño del hogar)',
                  style: pw.TextStyle(font: font, fontSize: 8),
                  maxLines: 2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<pw.Widget> _publicacionesSection(
    Map<String, List<dynamic>> grouped,
    List<Evento> eventos,
    pw.Font font,
    pw.Font bold,
  ) async {
    if (grouped.isEmpty) {
      return pw.Text(
        'Sin publicaciones registradas.',
        style: pw.TextStyle(font: font, fontSize: 10, color: _grey),
      );
    }

    final widgets = <pw.Widget>[
      pw.Text(
        'Publicaciones',
        style: pw.TextStyle(font: bold, fontSize: 12, color: _navy),
      ),
      pw.Divider(color: _navy, thickness: 0.5),
      pw.SizedBox(height: 8),
    ];

    for (final key in grouped.keys.where((k) => k != 'general')) {
      final parts = key.split('::');
      final evTitle = parts.length > 1 ? parts[1] : 'Evento';
      final evId = int.tryParse(parts[0]);
      final evento = evId != null
          ? eventos.where((e) => e.idActividad == evId).firstOrNull
          : null;

      widgets.add(_eventoHeader(evTitle, evento, font, bold));
      widgets.add(pw.SizedBox(height: 6));
      for (final post in grouped[key]!) {
        widgets.add(await _postCard(post, font, bold));
        widgets.add(pw.SizedBox(height: 6));
      }
      widgets.add(pw.SizedBox(height: 12));
    }

    if (grouped.containsKey('general')) {
      widgets.add(_sectionDivider('Publicaciones Generales', font, bold));
      widgets.add(pw.SizedBox(height: 6));
      for (final post in grouped['general']!) {
        widgets.add(await _postCard(post, font, bold));
        widgets.add(pw.SizedBox(height: 6));
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  pw.Widget _eventoHeader(
    String titulo,
    Evento? evento,
    pw.Font font,
    pw.Font bold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '  $titulo',
            style: pw.TextStyle(font: bold, fontSize: 10, color: _white),
          ),
          if (evento != null)
            pw.Text(
              _dateFmt.format(evento.fechaEvento),
              style: pw.TextStyle(font: font, fontSize: 9, color: _gold),
            ),
        ],
      ),
    );
  }

  pw.Widget _sectionDivider(String label, pw.Font font, pw.Font bold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _gold,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(font: bold, fontSize: 10, color: _navy),
      ),
    );
  }

  Future<pw.Widget> _postCard(dynamic post, pw.Font font, pw.Font bold) async {
    final fecha = _parseDate(post['created_at']);
    final autor = _sanitize(
      '${post['nombre'] ?? ''} ${post['apellido'] ?? ''}'.trim(),
    );
    final mensaje = _sanitize((post['mensaje'] ?? '').toString());
    final cat = _sanitize((post['categoria_post'] ?? '').toString());

    // ✅ Campo correcto según el backend
    final imageUrl = (post['url_imagen'] ?? '').toString();
    final image = await _fetchImage(imageUrl.isNotEmpty ? imageUrl : null);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
        color: _white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                autor.isEmpty ? 'Desconocido' : autor,
                style: pw.TextStyle(font: bold, fontSize: 9, color: _navy),
              ),
              pw.Text(
                fecha != null
                    ? '${_dateFmt.format(fecha)} ${_timeFmt.format(fecha)}'
                    : '',
                style: pw.TextStyle(font: font, fontSize: 8, color: _grey),
              ),
            ],
          ),
          if (cat.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              cat,
              style: pw.TextStyle(font: font, fontSize: 7, color: _grey),
            ),
          ],
          if (mensaje.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              mensaje,
              style: pw.TextStyle(font: font, fontSize: 9),
              maxLines: 8,
            ),
          ],
          // Imagen de la publicación
          if (image != null) ...[
            pw.SizedBox(height: 6),
            pw.SizedBox(
              width: 460,
              child: pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(image, height: 120, fit: pw.BoxFit.cover),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
