import 'dart:convert';
import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/encuestas_api.dart';
import 'package:edi301/src/pages/Encuestas/resultados_encuesta_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncuestasPage extends StatefulWidget {
  const EncuestasPage({super.key});
  @override
  State<EncuestasPage> createState() => _EncuestasPageState();
}

class _EncuestasPageState extends State<EncuestasPage> {
  final api = EncuestasApi();
  late Future<List<dynamic>> future;
  bool admin = false;
  @override
  void initState() {
    super.initState();
    future = api.list();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('user');
    if (raw != null && mounted)
      setState(
        () => admin =
            (jsonDecode(raw)['nombre_rol'] ?? jsonDecode(raw)['rol']) ==
            'Admin',
      );
  }

  void load() {
    setState(() {
      future = api.list();
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Encuestas'),
      backgroundColor: const Color(0xFF13436B),
      foregroundColor: Colors.white,
    ),
    floatingActionButton: admin
        ? FloatingActionButton.extended(
            backgroundColor: const Color(0xFFF5BC06),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: const Text('Nueva encuesta'),
            onPressed: () async {
              final done = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CrearEncuestaPage()),
              );
              if (done == true) load();
            },
          )
        : null,
    body: FutureBuilder<List<dynamic>>(
      future: future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text(friendlyError(s.error!)));
        final list = s.data ?? [];
        if (list.isEmpty)
          return RefreshIndicator(
            onRefresh: () async => load(),
            child: ListView(
              children: [
                const SizedBox(height: 180),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.poll_outlined,
                        size: 72,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        admin
                            ? 'Aún no has creado encuestas.'
                            : 'No hay encuestas disponibles.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        return RefreshIndicator(
          onRefresh: () async => load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (c, i) {
              final x = Map<String, dynamic>.from(list[i] as Map);
              final canAnswer = x['respondida'] != true && x['abierta'] == true;
              return Card(
                child: ListTile(
                  leading: Icon(
                    x['estado'] == 'CERRADA' ? Icons.lock_outline : Icons.poll,
                    color: const Color(0xFF13436B),
                  ),
                  title: Text(x['titulo']),
                  subtitle: Text(
                    x['respondida'] == true
                        ? 'Respuesta enviada'
                        : canAnswer
                        ? 'Disponible para responder'
                        : x['estado'] == 'BORRADOR'
                        ? 'Borrador'
                        : 'Cerrada',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: admin
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultadosEncuestaPage(
                              idEncuesta: x['id_encuesta'] as int,
                            ),
                          ),
                        )
                      : canAnswer
                      ? () async {
                          await Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ResponderEncuestaPage(encuesta: x),
                            ),
                          );
                          load();
                        }
                      : null,
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class CrearEncuestaPage extends StatefulWidget {
  const CrearEncuestaPage({super.key});
  @override
  State<CrearEncuestaPage> createState() => _CrearEncuestaPageState();
}

class _CrearEncuestaPageState extends State<CrearEncuestaPage> {
  final api = EncuestasApi();
  final title = TextEditingController();
  final description = TextEditingController();
  final questions = <_DraftQuestion>[_DraftQuestion()];
  bool publish = true, saving = false;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    for (final q in questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      _error('Escribe un título.');
      return;
    }
    if (questions.length > 50) {
      _error('El máximo es 50 preguntas.');
      return;
    }
    for (final q in questions) {
      if (q.text.text.trim().isEmpty) {
        _error('Todas las preguntas deben tener texto.');
        return;
      }
      if (q.type != 'LIBRE' &&
          q.options.where((x) => x.text.trim().isNotEmpty).length < 2) {
        _error('Las preguntas de opciones requieren al menos dos opciones.');
        return;
      }
    }
    setState(() => saving = true);
    try {
      await api.create({
        'titulo': title.text.trim(),
        'descripcion': description.text.trim(),
        'estado': publish ? 'PUBLICADA' : 'BORRADOR',
        'preguntas': questions
            .map(
              (q) => {
                'texto': q.text.text.trim(),
                'tipo': q.type,
                'requerida': q.required,
                'opciones': q.type == 'LIBRE'
                    ? <String>[]
                    : q.options
                          .where((x) => x.text.trim().isNotEmpty)
                          .map((x) => x.text.trim())
                          .toList(),
              },
            )
            .toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _error(friendlyError(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _error(String m) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Nueva encuesta'),
      backgroundColor: const Color(0xFF13436B),
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: title,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Título *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          value: publish,
          onChanged: (v) => setState(() => publish = v),
          title: const Text('Publicar al guardar'),
          subtitle: const Text('Si no, quedará como borrador.'),
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(),
        ...questions.asMap().entries.map((e) => _questionCard(e.key, e.value)),
        if (questions.length < 50)
          OutlinedButton.icon(
            onPressed: () => setState(() => questions.add(_DraftQuestion())),
            icon: const Icon(Icons.add),
            label: Text('Agregar pregunta (${questions.length}/50)'),
          ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.publish),
          label: Text(
            saving
                ? 'Guardando...'
                : publish
                ? 'Publicar encuesta'
                : 'Guardar borrador',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF13436B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(15),
          ),
        ),
      ],
    ),
  );
  Widget _questionCard(int i, _DraftQuestion q) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pregunta ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (questions.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    q.dispose();
                    questions.removeAt(i);
                  }),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          TextField(
            controller: q.text,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Pregunta *'),
          ),
          DropdownButtonFormField<String>(
            initialValue: q.type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'UNICA', child: Text('Opción única')),
              DropdownMenuItem(
                value: 'MULTIPLE',
                child: Text('Opción múltiple'),
              ),
              DropdownMenuItem(value: 'LIBRE', child: Text('Respuesta libre')),
            ],
            onChanged: (v) => setState(() => q.type = v!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: q.required,
            onChanged: (v) => setState(() => q.required = v),
            title: const Text('Respuesta obligatoria'),
          ),
          if (q.type != 'LIBRE') ...[_options(q)],
        ],
      ),
    ),
  );
  Widget _options(_DraftQuestion q) => Column(
    children: [
      ...q.options.asMap().entries.map(
        (e) => Row(
          children: [
            Expanded(
              child: TextField(
                controller: e.value,
                decoration: InputDecoration(labelText: 'Opción ${e.key + 1}'),
              ),
            ),
            if (q.options.length > 2)
              IconButton(
                onPressed: () => setState(() {
                  e.value.dispose();
                  q.options.removeAt(e.key);
                }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () => setState(() => q.options.add(TextEditingController())),
        icon: const Icon(Icons.add),
        label: const Text('Agregar opción'),
      ),
    ],
  );
}

class _DraftQuestion {
  final text = TextEditingController();
  String type = 'UNICA';
  bool required = true;
  final options = [TextEditingController(), TextEditingController()];
  void dispose() {
    text.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

class ResponderEncuestaPage extends StatefulWidget {
  final Map<String, dynamic> encuesta;
  const ResponderEncuestaPage({super.key, required this.encuesta});
  @override
  State<ResponderEncuestaPage> createState() => _ResponderState();
}

class _ResponderState extends State<ResponderEncuestaPage> {
  final api = EncuestasApi();
  Map<String, dynamic>? survey;
  bool saving = false;
  final values = <int, dynamic>{};
  @override
  void initState() {
    super.initState();
    api.get(widget.encuesta['id_encuesta']).then((v) {
      if (mounted) setState(() => survey = v);
    });
  }

  @override
  Widget build(BuildContext c) {
    final s = survey;
    if (s == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final qs = s['preguntas'] as List;
    return Scaffold(
      appBar: AppBar(
        title: Text(s['titulo']),
        backgroundColor: const Color(0xFF13436B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((s['descripcion'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s['descripcion']),
            ),
          ...qs.map((raw) {
            final q = Map<String, dynamic>.from(raw as Map);
            final id = q['id_pregunta'] as int;
            final type = q['tipo'];
            final opts = q['opciones'] as List;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['texto'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (type == 'LIBRE')
                      TextField(maxLines: 3, onChanged: (v) => values[id] = v)
                    else if (type == 'UNICA')
                      ...opts.map((o) {
                        final m = Map<String, dynamic>.from(o as Map);
                        return RadioListTile<int>(
                          value: m['id_opcion'],
                          groupValue: values[id],
                          title: Text(m['texto']),
                          onChanged: (v) => setState(() => values[id] = v),
                        );
                      })
                    else
                      ...opts.map((o) {
                        final m = Map<String, dynamic>.from(o as Map);
                        final selected =
                            (values[id] as Set<int>?)?.contains(
                              m['id_opcion'],
                            ) ??
                            false;
                        return CheckboxListTile(
                          value: selected,
                          title: Text(m['texto']),
                          onChanged: (v) => setState(() {
                            final set = Set<int>.from(values[id] ?? <int>{});
                            v == true
                                ? set.add(m['id_opcion'])
                                : set.remove(m['id_opcion']);
                            values[id] = set;
                          }),
                        );
                      }),
                  ],
                ),
              ),
            );
          }),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      final a = qs.map((raw) {
                        final q = Map<String, dynamic>.from(raw as Map);
                        final v = values[q['id_pregunta']];
                        return {
                          'id_pregunta': q['id_pregunta'],
                          if (q['tipo'] == 'LIBRE') 'texto_libre': v ?? '',
                          if (q['tipo'] != 'LIBRE')
                            'opciones': v is Set<int>
                                ? v.toList()
                                : v == null
                                ? <int>[]
                                : [v],
                        };
                      }).toList();
                      await api.submit(s['id_encuesta'], a);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(friendlyError(e))),
                        );
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'Enviando...' : 'Enviar respuesta'),
          ),
        ],
      ),
    );
  }
}
