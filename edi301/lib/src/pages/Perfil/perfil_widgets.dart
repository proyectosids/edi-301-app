import 'package:flutter/material.dart';
import 'package:edi301/tools/fullscreen_image_viewer.dart';

// ─── Color helpers ────────────────────────────────────────────────────────────
Color hexToColor(String hex, {Color fallback = Colors.blue}) {
  try {
    final buf = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buf.write('ff');
    buf.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buf.toString(), radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ─── Header Card ─────────────────────────────────────────────────────────────
class HeaderCard extends StatelessWidget {
  const HeaderCard({
    super.key,
    required this.name,
    required this.family,
    required this.residence,
    required this.status,
    required this.avatarUrl,
    required this.primary,
    required this.statusColor,
    required this.onEditAvatar,
    this.onTapStatus,
  });

  final String name, family, residence, status, avatarUrl;
  final Color primary, statusColor;
  final VoidCallback onEditAvatar;
  final VoidCallback? onTapStatus;

  static const _gold = Color.fromRGBO(245, 188, 6, 1);
  static const _navyL = Color.fromRGBO(30, 85, 135, 1);

  ImageProvider _imgProvider() {
    if (avatarUrl.isNotEmpty &&
        avatarUrl != '—' &&
        !avatarUrl.contains('null')) {
      return NetworkImage(avatarUrl);
    }
    return const AssetImage('assets/img/7141724.png');
  }

  @override
  Widget build(BuildContext context) {
    final imgProvider = _imgProvider();
    final heroTag = 'user_avatar_${avatarUrl.hashCode}';
    final hasAvatar =
        avatarUrl.isNotEmpty && !avatarUrl.contains('null') && avatarUrl != '—';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, _navyL],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top section: avatar + name ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Stack(
                  children: [
                    GestureDetector(
                      onTap: hasAvatar
                          ? () => FullScreenImageViewer.open(
                              context,
                              imageProvider: imgProvider,
                              heroTag: heroTag,
                            )
                          : null,
                      child: Hero(
                        tag: heroTag,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _gold, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: imgProvider,
                            onBackgroundImageError: (_, __) {},
                            child: !hasAvatar
                                ? const Icon(
                                    Icons.person,
                                    size: 42,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    // Camera button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onEditAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _gold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Status chip
                      GestureDetector(
                        onTap: onTapStatus,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (onTapStatus != null) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 11,
                                  color: statusColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom section: family + residence badges ──────────────────
          if ((family.isNotEmpty && family != '—') ||
              (residence.isNotEmpty && residence != '—'))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (family.isNotEmpty && family != '—')
                    _badge(Icons.family_restroom_rounded, family),
                  if (residence.isNotEmpty && residence != '—')
                    _badge(Icons.home_rounded, 'Residencia $residence'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    required this.primary,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final Color primary;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: primary),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  final IconData icon;
  final String label, value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
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

// ─── Settings Card (unchanged, kept for compatibility) ────────────────────────
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.primary,
    required this.notif,
    required this.darkMode,
    required this.bgRefresh,
    required this.birthdayReminder,
    required this.onChanged,
  });

  final Color primary;
  final bool notif, darkMode, bgRefresh, birthdayReminder;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _tile(Icons.dark_mode_outlined, 'Modo oscuro', darkMode, 'dark'),
          _div(),
          _tile(
            Icons.cake_outlined,
            'Recordar cumpleaños',
            birthdayReminder,
            'bd',
          ),
        ],
      ),
    );
  }

  Widget _div() => const Divider(height: 1, indent: 56, endIndent: 16);

  Widget _tile(IconData icon, String title, bool value, String key) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: (v) => onChanged(key, v),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      secondary: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 18, color: primary),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
