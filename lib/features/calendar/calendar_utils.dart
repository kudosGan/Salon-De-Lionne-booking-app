import '../../core/utils/format.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Moves by whole months, keeping the day when it exists (Jan 31 + 1 month
/// becomes Feb 28/29, not March 3).
DateTime addMonths(DateTime d, int n) {
  final lastDay = DateTime(d.year, d.month + n + 1, 0).day;
  return DateTime(d.year, d.month + n, d.day > lastDay ? lastDay : d.day);
}

/// The 6 weeks (42 days, Monday first) shown for the month of [month].
List<DateTime> monthGrid(DateTime month) {
  final start = startOfWeek(DateTime(month.year, month.month, 1));
  return [for (var i = 0; i < 42; i++) addDays(start, i)];
}

/// "Nov 23 – 29, 2026" or "Nov 30 – Dec 6, 2026".
String weekLabel(DateTime d) {
  final a = startOfWeek(d);
  final b = addDays(a, 6);
  final left = '${shortMonth(a.month)} ${a.day}';
  final right = a.month == b.month ? '${b.day}' : '${shortMonth(b.month)} ${b.day}';
  return '$left – $right, ${b.year}';
}
