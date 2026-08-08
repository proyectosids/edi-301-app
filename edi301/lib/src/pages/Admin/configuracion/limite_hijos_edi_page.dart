import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/configuracion_api.dart';
import 'package:flutter/material.dart';

class LimiteHijosEdiPage extends StatefulWidget {
  const LimiteHijosEdiPage({super.key});

  @override
  State<LimiteHijosEdiPage> createState() => _LimiteHijosEdiPageState();
}

class _LimiteHijosEdiPageState extends State<LimiteHijosEdiPage> {
  static const _navy = Color(0xFF13436B);
  final _api = ConfiguracionApi();
  int? _limit;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final limit = await _api.getLimiteHijosEdi();
      if (mounted) setState(() => _limit = limit);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final limit = _limit;
    if (limit == null) return;
    setState(() => _saving = true);
    try {
      final saved = await _api.updateLimiteHijosEdi(limit);
      if (!mounted) return;
      setState(() => _limit = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Límite actualizado a $saved hijo(s) EDI por familia.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Límite de hijos EDI'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 40,
                          color: _navy,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Máximo global por familia',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Este valor aplica a todas las familias. Los hijos sanguíneos no se incluyen en este límite.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<int>(
                          key: ValueKey(_limit),
                          initialValue: _limit,
                          decoration: const InputDecoration(
                            labelText: 'Hijos EDI permitidos por familia',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.format_list_numbered),
                          ),
                          items: List.generate(
                            20,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1} hijo(s) EDI'),
                            ),
                          ),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _limit = value),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Rango permitido: de 1 a 20. El valor predeterminado es 7.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving || _limit == null ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _saving ? 'Guardando...' : 'Guardar límite',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
