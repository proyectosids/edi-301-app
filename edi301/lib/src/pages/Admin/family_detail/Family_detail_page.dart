import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/models/family_model.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/services/members_api.dart';
import 'package:edi301/src/pages/Admin/add_alumns/add_alumns_controller.dart';
import 'package:edi301/services/search_api.dart';

class FamilyDetailPage extends StatefulWidget {
  const FamilyDetailPage({super.key});

  @override
  State<FamilyDetailPage> createState() => _FamilyDetailPageState();
}

class _FamilyDetailPageState extends State<FamilyDetailPage> {
  final SocketService _socketService = SocketService();
  bool _realtimeSetup = false;
  int? _rtFamilyId;
  Family? _family;
  bool _isLoading = true;
  String? _error;
  final _membersApi = MembersApi();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      final args = ModalRoute.of(context)!.settings.arguments;

      int? familyId;
      if (args is Family) {
        familyId = args.id;
      } else if (args is int) {
        familyId = args;
      }

      if (familyId != null) {
        // ✅ Fijar a no-null para usarlo dentro de closures sin errores de null-safety.
        final int fid = familyId;
        if (!_realtimeSetup || _rtFamilyId != familyId) {
          _socketService.initSocket();
          _socketService.joinFamilyRoom(fid);

          _socketService.socket.off('miembro_agregado');
          _socketService.socket.on('miembro_agregado', (_) {
            if (mounted) _fetchFamilyDetails(fid);
          });

          _socketService.socket.off('miembro_eliminado');
          _socketService.socket.on('miembro_eliminado', (_) {
            if (mounted) _fetchFamilyDetails(fid);
          });

          _socketService.socket.off('miembros_actualizados');
          _socketService.socket.on('miembros_actualizados', (_) {
            if (mounted) _fetchFamilyDetails(fid);
          });

          _socketService.socket.off('nuevos_alumnos_asignados');
          _socketService.socket.on('nuevos_alumnos_asignados', (_) {
            if (mounted) _fetchFamilyDetails(fid);
          });

          _realtimeSetup = true;
          _rtFamilyId = fid;
        }

        _fetchFamilyDetails(fid);
      } else {
        setState(() {
          _isLoading = false;
          _error = 'No se pudo cargar la familia. ID no encontrado.';
        });
      }
    }
  }

  Future<void> _fetchFamilyDetails(int familyId) async {
    try {
      final api = FamiliaApi();
      final familyData = await api.getById(familyId);
      if (mounted) {
        setState(() {
          _family = Family.fromJson(familyData!);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al cargar los detalles: ${e.toString()}';
        });
      }
    }
  }

  Future<bool> _showDeleteDialog(String memberName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de que deseas quitar a $memberName de esta familia? (La relación se desactivará, el usuario no se borrará).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDeleteMember(FamilyMember member) async {
    final confirmed = await _showDeleteDialog(member.fullName);
    if (!confirmed || !mounted) return;

    try {
      await _membersApi.removeMember(member.idMiembro);
      setState(() {
        if (member.tipoMiembro == 'HIJO') {
          _family!.householdChildren.removeWhere(
            (m) => m.idMiembro == member.idMiembro,
          );
        } else if (member.tipoMiembro == 'ALUMNO_ASIGNADO') {
          _family!.assignedStudents.removeWhere(
            (m) => m.idMiembro == member.idMiembro,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Miembro quitado con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al quitar miembro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando Familia...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final fam = _family!;
    return Scaffold(
      appBar: AppBar(
        title: Text(fam.familyName),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(f: fam),
            const SizedBox(height: 16),
            _Section(
              title: 'Hijos en casa',
              items: fam.householdChildren,
              emptyText: 'Sin hijos registrados en casa.',
              buildTrailing: (child) => IconButton(
                tooltip: 'Quitar de la familia',
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _handleDeleteMember(child),
              ),
              leadingIcon: Icons.family_restroom,
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Alumnos asignados',
              items: fam.assignedStudents,
              emptyText: 'Sin alumnos asignados.',
              buildTrailing: (student) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Ver detalles',
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      'student_detail',
                      arguments: student.idUsuario,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar de la familia',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _handleDeleteMember(student),
                  ),
                ],
              ),
              leadingIcon: Icons.school,
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar alumnos a esta familia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final bool? didAdd = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (ctx) => _AddAlumnsSheet(family: fam),
                );
                if (didAdd == true && mounted) {
                  setState(() => _isLoading = true);
                  await _fetchFamilyDetails(fam.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.f});
  final Family f;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.familyName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Padre: ${f.fatherName ?? "No asignado"}'),
            Text('Madre: ${f.motherName ?? "No asignada"}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.home, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Residencia: ${f.residence}',
                  style: TextStyle(
                    color: f.residence == 'Interna' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.emptyText,
    required this.buildTrailing,
    required this.leadingIcon,
  });

  final String title;
  final List<FamilyMember> items;
  final String emptyText;
  final Widget Function(FamilyMember item) buildTrailing;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              child: Text(
                emptyText,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          else
            ...items.map(
              (e) => ListTile(
                dense: true,
                leading: Icon(leadingIcon),
                title: Text(e.fullName),
                trailing: buildTrailing(e),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddAlumnsSheet extends StatefulWidget {
  final Family family;
  const _AddAlumnsSheet({required this.family});

  @override
  State<_AddAlumnsSheet> createState() => _AddAlumnsSheetState();
}

class _AddAlumnsSheetState extends State<_AddAlumnsSheet> {
  final _controller = AddAlumnsController();
  final _alumnSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.init(context);
    _controller.selectFamily(widget.family);
  }

  @override
  void dispose() {
    _controller.dispose();
    _alumnSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asignar alumnos a:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            widget.family.familyName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color.fromRGBO(19, 67, 107, 1),
            ),
          ),
          const SizedBox(height: 20),
          _buildAlumnSelector(),
          const SizedBox(height: 20),
          _buildSelectedAlumnsList(),
          const SizedBox(height: 30),
          _buildSaveButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAlumnSelector() {
    return Column(
      children: [
        TextField(
          controller: _alumnSearchCtrl,
          decoration: InputDecoration(
            labelText: 'Buscar alumno por matrícula o nombre',
            prefixIcon: const Icon(Icons.person_search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) {
            _controller.searchAlumns(value);
          },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<UserMini>>(
          valueListenable: _controller.alumnSearchResults,
          builder: (context, results, child) {
            if (results.isEmpty) {
              return const SizedBox.shrink();
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 180,
              ), // Altura limitada
              child: Card(
                elevation: 2,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final alumn = results[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school)),
                      title: Text('${alumn.nombre} ${alumn.apellido}'),
                      subtitle: Text('Matrícula: ${alumn.matricula ?? 'N/A'}'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.green,
                        ),
                        tooltip: 'Añadir alumno',
                        onPressed: () {
                          _controller.addAlumn(alumn);
                          _alumnSearchCtrl.clear();
                          _controller.searchAlumns('');
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSelectedAlumnsList() {
    return ValueListenableBuilder<List<UserMini>>(
      valueListenable: _controller.selectedAlumns,
      builder: (context, alumns, child) {
        if (alumns.isEmpty) {
          return const Center(
            child: Text(
              'Ningún alumno añadido todavía.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return SizedBox(
          height: 100,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: alumns
                  .map(
                    (alumn) => Chip(
                      label: Text('${alumn.nombre} ${alumn.apellido}'),
                      avatar: const Icon(Icons.school),
                      onDeleted: () => _controller.removeAlumn(alumn),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (context, isLoading, child) {
          return ElevatedButton.icon(
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(isLoading ? 'GUARDANDO...' : 'GUARDAR ASIGNACIONES'),
            onPressed: isLoading ? null : _controller.saveAssignments,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
