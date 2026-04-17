import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);
  static const _navyL = Color.fromRGBO(30, 85, 135, 1);

  // Módulo principal (ancho completo)
  static const _primary = _AdminItem(
    label: 'Consultar Familias',
    sub: 'Directorio, detalles y reportes',
    icon: Icons.family_restroom_rounded,
    route: 'get_family',
    gradient: [Color.fromRGBO(19, 67, 107, 1), Color.fromRGBO(10, 40, 75, 1)],
    accent: _gold,
  );

  // Grid 2x2
  static const _grid = [
    _AdminItem(
      label: 'Agregar\nFamilia',
      sub: 'Nueva familia',
      icon: Icons.add_home_rounded,
      route: 'add_family',
      gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
      accent: Color(0xFF82B1FF),
    ),
    _AdminItem(
      label: 'Asignar\nAlumnos',
      sub: 'A familia existente',
      icon: Icons.school_rounded,
      route: 'add_alumns',
      gradient: [Color(0xFF00695C), Color(0xFF004D40)],
      accent: Color(0xFF80CBC4),
    ),
    _AdminItem(
      label: 'Tutor\nExterno',
      sub: 'Sin correo inst.',
      icon: Icons.person_add_alt_1_rounded,
      route: 'add_tutor',
      gradient: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
      accent: Color(0xFFCE93D8),
    ),
    _AdminItem(
      label: 'Cumpleaños',
      sub: 'Pasados y próximos',
      icon: Icons.cake_rounded,
      route: 'cumpleaños',
      gradient: [Color(0xFFC62828), Color(0xFFB71C1C)],
      accent: Color(0xFFEF9A9A),
    ),
  ];

  // Fila inferior
  static const _bottom = [
    _AdminItem(
      label: 'Agenda',
      sub: 'Eventos',
      icon: Icons.event_rounded,
      route: 'agenda',
      gradient: [Color(0xFFE65100), Color(0xFFBF360C)],
      accent: Color(0xFFFFCC80),
    ),
    _AdminItem(
      label: 'Reportes PDF',
      sub: 'Exportar datos',
      icon: Icons.picture_as_pdf_rounded,
      route: 'reportes',
      gradient: [Color(0xFF37474F), Color(0xFF263238)],
      accent: Color(0xFFB0BEC5),
    ),
  ];

  // Card de Gestionar Admins (ancho completo, debajo del grid)
  static const _adminCard = _AdminItem(
    label: 'Gestionar Administradores',
    sub: 'Asignar rol de Admin a usuarios',
    icon: Icons.manage_accounts_rounded,
    route: 'assign_admin',
    gradient: [Color(0xFF4A148C), Color(0xFF2E004F)],
    accent: Color(0xFFCE93D8),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: ResponsiveContent(
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),

              // ── Primary card ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(child: _PrimaryCard(item: _primary)),
              ),

              // ── Grid 2x2 ────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _GridCard(item: _grid[i]),
                    childCount: _grid.length,
                  ),
                ),
              ),

              // ── Gestionar Admins ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                    child: _PrimaryCard(item: _adminCard)),
              ),

              // ── Bottom row ───────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: _bottom
                        .map(
                          (item) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: item == _bottom.first ? 0 : 6,
                                right: item == _bottom.last ? 0 : 6,
                              ),
                              child: _BottomCard(item: item),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navyL],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withOpacity(0.4)),
                ),
                child: const Text(
                  'ADMINISTRADOR',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Panel de Control',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gestiona familias, alumnos y más',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _AdminItem {
  final String label;
  final String sub;
  final IconData icon;
  final String route;
  final List<Color> gradient;
  final Color accent;

  const _AdminItem({
    required this.label,
    required this.sub,
    required this.icon,
    required this.route,
    required this.gradient,
    required this.accent,
  });
}

// ── Primary card (full width) ─────────────────────────────────────────────────
class _PrimaryCard extends StatelessWidget {
  final _AdminItem item;
  const _PrimaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: item.gradient.first.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: item.accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.sub,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid card ─────────────────────────────────────────────────────────────────
class _GridCard extends StatelessWidget {
  final _AdminItem item;
  const _GridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: item.gradient.first.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, color: item.accent, size: 24),
            ),
            const Spacer(),
            Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.sub,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom card ───────────────────────────────────────────────────────────────
class _BottomCard extends StatelessWidget {
  final _AdminItem item;
  const _BottomCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: item.gradient.first.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(item.icon, color: item.accent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    item.sub,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
