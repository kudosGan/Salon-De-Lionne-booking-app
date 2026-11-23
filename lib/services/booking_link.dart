import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/config/salon_config.dart';

/// The web address the QR code opens: the page where clients book.
class BookingLink {
  /// Which address to use:
  ///  1. [configured] (SalonConfig.bookingUrl) if you set one;
  ///  2. otherwise, when the app runs as a published website, its own address;
  ///  3. otherwise the salon website, as a stand-in.
  static String resolve(
      {required String configured, Uri? base, required bool isWeb}) {
    final set = configured.trim();
    if (set.isNotEmpty) return set;
    if (isWeb && base != null && _isPublic(base)) return base.origin;
    return SalonConfig.website;
  }

  static bool _isPublic(Uri u) =>
      (u.scheme == 'https' || u.scheme == 'http') &&
      u.host.isNotEmpty &&
      u.host != 'localhost' &&
      u.host != '127.0.0.1' &&
      !u.host.startsWith('192.168.') &&
      !u.host.startsWith('10.');

  static String current() => resolve(
      configured: SalonConfig.bookingUrl, base: Uri.base, isWeb: kIsWeb);

  /// True when the QR points at the real booking app (not the stand-in).
  static bool get isLive => current() != SalonConfig.website;

  /// The message sent with the QR code.
  static String shareMessage(String url) =>
      'Book your appointment at ${SalonConfig.name}: $url';
}
