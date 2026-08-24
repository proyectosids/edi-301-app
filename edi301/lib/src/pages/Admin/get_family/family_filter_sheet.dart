import 'package:flutter/material.dart';
import 'package:edi301/src/pages/Admin/get_family/get_family_controller.dart';

Future<void> showFamilyFilters(
  BuildContext context,
  GetFamilyController controller,
) async {
  var residence = controller.residenceFilter;
  var student = controller.studentFilter;
  var capacity = controller.capacityFilter;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        Widget choices(
          List<(String, String)> values,
          String selected,
          ValueChanged<String> onSelected,
        ) {
          return Wrap(
            spacing: 8,
            runSpacing: 6,
            children: values
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.$2),
                    selected: selected == option.$1,
                    onSelected: (_) =>
                        setSheetState(() => onSelected(option.$1)),
                  ),
                )
                .toList(),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtrar familias',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Residencia',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                choices(
                  const [
                    ('TODAS', 'Todas'),
                    ('INTERNA', 'Internas'),
                    ('EXTERNA', 'Externas'),
                  ],
                  residence,
                  (value) => residence = value,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tipo de alumnos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                choices(
                  const [
                    ('TODOS', 'Todos'),
                    ('COLIVI', 'COLIVI'),
                    ('UNIVERSITARIOS', 'Universitarios'),
                  ],
                  student,
                  (value) => student = value,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Disponibilidad',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                choices(
                  const [
                    ('TODAS', 'Todas'),
                    ('DISPONIBLES', 'Con espacio'),
                    ('LLENAS', 'Llenas'),
                  ],
                  capacity,
                  (value) => capacity = value,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        controller.clearFilters();
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Limpiar'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        controller.updateFilters(
                          residence: residence,
                          student: student,
                          capacity: capacity,
                        );
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.filter_alt),
                      label: const Text('Aplicar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class FamilyResidenceBadge extends StatelessWidget {
  const FamilyResidenceBadge({super.key, required this.residence});

  final dynamic residence;

  @override
  Widget build(BuildContext context) {
    final internal = residence.toString().toUpperCase().startsWith('INT');
    final color = internal ? Colors.blue : Colors.deepOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        internal ? 'INTERNA' : 'EXTERNA',
        style: TextStyle(
          color: color.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
