import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/search_api.dart';
import 'package:edi301/src/pages/Admin/add_family/add_family_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edi301/services/chat_api.dart';
import 'package:edi301/src/pages/Chat/chat_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _qCtrl = TextEditingController();
  final ValueNotifier<bool> _loading = ValueNotifier(false);
  final ValueNotifier<List<UserMini>> _alumnos = ValueNotifier([]);
  final ValueNotifier<List<UserMini>> _empleados = ValueNotifier([]);
  final ValueNotifier<List<FamilyMini>> _familias = ValueNotifier([]);
  final ValueNotifier<List<UserMini>> _externos = ValueNotifier([]);
  bool _searched = false;

  final _api = SearchApi();
  final ChatApi _chatApi = ChatApi();

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

  @override
  void dispose() {
    _qCtrl.dispose();
    _loading.dispose();
    _alumnos.dispose();
    _empleados.dispose();
    _familias.dispose();
    _externos.dispose();
    super.dispose();
  }

  Future<void> _runSearch([String? raw]) async {
    final q = (raw ?? _qCtrl.text).trim();
    if (q.isEmpty) {
      _alumnos.value = [];
      _empleados.value = [];
      _familias.value = [];
      _externos.value = [];
      setState(() => _searched = false);
      return;
    }
    _loading.value = true;
    try {
      final r = await _api.searchAll(q);
      _alumnos.value = r.alumnos;
      _empleados.value = r.empleados;
      _familias.value = r.familias;
      _externos.value = r.externos;
    } catch (_) {
      _alumnos.value = [];
      _empleados.value = [];
      _familias.value = [];
      _externos.value = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la búsqueda')),
        );
      }
    } finally {
      _loading.value = false;
      setState(() => _searched = true);
    }
  }

  void _startChat(int idUsuario, String nombre) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Abriendo chat..."),
        duration: Duration(milliseconds: 800),
      ),
    );

    final idSala = await _chatApi.initPrivateChat(idUsuario);

    if (idSala != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(idSala: idSala, nombreChat: nombre),
        ),
      );
    }
  }

  Future<void> _makeAction(
    String scheme,
    String path,
    String actionName,
  ) async {
    final String value = path.trim();
    if (value.isEmpty || value == '—') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay un $actionName disponible.')),
      );
      return;
    }
    final Uri uri = Uri(scheme: scheme, path: value);
    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo $actionName a $value')),
      );
    } else {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        title: const Text('Búsqueda general'),
        elevation: 0,
      ),
      body: ResponsiveContent(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: Column(
            children: [
              _searchField(),
              const SizedBox(height: 8),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _loading,
                  builder: (_, loading, __) {
                    if (loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _bodyResults();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bodyResults() {
    if (!_searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Ingresa una matrícula, # de empleado o nombre de familia',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      children: [
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: _alumnos,
          builder: (_, list, __) => _section(
            title: 'Alumnos (${list.length})',
            emptyText: 'Sin alumnos',
            children: list.map(_userTile).toList(),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: _empleados,
          builder: (_, list, __) => _section(
            title: 'Empleados (${list.length})',
            emptyText: 'Sin empleados',
            children: list.map(_userTile).toList(),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<FamilyMini>>(
          valueListenable: _familias,
          builder: (_, list, __) => _section(
            title: 'Familias (${list.length})',
            emptyText: 'Sin familias',
            children: list.map(_familyTile).toList(),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: _externos,
          builder: (_, list, __) => _section(
            title: 'Tutores Externos (${list.length})',
            emptyText: 'Sin tutores externos',
            children: list.map(_userTile).toList(),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _section({
    required String title,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  emptyText,
                  style: const TextStyle(color: Colors.black54),
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }

  Widget _userTile(UserMini u) {
    final tipo = (u.tipo).toUpperCase();
    final fullName = '${u.nombre} ${u.apellido}'.trim();
    final doc = (tipo == 'EMPLEADO' && u.numEmpleado != null)
        ? 'No. empleado: ${u.numEmpleado}'
        : (u.matricula != null ? 'Matrícula: ${u.matricula}' : '');
    final fotoAbs = _absUrl(u.fotoPerfil ?? '');

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: fotoAbs.isNotEmpty ? NetworkImage(fotoAbs) : null,
        child: fotoAbs.isNotEmpty ? null : const Icon(Icons.person),
      ),
      title: Text(fullName.isEmpty ? '—' : fullName),
      subtitle: Text([tipo, doc].where((e) => e.isNotEmpty).join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Enviar mensaje',
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
            onPressed: () => _startChat(u.id, fullName),
          ),
          IconButton(
            tooltip: 'Ver detalle',
            icon: const Icon(Icons.remove_red_eye_outlined),
            onPressed: () {
              Navigator.pushNamed(context, 'student_detail', arguments: u.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _familyTile(FamilyMini f) {
    final res = (f.residencia ?? 'Desconocida');
    final color = res.toLowerCase().startsWith('intern')
        ? Colors.green
        : Colors.red;

    void openFamily() {
      Navigator.pushNamed(context, 'family_detail', arguments: f.id);
    }

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.home)),
      title: Text(f.nombre.isEmpty ? '—' : f.nombre),
      subtitle: Text('Residencia: $res'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Ver detalle',
            icon: const Icon(Icons.remove_red_eye_outlined),
            onPressed: openFamily,
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
      onTap: openFamily,
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _qCtrl,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      onSubmitted: _runSearch,
      onChanged: (v) {
        if (v.trim().length >= 3) _runSearch(v);
      },
      decoration: InputDecoration(
        hintText: 'Ingrese matrícula, # de empleado o nombre de familia',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color.fromRGBO(245, 188, 6, 1)),
        ),
        enabledBorder: OutlineInputBorder(
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
          horizontal: 16,
          vertical: 12,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search, color: Color.fromRGBO(19, 67, 107, 1)),
          onPressed: () => _runSearch(),
        ),
      ),
    );
  }
}
