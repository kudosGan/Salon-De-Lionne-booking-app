import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models.dart';
import 'report_export.dart';

class SheetsResult {
  final bool ok;
  final bool confirmed; // false = sent, but the reply could not be read
  final int added;
  final int updated;
  final String message;
  const SheetsResult(this.ok, this.message,
      {this.confirmed = true, this.added = 0, this.updated = 0});
}

/// Sends appointment rows to a Google Sheet through a small Google Apps
/// Script web app that the salon owner creates once (see docs/google_sheets.md).
///
/// The app database stays the main database; the sheet is a reporting copy.
/// Rows are matched by appointment id, so syncing twice updates instead of
/// duplicating. Each row lands on a tab named for its month ("2026-12").
class SheetsSync {
  /// The row payload for one appointment.
  static Map<String, Object> rowFor(BookingRequest a) {
    final d = a.date;
    final month =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
    return {
      'id': a.id,
      'month': month,
      'values': [for (final c in exportRow(a)) safeCell(c)],
    };
  }

  static String body(String secret, List<BookingRequest> appointments) =>
      jsonEncode({
        'secret': secret,
        'headers': exportHeaders,
        'rows': [for (final a in appointments) rowFor(a)],
      });

  static bool looksLikeScriptUrl(String url) {
    final u = Uri.tryParse(url.trim());
    return u != null &&
        u.scheme == 'https' &&
        u.host == 'script.google.com' &&
        u.path.endsWith('/exec');
  }

  static Future<SheetsResult> push(
      {required String url,
      required String secret,
      required List<BookingRequest> appointments,
      http.Client? client}) async {
    if (!looksLikeScriptUrl(url)) {
      return const SheetsResult(false,
          'That does not look like a Google Apps Script web app link. It should start with https://script.google.com/ and end with /exec');
    }
    if (secret.trim().isEmpty) {
      return const SheetsResult(false, 'Enter the secret word first.');
    }
    final c = client ?? http.Client();
    try {
      // "text/plain" keeps this a simple request, so browsers do not block it.
      var res = await c
          .post(Uri.parse(url.trim()),
              headers: {'Content-Type': 'text/plain;charset=utf-8'},
              body: body(secret.trim(), appointments))
          .timeout(const Duration(seconds: 45));
      // Apps Script answers with a redirect that holds the actual reply.
      if (const [301, 302, 303, 307, 308].contains(res.statusCode)) {
        final loc = res.headers['location'];
        if (loc != null) res = await c.get(Uri.parse(loc));
      }
      if (res.statusCode != 200) {
        return SheetsResult(
            false, 'Google answered with an error (${res.statusCode}).');
      }
      final json = jsonDecode(res.body);
      if (json is Map && json['ok'] == true) {
        return SheetsResult(true, 'Done.',
            added: (json['added'] as num?)?.toInt() ?? 0,
            updated: (json['updated'] as num?)?.toInt() ?? 0);
      }
      return SheetsResult(false,
          (json is Map ? json['error'] : null)?.toString() ?? 'The sheet refused the data.');
    } on FormatException {
      return const SheetsResult(false,
          'Google did not return the expected answer. Check the link, and that the web app is shared with "Anyone".');
    } on http.ClientException {
      // In a browser, Google's reply can be blocked even though the data
      // arrived. Check the sheet.
      return const SheetsResult(true,
          'Sent. This browser could not read Google\'s reply, so please check the sheet.',
          confirmed: false);
    } catch (e) {
      return SheetsResult(false, 'Could not reach Google: $e');
    } finally {
      if (client == null) c.close();
    }
  }
}
