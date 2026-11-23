import '../core/config/salon_config.dart';
import '../core/utils/format.dart';
import '../data/models.dart';
import 'calendar_links.dart';

enum MessageKind {
  confirmation('Confirmation'),
  reschedule('Reschedule notice'),
  cancellation('Cancellation notice'),
  reminder('Reminder'),
  declined('Decline notice');

  final String label;
  const MessageKind(this.label);
}

/// The WhatsApp texts the salon sends. The salon taps Send in WhatsApp
/// itself (no WhatsApp Business API needed in Version 1).
class MessageTemplates {
  static String build(MessageKind kind, BookingRequest a) {
    final first = a.clientName.trim().split(' ').first;
    final details = [
      if (a.stylist != null) 'Stylist: ${a.stylist!.name}',
      'Date: ${formatDate(a.date)}',
      'Time: ${formatSlot(a.slotMinutes)}',
      'Service: ${a.serviceName}',
      if (a.hairstyle != null) 'Style: ${a.hairstyle!.name}',
      'Address: ${SalonConfig.address}',
    ].join('\n');
    final calendar = 'Add it to your calendar so you get a reminder:\n'
        '${CalendarLinks.googleUrl(a)}';

    switch (kind) {
      case MessageKind.confirmation:
        return 'Hello $first! Thank you for choosing ${SalonConfig.name}. '
            "We're at your service. ✨\n\n"
            'We are happy to confirm your appointment:\n\n'
            '$details\n\n'
            '$calendar\n\n'
            'We look forward to seeing you!';
      case MessageKind.reschedule:
        return 'Hello $first! Your appointment at ${SalonConfig.name} has '
            'been rescheduled. Here are your new details:\n\n'
            '$details\n\n'
            '$calendar\n\n'
            'Please reply if this time does not work for you.';
      case MessageKind.cancellation:
        return 'Hello $first, your appointment at ${SalonConfig.name} on '
            '${formatDate(a.date)} at ${formatSlot(a.slotMinutes)} has been '
            'cancelled.\n\n'
            'We would love to see you soon. Reply here or visit our website '
            'to book a new time.';
      case MessageKind.declined:
        return 'Hello $first, thank you for your request to ${SalonConfig.name}. '
            'Unfortunately we are not able to book ${formatDate(a.date)} at '
            '${formatSlot(a.slotMinutes)}.\n\n'
            'We would love to find another time that works for you. Reply '
            'here or visit our website to choose a different date.';
      case MessageKind.reminder:
        return 'Hello $first! This is a friendly reminder of your '
            'appointment at ${SalonConfig.name}:\n\n'
            '$details\n\n'
            'See you soon!';
    }
  }
}
