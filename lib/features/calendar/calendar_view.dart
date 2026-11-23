import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/admin_repository.dart';
import '../../data/availability.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../admin/appointment_detail.dart';
import '../admin/widgets/status_chip.dart';
import 'calendar_utils.dart';
import 'month_grid.dart';
import 'week_grid.dart';

enum CalendarMode { day, week, month, list }

/// Day / week / month / list calendar.
///
/// Week and Month fit the screen with no scrolling. Day and List scroll
/// because they can be long.
///
/// Admin: sees every stylist and can filter by stylist.
/// Stylist ([forStylist] set): sees only their own appointments.
class CalendarView extends StatefulWidget {
  final AdminRepository repo;
  final String? forStylist;
  const CalendarView({super.key, required this.repo, this.forStylist});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  CalendarMode _mode = CalendarMode.week;
  DateTime _focus = dateOnly(DateTime.now());
  String _filter = 'all'; // 'all' | 'unassigned' | a stylist id (admin only)
  bool _showClosed = false; // declined / cancelled
  List<BookingRequest> _all = [];
  List<StaffMember> _staff = [];
  List<BlockedSlot> _blocks = [];
  bool _loaded = false;

  bool get _isStylist => widget.forStylist != null;

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
    final a = await widget.repo.appointments(forStylist: widget.forStylist);
    final s = await widget.repo.staff();
    final b = await widget.repo.blocks();
    if (mounted) {
      setState(() {
        _all = a;
        _staff = s;
        _blocks = b;
        _loaded = true;
      });
    }
  }

  Set<int> _blockedSlots(String stylistId, DateTime d) => {
        for (final b in _blocks)
          if (b.stylistId == stylistId && Availability.sameDay(b.date, d)) b.slot
      };

  void _say(String? error, [String ok = 'Saved.']) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? ok)));
  }

  Future<void> _toggleSlot(String stylistId, DateTime day, int slot, bool on) async {
    final err = await widget.repo.setBlocked(stylistId, day, slot, on,
        actingStylist: widget.forStylist);
    if (err != null && mounted) _say(err);
  }

  Future<void> _toggleDay(
      String stylistId, DateTime day, bool on, List<int> slots) async {
    final err = await widget.repo.setDayBlocked(stylistId, day, on,
        actingStylist: widget.forStylist, slots: slots);
    if (mounted) {
      _say(err, on ? 'Day blocked.' : 'Day is open again.');
    }
  }

  List<BookingRequest> get _visible => _all.where((a) {
        if (!_showClosed &&
            (a.status == AppointmentStatus.declined ||
                a.status == AppointmentStatus.cancelled)) {
          return false;
        }
        if (_isStylist || _filter == 'all') return true;
        if (_filter == 'unassigned') return a.stylist == null;
        return a.stylist?.id == _filter;
      }).toList()
        ..sort((a, b) {
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : a.slotMinutes.compareTo(b.slotMinutes);
        });

  List<BookingRequest> _on(DateTime d) =>
      _visible.where((a) => Availability.sameDay(a.date, d)).toList();

  void _open(BookingRequest a) => showAppointmentDetail(context, widget.repo, a,
      asStylistId: widget.forStylist);

  /// Several appointments share a week-grid block: pick one from a short list.
  void _openGroup(List<BookingRequest> group) {
    if (group.length == 1) return _open(group.first);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('${formatDate(group.first.date)} · ${formatSlot(group.first.slotMinutes)}',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final a in group)
              _CompactTile(
                appointment: a,
                onTap: () {
                  Navigator.pop(ctx);
                  _open(a);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _goToDay(DateTime d) => setState(() {
        _focus = dateOnly(d);
        _mode = CalendarMode.day;
      });

  void _step(int dir) => setState(() {
        _focus = switch (_mode) {
          CalendarMode.day => addDays(_focus, dir),
          CalendarMode.week => addDays(_focus, 7 * dir),
          _ => addMonths(_focus, dir),
        };
      });

  String get _title => switch (_mode) {
        CalendarMode.day => formatDate(_focus),
        CalendarMode.week => weekLabel(_focus),
        _ => monthYear(_focus),
      };

  String? get _filterCaption {
    if (_isStylist || _filter == 'all') return null;
    if (_filter == 'unassigned') return 'Unassigned only';
    final s = _staff.where((s) => s.id == _filter).firstOrNull;
    return s == null ? null : 'Showing ${s.name}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final caption = _filterCaption;

    return Column(
      children: [
        // ---- compact header: mode switch, then ‹ title › Today [filter] ----
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<CalendarMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity(horizontal: -2, vertical: -3),
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
              ),
              segments: const [
                ButtonSegment(value: CalendarMode.day, label: Text('Day')),
                ButtonSegment(value: CalendarMode.week, label: Text('Week')),
                ButtonSegment(value: CalendarMode.month, label: Text('Month')),
                ButtonSegment(value: CalendarMode.list, label: Text('List')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _step(-1)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  if (caption != null)
                    Text(caption,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.brown)),
                ],
              ),
            ),
            IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Next',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _step(1)),
            TextButton(
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () =>
                    setState(() => _focus = dateOnly(DateTime.now())),
                child: const Text('Today')),
            if (!_isStylist) _filterMenu(),
          ],
        ),
        Expanded(
          child: switch (_mode) {
            CalendarMode.day => _dayView(),
            CalendarMode.week => _weekView(),
            CalendarMode.month => _monthView(),
            CalendarMode.list => _listView(),
          },
        ),
      ],
    );
  }

  /// Stylist filter and "show cancelled" tucked into one small menu.
  Widget _filterMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Filter',
      icon: Badge(
        isLabelVisible: _filter != 'all' || _showClosed,
        smallSize: 8,
        child: const Icon(Icons.filter_list),
      ),
      onSelected: (v) => setState(() {
        if (v == '__closed') {
          _showClosed = !_showClosed;
        } else {
          _filter = v;
        }
      }),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
            value: 'all', checked: _filter == 'all', child: const Text('All stylists')),
        CheckedPopupMenuItem(
            value: 'unassigned',
            checked: _filter == 'unassigned',
            child: const Text('Unassigned')),
        for (final s in _staff.where((s) => s.active))
          CheckedPopupMenuItem(
              value: s.id, checked: _filter == s.id, child: Text(s.name)),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
            value: '__closed',
            checked: _showClosed,
            child: const Text('Show cancelled')),
      ],
    );
  }

  // ---------------- Day ----------------

  Widget _dayView() {
    final day = _focus;
    final appts = _on(day);
    final selected = _isStylist
        ? _staff.where((s) => s.id == widget.forStylist).firstOrNull
        : _staff.where((s) => s.id == _filter).firstOrNull;
    final working = _staff.where((s) => Availability.worksOn(s, day)).toList();

    // Which rows to show: the stylist's hours, or everyone's combined.
    int lo, hi;
    String? note;
    if (selected != null) {
      if (!Availability.worksOn(selected, day)) {
        note = '${selected.name} is not working this day.';
      }
      lo = selected.startMinutes;
      hi = selected.endMinutes;
    } else if (working.isNotEmpty) {
      lo = working.map((s) => s.startMinutes).reduce((a, b) => a < b ? a : b);
      hi = working.map((s) => s.endMinutes).reduce((a, b) => a > b ? a : b);
    } else {
      lo = 540;
      hi = 1080;
      note = 'No stylists are scheduled to work this day.';
    }
    for (final a in appts) {
      if (a.slotMinutes < lo) lo = a.slotMinutes;
      if (a.slotMinutes + 30 > hi) hi = a.slotMinutes + 30;
    }
    final rows = [for (final m in Catalog.slots) if (m >= lo && m < hi) m];

    // Blocking is available when one stylist's calendar is showing.
    final canBlock = selected != null && Availability.worksOn(selected, day);
    final blocked =
        selected == null ? <int>{} : _blockedSlots(selected.id, day);
    final blockable = selected == null
        ? <int>[]
        : [
            for (final m in rows)
              if (Availability.inHours(selected, m) &&
                  !appts.any((a) =>
                      a.stylist?.id == selected.id &&
                      a.slotMinutes == m &&
                      Availability.blocksSlot(a.status)))
                m
          ];
    final dayBlocked =
        blockable.isNotEmpty && blockable.every(blocked.contains);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(note,
                style: const TextStyle(color: AppColors.brown, fontSize: 12)),
          ),
        if (canBlock)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: SwitchListTile(
              dense: true,
              title: Text('Block the whole day for ${selected.name}'),
              subtitle: const Text('Clients cannot book any time this day.'),
              value: dayBlocked,
              onChanged: (v) => _toggleDay(selected.id, day, v, blockable),
            ),
          )
        else if (selected == null && !_isStylist)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Use the filter (top right) to pick a stylist and block times.',
                style: TextStyle(color: AppColors.brown, fontSize: 12)),
          ),
        for (final m in rows)
          _daySlotRow(m, day, appts.where((a) => a.slotMinutes == m).toList(),
              selected),
      ],
    );
  }

  Widget _daySlotRow(int slot, DateTime day, List<BookingRequest> here,
      StaffMember? selected) {
    final isBlocked =
        selected != null && _blockedSlots(selected.id, day).contains(slot);
    final canToggle = selected != null &&
        Availability.worksOn(selected, day) &&
        Availability.inHours(selected, slot) &&
        !here.any((a) =>
            a.stylist?.id == selected.id && Availability.blocksSlot(a.status));

    // Who is free at this time (shows the available slots).
    Widget? free;
    if (isBlocked) {
      free = const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, size: 13, color: AppColors.brown),
        SizedBox(width: 4),
        Text('Blocked',
            style: TextStyle(color: AppColors.brown, fontSize: 12)),
      ]);
    } else if (selected != null) {
      if (Availability.isFree(selected, day, slot, _all,
          blocked: _blockedSlots(selected.id, day))) {
        free = const Text('Available',
            style: TextStyle(color: Color(0xFF5B8C5A), fontSize: 12));
      }
    } else {
      final names = [
        for (final s in _staff)
          if (Availability.isFree(s, day, slot, _all,
              blocked: _blockedSlots(s.id, day)))
            s.name
      ];
      if (names.isNotEmpty) {
        free = Text('Free: ${names.join(', ')}',
            style: const TextStyle(color: Color(0xFF5B8C5A), fontSize: 12));
      }
    }
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.beige))),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 62,
            child: Text(formatSlot(slot),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.brown,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: here.isEmpty
                ? Container(
                    constraints: const BoxConstraints(minHeight: 28),
                    alignment: Alignment.centerLeft,
                    child: free ?? const SizedBox.shrink(),
                  )
                : Column(
                    children: [
                      for (final a in here)
                        _CompactTile(appointment: a, onTap: () => _open(a)),
                    ],
                  ),
          ),
          if (canToggle)
            Tooltip(
              message: isBlocked ? 'Open this time' : 'Block this time',
              child: Transform.scale(
                scale: .8,
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  // On = the time is blocked.
                  value: isBlocked,
                  onChanged: (v) => _toggleSlot(selected.id, day, slot, v),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- Week (fits the screen) ----------------

  /// Rows to show: the working hours of whoever is on screen, widened to
  /// include any appointment that week, rounded to whole hours.
  (int, int) _weekRange(DateTime start) {
    final people = _staff.where((s) {
      if (!s.active) return false;
      if (_isStylist) return s.id == widget.forStylist;
      return _filter == 'all' || _filter == 'unassigned' || s.id == _filter;
    });
    var lo = 1 << 30, hi = 0;
    for (final s in people) {
      if (s.startMinutes < lo) lo = s.startMinutes;
      if (s.endMinutes > hi) hi = s.endMinutes;
    }
    if (hi == 0) {
      lo = 540;
      hi = 1080;
    }
    for (var d = 0; d < 7; d++) {
      for (final a in _on(addDays(start, d))) {
        if (a.slotMinutes < lo) lo = a.slotMinutes;
        if (a.slotMinutes + 30 > hi) hi = a.slotMinutes + 30;
      }
    }
    lo = (lo ~/ 60) * 60;
    hi = ((hi + 59) ~/ 60) * 60;
    if (lo < 6 * 60) lo = 6 * 60;
    if (hi > 22 * 60) hi = 22 * 60;
    if (hi - lo < 120) hi = lo + 120;
    return (lo, hi);
  }

  Widget _weekView() {
    final start = startOfWeek(_focus);
    final (lo, hi) = _weekRange(start);
    return WeekGrid(
      weekStart: start,
      from: lo,
      to: hi,
      appointmentsOn: _on,
      onTapAppointments: _openGroup,
      onTapDay: _goToDay,
    );
  }

  // ---------------- Month (fits the screen) ----------------

  Widget _monthView() => MonthGrid(
        month: _focus,
        appointmentsOn: _on,
        onTapDay: _goToDay,
      );

  // ---------------- List ----------------

  Widget _listView() {
    final month = _visible
        .where((a) => a.date.year == _focus.year && a.date.month == _focus.month)
        .toList();
    if (month.isEmpty) {
      return const Center(
          child: Text('No appointments this month.',
              style: TextStyle(color: AppColors.brown)));
    }
    final children = <Widget>[];
    DateTime? last;
    for (final a in month) {
      if (last == null || !Availability.sameDay(last, a.date)) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(formatDate(a.date),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brown)),
        ));
        last = a.date;
      }
      children.add(_CompactTile(appointment: a, onTap: () => _open(a)));
    }
    return ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: children);
  }
}

/// One slim row: colour bar, time, client, service and stylist, status.
class _CompactTile extends StatelessWidget {
  final BookingRequest appointment;
  final VoidCallback onTap;
  const _CompactTile({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final c = statusColor(a.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: c, width: 4)),
            ),
            child: Row(children: [
              Text(shortTime(a.slotMinutes),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                        [
                          a.hairstyle?.name ?? a.serviceName,
                          a.stylist?.name ?? 'Unassigned',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.brown)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(a.status.label.replaceAll(' Confirmation', ''),
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: c)),
            ]),
          ),
        ),
      ),
    );
  }
}
