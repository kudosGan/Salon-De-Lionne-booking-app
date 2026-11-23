import 'models.dart';

class CountRow {
  final String label;
  final int count;
  const CountRow(this.label, this.count);
}

/// Numbers for one month. Everything is worked out from the appointments list
/// so it can be tested without a database.
///
/// * "Total" counts every request dated in the month, whatever its status.
/// * "Booked" means not declined and not cancelled. The per-stylist,
///   per-service, per-hairstyle and client counts use booked appointments.
/// * A client is "new" in a month if their first booked appointment ever is in
///   that month, and "returning" if they had an earlier one.
class MonthlyReport {
  final int year;
  final int month;
  final List<BookingRequest> appointments; // dated in this month, sorted
  final Map<AppointmentStatus, int> byStatus;
  final List<CountRow> perStylist;
  final List<CountRow> perService;
  final List<CountRow> perHairstyle;
  final int newClients;
  final int returningClients;

  const MonthlyReport({
    required this.year,
    required this.month,
    required this.appointments,
    required this.byStatus,
    required this.perStylist,
    required this.perService,
    required this.perHairstyle,
    required this.newClients,
    required this.returningClients,
  });

  int get total => appointments.length;
  int count(AppointmentStatus s) => byStatus[s] ?? 0;
  int get booked => appointments.where(isBooked).length;

  static bool isBooked(BookingRequest a) =>
      a.status != AppointmentStatus.declined &&
      a.status != AppointmentStatus.cancelled;

  static String _who(BookingRequest a) => a.clientId ?? a.phone;

  static List<CountRow> _tally(Iterable<String> labels) {
    final m = <String, int>{};
    for (final l in labels) {
      m[l] = (m[l] ?? 0) + 1;
    }
    final rows = [for (final e in m.entries) CountRow(e.key, e.value)];
    rows.sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.label.compareTo(b.label);
    });
    return rows;
  }

  /// [all] must be every appointment ever (needed to tell new from returning).
  static MonthlyReport build(List<BookingRequest> all, int year, int month) {
    bool inMonth(DateTime d) => d.year == year && d.month == month;

    final mine = all.where((a) => inMonth(a.date)).toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.slotMinutes.compareTo(b.slotMinutes);
      });
    final booked = mine.where(isBooked).toList();

    // First booked appointment date per client, across all time.
    final first = <String, DateTime>{};
    for (final a in all.where(isBooked)) {
      final k = _who(a);
      if (first[k] == null || a.date.isBefore(first[k]!)) first[k] = a.date;
    }
    final clients = {for (final a in booked) _who(a)};
    final newCount = clients.where((c) => inMonth(first[c]!)).length;

    return MonthlyReport(
      year: year,
      month: month,
      appointments: mine,
      byStatus: {
        for (final s in AppointmentStatus.values)
          s: mine.where((a) => a.status == s).length
      },
      perStylist: _tally(booked.map((a) => a.stylist?.name ?? 'Unassigned')),
      perService: _tally(booked.map((a) => a.serviceName)),
      perHairstyle:
          _tally(booked.map((a) => a.hairstyle?.name ?? 'No style chosen')),
      newClients: newCount,
      returningClients: clients.length - newCount,
    );
  }
}
