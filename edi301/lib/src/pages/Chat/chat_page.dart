import 'package:flutter/material.dart';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/services/socket_service.dart';

class ChatPage extends StatefulWidget {
  final int idSala;
  final String nombreChat;

  const ChatPage({super.key, required this.idSala, required this.nombreChat});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatApi _api = ChatApi();
  final SocketService _socketService = SocketService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<dynamic> _mensajes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _socketService.socket.off('nuevo_mensaje');
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _setupSocketListeners() {
    _socketService.socket.emit('join_room', widget.idSala.toString());

    _socketService.socket.on('nuevo_mensaje', (data) {
      if (mounted) {
        final yaExiste = _mensajes.any(
          (m) => m['id_mensaje'] == data['id_mensaje'],
        );
        if (!yaExiste) {
          setState(() {
            _mensajes.add(data);
          });
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final msgs = await _api.getMessages(widget.idSala);
    if (mounted) {
      setState(() {
        _mensajes = msgs;
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();

    final success = await _api.sendMessage(widget.idSala, text);

    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error al enviar mensaje")));
    }
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
                                  msg['nombre_remitente'] ?? 'Usuario',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              Text(
                                msg['mensaje'] ?? '',
                                style: const TextStyle(fontSize: 16),
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
            decoration: BoxDecoration(
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
