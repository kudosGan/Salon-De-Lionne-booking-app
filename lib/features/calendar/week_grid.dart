import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/availability.dart';
import '../../data/models.dart';
import '../admin/widgets/status_chip.dart';
import 'calendar_utils.dart';

/// "2p", "9:30a" - short enough for a narrow column.
String shortTime(int minutes) {
  final h24 = minutes ~/ 60;
  final m = minutes % 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h12${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}${h24 >= 12 ? 'p' : 'a'}';
}

/// The whole week on one screen, no scrolling: seven day columns and one row
/// per 30 minutes, sized to fill the space. Tap a block to open it, tap a day
/// heading to jump to that day.
class WeekGrid extends StatelessWidget {
  final DateTime weekStart;
  final int from; // first visible minute (multiple of 30)
  final int to; // end of the last visible row
  final List<BookingRequest> Function(DateTime day) appointmentsOn;
  final void Function(List<BookingRequest> appointments) onTapAppointments;
  final ValueChanged<DateTime> onTapDay;

  const WeekGrid({
    super.key,
    required this.weekStart,
    required this.from,
    required this.to,
    required this.appointmentsOn,
    required this.onTapAppointments,
    required this.onTapDay,
  });

  static const _gutter = 36.0;
  static const _headerHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final colW = (c.maxWidth - _gutter) / 7;
      final rows = (to - from) ~/ 30;
      final rowH = (c.maxHeight - _headerHeight) / rows;
      final narrow = colW < 62;
      final now = DateTime.now();
      final children = <Widget>[];

      // Tint today's column.
      for (var d = 0; d < 7; d++) {
        final day = addDays(weekStart, d);
        if (Availability.sameDay(day, now)) {
          children.add(Positioned(
            left: _gutter + d * colW,
            top: _headerHeight,
            width: colW,
            bottom: 0,
            child: ColoredBox(color: AppColors.softPink.withValues(alpha: .18)),
          ));
        }
      }

      // Time labels and horizontal lines.
      final labelEvery = rowH * 2 >= 15 ? 1 : 2; // skip labels if too tight
      for (var r = 0; r <= rows; r++) {
        final minute = from + r * 30;
        final hour = minute % 60 == 0;
        final top = _headerHeight + r * rowH;
        children.add(Positioned(
          left: _gutter,
          right: 0,
          top: top,
          height: 1,
          child: ColoredBox(
              color: AppColors.beige.withValues(alpha: hour ? 1 : .45)),
        ));
        if (hour && ((minute ~/ 60) % labelEvery == 0) && r < rows) {
          final h24 = minute ~/ 60;
          final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
          children.add(Positioned(
            left: 0,
            width: _gutter - 4,
            top: top - 1,
            child: Text('$h12${h24 >= 12 ? 'p' : 'a'}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 10, height: 1, color: AppColors.brown)),
          ));
        }
      }

      // Vertical lines + day headings.
      for (var d = 0; d <= 7; d++) {
        children.add(Positioned(
          left: _gutter + d * colW,
          top: _headerHeight,
          bottom: 0,
          width: 1,
          child: ColoredBox(color: AppColors.beige.withValues(alpha: .6)),
        ));
      }
      for (var d = 0; d < 7; d++) {
        final day = addDays(weekStart, d);
        final isToday = Availability.sameDay(day, now);
        children.add(Positioned(
          left: _gutter + d * colW,
          top: 0,
          width: colW,
          height: _headerHeight,
          child: InkWell(
            onTap: () => onTapDay(day),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayName(day.weekday).substring(0, narrow ? 1 : 3),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.brown, height: 1.1)),
                const SizedBox(height: 2),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.brown : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${day.day}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              isToday ? AppColors.white : AppColors.charcoal)),
                ),
              ],
            ),
          ),
        ));
      }

      // Appointments: one block per start time; several at the same time
      // (different stylists) share the block and show "+n".
      for (var d = 0; d < 7; d++) {
        final day = addDays(weekStart, d);
        final bySlot = <int, List<BookingRequest>>{};
        for (final a in appointmentsOn(day)) {
          (bySlot[a.slotMinutes] ??= []).add(a);
        }
        for (final e in bySlot.entries) {
          final row = (e.key - from) ~/ 30;
          if (row < 0 || row >= rows) continue;
          children.add(Positioned(
            left: _gutter + d * colW + 1.5,
            top: _headerHeight + row * rowH + 1,
            width: colW - 3,
            height: rowH - 2 < 11 ? 11 : rowH - 2,
            child: _Block(
                group: e.value,
                narrow: narrow,
                onTap: () => onTapAppointments(e.value)),
          ));
        }
      }

      return SizedBox(
        width: c.maxWidth,
        height: c.maxHeight,
        child: Stack(clipBehavior: Clip.hardEdge, children: children),
      );
    });
  }
}

class _Block extends StatelessWidget {
  final List<BookingRequest> group;
  final bool narrow;
  final VoidCallback onTap;
  const _Block({required this.group, required this.narrow, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final first = group.first;
    final color = statusColor(first.status);
    final name = first.clientName.trim().split(' ').first;
    final label = [
      if (!narrow) shortTime(first.slotMinutes),
      name,
      if (group.length > 1) '+${group.length - 1}',
    ].join(' ');
    return Tooltip(
      message: group
          .map((a) => '${formatSlot(a.slotMinutes)} ${a.clientName} '
              '(${a.stylist?.name ?? 'unassigned'}) - ${a.status.label}')
          .join('\n'),
      child: Material(
        color: color.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.only(left: 3, right: 1),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: TextStyle(
                    fontSize: narrow ? 9 : 11,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal)),
          ),
        ),
      ),
    );
  }
}
