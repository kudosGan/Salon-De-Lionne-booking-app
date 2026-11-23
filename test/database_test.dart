import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/data/catalog.dart';
import 'package:salon_booking/data/db/app_database.dart';
import 'package:salon_booking/data/models.dart';
import 'package:salon_booking/data/sqlite_booking_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

BookingRequest _req(String id, String phone,
        {String name = 'Sarah Lee', String? email, List<ReferencePhoto>? photos}) =>
    BookingRequest(
      id: id,
      clientName: name,
      phone: phone,
      email: email,
      date: DateTime(2026, 12, 10),
      slotMinutes: 14 * 60,
      stylist: Catalog.stylists.first,
      serviceName: Catalog.services.first.name,
      hairstyle: Catalog.hairstyles.first,
      notes: 'hello',
      photos: photos ?? const [],
      createdAt: DateTime(2026, 11, 22, 10),
    );

void main() {
  sqfliteFfiInit();

  late SqliteBookingRepository repo;

  setUp(() async {
    final db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = SqliteBookingRepository(db);
  });

  // Closing an in-memory database wipes it, so each test starts clean.
  tearDown(() => repo.db.close());

  test('saves a booking as Pending with all its details', () async {
    await repo.submit(_req('a1', '(647) 986-5466', email: 'sarah@x.com'));
    final all = await repo.all();

    expect(all, hasLength(1));
    final b = all.single;
    expect(b.status, AppointmentStatus.pending);
    expect(b.clientName, 'Sarah Lee');
    expect(b.email, 'sarah@x.com');
    expect(b.date, DateTime(2026, 12, 10));
    expect(b.slotMinutes, 840);
    expect(b.stylist?.name, Catalog.stylists.first.name);
    expect(b.hairstyle?.id, Catalog.hairstyles.first.id);
    expect(b.notes, 'hello');
  });

  test('same phone number in different formats reuses one client', () async {
    await repo.submit(_req('a1', '(647) 986-5466'));
    await repo.submit(_req('a2', '+1 647 986 5466', name: 'Sarah L.'));

    final db = repo.db;
    expect(await db.query('clients'), hasLength(1));
    final all = await repo.all();
    expect(all, hasLength(2));
    expect(all[0].clientId, all[1].clientId);
  });

  test('blank email on a repeat booking keeps the old email', () async {
    await repo.submit(_req('a1', '6479865466', email: 'keep@x.com'));
    await repo.submit(_req('a2', '6479865466'));
    final rows = await repo.db.query('clients');
    expect(rows.single['email'], 'keep@x.com');
  });

  test('reference photos are stored and loaded back', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await repo.submit(_req('a1', '6479865466',
        photos: [ReferencePhoto('ref.jpg', bytes)]));

    expect((await repo.all()).single.photos, isEmpty); // not loaded by default
    final photos = await repo.photosOf('a1');
    expect(photos.single.name, 'ref.jpg');
    expect(photos.single.bytes, bytes);
  });

  test('starting services, hairstyles and stylists are seeded', () async {
    expect(await repo.db.query('services'), hasLength(Catalog.services.length));
    expect(await repo.db.query('hairstyles'), hasLength(Catalog.hairstyles.length));
    expect(await repo.db.query('stylists'), hasLength(Catalog.stylists.length));
  });
}
