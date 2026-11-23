import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salon_booking/data/admin_repository.dart';
import 'package:salon_booking/data/catalog.dart';
import 'package:salon_booking/data/db/app_database.dart';
import 'package:salon_booking/data/models.dart';
import 'package:salon_booking/data/report.dart';
import 'package:salon_booking/services/report_export.dart';
import 'package:salon_booking/services/sheets_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

BookingRequest _a(String id, String client, DateTime date,
        {AppointmentStatus s = AppointmentStatus.confirmed,
        String? stylist = 'Amy',
        String service = 'Hairstyling',
        Hairstyle? style,
        String name = 'Client',
        String notes = '',
        DateTime? confirmedAt}) =>
    BookingRequest(
      id: id,
      clientId: client,
      clientName: name,
      phone: '416-555-0100',
      date: date,
      slotMinutes: 840,
      stylist: stylist == null ? null : Stylist(stylist.toLowerCase(), stylist),
      serviceName: service,
      hairstyle: style,
      notes: notes,
      status: s,
      createdAt: DateTime(2026, 11, 1),
      confirmedAt: confirmedAt,
    );

void main() {
  sqfliteFfiInit();

  group('MonthlyReport', () {
    final nov = DateTime(2026, 11, 10);
    final dec = DateTime(2026, 12, 10);
    final all = [
      // November: c1 is new, c2 is new.
      _a('1', 'c1', nov, s: AppointmentStatus.completed),
      _a('2', 'c2', nov, service: 'Extensions', stylist: 'Bo'),
      // December
      _a('3', 'c1', dec, s: AppointmentStatus.completed), // returning
      _a('4', 'c3', dec, style: Catalog.hairstyles.first), // new
      _a('5', 'c3', dec, s: AppointmentStatus.cancelled),
      _a('6', 'c4', dec, s: AppointmentStatus.pending, stylist: null),
      _a('7', 'c5', dec, s: AppointmentStatus.declined),
    ];
    final r = MonthlyReport.build(all, 2026, 12);

    test('counts every request dated in the month, by status', () {
      expect(r.total, 5);
      expect(r.count(AppointmentStatus.completed), 1);
      expect(r.count(AppointmentStatus.confirmed), 1);
      expect(r.count(AppointmentStatus.cancelled), 1);
      expect(r.count(AppointmentStatus.pending), 1);
      expect(r.count(AppointmentStatus.declined), 1);
      expect(r.booked, 3);
    });

    test('per stylist / service / hairstyle use booked appointments only', () {
      expect({for (final x in r.perStylist) x.label: x.count},
          {'Amy': 2, 'Unassigned': 1});
      expect(r.perService.single.label, 'Hairstyling');
      expect(r.perService.single.count, 3);
      expect({for (final x in r.perHairstyle) x.label: x.count},
          {Catalog.hairstyles.first.name: 1, 'No style chosen': 2});
    });

    test('new and returning clients', () {
      // Booked in December: c1 (first seen in Nov), c3 and c4 (first in Dec).
      expect(r.newClients, 2);
      expect(r.returningClients, 1);
      final n = MonthlyReport.build(all, 2026, 11);
      expect(n.newClients, 2);
      expect(n.returningClients, 0);
    });

    test('an empty month is all zeros', () {
      final e = MonthlyReport.build(all, 2027, 5);
      expect(e.total, 0);
      expect(e.perStylist, isEmpty);
      expect(e.newClients + e.returningClients, 0);
    });
  });

  group('exports', () {
    final appt = _a('1', 'c1', DateTime(2026, 12, 10),
        name: 'Sarah, "Sas" Lee',
        notes: 'line one\nline two',
        style: Catalog.hairstyles.first,
        confirmedAt: DateTime(2026, 11, 20));

    test('CSV has the requested columns, quotes properly, starts with BOM', () {
      final csv = ReportExport.csv([appt]);
      expect(csv.startsWith('﻿'), isTrue);
      final lines = csv.substring(1).split('\r\n');
      expect(
          lines.first,
          'Client name,Client phone,Appointment date,Appointment time,'
          'Hairstyle / service,Stylist,Status,Booking date,'
          'Confirmation date,Notes');
      expect(csv, contains('"Sarah, ""Sas"" Lee"'));
      expect(csv, contains('"line one\nline two"'));
      expect(csv, contains('2026-12-10,2:00 PM'));
      expect(csv, contains('Hairstyling - ${Catalog.hairstyles.first.name}'));
      expect(csv, contains('2026-11-01')); // booking date
      expect(csv, contains('2026-11-20')); // confirmation date
    });

    test('spreadsheet formulas typed by clients are neutralised', () {
      final evil = _a('2', 'c2', DateTime(2026, 12, 11),
          name: '=HYPERLINK("http://x","click")', notes: '+1+1');
      final csv = ReportExport.csv([evil]);
      expect(csv, contains("\"'=HYPERLINK("));
      expect(csv, contains("'+1+1"));
      expect(safeCell('normal'), 'normal');
      expect(safeCell('@x'), "'@x");
    });

    test('Excel file has Appointments and Summary sheets', () {
      final report = MonthlyReport.build([appt], 2026, 12);
      final bytes = ReportExport.xlsx(report);
      final book = Excel.decodeBytes(bytes);
      expect(book.tables.keys, containsAll(['Appointments', 'Summary']));
      final rows = book.tables['Appointments']!.rows;
      expect(rows, hasLength(2)); // header + 1
      expect(rows[0][0]!.value.toString(), 'Client name');
      expect(rows[1][0]!.value.toString(), 'Sarah, "Sas" Lee');
      final summary = book.tables['Summary']!.rows
          .map((r) => r.map((c) => c?.value.toString()).toList())
          .toList();
      expect(summary.any((r) => r.first == 'Total appointments' && r[1] == '1'),
          isTrue);
    });
  });

  group('Google Sheets sync', () {
    final appt = _a('abc', 'c1', DateTime(2026, 12, 10));
    const url = 'https://script.google.com/macros/s/AKfycbx123/exec';

    test('payload groups by month and carries the id and secret', () {
      final data = jsonDecode(SheetsSync.body('s3cret', [appt]));
      expect(data['secret'], 's3cret');
      expect(data['headers'], exportHeaders);
      final row = data['rows'].single;
      expect(row['id'], 'abc');
      expect(row['month'], '2026-12');
      expect(row['values'], hasLength(exportHeaders.length));
    });

    test('rejects links that are not Apps Script web apps', () async {
      final res = await SheetsSync.push(
          url: 'https://evil.example.com/exec', secret: 'x', appointments: [appt]);
      expect(res.ok, isFalse);
      expect(res.message, contains('Apps Script'));
      expect(SheetsSync.looksLikeScriptUrl(url), isTrue);
      expect(SheetsSync.looksLikeScriptUrl('http://script.google.com/a/exec'), isFalse);
    });

    test('success reply is understood', () async {
      final client = MockClient((req) async {
        expect(req.headers['Content-Type'], startsWith('text/plain'));
        return http.Response(jsonEncode({'ok': true, 'added': 1, 'updated': 2}), 200);
      });
      final res = await SheetsSync.push(
          url: url, secret: 'x', appointments: [appt], client: client);
      expect(res.ok, isTrue);
      expect(res.added, 1);
      expect(res.updated, 2);
    });

    test('follows the redirect Apps Script answers with', () async {
      final client = MockClient((req) async {
        if (req.method == 'POST') {
          return http.Response('', 302,
              headers: {'location': 'https://script.googleusercontent.com/echo?x=1'});
        }
        return http.Response(jsonEncode({'ok': true, 'added': 3, 'updated': 0}), 200);
      });
      final res = await SheetsSync.push(
          url: url, secret: 'x', appointments: [appt], client: client);
      expect(res.ok, isTrue);
      expect(res.added, 3);
    });

    test('wrong secret and bad replies show a clear message', () async {
      final wrong = MockClient((_) async =>
          http.Response(jsonEncode({'ok': false, 'error': 'Wrong secret word.'}), 200));
      var res = await SheetsSync.push(
          url: url, secret: 'x', appointments: [appt], client: wrong);
      expect(res.ok, isFalse);
      expect(res.message, 'Wrong secret word.');

      final html = MockClient((_) async => http.Response('<html>login</html>', 200));
      res = await SheetsSync.push(
          url: url, secret: 'x', appointments: [appt], client: html);
      expect(res.ok, isFalse);
      expect(res.message, contains('expected answer'));

      final blocked = MockClient((_) async => throw http.ClientException('CORS'));
      res = await SheetsSync.push(
          url: url, secret: 'x', appointments: [appt], client: blocked);
      expect(res.ok, isTrue);
      expect(res.confirmed, isFalse);
    });
  });

  group('database', () {
    late AdminRepository repo;
    setUp(() async {
      final db = await AppDatabase.open(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      repo = AdminRepository(db);
    });
    tearDown(() => repo.db.close());

    test('report uses saved appointments and the confirmation date', () async {
      await repo.bookings.submit(BookingRequest(
        id: 'x',
        clientName: 'Sarah',
        phone: '4165550100',
        date: DateTime(2026, 12, 10),
        slotMinutes: 840,
        stylist: Catalog.stylists.first,
        serviceName: 'Hairstyling',
        createdAt: DateTime(2026, 11, 22),
      ));
      await repo.confirm('x');
      final r = await repo.report(2026, 12);
      expect(r.total, 1);
      expect(r.newClients, 1);
      expect(r.appointments.single.confirmedAt, isNotNull);
      expect(ReportExport.csv(r.appointments), contains(
          DateTime.now().toIso8601String().substring(0, 10)));
    });

    test('settings are saved and overwritten', () async {
      expect(await repo.getSetting('sheets_url'), isNull);
      await repo.setSetting('sheets_url', 'a');
      await repo.setSetting('sheets_url', 'b');
      expect(await repo.getSetting('sheets_url'), 'b');
    });
  });
}
