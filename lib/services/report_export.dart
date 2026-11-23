import 'package:excel/excel.dart';
import '../core/utils/format.dart';
import '../data/models.dart';
import '../data/report.dart';

/// The columns in every export, in the order requested for the monthly
/// records.
const exportHeaders = [
  'Client name',
  'Client phone',
  'Appointment date',
  'Appointment time',
  'Hairstyle / service',
  'Stylist',
  'Status',
  'Booking date',
  'Confirmation date',
  'Notes',
];

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "Hair Colouring - Balayage" (or just the service when no style was chosen).
String serviceAndStyle(BookingRequest a) => a.hairstyle == null
    ? a.serviceName
    : '${a.serviceName} - ${a.hairstyle!.name}';

/// One appointment as plain text cells (same order as [exportHeaders]).
List<String> exportRow(BookingRequest a) => [
      a.clientName,
      a.phone,
      _isoDate(a.date),
      formatSlot(a.slotMinutes),
      serviceAndStyle(a),
      a.stylist?.name ?? 'Unassigned',
      a.status.label,
      _isoDate(a.createdAt),
      a.confirmedAt == null ? '' : _isoDate(a.confirmedAt!),
      a.notes,
    ];

/// Clients type their own names and notes, so a cell like =HYPERLINK(...)
/// could run as a formula when the file is opened. A leading apostrophe makes
/// spreadsheets treat it as plain text.
String safeCell(String s) {
  if (s.isEmpty) return s;
  return '=+-@\t\r'.contains(s[0]) ? "'$s" : s;
}

class ReportExport {
  static String _csvCell(String s) {
    final v = safeCell(s);
    return v.contains(RegExp(r'[",\r\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  }

  /// Excel-friendly CSV (UTF-8 with a byte-order mark so accents display).
  static String csv(List<BookingRequest> appointments) {
    final lines = [
      exportHeaders.map(_csvCell).join(','),
      for (final a in appointments) exportRow(a).map(_csvCell).join(','),
    ];
    return '﻿${lines.join('\r\n')}\r\n';
  }

  /// A .xlsx with an "Appointments" sheet and a "Summary" sheet.
  static List<int> xlsx(MonthlyReport r) {
    final book = Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();

    final sheet = book['Appointments'];
    sheet.appendRow([for (final h in exportHeaders) TextCellValue(h)]);
    for (final a in r.appointments) {
      sheet.appendRow([for (final c in exportRow(a)) TextCellValue(c)]);
    }

    final sum = book['Summary'];
    void line(String label, [Object? value]) => sum.appendRow([
          TextCellValue(label),
          if (value is int) IntCellValue(value),
          if (value is String) TextCellValue(value),
        ]);
    void section(String title, List<CountRow> rows) {
      sum.appendRow([TextCellValue('')]);
      line(title);
      for (final x in rows) {
        line(x.label, x.count);
      }
    }

    line('Monthly report', '${monthName(r.month)} ${r.year}');
    sum.appendRow([TextCellValue('')]);
    line('Total appointments', r.total);
    for (final s in AppointmentStatus.values) {
      line(s.label, r.count(s));
    }
    sum.appendRow([TextCellValue('')]);
    line('New clients', r.newClients);
    line('Returning clients', r.returningClients);
    section('Appointments per stylist', r.perStylist);
    section('Appointments per service', r.perService);
    section('Appointments per hairstyle', r.perHairstyle);

    if (defaultSheet != null &&
        defaultSheet != 'Appointments' &&
        defaultSheet != 'Summary') {
      book.delete(defaultSheet);
    }
    return book.encode() ?? <int>[];
  }

  static String fileBase(int year, int month) =>
      'salon-report-$year-${month.toString().padLeft(2, '0')}';
}
