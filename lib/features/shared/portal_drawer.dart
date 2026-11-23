import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/config/salon_assets.dart';
import '../../core/config/salon_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/salon_image.dart';
import '../auth/auth_controller.dart';

class DrawerItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const DrawerItem(this.icon, this.selectedIcon, this.label);
}

/// Left-hand menu opened with the hamburger (☰) button.
class PortalDrawer extends StatelessWidget {
  final String roleLabel; // e.g. "Admin" or "Stylist"
  final String userName;
  final List<DrawerItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  const PortalDrawer({
    super.key,
    required this.roleLabel,
    required this.userName,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return NavigationDrawer(
      backgroundColor: AppColors.cream,
      selectedIndex: selected,
      onDestinationSelected: (i) {
        Navigator.of(context).pop(); // close the drawer
        onSelect(i);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 16, 12),
          child: Row(
            children: [
              const SizedBox(
                width: 52,
                height: 52,
                child: ClipOval(
                    child: SalonImage(SalonAssets.logo, fit: BoxFit.contain)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(SalonConfig.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('$roleLabel · $userName',
                        style: const TextStyle(
                            color: AppColors.brown, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 24, endIndent: 24),
        for (final d in items)
          NavigationDrawerDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
        const Divider(indent: 24, endIndent: 24),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.public),
          title: const Text('View website'),
          onTap: () {
            Navigator.of(context).pop();
            context.go('/');
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.logout),
          title: const Text('Log out'),
          onTap: () {
            Navigator.of(context).pop();
            auth.logout(); // the router sends you back to the login page
          },
        ),
      ],
    );
  }
}
