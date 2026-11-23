import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../services/message_templates.dart';
import '../shared/whatsapp_dialog.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import 'appointment_detail.dart';
import 'widgets/appointment_card.dart';
import 'widgets/status_chip.dart';

class DashboardTab extends StatefulWidget {
  final AdminRepository repo;

  /// Jump to the appointments list, optionally filtered.
  final void Function(AppointmentStatus? filter) onOpenList;
  const DashboardTab({super.key, required this.repo, required this.onOpenList});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DashboardStats? _stats;
  List<BookingRequest> _pending = [];
  List<BookingRequest> _reminders = [];

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
    final s = await widget.repo.stats();
    final p = await widget.repo.appointments(status: AppointmentStatus.pending);
    final r = await widget.repo.remindersToSend();
    if (mounted) {
      setState(() {
        _stats = s;
        _pending = p;
        _reminders = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    if (s == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;

    Widget stat(String label, int value, IconData icon, Color color,
        {AppointmentStatus? filter, bool tappable = true}) {
      return SizedBox(
        width: 170,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tappable ? () => widget.onOpenList(filter) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: .15),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(height: 12),
                  Text('$value',
                      style: t.headlineMedium?.copyWith(fontSize: 30)),
                  Text(label, style: const TextStyle(color: AppColors.brown)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Dashboard', style: t.headlineSmall),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [
            stat('Today', s.today, Icons.today, AppColors.brown, tappable: false),
            stat('New requests', s.pending, Icons.notifications_active_outlined,
                statusColor(AppointmentStatus.pending),
                filter: AppointmentStatus.pending),
            stat('Confirmed', s.confirmed, Icons.check_circle_outline,
                statusColor(AppointmentStatus.confirmed),
                filter: AppointmentStatus.confirmed),
            stat('Completed', s.completed, Icons.done_all,
                statusColor(AppointmentStatus.completed),
                filter: AppointmentStatus.completed),
            stat('Cancelled', s.cancelled, Icons.event_busy,
                statusColor(AppointmentStatus.cancelled),
                filter: AppointmentStatus.cancelled),
            stat('Total clients', s.clients, Icons.people_outline,
                AppColors.brown, tappable: false),
            stat('Stylists', s.stylists, Icons.content_cut, AppColors.brown,
                tappable: false),
            stat('This month', s.month, Icons.calendar_month, AppColors.brown,
                tappable: false),
          ]),
          if (_reminders.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Reminders to send', style: t.titleLarge),
            const SizedBox(height: 4),
            const Text('These appointments start within 24 hours.',
                style: TextStyle(color: AppColors.brown, fontSize: 12)),
            const SizedBox(height: 8),
            for (final a in _reminders)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.blush,
                    child: Icon(Icons.alarm, color: AppColors.brown),
                  ),
                  title: Text(a.clientName),
                  subtitle: Text(
                      '${formatDate(a.date)} · ${formatSlot(a.slotMinutes)}'),
                  trailing: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.whatsapp,
                        padding: const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: () => showWhatsAppDialog(
                      context,
                      a,
                      MessageKind.reminder,
                      onOpened: () => widget.repo.markReminderSent(a.id),
                    ),
                    child: const Text('Send'),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: Text('New booking requests', style: t.titleLarge)),
            if (_pending.isNotEmpty)
              TextButton(
                  onPressed: () => widget.onOpenList(AppointmentStatus.pending),
                  child: const Text('See all')),
          ]),
          const SizedBox(height: 8),
          if (_pending.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No requests waiting. New bookings from the website show up here.',
                    style: TextStyle(color: AppColors.brown)),
              ),
            )
          else
            for (final a in _pending.take(5))
              AppointmentCard(
                appointment: a,
                onTap: () => showAppointmentDetail(context, widget.repo, a),
              ),
        ],
      ),
    );
  }
}
