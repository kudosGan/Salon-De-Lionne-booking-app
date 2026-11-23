import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/data/admin_repository.dart';
import 'package:salon_booking/data/catalog.dart';
import 'package:salon_booking/data/db/app_database.dart';
import 'package:salon_booking/data/models.dart';
import 'package:salon_booking/features/auth/auth_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

BookingRequest _req(String id, String phone,
        {Stylist? stylist, DateTime? date, int slot = 840}) =>
    BookingRequest(
      id: id,
      clientName: 'Client $id',
      phone: phone,
      date: date ?? DateTime(2026, 12, 10),
      slotMinutes: slot,
      stylist: stylist,
      serviceName: Catalog.services.first.name,
      createdAt: DateTime(2026, 11, 22),
    );

void main() {
  sqfliteFfiInit();
  late AdminRepository repo;
  late AuthService authService;

  setUp(() async {
    final db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = AdminRepository(db);
    authService = AuthService(db);
  });
  tearDown(() => repo.db.close());

  group('login', () {
    test('first admin can be created once, then login works', () async {
      expect(await authService.hasAdmin(), isFalse);
      await authService.createFirstAdmin('owner', 'correct-horse');
      expect(await authService.hasAdmin(), isTrue);
      expect(() => authService.createFirstAdmin('other', 'another-pass1'),
          throwsStateError);

      final ok = await authService.login('OWNER', 'correct-horse');
      expect(ok?.isAdmin, isTrue);
      expect(await authService.login('owner', 'wrong-pass'), isNull);
      expect(await authService.login('nobody', 'correct-horse'), isNull);
    });

    test('password is not stored in plain text; short passwords rejected',
        () async {
      await authService.createFirstAdmin('owner', 'correct-horse');
      final row = (await repo.db.query('users')).single;
      expect(row.values.join(' ').contains('correct-horse'), isFalse);
      expect(() => authService.createEmployee('amy', 'short', 's1'),
          throwsArgumentError);
    });

    test('employee login is not an admin', () async {
      await authService.createEmployee('amy', 'long-enough-pw', 's1');
      final s = await authService.login('amy', 'long-enough-pw');
      expect(s?.isAdmin, isFalse);
      expect(s?.stylistId, 's1');
    });
  });

  group('staff', () {
    StaffMember newStaff(String id, {String name = 'Jess'}) =>
        StaffMember(id: id, name: name, specialties: 'Colour');

    test('add a stylist with a login; they can log in', () async {
      expect(
          await repo.saveStaff(newStaff('n1'),
              isNew: true, username: 'jess', password: 'jess-password'),
          isNull);
      final s = (await repo.staff()).firstWhere((m) => m.id == 'n1');
      expect(s.username, 'jess');
      expect(s.workDays, {1, 2, 3, 4, 5, 6});

      final session = await authService.login('jess', 'jess-password');
      expect(session?.stylistId, 'n1');
      expect(session?.isAdmin, isFalse);
    });

    test('rejects duplicate usernames, weak passwords and bad hours', () async {
      await repo.saveStaff(newStaff('n1'),
          isNew: true, username: 'jess', password: 'jess-password');
      expect(
          await repo.saveStaff(newStaff('n2', name: 'Other'),
              isNew: true, username: 'JESS', password: 'another-password'),
          contains('already taken'));
      expect(
          await repo.saveStaff(newStaff('n3'),
              isNew: true, username: 'newone', password: 'short'),
          contains('at least 8'));
      expect(
          await repo.saveStaff(
              StaffMember(id: 'n4', name: 'X', startMinutes: 900, endMinutes: 600),
              isNew: true),
          contains('start must be before'));
    });

    test('edit schedule and days off; reset password', () async {
      await repo.saveStaff(newStaff('n1'),
          isNew: true, username: 'jess', password: 'jess-password');
      final m = (await repo.staff()).firstWhere((m) => m.id == 'n1');
      await repo.saveStaff(
          StaffMember(
            id: 'n1',
            name: 'Jessica',
            workDays: {2, 3},
            startMinutes: 600,
            endMinutes: 960,
            daysOff: [DateTime(2026, 12, 24)],
            username: m.username,
          ),
          isNew: false,
          password: 'brand-new-pass');
      final e = (await repo.staff()).firstWhere((m) => m.id == 'n1');
      expect(e.name, 'Jessica');
      expect(e.workDays, {2, 3});
      expect(e.daysOff, [DateTime(2026, 12, 24)]);
      expect(await authService.login('jess', 'jess-password'), isNull);
      expect(await authService.login('jess', 'brand-new-pass'), isNotNull);
    });

    test('deactivating blocks login and hides from booking', () async {
      await repo.saveStaff(newStaff('n1'),
          isNew: true, username: 'jess', password: 'jess-password');
      await repo.setStaffActive('n1', false);
      expect(await authService.login('jess', 'jess-password'), isNull);
      expect((await repo.bookings.stylists()).any((s) => s.id == 'n1'), isFalse);
      await repo.setStaffActive('n1', true);
      expect(await authService.login('jess', 'jess-password'), isNotNull);
    });

    test('cannot delete a stylist who has appointments', () async {
      await repo.saveStaff(newStaff('n1'), isNew: true);
      await repo.bookings.submit(
          _req('a', '6470000001', stylist: Stylist('n1', 'Jess')));
      expect(await repo.deleteStaff('n1'), contains('deactivate'));

      await repo.saveStaff(newStaff('n2', name: 'Spare'), isNew: true);
      expect(await repo.deleteStaff('n2'), isNull);
      expect((await repo.staff()).any((m) => m.id == 'n2'), isFalse);
    });

    test('a stylist only sees and acts on their own appointments', () async {
      final amy = Catalog.stylists[0];
      final bo = Catalog.stylists[1];
      await repo.bookings.submit(_req('mine', '6470000001', stylist: amy));
      await repo.bookings.submit(_req('theirs', '6470000002', stylist: bo, slot: 900));
      await repo.bookings.submit(_req('open', '6470000003', slot: 960));

      final seen = (await repo.appointments(forStylist: amy.id)).map((a) => a.id);
      expect(seen, unorderedEquals(['mine', 'open']));

      expect(await repo.acceptAs('theirs', amy.id), contains('another stylist'));
      expect(await repo.declineAs('theirs', amy.id), contains('another stylist'));
      // Taking an unassigned request assigns it to them and confirms it.
      expect(await repo.acceptAs('open', amy.id), isNull);
      final open = (await repo.appointments()).firstWhere((a) => a.id == 'open');
      expect(open.stylist?.id, amy.id);
      expect(open.status, AppointmentStatus.confirmed);
      expect(await repo.completeAs('open', amy.id), isNull);
    });
  });

  group('appointments', () {
    final amy = Catalog.stylists[0];
    final bo = Catalog.stylists[1];

    test('dashboard counts', () async {
      final now = DateTime(2026, 12, 10);
      await repo.bookings.submit(_req('a', '6470000001', stylist: amy, date: now));
      await repo.bookings.submit(_req('b', '6470000002', stylist: bo, date: now));
      await repo.bookings.submit(_req('c', '6470000002', date: DateTime(2026, 11, 2)));
      await repo.confirm('a');
      await repo.setStatus('b', AppointmentStatus.declined);

      final s = await repo.stats(now: now);
      expect(s.pending, 1); // c
      expect(s.confirmed, 1); // a
      expect(s.today, 1); // a is confirmed today; b was declined
      expect(s.clients, 2);
      expect(s.stylists, Catalog.stylists.length);
      expect(s.month, 1); // a only (c is November, b declined)
    });

    test('cannot confirm without a stylist', () async {
      await repo.bookings.submit(_req('a', '6470000001'));
      expect(await repo.confirm('a'), contains('Assign a stylist'));
      expect(await repo.assignStylist('a', amy.id), isNull);
      expect(await repo.confirm('a'), isNull);
      final a = (await repo.appointments()).single;
      expect(a.status, AppointmentStatus.confirmed);
    });

    test('prevents double-booking the same stylist at the same time', () async {
      await repo.bookings.submit(_req('a', '6470000001', stylist: amy));
      await repo.bookings.submit(_req('b', '6470000002', stylist: amy));
      expect(await repo.confirm('a'), isNull);
      expect(await repo.confirm('b'), contains('already has'));

      // A different stylist at the same time is fine.
      expect(await repo.assignStylist('b', bo.id), isNull);
      expect(await repo.confirm('b'), isNull);
    });

    test('reschedule moves it, sets Rescheduled, and checks conflicts',
        () async {
      await repo.bookings.submit(_req('a', '6470000001', stylist: amy));
      await repo.bookings.submit(_req('b', '6470000002', stylist: amy, slot: 900));
      await repo.confirm('a');
      await repo.confirm('b');

      expect(await repo.reschedule('a', DateTime(2026, 12, 10), 900),
          contains('already has'));
      expect(await repo.reschedule('a', DateTime(2026, 12, 11), 600), isNull);
      final a = (await repo.appointments()).firstWhere((x) => x.id == 'a');
      expect(a.status, AppointmentStatus.rescheduled);
      expect(a.date, DateTime(2026, 12, 11));
      expect(a.slotMinutes, 600);
    });

    test('client history shows all of a client\'s visits', () async {
      await repo.bookings.submit(_req('a', '6470000001'));
      await repo.bookings.submit(_req('b', '(647) 000-0001'));
      final id = (await repo.appointments()).first.clientId!;
      final c = await repo.client(id);
      expect(c.history, hasLength(2));
    });
  });
}
