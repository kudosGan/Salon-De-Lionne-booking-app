import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../catalog.dart';

/// Opens the local SQLite database (one file on the device / in the browser).
///
/// Schema changes later: bump [version] and add a step in [_upgrade].
class AppDatabase {
  static const version = 6;
  static const fileName = 'salon.db';

  /// Pass a [factory] and [path] in tests (e.g. in-memory).
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    if (factory == null && kIsWeb) databaseFactory = databaseFactoryFfiWeb;
    final f = factory ?? databaseFactory;
    return f.openDatabase(
      path ?? fileName,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
  }

  static Future<void> _create(Database db, int v) async {
    await db.execute('''
      CREATE TABLE services (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        price_cents INTEGER,
        active INTEGER NOT NULL DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE hairstyles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        image_path TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )''');
    // Stage 5 adds login, photo, working days/hours, days off, specialties.
    await db.execute('''
      CREATE TABLE stylists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        photo BLOB,
        specialties TEXT NOT NULL DEFAULT '',
        work_days TEXT NOT NULL DEFAULT '1,2,3,4,5,6',
        start_minutes INTEGER NOT NULL DEFAULT 540,
        end_minutes INTEGER NOT NULL DEFAULT 1080,
        days_off TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        phone_key TEXT NOT NULL UNIQUE,
        email TEXT,
        preferred_stylist_id TEXT REFERENCES stylists(id),
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL REFERENCES clients(id),
        stylist_id TEXT REFERENCES stylists(id),
        service_name TEXT NOT NULL,
        hairstyle_id TEXT REFERENCES hairstyles(id),
        date TEXT NOT NULL,
        slot_minutes INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        confirmed_at TEXT,
        reminder_notified_at TEXT,
        reminder_sent_at TEXT
      )''');
    await db.execute(
        'CREATE INDEX idx_appt_date ON appointments(date, stylist_id)');
    await db.execute('''
      CREATE TABLE appointment_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id TEXT NOT NULL
          REFERENCES appointments(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        bytes BLOB NOT NULL
      )''');

    await _createUsers(db);
    await _createBlockedSlots(db);
    await _createNotifications(db);
    await _createSettings(db);

    await _seedCatalog(db);
  }

  /// Starting data. The admin edits all of this inside the app later.
  /// Safe to run on an existing database: it adds missing rows and never
  /// deletes old ones (old appointments may still point at them).
  static Future<void> _seedCatalog(Database db) async {
    final batch = db.batch();
    const replace = ConflictAlgorithm.replace;
    for (final s in Catalog.services) {
      batch.insert('services',
          {'id': s.name, 'name': s.name, 'description': s.description},
          conflictAlgorithm: replace);
    }
    for (final h in Catalog.hairstyles) {
      batch.insert('hairstyles',
          {'id': h.id, 'name': h.name, 'image_path': h.asset},
          conflictAlgorithm: replace);
    }
    for (final s in Catalog.stylists) {
      batch.insert('stylists', {'id': s.id, 'name': s.name},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await _createUsers(db);
      // The starter hairstyles/services changed, so make sure the new ones exist
      // (otherwise bookings for them would fail the database link check).
      await _seedCatalog(db);
    }
    if (oldV < 3) {
      // Stage 5: stylist profile, working days/hours and days off.
      for (final col in [
        'photo BLOB',
        "specialties TEXT NOT NULL DEFAULT ''",
        "work_days TEXT NOT NULL DEFAULT '1,2,3,4,5,6'",
        'start_minutes INTEGER NOT NULL DEFAULT 540',
        'end_minutes INTEGER NOT NULL DEFAULT 1080',
        "days_off TEXT NOT NULL DEFAULT ''",
      ]) {
        await db.execute('ALTER TABLE stylists ADD COLUMN $col');
      }
    }
    if (oldV < 4) await _createBlockedSlots(db);
    if (oldV < 5) {
      await db.execute(
          'ALTER TABLE appointments ADD COLUMN reminder_notified_at TEXT');
      await db.execute(
          'ALTER TABLE appointments ADD COLUMN reminder_sent_at TEXT');
      await _createNotifications(db);
    }
    if (oldV < 6) await _createSettings(db);
  }

  /// Small key/value store for app settings (e.g. the Google Sheets link).
  static Future<void> _createSettings(Database db) => db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');

  /// In-app notifications. audience 'admin' = the admin; 'stylist' = the
  /// stylist whose id is in stylist_id.
  static Future<void> _createNotifications(Database db) => db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audience TEXT NOT NULL,
        stylist_id TEXT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        appointment_id TEXT,
        created_at TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0
      )''');

  /// Times a stylist (or the admin for them) has switched off. Clients cannot
  /// book a blocked slot.
  static Future<void> _createBlockedSlots(Database db) => db.execute('''
      CREATE TABLE blocked_slots (
        stylist_id TEXT NOT NULL
          REFERENCES stylists(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        slot_minutes INTEGER NOT NULL,
        PRIMARY KEY (stylist_id, date, slot_minutes)
      )''');

  /// Logins for the admin and (from Stage 5) each stylist.
  static Future<void> _createUsers(Database db) => db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        role TEXT NOT NULL,
        stylist_id TEXT REFERENCES stylists(id),
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )''');
}
