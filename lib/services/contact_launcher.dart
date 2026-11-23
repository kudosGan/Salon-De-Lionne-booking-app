import 'package:url_launcher/url_launcher.dart';
import '../core/config/salon_config.dart';

/// Opens phone, WhatsApp, email and maps. Stage 7 builds on this for the
/// appointment confirmation messages.
class ContactLauncher {
  static Future<void> whatsapp([String message = '']) {
    final uri = Uri.https('wa.me', '/${SalonConfig.whatsappNumber}',
        message.isEmpty ? null : {'text': message});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// "(647) 986-5466" -> "16479865466" (WhatsApp wants country code + digits).
  static String whatsappDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10
        ? '${SalonConfig.defaultCountryCode}$digits'
        : digits;
  }

  /// Opens WhatsApp to a client with the message already typed. The salon just
  /// taps Send.
  static Future<void> whatsappTo(String clientPhone, String message) {
    final uri = Uri.https(
        'wa.me', '/${whatsappDigits(clientPhone)}', {'text': message});
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens WhatsApp's "choose a contact" screen with [message] ready to send.
  static Future<void> whatsappShare(String message) => launchUrl(
      Uri.https('wa.me', '/', {'text': message}),
      mode: LaunchMode.externalApplication);

  /// Opens the messages app with [message] typed, ready to pick a recipient.
  static Future<void> smsShare(String message) =>
      launchUrl(Uri(scheme: 'sms', queryParameters: {'body': message}));

  static Future<void> website() => launchUrl(Uri.parse(SalonConfig.website),
      mode: LaunchMode.externalApplication);

  static Future<void> instagram() => launchUrl(
      Uri.parse(SalonConfig.instagramUrl),
      mode: LaunchMode.externalApplication);

  static Future<void> text() =>
      launchUrl(Uri(scheme: 'sms', path: SalonConfig.phone));

  static Future<void> email() =>
      launchUrl(Uri(scheme: 'mailto', path: SalonConfig.email));

  static Future<void> map() => launchUrl(
        Uri.https('www.google.com', '/maps/search/',
            {'api': '1', 'query': SalonConfig.address}),
        mode: LaunchMode.externalApplication,
      );
}
