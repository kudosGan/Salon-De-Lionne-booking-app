import 'package:material_ui/material_ui.dart';
import '../../services/calendar_links.dart';
import '../../services/file_share.dart';
import '../shared/whatsapp_dialog.dart';
import '../../services/message_templates.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/salon_image.dart';
import '../../data/admin_repository.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import 'widgets/status_chip.dart';

/// Opens the full appointment view as a bottom sheet.
///
/// Pass [asStylistId] when a stylist (not the admin) is viewing: they get
/// Accept / Decline / Completed only, never assign, reschedule or cancel.
Future<void> showAppointmentDetail(
    BuildContext context, AdminRepository repo, BookingRequest appointment,
    {String? asStylistId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      maxChildSize: .95,
      builder: (context, scroll) => _Detail(
          repo: repo,
          appointment: appointment,
          scrollController: scroll,
          asStylistId: asStylistId),
    ),
  );
}

class _Detail extends StatefulWidget {
  final AdminRepository repo;
  final BookingRequest appointment;
  final ScrollController scrollController;
  final String? asStylistId;
  const _Detail(
      {required this.repo,
      required this.appointment,
      required this.scrollController,
      this.asStylistId});

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  late BookingRequest a = widget.appointment;
  ClientSummary? _client;
  List<ReferencePhoto> _photos = [];
  List<Stylist> _stylists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.repo;
    final all = await repo.appointments();
    final fresh = all.where((x) => x.id == a.id).firstOrNull ?? a;
    final client = fresh.clientId == null ? null : await repo.client(fresh.clientId!);
    final photos = await repo.photos(a.id);
    final stylists = await repo.stylists();
    if (!mounted) return;
    setState(() {
      a = fresh;
      _client = client;
      _photos = photos;
      _stylists = stylists;
    });
  }

  /// Runs a change. If it worked and [offer] is set, immediately offers to
  /// send the matching WhatsApp message to the client.
  Future<void> _run(Future<String?> Function() action, String done,
      {MessageKind? offer}) async {
    final error = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? done)));
    if (error != null) return;
    await _load();
    if (offer != null && mounted) await _offerWhatsApp(offer);
  }

  /// Shows the ready-made message; the salon taps Send in WhatsApp.
  Future<void> _offerWhatsApp(MessageKind kind) => showWhatsAppDialog(
        context,
        a,
        kind,
        // A reminder that was sent no longer shows in "Reminders to send".
        onOpened: kind == MessageKind.reminder
            ? () => widget.repo.markReminderSent(a.id)
            : null,
      );

  /// Calendar file the client can open in Apple Calendar / Google Calendar.
  Future<void> _shareIcs() async {
    try {
      await shareTextFile(
        fileName: 'appointment.ics',
        content: CalendarLinks.ics(a),
        mimeType: 'text/calendar',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not create the calendar file.')));
      }
    }
  }

  Future<void> _reschedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: a.date.isBefore(today) ? today : a.date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final free = await widget.repo.availableSlots(date,
        stylistId: a.stylist?.id, exceptAppointmentId: a.id);
    final nowMin = now.hour * 60 + now.minute;
    final isToday = date == today;
    final options = [
      for (final m in Catalog.slots)
        if (free.contains(m) && !(isToday && m <= nowMin)) m
    ];
    if (!mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No free times on that day. Try another date.')));
      return;
    }
    final slot = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Free times on ${formatDate(date)}'),
        content: SingleChildScrollView(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in options)
              ActionChip(
                  label: Text(formatSlot(m)),
                  onPressed: () => Navigator.pop(ctx, m)),
          ]),
        ),
      ),
    );
    if (slot == null) return;
    await _run(() => widget.repo.reschedule(a.id, date, slot),
        'Rescheduled to ${formatDate(date)} at ${formatSlot(slot)}.',
        offer: MessageKind.reschedule);
  }

  Future<void> _confirmAction(String title, Future<String?> Function() action,
      String done,
      {MessageKind? offer}) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('${a.clientName} · ${formatDate(a.date)} at ${formatSlot(a.slotMinutes)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go back')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (yes == true) await _run(action, done, offer: offer);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final open = a.status == AppointmentStatus.pending ||
        a.status == AppointmentStatus.confirmed ||
        a.status == AppointmentStatus.rescheduled;

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 100,
                child: Text(k,
                    style: const TextStyle(
                        color: AppColors.brown, fontWeight: FontWeight.w600))),
            Expanded(child: SelectableText(v)),
          ]),
        );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Expanded(child: Text(a.clientName, style: t.headlineSmall)),
          StatusChip(a.status),
        ]),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              row('Date', formatDate(a.date)),
              row('Time', formatSlot(a.slotMinutes)),
              row('Service', a.serviceName),
              if (a.hairstyle != null) row('Style', a.hairstyle!.name),
              if (a.notes.isNotEmpty) row('Notes', a.notes),
              row('Requested', formatDate(a.createdAt)),
            ]),
          ),
        ),
        if (a.hairstyle != null) ...[
          const SizedBox(height: 12),
          Text('Requested hairstyle', style: t.titleLarge),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
                height: 180,
                width: double.infinity,
                child: SalonImage(a.hairstyle!.asset, label: a.hairstyle!.name)),
          ),
        ],
        const SizedBox(height: 12),
        Text('Reference photos', style: t.titleLarge),
        const SizedBox(height: 8),
        if (_photos.isEmpty)
          const Text('The client did not upload any photos.',
              style: TextStyle(color: AppColors.brown))
        else
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in _photos)
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                      child: InteractiveViewer(child: Image.memory(p.bytes))),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(p.bytes,
                      width: 100, height: 100, fit: BoxFit.cover),
                ),
              ),
          ]),
        const SizedBox(height: 16),
        Text('Client', style: t.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _client == null
                ? const Text('Loading…')
                : Column(children: [
                    row('Name', _client!.name),
                    row('Phone', _client!.phone),
                    row('Email', _client!.email ?? '—'),
                    row('Visits', '${_client!.history.length} appointment(s) in total'),
                    if (_client!.history.length > 1) ...[
                      const Divider(),
                      for (final h in _client!.history.where((h) => h.id != a.id).take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    '${formatDate(h.date)} · ${h.serviceName}'
                                    '${h.hairstyle != null ? ' · ${h.hairstyle!.name}' : ''}',
                                    style: const TextStyle(fontSize: 13))),
                            StatusChip(h.status),
                          ]),
                        ),
                    ],
                  ]),
          ),
        ),
        const SizedBox(height: 16),
        if (open && widget.asStylistId != null) ...[
          // Stylist view: accept / decline / complete only.
          Text('Your actions', style: t.titleLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (a.status == AppointmentStatus.pending) ...[
              FilledButton.icon(
                onPressed: () => _run(
                    () => widget.repo.acceptAs(a.id, widget.asStylistId!),
                    'Request accepted and confirmed.',
                    offer: MessageKind.confirmation),
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmAction(
                    'Decline this request?',
                    () => widget.repo.declineAs(a.id, widget.asStylistId!),
                    'Request declined.',
                    offer: MessageKind.declined),
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () => _confirmAction(
                    'Mark as completed?',
                    () => widget.repo.completeAs(a.id, widget.asStylistId!),
                    'Marked completed.'),
                icon: const Icon(Icons.done_all),
                label: const Text('Mark completed'),
              ),
          ]),
        ] else if (open) ...[
          Text('Manage', style: t.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: a.stylist?.id,
            decoration: const InputDecoration(labelText: 'Assigned stylist'),
            hint: const Text('Choose a stylist'),
            items: [
              for (final s in _stylists)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (id) => id == null
                ? null
                : _run(() => widget.repo.assignStylist(a.id, id), 'Stylist assigned.'),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (a.status == AppointmentStatus.pending) ...[
              FilledButton.icon(
                onPressed: () => _run(() => widget.repo.confirm(a.id),
                    'Appointment confirmed.',
                    offer: MessageKind.confirmation),
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmAction(
                    'Decline this request?',
                    () => widget.repo.setStatus(a.id, AppointmentStatus.declined),
                    'Request declined.',
                    offer: MessageKind.declined),
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _reschedule,
              icon: const Icon(Icons.event_repeat),
              label: const Text('Reschedule'),
            ),
            if (a.status != AppointmentStatus.pending)
              OutlinedButton.icon(
                onPressed: () => _confirmAction(
                    'Mark as completed?',
                    () => widget.repo.setStatus(a.id, AppointmentStatus.completed),
                    'Marked completed.'),
                icon: const Icon(Icons.done_all),
                label: const Text('Completed'),
              ),
            if (a.status != AppointmentStatus.pending)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB5544B),
                    side: const BorderSide(color: Color(0xFFB5544B))),
                onPressed: () => _confirmAction(
                    'Cancel this appointment?',
                    () => widget.repo.setStatus(a.id, AppointmentStatus.cancelled),
                    'Appointment cancelled.',
                    offer: MessageKind.cancellation),
                icon: const Icon(Icons.event_busy),
                label: const Text('Cancel'),
              ),
          ]),
        ],
        if (a.status == AppointmentStatus.confirmed ||
            a.status == AppointmentStatus.rescheduled ||
            a.status == AppointmentStatus.cancelled) ...[
          const SizedBox(height: 20),
          Text('Message the client', style: t.titleLarge),
          const SizedBox(height: 4),
          const Text(
              'Opens WhatsApp with the message ready. You tap Send there.',
              style: TextStyle(color: AppColors.brown, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (a.status == AppointmentStatus.confirmed ||
                a.status == AppointmentStatus.rescheduled) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
                onPressed: () => _offerWhatsApp(MessageKind.confirmation),
                icon: const Icon(Icons.chat),
                label: const Text('Confirmation'),
              ),
              if (a.status == AppointmentStatus.rescheduled)
                OutlinedButton.icon(
                  onPressed: () => _offerWhatsApp(MessageKind.reschedule),
                  icon: const Icon(Icons.event_repeat),
                  label: const Text('Reschedule notice'),
                ),
              OutlinedButton.icon(
                onPressed: () => _offerWhatsApp(MessageKind.reminder),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Reminder'),
              ),
              OutlinedButton.icon(
                onPressed: _shareIcs,
                icon: const Icon(Icons.event_available),
                label: const Text('Calendar file (.ics)'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () => _offerWhatsApp(MessageKind.cancellation),
                icon: const Icon(Icons.chat),
                label: const Text('Cancellation notice'),
              ),
          ]),
        ],
        const SizedBox(height: 30),
      ],
    );
  }
}
