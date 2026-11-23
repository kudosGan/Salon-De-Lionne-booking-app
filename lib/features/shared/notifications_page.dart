import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/admin_repository.dart';
import '../../data/notifications.dart';
import '../admin/appointment_detail.dart';

/// Bell icon with an unread count. Tapping opens the notifications list.
/// Pass [stylistId] for a stylist; leave it null for the admin.
class NotificationBell extends StatefulWidget {
  final AdminRepository repo;
  final String? stylistId;
  const NotificationBell({super.key, required this.repo, this.stylistId});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

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
    final n = await widget.repo.unreadCount(stylistId: widget.stylistId);
    if (mounted) setState(() => _unread = n);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            NotificationsPage(repo: widget.repo, stylistId: widget.stylistId),
      )),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  final AdminRepository repo;
  final String? stylistId;
  const NotificationsPage({super.key, required this.repo, this.stylistId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification>? _items;

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
    final list = await widget.repo.notifications(stylistId: widget.stylistId);
    if (mounted) setState(() => _items = list);
  }

  Future<void> _open(AppNotification n) async {
    await widget.repo.markRead(n.id);
    final id = n.appointmentId;
    if (id == null || !mounted) return;
    final all = await widget.repo.appointments();
    final a = all.where((x) => x.id == id).firstOrNull;
    if (a == null || !mounted) return;
    await showAppointmentDetail(context, widget.repo, a,
        asStylistId: widget.stylistId);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () =>
                widget.repo.markAllRead(stylistId: widget.stylistId),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Text('Nothing new yet.',
                      style: TextStyle(color: AppColors.brown)))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return ListTile(
                      onTap: () => _open(n),
                      tileColor: n.read ? null : AppColors.blush.withValues(alpha: .6),
                      leading: CircleAvatar(
                        backgroundColor:
                            n.read ? AppColors.beige : AppColors.softPink,
                        child: Icon(_iconFor(n.title),
                            size: 20, color: AppColors.brown),
                      ),
                      title: Text(n.title,
                          style: TextStyle(
                              fontWeight:
                                  n.read ? FontWeight.w400 : FontWeight.w700)),
                      subtitle: Text(n.body),
                      trailing: Text(timeAgo(n.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.brown)),
                    );
                  },
                ),
    );
  }

  static IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('reminder') || t.contains('upcoming')) {
      return Icons.alarm;
    }
    if (t.contains('cancel') || t.contains('declin')) return Icons.event_busy;
    if (t.contains('reschedul')) return Icons.event_repeat;
    if (t.contains('confirm') || t.contains('accept')) return Icons.check_circle_outline;
    if (t.contains('assign')) return Icons.person_add_alt;
    return Icons.notifications_active_outlined;
  }
}
