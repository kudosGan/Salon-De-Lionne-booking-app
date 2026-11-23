import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/data/admin_repository.dart';
import 'package:salon_booking/data/catalog.dart';
import 'package:salon_booking/data/db/app_database.dart';
import 'package:salon_booking/data/models.dart';
import 'package:salon_booking/services/message_templates.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AdminRepository repo;
  final amy = Catalog.stylists[0];
  final bo = Catalog.stylists[1];
  final day = DateTime(2026, 12, 10); // a Thursday

  BookingRequest req(String id, {Stylist? stylist, DateTime? date, int slot = 840}) =>
      BookingRequest(
        id: id,
        clientName: 'Client $id',
        phone: '64700000$id',
        date: date ?? day,
        slotMinutes: slot,
        stylist: stylist,
        serviceName: 'Hairstyling',
        createdAt: DateTime(2026, 11, 22),
      );

  Future<List<String>> adminTitles() async =>
      [for (final n in await repo.notifications()) n.title];
  Future<List<String>> stylistTitles(String id) async =>
      [for (final n in await repo.notifications(stylistId: id)) n.title];

  setUp(() async {
    final db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = AdminRepository(db);
  });
  tearDown(() => repo.db.close());

  group('booking notifications', () {
    test('new request: admin and the chosen stylist are told, others not',
        () async {
      await repo.bookings.submit(req('1', stylist: amy));
      expect(await adminTitles(), ['New booking request']);
      expect(await stylistTitles(amy.id), ['New appointment request']);
      expect(await stylistTitles(bo.id), isEmpty);
    });

    test('"Any stylist" tells every active stylist', () async {
      await repo.setStaffActive(Catalog.stylists[2].id, false);
      await repo.bookings.submit(req('1'));
      expect(await stylistTitles(amy.id), ['New appointment request']);
      expect(await stylistTitles(bo.id), ['New appointment request']);
      expect(await stylistTitles(Catalog.stylists[2].id), isEmpty);
    });

    test('admin confirms: the stylist is told', () async {
      await repo.bookings.submit(req('1', stylist: amy));
      await repo.confirm('1');
      expect(await stylistTitles(amy.id), contains('Appointment confirmed'));
      expect(await adminTitles(), isNot(contains('Stylist accepted booking')));
    });

    test('stylist accepts: the admin is told', () async {
      await repo.bookings.submit(req('1'));
      expect(await repo.acceptAs('1', amy.id), isNull);
      expect(await adminTitles(), contains('Stylist accepted booking'));
      // Taking an unassigned request must not tell the stylist they were "assigned".
      expect(await stylistTitles(amy.id), isNot(contains('Appointment assigned')));
    });

    test('stylist declines: the admin is told', () async {
      await repo.bookings.submit(req('1', stylist: amy));
      await repo.declineAs('1', amy.id);
      expect(await adminTitles(), contains('Stylist declined booking'));
    });

    test('assign, cancel and reschedule tell the stylist', () async {
      await repo.bookings.submit(req('1'));
      await repo.assignStylist('1', bo.id);
      expect(await stylistTitles(bo.id), contains('Appointment assigned'));

      await repo.reschedule('1', DateTime(2026, 12, 11), 600);
      expect(await stylistTitles(bo.id), contains('Appointment rescheduled'));

      await repo.setStatus('1', AppointmentStatus.cancelled);
      expect(await stylistTitles(bo.id), contains('Appointment cancelled'));
    });

    test('read / unread is tracked separately per person', () async {
      await repo.bookings.submit(req('1', stylist: amy));
      expect(await repo.unreadCount(), 1);
      expect(await repo.unreadCount(stylistId: amy.id), 1);
      expect(await repo.unreadCount(stylistId: bo.id), 0);

      await repo.markAllRead(stylistId: amy.id);
      expect(await repo.unreadCount(stylistId: amy.id), 0);
      expect(await repo.unreadCount(), 1); // admin's is untouched

      final id = (await repo.notifications()).single.id;
      await repo.markRead(id);
      expect(await repo.unreadCount(), 0);
    });
  });

  group('reminders', () {
    final now = DateTime(2026, 12, 9, 14); // Wed 2 PM; appointment is Thu 2 PM

    Future<void> confirmed(String id, {DateTime? date, Stylist? stylist}) async {
      await repo.bookings.submit(req(id, stylist: stylist ?? amy, date: date));
      expect(await repo.confirm(id), isNull);
    }

    test('appointment within 24 hours creates one notification each, once',
        () async {
      await confirmed('1');
      expect(await repo.generateDueReminders(now: now), 1);
      expect(await stylistTitles(amy.id), contains('Upcoming appointment'));
      expect(await adminTitles(), contains('Reminder to send to client'));
      // Running again must not repeat it.
      expect(await repo.generateDueReminders(now: now), 0);
    });

    test('far-away, past and unconfirmed appointments are ignored', () async {
      await confirmed('far', date: DateTime(2026, 12, 20));
      await repo.bookings.submit(req('pending', stylist: bo)); // not confirmed
      expect(await repo.generateDueReminders(now: now), 0);
      // An appointment that already started is not a reminder.
      expect(
          await repo.generateDueReminders(now: DateTime(2026, 12, 10, 15)), 0);
    });

    test('remindersToSend lists it until the reminder is sent', () async {
      await confirmed('1');
      expect((await repo.remindersToSend(now: now)).map((a) => a.id), ['1']);
      await repo.markReminderSent('1', now: now);
      expect(await repo.remindersToSend(now: now), isEmpty);
    });

    test('rescheduling restarts the reminders', () async {
      await confirmed('1');
      await repo.generateDueReminders(now: now);
      await repo.markReminderSent('1', now: now);
      // 1 PM Thursday is 23 hours after "now", so it is inside the window.
      await repo.reschedule('1', DateTime(2026, 12, 10), 780);
      expect((await repo.remindersToSend(now: now)).map((a) => a.id), ['1']);
      expect(await repo.generateDueReminders(now: now), 1);
    });
  });

  test('decline message is polite and offers another time', () {
    final m = MessageTemplates.build(MessageKind.declined, req('1'));
    expect(m, contains('Hello Client'));
    expect(m, contains('not able to book'));
    expect(m, contains('another time'));
  });
}
