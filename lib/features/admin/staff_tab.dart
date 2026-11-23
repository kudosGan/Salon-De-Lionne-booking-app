import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import 'staff_form.dart';

const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class StaffTab extends StatefulWidget {
  final AdminRepository repo;
  const StaffTab({super.key, required this.repo});

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  List<StaffMember>? _staff;

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final s = await widget.repo.staff();
    if (mounted) setState(() => _staff = s);
  }

  void _open([StaffMember? member]) => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => StaffFormPage(repo: widget.repo, member: member)),
      );

  @override
  Widget build(BuildContext context) {
    final staff = _staff;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brown,
        foregroundColor: AppColors.white,
        onPressed: _open,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add stylist'),
      ),
      body: staff == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                for (final m in staff) _StaffCard(member: m, onTap: () => _open(m)),
                if (staff.isEmpty)
                  const Center(child: Text('No stylists yet. Tap "Add stylist".')),
              ],
            ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  final VoidCallback onTap;
  const _StaffCard({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = member;
    final days = (m.workDays.toList()..sort()).map((d) => dayNames[d - 1]).join(', ');
    return Opacity(
      opacity: m.active ? 1 : .55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                StaffAvatar(photo: m.photo, name: m.name, radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      if (m.specialties.isNotEmpty)
                        Text(m.specialties,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                          '$days · ${formatSlot(m.startMinutes)} – ${formatSlot(m.endMinutes)}',
                          style: const TextStyle(
                              color: AppColors.brown, fontSize: 12)),
                      Text(
                          m.username == null
                              ? 'No login yet'
                              : 'Login: ${m.username}',
                          style: TextStyle(
                              fontSize: 12,
                              color: m.username == null
                                  ? const Color(0xFFB5544B)
                                  : AppColors.brown)),
                    ],
                  ),
                ),
                if (!m.active)
                  const Chip(
                      label: Text('Inactive'), visualDensity: VisualDensity.compact),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StaffAvatar extends StatelessWidget {
  final Uint8List? photo;
  final String name;
  final double radius;
  const StaffAvatar(
      {super.key, required this.photo, required this.name, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final p = photo;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.blush,
      backgroundImage: p == null ? null : MemoryImage(p),
      child: p == null
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                  fontSize: radius * .8,
                  color: AppColors.brown,
                  fontWeight: FontWeight.w700))
          : null,
    );
  }
}
