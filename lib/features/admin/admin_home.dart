import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../shared/notifications_page.dart';
import '../../core/theme/app_colors.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import '../auth/auth_controller.dart';
import '../shared/portal_drawer.dart';
import '../calendar/calendar_view.dart';
import 'appointments_tab.dart';
import 'reports_tab.dart';
import 'dashboard_tab.dart';
import 'staff_tab.dart';

/// Admin area. Navigation is the left menu that opens with the ☰ button.
/// Calendar and Reports are added in later stages.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;
  AppointmentStatus? _filter;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    // Create "upcoming appointment" notifications now and every 5 minutes.
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
    DrawerItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    DrawerItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'),
    DrawerItem(Icons.list_alt_outlined, Icons.list_alt, 'Appointments'),
    DrawerItem(Icons.people_outline, Icons.people, 'Staff'),
    DrawerItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
  ];

  static const _appointmentsIndex = 2;

  void _select(int i) => setState(() {
        _index = i;
        if (i == _appointmentsIndex) _filter = null;
      });

  void _openList(AppointmentStatus? filter) => setState(() {
        _filter = filter;
        _index = _appointmentsIndex;
      });

  @override
  Widget build(BuildContext context) {
    final repo = adminRepository;
    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(child: Text('The database is not available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: Text(_items[_index].label),
        actions: [NotificationBell(repo: repo)],
      ),
      drawer: PortalDrawer(
        roleLabel: 'Admin',
        userName: auth.session?.username ?? '',
        items: _items,
        selected: _index,
        onSelect: _select,
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardTab(repo: repo, onOpenList: _openList),
          CalendarView(repo: repo),
          AppointmentsTab(repo: repo, initialFilter: _filter),
          StaffTab(repo: repo),
          ReportsTab(repo: repo),
        ],
      ),
    );
  }
}
