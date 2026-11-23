import 'models.dart';

/// Who can be booked when. One appointment occupies one 30-minute slot.
/// Only Confirmed and Rescheduled appointments block a slot; a Pending
/// request does not (several people may request the same time).
class Availability {
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool blocksSlot(AppointmentStatus s) =>
      s == AppointmentStatus.confirmed || s == AppointmentStatus.rescheduled;

  /// Is this stylist scheduled to work on [date] at all?
  static bool worksOn(StaffMember s, DateTime date) =>
      s.active &&
      s.workDays.contains(date.weekday) &&
      !s.daysOff.any((d) => sameDay(d, date));

  static bool inHours(StaffMember s, int slot) =>
      slot >= s.startMinutes && slot < s.endMinutes;

  /// Slots (from [allSlots]) this stylist can still take on [date], given the
  /// slots they already have booked.
  static Set<int> openSlots(
      StaffMember s, DateTime date, Set<int> busy, Iterable<int> allSlots) {
    if (!worksOn(s, date)) return {};
    return {
      for (final m in allSlots)
        if (inHours(s, m) && !busy.contains(m)) m
    };
  }

  /// For the day view: is [s] free at [slot], given that day's appointments?
  static bool isFree(StaffMember s, DateTime date, int slot,
      Iterable<BookingRequest> dayAppointments,
      {Set<int> blocked = const {}}) {
    if (!worksOn(s, date) || !inHours(s, slot) || blocked.contains(slot)) {
      return false;
    }
    return !dayAppointments.any((a) =>
        a.stylist?.id == s.id &&
        a.slotMinutes == slot &&
        blocksSlot(a.status));
  }
}
