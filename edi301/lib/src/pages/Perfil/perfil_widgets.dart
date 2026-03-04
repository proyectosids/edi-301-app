import 'package:flutter/material.dart';
import 'package:edi301/tools/fullscreen_image_viewer.dart';

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

  ImageProvider _getImageProvider() {
    if (avatarUrl.isNotEmpty &&
        avatarUrl != '—' &&
        !avatarUrl.contains('null')) {
      return NetworkImage(avatarUrl);
    }
    return const AssetImage('assets/img/7141724.png');
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _getImageProvider();
    final heroTag = 'user_avatar_${avatarUrl.hashCode}';
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Container(height: 120, color: primary),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Solo abre si hay imagen válida (no default / null)
                        if (avatarUrl.isNotEmpty &&
                            !avatarUrl.contains('null') &&
                            avatarUrl != '—') {
                          FullScreenImageViewer.open(
                            context,
                            imageProvider: imageProvider,
                            heroTag: heroTag,
                          );
                        }
                      },
                      child: Hero(
                        tag: heroTag,
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: imageProvider,
                            onBackgroundImageError: (_, __) {},
                            child:
                                (avatarUrl.isEmpty ||
                                    avatarUrl.contains('null'))
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onEditAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color.fromRGBO(245, 188, 6, 1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: -8,
                          children: [
                            ActionChip(
                              avatar: onTapStatus != null
                                  ? const Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                              label: Text(status),
                              backgroundColor: statusColor.withOpacity(
                                onTapStatus != null ? 1 : 0.15,
                              ),
                              labelStyle: TextStyle(
                                color: onTapStatus != null
                                    ? Colors.white
                                    : statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                              onPressed: onTapStatus,
                              visualDensity: VisualDensity.compact,
                              side: BorderSide.none,
                            ),
                            if (residence.isNotEmpty && residence != '—')
                              Chip(
                                label: Text('Residencia: $residence'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.white,
                              ),
                            if (family.isNotEmpty && family != '—')
                              Chip(
                                label: Text('$family'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  174,
                                  174,
                                  174,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    required this.primary,
  });
  final String title;
  final List<Widget> children;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 2),
                SelectableText(value, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _divider(),
          _switchTile(
            icon: Icons.dark_mode_outlined,
            title: 'Modo oscuro',
            value: darkMode,
            onChanged: (v) => onChanged('dark', v),
          ),
          _divider(),
          _switchTile(
            icon: Icons.cake_outlined,
            title: 'Recordar cumpleaños',
            value: birthdayReminder,
            onChanged: (v) => onChanged('bd', v),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _switchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      secondary: Icon(icon, color: primary),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
