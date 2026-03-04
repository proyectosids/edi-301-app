import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edi301/core/api_client_http.dart';
import 'agenda_controller.dart';
import 'package:edi301/tools/media_picker.dart';

class CreateEventPage extends StatefulWidget {
  final Map<String, dynamic>? eventoExistente;

  const CreateEventPage({super.key, this.eventoExistente});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final AgendaController _controller = AgendaController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _controller.init(context, evento: widget.eventoExistente);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await MediaPicker.pickImage(context);
    if (image != null) {
      setState(() => _controller.imagenSeleccionada = File(image.path));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _controller.fechaEvento ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _controller.fechaEvento = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _controller.horaEvento ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _controller.horaEvento = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.eventoExistente != null;

    ImageProvider? imagenProvider;
    if (_controller.imagenSeleccionada != null) {
      imagenProvider = FileImage(_controller.imagenSeleccionada!);
    } else if (_controller.imagenUrlRemota != null &&
        _controller.imagenUrlRemota!.isNotEmpty) {
      imagenProvider = NetworkImage(
        '${ApiHttp.baseUrl}${_controller.imagenUrlRemota}',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? "Editar Evento" : "Nuevo Evento"),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (context, isLoading, child) {
          if (isLoading)
            return const Center(child: CircularProgressIndicator());

          return Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                // Imagen
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                      image: imagenProvider != null
                          ? DecorationImage(
                              image: imagenProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imagenProvider == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.camera_alt,
                                size: 50,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Toca para agregar imagen",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                if (imagenProvider != null)
                  Center(
                    child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.edit),
                      label: const Text("Cambiar imagen"),
                    ),
                  ),

                const SizedBox(height: 20),

                TextField(
                  controller: _controller.tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: "Título del Evento",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: _controller.descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Descripción",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 15),

                // Fecha y Hora
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(
                          _controller.fechaEvento == null
                              ? "Fecha"
                              : "${_controller.fechaEvento!.day}/${_controller.fechaEvento!.month}/${_controller.fechaEvento!.year}",
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                        tileColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ListTile(
                        title: Text(
                          _controller.horaEvento == null
                              ? "Hora"
                              : _controller.horaEvento!.format(context),
                        ),
                        trailing: const Icon(Icons.access_time),
                        onTap: _pickTime,
                        tileColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: _controller.recordatorioDiasAntesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Días de anticipación",
                    helperText: "Días antes para mostrar en el feed.",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer),
                  ),
                ),
                const SizedBox(height: 30),

                // Botón Guardar
                ElevatedButton(
                  onPressed: () => _controller.guardarEvento(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    esEdicion ? "Guardar Cambios" : "Publicar Evento",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
