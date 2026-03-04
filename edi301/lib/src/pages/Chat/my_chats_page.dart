import 'package:flutter/material.dart';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/src/pages/Chat/chat_page.dart';
import 'package:edi301/core/api_client_http.dart';

class MyChatsPage extends StatefulWidget {
  const MyChatsPage({super.key});

  @override
  State<MyChatsPage> createState() => _MyChatsPageState();
}

class _MyChatsPageState extends State<MyChatsPage> {
  final ChatApi _api = ChatApi();
  List<dynamic> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _loading = true);
    try {
      final chats = await _api.getMyChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _absUrl(String raw) {
    if (raw.isEmpty || raw == 'null') return '';
    var s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    s = s.replaceAll('\\', '/');

    final idxPublic = s.indexOf('public/uploads/');
    if (idxPublic != -1) {
      s = s.substring(idxPublic + 'public'.length);
    }

    final idxUploads = s.indexOf('/uploads/');
    if (idxUploads != -1) {
      s = s.substring(idxUploads);
    } else if (s.startsWith('uploads/')) {
      s = '/$s';
    } else if (!s.startsWith('/')) {
      s = '/$s';
    }

    return '${ApiHttp.baseUrl}$s';
  }

  String _formatDate(String? fechaIso) {
    if (fechaIso == null) return "";
    final date = DateTime.parse(fechaIso).toLocal();
    final now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      return "${date.day}/${date.month}";
    }
  }

  void _goToChat(Map<String, dynamic> chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          idSala: chat['id_sala'],
          nombreChat: chat['titulo_chat'] ?? 'Chat',
        ),
      ),
    );
    _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Conversaciones"),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "No tienes chats activos",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (ctx, i) {
                final chat = _chats[i];
                final tipo = chat['tipo'];
                final fotoRaw = (chat['foto_perfil_chat'] ?? '').toString();
                final fotoAbs = _absUrl(fotoRaw);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tipo == 'GRUPAL'
                        ? Colors.orange
                        : const Color.fromRGBO(19, 67, 107, 1),
                    backgroundImage: (tipo != 'GRUPAL' && fotoAbs.isNotEmpty)
                        ? NetworkImage(fotoAbs)
                        : null,
                    child: (tipo != 'GRUPAL' && fotoAbs.isNotEmpty)
                        ? null
                        : Icon(
                            tipo == 'GRUPAL' ? Icons.groups : Icons.person,
                            color: Colors.white,
                          ),
                  ),
                  title: Text(
                    chat['titulo_chat'] ?? 'Desconocido',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    chat['ultimo_mensaje'] ?? 'Incia la conversascion...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: chat['ultimo_mensaje'] == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  trailing: Text(
                    _formatDate(chat['fecha_ultimo']),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () => _goToChat(chat),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
        child: const Icon(Icons.info, color: Colors.black),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Ve a la sección de Familias o Alumnos para iniciar un chat.",
              ),
            ),
          );
        },
      ),
    );
  }
}
