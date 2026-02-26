import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/mensajes_api.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/core/api_client_http.dart';

class ChatFamilyPage extends StatefulWidget {
  final int idFamilia;
  final String nombreFamilia;

  const ChatFamilyPage({
    Key? key,
    required this.idFamilia,
    required this.nombreFamilia,
  }) : super(key: key);

  @override
  _ChatFamilyPageState createState() => _ChatFamilyPageState();
}

class _ChatFamilyPageState extends State<ChatFamilyPage> {
  final MensajesApi _api = MensajesApi();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _mensajes = [];
  int _miIdUsuario = 0;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _socketService.initSocket();

    _loadUser();
    _cargarMensajes();

    // ✅ Tiempo real (chat familiar)
    _socketService.joinFamilyRoom(widget.idFamilia);
    _socketService.socket.off('nuevo_mensaje_familia');
    _socketService.socket.on('nuevo_mensaje_familia', (data) {
      if (mounted) _cargarMensajes();
    });
  }

  @override
  void dispose() {
    _socketService.socket.off('nuevo_mensaje_familia');
    _socketService.leaveRoom('familia_${widget.idFamilia}');
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      setState(() {
        _miIdUsuario = user['id_usuario'] ?? user['id'] ?? 0;
      });
    }
  }

  Future<void> _cargarMensajes({bool quiet = false}) async {
    final nuevos = await _api.getMensajesFamilia(widget.idFamilia);
    if (mounted) {
      setState(() {
        _mensajes = nuevos;
      });
      if (!quiet) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _enviar() async {
    final texto = _textController.text.trim();
    if (texto.isEmpty) return;

    _textController.clear();
    final exito = await _api.enviarMensaje(widget.idFamilia, texto);
    if (exito) {
      _cargarMensajes();
    }
  }

  Color _getColorForName(String name) {
    final List<Color> colors = [
      Colors.red[700]!,
      Colors.pink[700]!,
      Colors.purple[700]!,
      Colors.deepPurple[700]!,
      Colors.indigo[700]!,
      Colors.blue[700]!,
      Colors.teal[700]!,
      Colors.green[700]!,
      Colors.orange[800]!,
      Colors.brown[700]!,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreFamilia),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        elevation: 0,
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                final msg = _mensajes[index];
                final esMio = msg['id_usuario'] == _miIdUsuario;
                return _buildMessageBubble(msg, esMio);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(
                    255,
                    255,
                    255,
                    255,
                  ).withOpacity(0.1),
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _enviar,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool esMio) {
    final baseUrl = ApiHttp.baseUrl;
    final hora = msg['created_at'] != null
        ? msg['created_at'].toString().substring(11, 16)
        : '';

    final colorFondo = esMio
        ? const Color.fromRGBO(19, 67, 107, 1)
        : Color.fromRGBO(245, 188, 6, 1);

    final colorTexto = esMio ? Colors.white : Colors.black87;
    final colorHora = esMio ? Colors.white70 : Colors.grey[600];
    final nombreUsuario = msg['nombre'] ?? 'Desconocido';
    final colorNombre = _getColorForName(nombreUsuario);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: esMio
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esMio) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[300],
              backgroundImage: (msg['foto_perfil'] != null)
                  ? NetworkImage('$baseUrl${msg['foto_perfil']}')
                  : null,
              child: (msg['foto_perfil'] == null)
                  ? Text(
                      nombreUsuario.isNotEmpty ? nombreUsuario[0] : '?',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
          ],

          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorFondo,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: esMio
                      ? const Radius.circular(18)
                      : const Radius.circular(2),
                  bottomRight: esMio
                      ? const Radius.circular(2)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!esMio)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        nombreUsuario,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorNombre,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  Text(
                    msg['mensaje'] ?? '',
                    style: TextStyle(fontSize: 15, color: colorTexto),
                  ),

                  const SizedBox(height: 4),

                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      hora,
                      style: TextStyle(fontSize: 10, color: colorHora),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
