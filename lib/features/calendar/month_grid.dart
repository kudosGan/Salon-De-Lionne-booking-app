import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/availability.dart';
import '../../data/models.dart';
import '../admin/widgets/status_chip.dart';
import 'calendar_utils.dart';
import 'week_grid.dart' show shortTime;

/// The whole month on one screen, no scrolling. The weeks share the height, so
/// the cells are as big as the screen allows. Roomy cells list the
/// appointments; small cells show one coloured dot per appointment.
/// Tap a day to open it.
class MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<BookingRequest> Function(DateTime day) appointmentsOn;
  final ValueChanged<DateTime> onTapDay;

  const MonthGrid({
    super.key,
    required this.month,
    required this.appointmentsOn,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final all = monthGrid(month);
    // Only as many weeks as the month needs (4-6).
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((offset + daysInMonth) / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      child: Column(
        children: [
          SizedBox(
            height: 20,
            child: Row(children: [
              for (var w = 1; w <= 7; w++)
                Expanded(
                  child: Center(
                    child: Text(dayName(w).substring(0, 3),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.brown)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: Column(children: [
              for (var r = 0; r < weeks; r++)
                Expanded(
                  child: Row(children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: _Cell(
                          day: all[r * 7 + c],
                          inMonth: all[r * 7 + c].month == month.month,
                          appointments: appointmentsOn(all[r * 7 + c]),
                          onTap: () => onTapDay(all[r * 7 + c]),
                        ),
                      ),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final List<BookingRequest> appointments;
  final VoidCallback onTap;
  const _Cell({
    required this.day,
    required this.inMonth,
    required this.appointments,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = Availability.sameDay(day, DateTime.now());
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: isToday
            ? AppColors.softPink.withValues(alpha: .35)
            : AppColors.white.withValues(alpha: inMonth ? 1 : .4),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.beige),
            ),
            padding: const EdgeInsets.all(3),
            child: LayoutBuilder(builder: (context, c) {
              final roomy = c.maxHeight >= 66 && c.maxWidth >= 60;
              final lines = roomy ? ((c.maxHeight - 22) / 12.5).floor() : 0;
              final shown = appointments.take(lines).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${day.day}',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.w600,
                          color:
                              inMonth ? AppColors.charcoal : AppColors.sand)),
                  const SizedBox(height: 2),
                  if (roomy) ...[
                    for (final a in shown)
                      Text('${shortTime(a.slotMinutes)} ${a.clientName.split(' ').first}',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: statusColor(a.status),
                              fontWeight: FontWeight.w600)),
                    if (appointments.length > shown.length)
                      Text('+${appointments.length - shown.length} more',
                          style: const TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              color: AppColors.brown)),
                  ] else if (appointments.isNotEmpty)
                    Wrap(spacing: 2, runSpacing: 2, children: [
                      for (final a in appointments.take(4))
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: statusColor(a.status),
                              shape: BoxShape.circle),
                        ),
                      if (appointments.length > 4)
                        Text('+${appointments.length - 4}',
                            style: const TextStyle(fontSize: 8, height: 1)),
                    ]),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
