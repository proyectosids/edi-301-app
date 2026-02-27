import 'dart:async'; // ✅ Importante para el Timer
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edi301/services/chat_api.dart';

class ChatPage extends StatefulWidget {
  final int idSala;
  final String nombreChat;

  const ChatPage({super.key, required this.idSala, required this.nombreChat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatApi _api = ChatApi();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<dynamic> _mensajes = [];
  bool _loading = true;
  int? _myId;

  Timer? _pollingTimer; // ✅ Referencia para el temporizador

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadMyId();
    await _loadMessages(); // Carga inicial
    _startPolling(); // ✅ Inicia el refresco automático
  }

  // ✅ Inicia el temporizador de pulling cada 3 segundos
  void _startPolling() {
    _pollingTimer?.cancel(); // Limpia cualquier timer previo
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadMessages(isPolling: true);
      }
    });
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr == null) return;
    final user = jsonDecode(userStr);
    final dynamic raw =
        user['id_usuario'] ?? user['id'] ?? user['ID'] ?? user['Id'];
    _myId = (raw is int) ? raw : int.tryParse(raw?.toString() ?? '');
  }

  @override
  void dispose() {
    _pollingTimer
        ?.cancel(); // ✅ Obligatorio: detener el timer al salir de la página
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ✅ Ajustado para manejar refrescos silenciosos
  Future<void> _loadMessages({bool isPolling = false}) async {
    // Solo mostramos el loader principal si es la primera carga y no hay mensajes
    if (!isPolling && _mensajes.isEmpty) {
      setState(() => _loading = true);
    }

    final msgs = await _api.getMessages(widget.idSala);

    final normalized = msgs.map((m) {
      if (m is! Map) return m;
      final msg = Map<String, dynamic>.from(m);
      final int? senderId = msg['id_usuario'] is int
          ? msg['id_usuario']
          : int.tryParse((msg['id_usuario'] ?? '').toString());
      msg['es_mio'] = (_myId != null && senderId == _myId) ? 1 : 0;
      return msg;
    }).toList();

    if (mounted) {
      // Solo actualizamos la UI si la cantidad de mensajes cambió
      if (normalized.length != _mensajes.length) {
        setState(() {
          _mensajes = normalized;
          _loading = false;
        });
        _scrollToBottom();
      } else {
        // Si no hay cambios, simplemente quitamos el loading si estaba activo
        if (_loading) setState(() => _loading = false);
      }
    }
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    final tempMsg = <String, dynamic>{
      'id_mensaje': tempId,
      'mensaje': text,
      'es_mio': 1,
      '_temp': true,
    };

    setState(() {
      _mensajes.add(tempMsg);
      _scrollToBottom();
    });

    // Petición HTTP (El backend enviará la Push de Firebase automáticamente)
    final success = await _api.sendMessage(widget.idSala, text);

    if (success) {
      // Refrescamos inmediatamente para confirmar el mensaje
      _loadMessages(isPolling: true);
    } else {
      if (mounted) {
        setState(() => _mensajes.removeWhere((m) => m['id_mensaje'] == tempId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al enviar mensaje")),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreChat),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _mensajes.isEmpty
                ? const Center(child: Text("Inicia la conversación..."))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(10),
                    itemCount: _mensajes.length,
                    itemBuilder: (ctx, i) {
                      final msg = _mensajes[i];
                      if (msg is! Map) return const SizedBox.shrink();

                      final esMio = msg['es_mio'] == 1 || msg['es_mio'] == true;

                      return Align(
                        alignment: esMio
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: esMio
                                ? const Color.fromRGBO(245, 188, 6, 1)
                                : Colors.grey[300],
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: esMio
                                  ? const Radius.circular(15)
                                  : Radius.zero,
                              bottomRight: esMio
                                  ? Radius.zero
                                  : const Radius.circular(15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!esMio)
                                Text(
                                  (msg['nombre_remitente'] ?? 'Usuario')
                                      .toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              Text(
                                (msg['mensaje'] ?? '').toString(),
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (msg['_temp'] == true)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Enviando...',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
