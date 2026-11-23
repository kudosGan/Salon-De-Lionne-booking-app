import 'package:sqflite/sqflite.dart';
import '../core/utils/format.dart';
import 'models.dart';

class AppNotification {
  final int id;
  final String title;
  final String body;
  final String? appointmentId;
  final DateTime createdAt;
  final bool read;
  const AppNotification(
      this.id, this.title, this.body, this.appointmentId, this.createdAt, this.read);
}

/// Writes in-app notifications. Works inside a transaction too.
class Notifier {
  /// One line describing an appointment, used in notification bodies.
  static String summary(BookingRequest a) =>
      '${a.clientName} · ${a.serviceName} · ${formatDate(a.date)} at '
      '${formatSlot(a.slotMinutes)}';

  static Future<void> toAdmin(DatabaseExecutor db, String title, String body,
          {String? appointmentId, DateTime? now}) =>
      _add(db, 'admin', null, title, body, appointmentId, now);

  static Future<void> toStylist(
          DatabaseExecutor db, String stylistId, String title, String body,
          {String? appointmentId, DateTime? now}) =>
      _add(db, 'stylist', stylistId, title, body, appointmentId, now);

  static Future<void> _add(DatabaseExecutor db, String audience,
      String? stylistId, String title, String body, String? appointmentId,
      DateTime? now) {
    return db.insert('notifications', {
      'audience': audience,
      'stylist_id': stylistId,
      'title': title,
      'body': body,
      'appointment_id': appointmentId,
      'created_at': (now ?? DateTime.now()).toIso8601String(),
    });
  }
}
