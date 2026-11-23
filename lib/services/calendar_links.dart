import '../core/config/salon_config.dart';
import '../data/models.dart';

/// Builds "add to calendar" data for an appointment.
///
/// * Google Calendar: a link that opens the event pre-filled (works on
///   Android, iPhone and computers). Google Calendar's link cannot set a
///   reminder, so the client's default Google reminder applies.
/// * .ics file: opens in Apple Calendar (iPhone/Mac), Google Calendar,
///   Outlook, etc. This one includes reminders (1 day and 2 hours before).
class CalendarLinks {
  static DateTime start(BookingRequest a) =>
      DateTime(a.date.year, a.date.month, a.date.day, 0, a.slotMinutes);

  static DateTime end(BookingRequest a) =>
      start(a).add(const Duration(minutes: SalonConfig.appointmentMinutes));

  static String title(BookingRequest a) =>
      '${a.hairstyle?.name ?? a.serviceName} at ${SalonConfig.name}';

  static String description(BookingRequest a) => [
        'Appointment at ${SalonConfig.name}',
        'Service: ${a.serviceName}',
        if (a.hairstyle != null) 'Style: ${a.hairstyle!.name}',
        if (a.stylist != null) 'Stylist: ${a.stylist!.name}',
        'Questions? Text ${SalonConfig.phone}',
      ].join('\n');

  /// "20261210T140000" (local time, no time zone, so it lands at 2 PM
  /// wherever the client's phone is).
  static String _local(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${_pad(d.month)}${_pad(d.day)}'
      'T${_pad(d.hour)}${_pad(d.minute)}00';

  static String _utc(DateTime d) {
    final u = d.toUtc();
    return '${_local(u)}Z';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static Uri googleUrl(BookingRequest a) =>
      Uri.https('calendar.google.com', '/calendar/render', {
        'action': 'TEMPLATE',
        'text': title(a),
        'dates': '${_local(start(a))}/${_local(end(a))}',
        'details': description(a),
        'location': '${SalonConfig.name}, ${SalonConfig.address}',
      });

  static String _escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  /// Long lines must be folded at 75 characters (RFC 5545).
  static String _fold(String line) {
    if (line.length <= 73) return line;
    final out = StringBuffer(line.substring(0, 73));
    for (var i = 73; i < line.length; i += 72) {
      out.write('\r\n ');
      out.write(line.substring(i, i + 72 > line.length ? line.length : i + 72));
    }
    return out.toString();
  }

  static String ics(BookingRequest a, {DateTime? now}) {
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//${SalonConfig.name}//Booking//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:${a.id}@salon-booking',
      'DTSTAMP:${_utc(now ?? DateTime.now())}',
      'DTSTART:${_local(start(a))}',
      'DTEND:${_local(end(a))}',
      'SUMMARY:${_escape(title(a))}',
      'DESCRIPTION:${_escape(description(a))}',
      'LOCATION:${_escape('${SalonConfig.name}, ${SalonConfig.address}')}',
      'STATUS:CONFIRMED',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:Appointment tomorrow',
      'TRIGGER:-P1D',
      'END:VALARM',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:Appointment in 2 hours',
      'TRIGGER:-PT2H',
      'END:VALARM',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return '${lines.map(_fold).join('\r\n')}\r\n';
  }
}
