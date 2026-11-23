import 'package:material_ui/material_ui.dart';
import 'package:sqflite/sqflite.dart';
import '../core/utils/format.dart';
import '../features/auth/auth_service.dart';
import 'models.dart';
import 'notifications.dart';
import 'report.dart';
import 'sqlite_booking_repository.dart';

class DashboardStats {
  final int today, pending, confirmed, completed, cancelled;
  final int clients, stylists, month;
  const DashboardStats({
    required this.today,
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.clients,
    required this.stylists,
    required this.month,
  });
}

class ClientSummary {
  final String name, phone;
  final String? email;
  final List<BookingRequest> history; // all of this client's appointments
  const ClientSummary(this.name, this.phone, this.email, this.history);
}

/// Everything the admin screens read and change. Notifies listeners whenever
/// data changes so open screens refresh themselves.
class AdminRepository extends ChangeNotifier {
  final Database db;
  final SqliteBookingRepository bookings;
  AdminRepository(this.db) : bookings = SqliteBookingRepository(db);

  /// Statuses that occupy a stylist's time slot.
  static const _busy = "('confirmed','rescheduled')";

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<int> _count(String where, [List<Object?> args = const []]) async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM appointments WHERE $where', args);
    return r.first['n'] as int;
  }

  Future<DashboardStats> stats({DateTime? now}) async {
    now ??= DateTime.now();
    final today = dateKey(now);
    final monthStart = dateKey(DateTime(now.year, now.month, 1));
    final nextMonth = dateKey(DateTime(now.year, now.month + 1, 1));
    Future<int> table(String t) async =>
        (await db.rawQuery('SELECT COUNT(*) AS n FROM $t WHERE ${t == 'stylists' ? 'active = 1' : '1=1'}'))
            .first['n'] as int;

    return DashboardStats(
      // Actual appointments on today's schedule (not requests still waiting).
      today: await _count(
          "date = ? AND status IN ('confirmed','rescheduled','completed')",
          [today]),
      pending: await _count("status = 'pending'"),
      confirmed: await _count("status = 'confirmed'"),
      completed: await _count("status = 'completed'"),
      cancelled: await _count("status = 'cancelled'"),
      clients: await table('clients'),
      stylists: await table('stylists'),
      // Everything dated this month except declined/cancelled.
      month: await _count(
          "date >= ? AND date < ? AND status NOT IN ('declined','cancelled')",
          [monthStart, nextMonth]),
    );
  }

  /// [forStylist]: only that stylist's appointments, plus new requests that
  /// nobody has been assigned to yet (so any stylist can pick them up).
  Future<List<BookingRequest>> appointments(
      {AppointmentStatus? status, String? forStylist}) async {
    final all = await bookings.all();
    final list = all
        .where((a) => status == null || a.status == status)
        .where((a) =>
            forStylist == null ||
            a.stylist?.id == forStylist ||
            (a.stylist == null && a.status == AppointmentStatus.pending))
        .toList();
    // Newest dates first.
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.slotMinutes.compareTo(a.slotMinutes);
    });
    return list;
  }

  Future<List<ReferencePhoto>> photos(String appointmentId) =>
      bookings.photosOf(appointmentId);

  Future<List<Stylist>> stylists() async {
    final rows =
        await db.query('stylists', where: 'active = 1', orderBy: 'name');
    return [for (final r in rows) Stylist(r['id'] as String, r['name'] as String)];
  }

  Future<ClientSummary> client(String clientId) async {
    final c = (await db.query('clients', where: 'id = ?', whereArgs: [clientId]))
        .first;
    final history = (await bookings.all())
        .where((a) => a.clientId == clientId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ClientSummary(
        c['name'] as String, c['phone'] as String, c['email'] as String?, history);
  }

  // ---- changes. Each returns an error message, or null on success. ----

  Future<bool> _hasConflict(
      String stylistId, DateTime date, int slot, String exceptId) async {
    final n = await _count(
        'stylist_id = ? AND date = ? AND slot_minutes = ? AND id != ? AND status IN $_busy',
        [stylistId, dateKey(date), slot, exceptId]);
    return n > 0;
  }

  Future<BookingRequest?> _find(String id) async =>
      (await bookings.all()).where((a) => a.id == id).firstOrNull;

  /// [byStylist]: set when the stylist accepted it themselves (the admin is
  /// told); otherwise the admin confirmed it (the stylist is told).
  Future<String?> confirm(String id, {String? byStylist}) async {
    final a = await _find(id);
    if (a == null) return 'Appointment not found.';
    if (a.stylist == null) return 'Assign a stylist before confirming.';
    if (await _hasConflict(a.stylist!.id, a.date, a.slotMinutes, id)) {
      return '${a.stylist!.name} already has a confirmed appointment at that time.';
    }
    if (await _isBlocked(a.stylist!.id, a.date, a.slotMinutes)) {
      return '${a.stylist!.name} has blocked that time.';
    }
    await db.update(
        'appointments',
        {
          'status': AppointmentStatus.confirmed.name,
          'confirmed_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id]);
    if (byStylist != null) {
      await Notifier.toAdmin(db, 'Stylist accepted booking',
          '${a.stylist!.name}: ${Notifier.summary(a)}',
          appointmentId: id);
    } else {
      await Notifier.toStylist(
          db, a.stylist!.id, 'Appointment confirmed', Notifier.summary(a),
          appointmentId: id);
    }
    notifyListeners();
    return null;
  }

  /// decline / cancel / complete. [byStylist] is set when a stylist did it.
  Future<String?> setStatus(String id, AppointmentStatus status,
      {String? byStylist}) async {
    if (status == AppointmentStatus.confirmed) {
      return confirm(id, byStylist: byStylist);
    }
    final a = await _find(id);
    await db.update('appointments', {'status': status.name},
        where: 'id = ?', whereArgs: [id]);
    if (a != null) {
      if (status == AppointmentStatus.declined && byStylist != null) {
        await Notifier.toAdmin(db, 'Stylist declined booking',
            '${a.stylist?.name ?? 'A stylist'}: ${Notifier.summary(a)}',
            appointmentId: id);
      }
      if (status == AppointmentStatus.cancelled && a.stylist != null) {
        await Notifier.toStylist(
            db, a.stylist!.id, 'Appointment cancelled', Notifier.summary(a),
            appointmentId: id);
      }
    }
    notifyListeners();
    return null;
  }

  Future<String?> assignStylist(String id, String? stylistId,
      {bool notify = true}) async {
    final a = await _find(id);
    if (a == null) return 'Appointment not found.';
    final busyStatus = a.status == AppointmentStatus.confirmed ||
        a.status == AppointmentStatus.rescheduled;
    if (stylistId != null &&
        busyStatus &&
        await _hasConflict(stylistId, a.date, a.slotMinutes, id)) {
      return 'That stylist already has an appointment at this time.';
    }
    if (stylistId != null &&
        busyStatus &&
        await _isBlocked(stylistId, a.date, a.slotMinutes)) {
      return 'That stylist has blocked this time.';
    }
    await db.update('appointments', {'stylist_id': stylistId},
        where: 'id = ?', whereArgs: [id]);
    if (notify && stylistId != null && a.stylist?.id != stylistId) {
      await Notifier.toStylist(
          db, stylistId, 'Appointment assigned', Notifier.summary(a),
          appointmentId: id);
    }
    notifyListeners();
    return null;
  }

  // ---- blocking times off ----

  Future<List<BlockedSlot>> blocks() async {
    final rows = await db.query('blocked_slots');
    return [
      for (final r in rows)
        BlockedSlot(r['stylist_id'] as String,
            DateTime.parse(r['date'] as String), r['slot_minutes'] as int)
    ];
  }

  Future<bool> _isBlocked(String stylistId, DateTime date, int slot) async =>
      (await db.query('blocked_slots',
              where: 'stylist_id = ? AND date = ? AND slot_minutes = ?',
              whereArgs: [stylistId, dateKey(date), slot]))
          .isNotEmpty;

  /// Switch one slot off or on. A stylist may only change their own times
  /// (pass [actingStylist]); the admin leaves it null and can change anyone's.
  Future<String?> setBlocked(String stylistId, DateTime date, int slot, bool blocked,
      {String? actingStylist}) async {
    if (actingStylist != null && actingStylist != stylistId) {
      return 'You can only change your own times.';
    }
    if (blocked) {
      if (await _count(
              'stylist_id = ? AND date = ? AND slot_minutes = ? AND status IN $_busy',
              [stylistId, dateKey(date), slot]) >
          0) {
        return 'There is already an appointment at that time.';
      }
      await db.insert(
          'blocked_slots',
          {
            'stylist_id': stylistId,
            'date': dateKey(date),
            'slot_minutes': slot,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('blocked_slots',
          where: 'stylist_id = ? AND date = ? AND slot_minutes = ?',
          whereArgs: [stylistId, dateKey(date), slot]);
    }
    notifyListeners();
    return null;
  }

  /// Block (or unblock) every slot of the stylist's working hours that day.
  /// Slots that already hold an appointment are left alone.
  Future<String?> setDayBlocked(String stylistId, DateTime date, bool blocked,
      {String? actingStylist, required List<int> slots}) async {
    if (actingStylist != null && actingStylist != stylistId) {
      return 'You can only change your own times.';
    }
    final key = dateKey(date);
    await db.transaction((txn) async {
      if (!blocked) {
        await txn.delete('blocked_slots',
            where: 'stylist_id = ? AND date = ?', whereArgs: [stylistId, key]);
        return;
      }
      final taken = (await txn.rawQuery(
              'SELECT slot_minutes FROM appointments WHERE stylist_id = ? AND date = ? AND status IN $_busy',
              [stylistId, key]))
          .map((r) => r['slot_minutes'] as int)
          .toSet();
      for (final m in slots.where((m) => !taken.contains(m))) {
        await txn.insert(
            'blocked_slots',
            {'stylist_id': stylistId, 'date': key, 'slot_minutes': m},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    notifyListeners();
    return null;
  }

  // ---- actions a stylist may take on their own appointments ----

  Future<String?> _ownedBy(String id, String stylistId) async {
    final a = await _find(id);
    if (a == null) return 'Appointment not found.';
    if (a.stylist != null && a.stylist!.id != stylistId) {
      return 'This appointment belongs to another stylist.';
    }
    return null;
  }

  /// Accept a request: takes it (if unassigned) and confirms it.
  Future<String?> acceptAs(String id, String stylistId) async {
    final err = await _ownedBy(id, stylistId);
    if (err != null) return err;
    final a = (await _find(id))!;
    if (a.stylist == null) {
      final e = await assignStylist(id, stylistId, notify: false);
      if (e != null) return e;
    }
    return confirm(id, byStylist: stylistId);
  }

  Future<String?> declineAs(String id, String stylistId) async =>
      await _ownedBy(id, stylistId) ??
      await setStatus(id, AppointmentStatus.declined, byStylist: stylistId);

  Future<String?> completeAs(String id, String stylistId) async =>
      await _ownedBy(id, stylistId) ??
      await setStatus(id, AppointmentStatus.completed);

  // ---- staff management ----

  Future<List<StaffMember>> staff() => bookings.staff();

  /// Free slots on [date] for one stylist (or any stylist if null).
  Future<Set<int>> availableSlots(DateTime date,
          {String? stylistId, String? exceptAppointmentId}) =>
      bookings.availableSlots(date,
          stylistId: stylistId, exceptAppointmentId: exceptAppointmentId);

  /// Creates or updates a stylist. If [username] and [password] are given, a
  /// login is created (new) or the password is reset (existing login).
  /// Returns an error message, or null on success.
  Future<String?> saveStaff(StaffMember m,
      {required bool isNew, String? username, String? password}) async {
    if (m.name.trim().isEmpty) return 'Please enter a name.';
    if (m.startMinutes >= m.endMinutes) {
      return 'Working hours: the start must be before the end.';
    }
    if (m.workDays.isEmpty) return 'Choose at least one working day.';
    final wantsLogin = (username ?? '').trim().isNotEmpty;
    final hasPassword = (password ?? '').isNotEmpty;
    if (wantsLogin && m.username == null && !hasPassword) {
      return 'Set a password for the new login.';
    }
    if (hasPassword) {
      try {
        AuthService.checkPassword(password!);
      } on ArgumentError catch (e) {
        return e.message.toString();
      }
    }
    if (wantsLogin && username!.trim().length < 3) {
      return 'Username must be at least 3 characters.';
    }

    try {
      await db.transaction((txn) async {
        final values = {
          'name': m.name.trim(),
          'photo': m.photo,
          'specialties': m.specialties.trim(),
          'work_days': (m.workDays.toList()..sort()).join(','),
          'start_minutes': m.startMinutes,
          'end_minutes': m.endMinutes,
          'days_off': m.daysOff.map(dateKey).join(','),
          'active': m.active ? 1 : 0,
        };
        if (isNew) {
          await txn.insert('stylists', {'id': m.id, ...values});
        } else {
          await txn.update('stylists', values, where: 'id = ?', whereArgs: [m.id]);
        }

        if (m.username == null && wantsLogin) {
          await AuthService(db)
              .createEmployee(username!, password!, m.id, on: txn);
        } else if (m.username != null && hasPassword) {
          final salt = AuthService.newSalt();
          await txn.update(
              'users',
              {
                'salt': salt,
                'password_hash': AuthService.hashPassword(password!, salt),
              },
              where: 'stylist_id = ?',
              whereArgs: [m.id]);
        }
        await txn.update('users', {'active': m.active ? 1 : 0},
            where: 'stylist_id = ?', whereArgs: [m.id]);
      });
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE') && e.toString().contains('username')) {
        return 'That username is already taken.';
      }
      rethrow;
    }
    notifyListeners();
    return null;
  }

  /// Deactivating hides the stylist from booking and blocks their login,
  /// but keeps their appointment history.
  Future<void> setStaffActive(String id, bool active) async {
    await db.transaction((txn) async {
      await txn.update('stylists', {'active': active ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);
      await txn.update('users', {'active': active ? 1 : 0},
          where: 'stylist_id = ?', whereArgs: [id]);
    });
    notifyListeners();
  }

  /// Only possible if the stylist has no appointments. Otherwise deactivate.
  Future<String?> deleteStaff(String id) async {
    if (await _count('stylist_id = ?', [id]) > 0) {
      return 'This stylist has appointments, so deactivate them instead.';
    }
    await db.transaction((txn) async {
      await txn.update('clients', {'preferred_stylist_id': null},
          where: 'preferred_stylist_id = ?', whereArgs: [id]);
      await txn.delete('users', where: 'stylist_id = ?', whereArgs: [id]);
      await txn.delete('notifications',
          where: 'stylist_id = ?', whereArgs: [id]);
      await txn.delete('stylists', where: 'id = ?', whereArgs: [id]);
    });
    notifyListeners();
    return null;
  }

  Future<String?> reschedule(String id, DateTime date, int slot) async {
    final a = await _find(id);
    if (a == null) return 'Appointment not found.';
    if (a.stylist != null &&
        await _hasConflict(a.stylist!.id, date, slot, id)) {
      return '${a.stylist!.name} already has an appointment at that time.';
    }
    if (a.stylist != null && await _isBlocked(a.stylist!.id, date, slot)) {
      return '${a.stylist!.name} has blocked that time.';
    }
    await db.update(
        'appointments',
        {
          'date': dateKey(date),
          'slot_minutes': slot,
          'status': AppointmentStatus.rescheduled.name,
          // New time, so reminders start over.
          'reminder_notified_at': null,
          'reminder_sent_at': null,
        },
        where: 'id = ?',
        whereArgs: [id]);
    if (a.stylist != null) {
      await Notifier.toStylist(
          db,
          a.stylist!.id,
          'Appointment rescheduled',
          '${a.clientName} · now ${formatDate(date)} at ${formatSlot(slot)}',
          appointmentId: id);
    }
    notifyListeners();
    return null;
  }

  // ---- settings ----

  Future<String?> getSetting(String key) async {
    final r = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) => db.insert(
      'settings', {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace);

  // ---- reports ----

  /// Every appointment ever (needed to tell new clients from returning ones).
  Future<MonthlyReport> report(int year, int month) async =>
      MonthlyReport.build(await bookings.all(), year, month);

  // ---- notifications ----

  /// Admin: pass nothing. Stylist: pass their [stylistId].
  String _audience(String? stylistId) =>
      stylistId == null ? "audience = 'admin'" : "audience = 'stylist' AND stylist_id = ?";
  List<Object?> _args(String? stylistId) => stylistId == null ? [] : [stylistId];

  Future<List<AppNotification>> notifications({String? stylistId}) async {
    final rows = await db.query('notifications',
        where: _audience(stylistId),
        whereArgs: _args(stylistId),
        orderBy: 'id DESC',
        limit: 100);
    return [
      for (final r in rows)
        AppNotification(
          r['id'] as int,
          r['title'] as String,
          r['body'] as String,
          r['appointment_id'] as String?,
          DateTime.parse(r['created_at'] as String),
          (r['is_read'] as int) == 1,
        )
    ];
  }

  Future<int> unreadCount({String? stylistId}) async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM notifications WHERE is_read = 0 AND ${_audience(stylistId)}',
        _args(stylistId));
    return r.first['n'] as int;
  }

  Future<void> markRead(int id) async {
    await db.update('notifications', {'is_read': 1},
        where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> markAllRead({String? stylistId}) async {
    await db.update('notifications', {'is_read': 1},
        where: _audience(stylistId), whereArgs: _args(stylistId));
    notifyListeners();
  }

  // ---- reminders ----

  /// Appointment start as a date + time.
  static DateTime startOf(BookingRequest a) =>
      DateTime(a.date.year, a.date.month, a.date.day, 0, a.slotMinutes);

  Future<List<BookingRequest>> _upcoming(DateTime now, String markerColumn) async {
    final rows = await db.query('appointments',
        columns: ['id'],
        where: "status IN $_busy AND $markerColumn IS NULL AND date >= ? AND date <= ?",
        whereArgs: [dateKey(now), dateKey(now.add(const Duration(days: 1)))]);
    final ids = {for (final r in rows) r['id'] as String};
    final limit = now.add(const Duration(hours: 24));
    return (await bookings.all()).where((a) {
      final s = startOf(a);
      return ids.contains(a.id) && s.isAfter(now) && !s.isAfter(limit);
    }).toList();
  }

  /// Creates "upcoming appointment" notifications (once each) for anything
  /// starting in the next 24 hours. Call this when the app is opened and every
  /// few minutes while it stays open. Returns how many were created.
  Future<int> generateDueReminders({DateTime? now}) async {
    now ??= DateTime.now();
    final due = await _upcoming(now, 'reminder_notified_at');
    for (final a in due) {
      final text = Notifier.summary(a);
      if (a.stylist != null) {
        await Notifier.toStylist(
            db, a.stylist!.id, 'Upcoming appointment', text,
            appointmentId: a.id, now: now);
      }
      await Notifier.toAdmin(db, 'Reminder to send to client', text,
          appointmentId: a.id, now: now);
      await db.update('appointments',
          {'reminder_notified_at': now.toIso8601String()},
          where: 'id = ?', whereArgs: [a.id]);
    }
    if (due.isNotEmpty) notifyListeners();
    return due.length;
  }

  /// Appointments in the next 24 hours whose client has not been sent a
  /// reminder yet (shown on the admin dashboard).
  Future<List<BookingRequest>> remindersToSend({DateTime? now}) async {
    final list = await _upcoming(now ?? DateTime.now(), 'reminder_sent_at');
    list.sort((a, b) => startOf(a).compareTo(startOf(b)));
    return list;
  }

  Future<void> markReminderSent(String appointmentId, {DateTime? now}) async {
    await db.update('appointments',
        {'reminder_sent_at': (now ?? DateTime.now()).toIso8601String()},
        where: 'id = ?', whereArgs: [appointmentId]);
    notifyListeners();
  }
}

/// Set in main() once the database is open.
AdminRepository? adminRepository;
