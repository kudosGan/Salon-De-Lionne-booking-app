import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/data/admin_repository.dart';
import 'package:salon_booking/data/availability.dart';
import 'package:salon_booking/data/catalog.dart';
import 'package:salon_booking/data/db/app_database.dart';
import 'package:salon_booking/data/models.dart';
import 'package:salon_booking/features/calendar/calendar_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('calendar helpers', () {
    test('week starts on Monday', () {
      // 22 Nov 2026 is a Sunday.
      expect(startOfWeek(DateTime(2026, 11, 22)), DateTime(2026, 11, 16));
      expect(startOfWeek(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    });

    test('adding months keeps valid days', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
      expect(addMonths(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 15));
    });

    test('month grid is 42 days starting on a Monday and covers the month', () {
      final g = monthGrid(DateTime(2026, 11, 10));
      expect(g, hasLength(42));
      expect(g.first.weekday, DateTime.monday);
      expect(g.contains(DateTime(2026, 11, 1)), isTrue);
      expect(g.contains(DateTime(2026, 11, 30)), isTrue);
    });

    test('week label', () {
      expect(weekLabel(DateTime(2026, 11, 18)), 'Nov 16 – 22, 2026');
      expect(weekLabel(DateTime(2026, 12, 2)), 'Nov 30 – Dec 6, 2026');
    });
  });

  group('availability rules', () {
    const amy = StaffMember(
        id: 'a', name: 'Amy', workDays: {1, 2, 3, 4, 5}, startMinutes: 600, endMinutes: 780);
    final thursday = DateTime(2026, 12, 10);

    test('only working hours, minus booked slots', () {
      final open =
          Availability.openSlots(amy, thursday, {660}, Catalog.slots);
      expect(open, {600, 630, 690, 720, 750}); // 10:00-12:30 except 11:00
    });

    test('not working on a non-work day or a day off', () {
      expect(Availability.openSlots(amy, DateTime(2026, 12, 12), {}, Catalog.slots),
          isEmpty); // Saturday
      final off = StaffMember(
          id: 'a', name: 'Amy', daysOff: [thursday]);
      expect(Availability.openSlots(off, thursday, {}, Catalog.slots), isEmpty);
    });

    test('inactive stylists are never available', () {
      const gone = StaffMember(id: 'g', name: 'G', active: false);
      expect(Availability.worksOn(gone, DateTime(2026, 12, 10)), isFalse);
    });

    test('pending requests do not block a slot, confirmed ones do', () {
      BookingRequest appt(AppointmentStatus s) => BookingRequest(
            id: 'x',
            clientName: 'C',
            phone: '1',
            date: thursday,
            slotMinutes: 660,
            stylist: const Stylist('a', 'Amy'),
            serviceName: 'Hairstyling',
            status: s,
            createdAt: DateTime(2026, 11, 1),
          );
      expect(Availability.isFree(amy, thursday, 660, [appt(AppointmentStatus.pending)]),
          isTrue);
      expect(Availability.isFree(amy, thursday, 660, [appt(AppointmentStatus.confirmed)]),
          isFalse);
      expect(Availability.isFree(amy, thursday, 660, [appt(AppointmentStatus.cancelled)]),
          isTrue);
    });
  });

  group('availableSlots from the database', () {
    late AdminRepository repo;
    final thursday = DateTime(2026, 12, 10);

    BookingRequest req(String id, String phone, String stylistId, int slot) =>
        BookingRequest(
          id: id,
          clientName: 'Client $id',
          phone: phone,
          date: thursday,
          slotMinutes: slot,
          stylist: Stylist(stylistId, 'S'),
          serviceName: Catalog.services.first.name,
          createdAt: DateTime(2026, 11, 22),
        );

    setUp(() async {
      final db = await AppDatabase.open(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      repo = AdminRepository(db);
    });
    tearDown(() => repo.db.close());

    test('default stylist hours 9:00-6:00; Sunday closed', () async {
      final s = await repo.availableSlots(thursday, stylistId: 's1');
      expect(s.contains(540), isTrue);
      expect(s.contains(1050), isTrue); // 5:30 PM
      expect(s.contains(1080), isFalse); // 6:00 PM is closing time
      expect(s.contains(510), isFalse);
      expect(await repo.availableSlots(DateTime(2026, 12, 13), stylistId: 's1'),
          isEmpty);
    });

    test('a confirmed booking removes the slot for that stylist only', () async {
      await repo.bookings.submit(req('a', '6470000001', 's1', 840));
      await repo.confirm('a');
      expect((await repo.availableSlots(thursday, stylistId: 's1')).contains(840),
          isFalse);
      // Another stylist is still free at 2 PM, so "any stylist" still offers it.
      expect((await repo.availableSlots(thursday)).contains(840), isTrue);
      // Rescheduling the same appointment may keep its own time.
      expect(
          (await repo.availableSlots(thursday,
                  stylistId: 's1', exceptAppointmentId: 'a'))
              .contains(840),
          isTrue);
    });

    test('blocked times cannot be booked; unblocking restores them', () async {
      expect(await repo.setBlocked('s1', thursday, 600, true), isNull);
      expect((await repo.availableSlots(thursday, stylistId: 's1')).contains(600),
          isFalse);
      // Another stylist can still take it, so "any stylist" still shows it.
      expect((await repo.availableSlots(thursday)).contains(600), isTrue);

      expect(await repo.setBlocked('s1', thursday, 600, false), isNull);
      expect((await repo.availableSlots(thursday, stylistId: 's1')).contains(600),
          isTrue);
    });

    test('a stylist can only block their own times; admin can block anyone',
        () async {
      expect(
          await repo.setBlocked('s2', thursday, 600, true, actingStylist: 's1'),
          contains('only change your own'));
      expect(
          await repo.setBlocked('s1', thursday, 600, true, actingStylist: 's1'),
          isNull);
      expect(await repo.setBlocked('s2', thursday, 600, true), isNull); // admin
      expect((await repo.blocks()).length, 2);
    });

    test('cannot block a time that already has a confirmed appointment',
        () async {
      await repo.bookings.submit(req('a', '6470000001', 's1', 840));
      await repo.confirm('a');
      expect(await repo.setBlocked('s1', thursday, 840, true),
          contains('already an appointment'));
    });

    test('blocking a whole day skips booked slots; unblocking clears it',
        () async {
      await repo.bookings.submit(req('a', '6470000001', 's1', 840));
      await repo.confirm('a');
      final slots = [for (var m = 540; m < 1080; m += 30) m];
      await repo.setDayBlocked('s1', thursday, true, slots: slots);
      final open = await repo.availableSlots(thursday, stylistId: 's1');
      expect(open, isEmpty);
      expect((await repo.blocks()).any((b) => b.slot == 840), isFalse);

      await repo.setDayBlocked('s1', thursday, false, slots: slots);
      expect(await repo.blocks(), isEmpty);
      expect((await repo.availableSlots(thursday, stylistId: 's1')).isNotEmpty,
          isTrue);
    });

    test('confirming into a blocked time is refused', () async {
      await repo.bookings.submit(req('a', '6470000001', 's1', 840));
      await repo.setBlocked('s1', thursday, 840, true);
      expect(await repo.confirm('a'), contains('blocked'));
      await repo.setBlocked('s1', thursday, 840, false);
      expect(await repo.confirm('a'), isNull);
    });

    test('days off and schedule changes are respected', () async {
      final s1 = (await repo.staff()).firstWhere((m) => m.id == 's1');
      await repo.saveStaff(
          StaffMember(
              id: 's1',
              name: s1.name,
              workDays: s1.workDays,
              startMinutes: 720,
              endMinutes: 840,
              daysOff: [DateTime(2026, 12, 11)]),
          isNew: false);
      expect(await repo.availableSlots(thursday, stylistId: 's1'),
          {720, 750, 780, 810});
      expect(await repo.availableSlots(DateTime(2026, 12, 11), stylistId: 's1'),
          isEmpty); // day off
    });
  });
}
