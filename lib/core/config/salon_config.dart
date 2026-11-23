/// Single place for salon details. Replace the placeholder values with the
/// real ones; every screen reads from here.
class SalonConfig {
  static const name = 'Salon De Lionne';
  static const tagline =
      'An exclusive salon in the east end of Toronto, specializing in '
      'lived-in colour, extensions, and expertly crafted haircuts.';
  static const phone = '(647) 986-5466'; // text only
  static const whatsappNumber = '16479865466'; // digits only, with country code
  /// Added to 10-digit client phone numbers when opening WhatsApp (Canada = 1).
  static const defaultCountryCode = '1';

  /// Length used for calendar events (appointments do not store a duration).
  static const appointmentMinutes = 60;

  /// The address of the published booking app (what the QR code opens), e.g.
  /// 'https://your-project.web.app'. Leave empty and the published website
  /// uses its own address automatically.
  ///
  /// For a quick test you can also pass it when starting the app:
  ///   flutter run -d web-server --dart-define=BOOKING_URL=http://192.168.1.20:8080
  static const bookingUrl = String.fromEnvironment('BOOKING_URL',
      defaultValue: 'https://salon-de-lionne.web.app');

  /// Google Sheets sync is built but switched off for now. Set to true to show
  /// the "Google Sheets" card on the Reports screen (see docs/google_sheets.md).
  static const showGoogleSheets = false;

  static const website ='https://www.salondelionne.ca';
  static const websiteLabel = 'salondelionne.ca';
  static const instagramUrl = 'https://www.instagram.com/salondelionne/';
  static const instagramHandle = '@salondelionne';

  static const email = 'Info.salondelionne@gmail.com';
  static const address = '1345 Morningside Avenue';
  static const about =
      'We provide a seamless hair experience specializing in premium '
      'extensions, vibrant hair colouring, and expert styling. Our passion is '
      'enhancing your natural beauty with precision and care.';
  // PLACEHOLDER: replace with the salon's real opening hours before launch.
  // (Shown to clients by the Version 2 assistant, so it must be accurate.)
  static const hours = <String, String>{
    'Mon – Fri': '9:00 AM – 6:00 PM',
    'Saturday': '9:00 AM – 5:00 PM',
    'Sunday': 'Closed',
  };
}
