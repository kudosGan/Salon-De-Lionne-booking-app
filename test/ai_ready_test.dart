import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/core/config/salon_config.dart';
import 'package:salon_booking/data/admin_repository.dart';
import 'package:salon_booking/data/booking_repository.dart';
import 'package:salon_booking/data/catalog.dart';
import 'package:salon_booking/data/db/app_database.dart';
import 'package:salon_booking/data/models.dart';
import 'package:salon_booking/features/ai_agent/assistant_contract.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('knowledge only contains salon-provided facts and no prices', () async {
    final k = await SalonKnowledge.load(InMemoryBookingRepository());
    final text = k.toPromptText();
    expect(text, contains(SalonConfig.name));
    expect(text, contains(SalonConfig.address));
    expect(text, contains('Never invent'));
    for (final s in Catalog.services) {
      expect(text, contains(s.name));
    }
    expect(text.contains(r'$'), isFalse);
  });

  group('booking gateway', () {
    late AdminRepository repo;
    final thursday = DateTime(2026, 12, 10);
    final amy = Catalog.stylists.first;

    setUp(() async {
      final db = await AppDatabase.open(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      repo = AdminRepository(db);
    });
    tearDown(() => repo.db.close());

    BookingDraft draft({int slot = 840, Stylist? stylist}) => BookingDraft(
          clientName: ' Sarah Lee ',
          phone: '(416) 555-0123',
          serviceName: 'Hair Colouring',
          date: thursday,
          slotMinutes: slot,
          stylist: stylist,
        );

    test('an assistant booking is always Pending and notifies the admin',
        () async {
      final saved = await BookingGateway(repo.bookings).submit(draft(stylist: amy));
      expect(saved.status, AppointmentStatus.pending);
      expect(saved.clientName, 'Sarah Lee');
      expect(
          [for (final n in await repo.notifications()) n.title],
          contains('New booking request'));
    });

    test('it cannot book a time that is not free', () async {
      final gateway = BookingGateway(repo.bookings);
      // Outside the stylist's hours (default 9:00-18:00).
      await expectLater(gateway.submit(draft(slot: 7 * 60, stylist: amy)),
          throwsA(isA<BookingRejected>()));
      // Blocked by the stylist.
      await repo.setBlocked(amy.id, thursday, 840, true);
      await expectLater(gateway.submit(draft(stylist: amy)),
          throwsA(isA<BookingRejected>()));
      // Taken by a confirmed appointment.
      await repo.setBlocked(amy.id, thursday, 840, false);
      final first = await gateway.submit(draft(stylist: amy));
      await repo.confirm(first.id);
      await expectLater(gateway.submit(draft(stylist: amy)),
          throwsA(isA<BookingRejected>()));
    });

    test('auto-confirm is off by default (setting absent)', () async {
      expect(await repo.getSetting(BookingGateway.autoConfirmSetting), isNull);
    });
  });
}
