import 'dart:math';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'availability.dart';
import 'booking_repository.dart';
import 'catalog.dart';
import 'models.dart';
import 'notifications.dart';

/// Saves bookings in SQLite. Existing clients are matched by phone number so
/// repeat visitors never create duplicate client records.
class SqliteBookingRepository implements BookingRepository {
  final Database db;
  SqliteBookingRepository(this.db);

  /// "(647) 986-5466" and "+1 647 986 5466" both become "6479865466".
  static String phoneKey(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<BookingRequest> submit(BookingRequest r) async {
    return db.transaction((txn) async {
      // 1. Find or create the client.
      final key = phoneKey(r.phone);
      final existing = await txn.query('clients',
          where: 'phone_key = ?', whereArgs: [key], limit: 1);
      String clientId;
      if (existing.isEmpty) {
        clientId = _newId();
        await txn.insert('clients', {
          'id': clientId,
          'name': r.clientName,
          'phone': r.phone,
          'phone_key': key,
          'email': r.email,
          'preferred_stylist_id': r.stylist?.id,
          'created_at': r.createdAt.toIso8601String(),
        });
      } else {
        clientId = existing.first['id'] as String;
        await txn.update(
          'clients',
          {
            'name': r.clientName,
            // Keep the old email if they leave it blank this time.
            if (r.email != null) 'email': r.email,
            if (r.stylist != null) 'preferred_stylist_id': r.stylist!.id,
          },
          where: 'id = ?',
          whereArgs: [clientId],
        );
      }

      // 2. The appointment itself.
      await txn.insert('appointments', {
        'id': r.id,
        'client_id': clientId,
        'stylist_id': r.stylist?.id,
        'service_name': r.serviceName,
        'hairstyle_id': r.hairstyle?.id,
        'date': _dateKey(r.date),
        'slot_minutes': r.slotMinutes,
        'notes': r.notes,
        'status': r.status.name,
        'created_at': r.createdAt.toIso8601String(),
      });

      // 3. Reference photos.
      for (final p in r.photos) {
        await txn.insert('appointment_photos',
            {'appointment_id': r.id, 'name': p.name, 'bytes': p.bytes});
      }

      // 4. Tell the admin, and the chosen stylist (or every active stylist
      // when the client picked "Any Available Stylist").
      final what = Notifier.summary(r);
      await Notifier.toAdmin(txn, 'New booking request', what,
          appointmentId: r.id, now: r.createdAt);
      final targets = r.stylist != null
          ? [r.stylist!.id]
          : [
              for (final s in await txn.query('stylists',
                  columns: ['id'], where: 'active = 1'))
                s['id'] as String
            ];
      for (final id in targets) {
        await Notifier.toStylist(txn, id, 'New appointment request', what,
            appointmentId: r.id, now: r.createdAt);
      }
      return r.copyWith(clientId: clientId);
    });
  }

  @override
  Future<List<BookingRequest>> all({bool withPhotos = false}) async {
    final rows = await db.rawQuery('''
      SELECT a.*, c.name AS client_name, c.phone, c.email,
             s.name AS stylist_name
      FROM appointments a
      JOIN clients c ON c.id = a.client_id
      LEFT JOIN stylists s ON s.id = a.stylist_id
      ORDER BY a.date, a.slot_minutes
    ''');
    final out = <BookingRequest>[];
    for (final m in rows) {
      final id = m['id'] as String;
      final stylistId = m['stylist_id'] as String?;
      final dateParts = (m['date'] as String).split('-').map(int.parse).toList();
      out.add(BookingRequest(
        id: id,
        clientId: m['client_id'] as String,
        clientName: m['client_name'] as String,
        phone: m['phone'] as String,
        email: m['email'] as String?,
        date: DateTime(dateParts[0], dateParts[1], dateParts[2]),
        slotMinutes: m['slot_minutes'] as int,
        stylist: stylistId == null
            ? null
            : Stylist(stylistId, m['stylist_name'] as String),
        serviceName: m['service_name'] as String,
        hairstyle: Catalog.hairstyleById(m['hairstyle_id'] as String?),
        notes: m['notes'] as String,
        photos: withPhotos ? await photosOf(id) : const [],
        status: AppointmentStatus.values.byName(m['status'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        confirmedAt: m['confirmed_at'] == null
            ? null
            : DateTime.parse(m['confirmed_at'] as String),
      ));
    }
    return out;
  }

  static List<DateTime> _parseDays(String s) => [
        for (final p in s.split(',').where((p) => p.isNotEmpty))
          DateTime.parse(p)
      ];

  /// Every stylist with profile, schedule and login name.
  Future<List<StaffMember>> staff() async {
    final rows = await db.rawQuery('''
      SELECT s.*, u.username AS username FROM stylists s
      LEFT JOIN users u ON u.stylist_id = s.id
      ORDER BY s.active DESC, s.name COLLATE NOCASE
    ''');
    return [
      for (final r in rows)
        StaffMember(
          id: r['id'] as String,
          name: r['name'] as String,
          photo: r['photo'] as Uint8List?,
          specialties: r['specialties'] as String,
          workDays: {
            for (final d in (r['work_days'] as String).split(','))
              if (d.isNotEmpty) int.parse(d)
          },
          startMinutes: r['start_minutes'] as int,
          endMinutes: r['end_minutes'] as int,
          daysOff: _parseDays(r['days_off'] as String),
          active: (r['active'] as int) == 1,
          username: r['username'] as String?,
        )
    ];
  }

  @override
  Future<Set<int>> availableSlots(DateTime date,
      {String? stylistId, String? exceptAppointmentId}) async {
    final key = _dateKey(date);
    final rows = await db.query('appointments',
        columns: ['id', 'stylist_id', 'slot_minutes', 'status'],
        where: 'date = ? AND stylist_id IS NOT NULL',
        whereArgs: [key]);
    final busy = <String, Set<int>>{};
    for (final r in rows) {
      if (r['id'] == exceptAppointmentId) continue;
      final status = AppointmentStatus.values.byName(r['status'] as String);
      if (!Availability.blocksSlot(status)) continue;
      busy
          .putIfAbsent(r['stylist_id'] as String, () => {})
          .add(r['slot_minutes'] as int);
    }

    // Slots a stylist has switched off count as taken.
    final blocked = await db.query('blocked_slots',
        where: 'date = ?', whereArgs: [key]);
    for (final r in blocked) {
      busy
          .putIfAbsent(r['stylist_id'] as String, () => {})
          .add(r['slot_minutes'] as int);
    }

    final out = <int>{};
    for (final s in await staff()) {
      if (stylistId != null && s.id != stylistId) continue;
      out.addAll(Availability.openSlots(
          s, date, busy[s.id] ?? const {}, Catalog.slots));
    }
    return out;
  }

  @override
  Future<List<Stylist>> stylists() async {
    final rows = await db.query('stylists',
        columns: ['id', 'name'],
        where: 'active = 1',
        orderBy: 'name COLLATE NOCASE');
    return [
      for (final r in rows) Stylist(r['id'] as String, r['name'] as String)
    ];
  }

  @override
  Future<List<ReferencePhoto>> photosOf(String appointmentId) async {
    final rows = await db.query('appointment_photos',
        where: 'appointment_id = ?', whereArgs: [appointmentId], orderBy: 'id');
    return [
      for (final p in rows)
        ReferencePhoto(p['name'] as String, p['bytes'] as Uint8List)
    ];
  }
}
