import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/core/config/salon_config.dart';
import 'package:salon_booking/data/models.dart';
import 'package:salon_booking/services/calendar_links.dart';
import 'package:salon_booking/services/contact_launcher.dart';
import 'package:salon_booking/services/message_templates.dart';

BookingRequest _appt({AppointmentStatus s = AppointmentStatus.confirmed}) =>
    BookingRequest(
      id: 'abc123',
      clientName: 'Sarah Lee',
      phone: '(416) 555-0123',
      date: DateTime(2026, 12, 10),
      slotMinutes: 14 * 60,
      stylist: const Stylist('s1', 'Jessica'),
      serviceName: 'Hair Colouring',
      hairstyle: const Hairstyle('balayage', 'Balayage', 'x.png'),
      status: s,
      createdAt: DateTime(2026, 11, 22),
    );

void main() {
  group('WhatsApp messages', () {
    test('confirmation thanks the client and has every detail', () {
      final m = MessageTemplates.build(MessageKind.confirmation, _appt());
      expect(m, contains('Hello Sarah!'));
      expect(m, contains('Thank you for choosing ${SalonConfig.name}'));
      expect(m, contains("We're at your service"));
      expect(m, contains('confirm your appointment'));
      expect(m, contains('Stylist: Jessica'));
      expect(m, contains('Thursday, December 10, 2026'));
      expect(m, contains('2:00 PM'));
      expect(m, contains('Style: Balayage'));
      expect(m, contains(SalonConfig.address));
      expect(m, contains('https://calendar.google.com/calendar/render'));
    });

    test('other message kinds', () {
      final a = _appt();
      expect(MessageTemplates.build(MessageKind.cancellation, a),
          contains('has been cancelled'));
      expect(MessageTemplates.build(MessageKind.reschedule, a),
          contains('rescheduled'));
      final r = MessageTemplates.build(MessageKind.reminder, a);
      expect(r, contains('reminder'));
      expect(r, contains('2:00 PM'));
    });

    test('client phone numbers become WhatsApp numbers', () {
      expect(ContactLauncher.whatsappDigits('(416) 555-0123'), '14165550123');
      expect(ContactLauncher.whatsappDigits('+1 416 555 0123'), '14165550123');
      expect(ContactLauncher.whatsappDigits('+44 7700 900123'), '447700900123');
    });
  });

  group('calendar', () {
    test('Google link has the right title, local time and place', () {
      final u = CalendarLinks.googleUrl(_appt());
      expect(u.host, 'calendar.google.com');
      expect(u.queryParameters['action'], 'TEMPLATE');
      expect(u.queryParameters['text'], contains('Balayage'));
      expect(u.queryParameters['dates'], '20261210T140000/20261210T150000');
      expect(u.queryParameters['location'], contains(SalonConfig.address));
    });

    test('ics file is valid-looking and has two reminders', () {
      final s = CalendarLinks.ics(_appt(), now: DateTime.utc(2026, 11, 22, 12));
      expect(s, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(s, endsWith('END:VCALENDAR\r\n'));
      expect(s, contains('DTSTART:20261210T140000'));
      expect(s, contains('DTEND:20261210T150000'));
      expect(s, contains('DTSTAMP:20261122T120000Z'));
      expect('TRIGGER:'.allMatches(s).length, 2);
      expect(s, contains('TRIGGER:-P1D'));
      expect(s, contains('TRIGGER:-PT2H'));
      // Commas must be escaped inside text values.
      expect(s, contains('SUMMARY:Balayage at ${SalonConfig.name}'));
      expect(s, contains('LOCATION:'));
    });

    test('ics lines are folded to 75 characters', () {
      final s = CalendarLinks.ics(_appt());
      for (final line in s.split('\r\n')) {
        expect(line.length, lessThanOrEqualTo(75), reason: line);
      }
    });
  });
}
