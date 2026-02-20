import 'dart:io';
import 'package:flutter/material.dart';
import 'package:edi301/services/eventos_api.dart';
import 'package:edi301/tools/generic_reminders.dart' as reminders_tool;
import 'package:edi301/core/api_client_http.dart';

class AgendaController {
  late BuildContext context;
  final EventosApi _api = EventosApi();
  final loading = ValueNotifier<bool>(false);

  int? _idEvento;

  final tituloCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final recordatorioDiasAntesCtrl = TextEditingController(text: '3');

  File? imagenSeleccionada;
  String? imagenUrlRemota;

  DateTime? fechaEvento;
  TimeOfDay? horaEvento;

  final crearRecordatorio = ValueNotifier<bool>(false);
  final recordatorioHoraCtrl = TextEditingController(text: '13:00');
  String recordatorioTipo = 'DAY';

  void init(BuildContext context, {Map<String, dynamic>? evento}) {
    this.context = context;

    if (evento != null) {
      _idEvento = evento['id_evento'] ?? evento['id_actividad'];
      tituloCtrl.text = evento['titulo'] ?? '';
      descCtrl.text = evento['mensaje'] ?? evento['descripcion'] ?? '';
      recordatorioDiasAntesCtrl.text = (evento['dias_anticipacion'] ?? 3)
          .toString();
      imagenUrlRemota = evento['imagen'];

      if (evento['fecha_evento'] != null) {
        fechaEvento = DateTime.tryParse(evento['fecha_evento'].toString());
      } else {
        fechaEvento = DateTime.now();
      }

      if (evento['hora_evento'] != null) {
        try {
          final parts = evento['hora_evento'].toString().split(':');
          if (parts.length >= 2) {
            horaEvento = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        } catch (e) {
          print("Error parseando hora: $e");
        }
      }
    } else {
      _idEvento = null;
      tituloCtrl.clear();
      descCtrl.clear();
      recordatorioDiasAntesCtrl.text = '3';
      imagenSeleccionada = null;
      imagenUrlRemota = null;
      fechaEvento = DateTime.now().add(const Duration(days: 1));
      horaEvento = null;
    }
  }

  void dispose() {
    tituloCtrl.dispose();
    descCtrl.dispose();
    crearRecordatorio.dispose();
    recordatorioHoraCtrl.dispose();
    recordatorioDiasAntesCtrl.dispose();
    loading.dispose();
  }

  Future<void> guardarEvento() async {
    loading.value = true;

    if (fechaEvento == null) {
      _snack('Debes seleccionar una fecha para el evento.');
      loading.value = false;
      return;
    }

    try {
      final success = await _api.guardarEvento(
        id: _idEvento,
        titulo: tituloCtrl.text,
        fecha: fechaEvento!,
        hora: horaEvento?.to24HourString(),
        descripcion: descCtrl.text,
        imagenFile: imagenSeleccionada,
        diasAnticipacion: int.tryParse(recordatorioDiasAntesCtrl.text) ?? 3,
      );

      if (success) {
        if (crearRecordatorio.value) {
          await _crearRecordatorioRecurrente();
        }

        if (context.mounted) {
          _snack(
            _idEvento == null
                ? 'Evento creado con éxito'
                : 'Evento actualizado',
            isError: false,
          );
          Navigator.pop(context, true);
        }
      } else {
        _snack('Error al guardar el evento en el servidor');
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      loading.value = false;
    }
  }

  Future<void> _crearRecordatorioRecurrente() async {
    try {
      final diasAntes = int.tryParse(recordatorioDiasAntesCtrl.text) ?? 1;
      final hora = recordatorioHoraCtrl.text.trim();
      final fechaFin = fechaEvento!;
      final fechaInicio = fechaFin.subtract(Duration(days: diasAntes));

      final String startDateStr = fechaInicio
          .toIso8601String()
          .split('T')
          .first;
      final String endDateStr = fechaFin.toIso8601String().split('T').first;
      final String timeStr = (hora.length == 5) ? '$hora:00' : '13:00:00';

      await reminders_tool.createReminder(
        title: tituloCtrl.text,
        description: descCtrl.text,
        start_date: startDateStr,
        end_date: endDateStr,
        time_of_day: timeStr,
        repeat_interval_unit: recordatorioTipo == 'DAY'
            ? reminders_tool.RepeatIntervalUnit.DAY
            : reminders_tool.RepeatIntervalUnit.WEEK,
        repeat_every_n: 1,
      );
    } catch (e) {
      print('Fallo recordatorio: $e');
    }
  }

  void _snack(String msg, {bool isError = true}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String to24HourString() {
    final String hourStr = hour.toString().padLeft(2, '0');
    final String minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }
}
