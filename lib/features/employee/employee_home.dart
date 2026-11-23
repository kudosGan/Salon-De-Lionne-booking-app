import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../shared/notifications_page.dart';
import '../../core/theme/app_colors.dart';
import '../../data/admin_repository.dart';
import '../admin/appointments_tab.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_view.dart';
import '../shared/portal_drawer.dart';

/// What a stylist sees after logging in: their own calendar and appointments,
/// plus new requests nobody has taken yet.
class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  int _index = 0;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    adminRepository?.generateDueReminders();
    _reminderTimer = Timer.periodic(const Duration(minutes: 5),
        (_) => adminRepository?.generateDueReminders());
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  static const _items = [
    DrawerItem(Icons.calendar_month_outlined, Icons.calendar_month, 'My calendar'),
    DrawerItem(Icons.list_alt_outlined, Icons.list_alt, 'My appointments'),
  ];

  @override
  Widget build(BuildContext context) {
    final session = auth.session;
    final repo = adminRepository;
    final stylistId = session?.stylistId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: Text(_items[_index].label),
        actions: [
          if (repo != null && stylistId != null)
            NotificationBell(repo: repo, stylistId: stylistId),
        ],
      ),
      drawer: PortalDrawer(
        roleLabel: 'Stylist',
        userName: session?.username ?? '',
        items: _items,
        selected: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
      body: (repo == null || stylistId == null)
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'This login is not linked to a stylist profile. '
                    'Please ask the admin.',
                    textAlign: TextAlign.center),
              ),
            )
          : IndexedStack(
              index: _index,
              children: [
                CalendarView(repo: repo, forStylist: stylistId),
                AppointmentsTab(repo: repo, forStylist: stylistId),
              ],
            ),
    );
  }
}
