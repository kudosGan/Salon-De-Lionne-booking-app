import 'package:material_ui/material_ui.dart';
import 'models.dart';

class SalonService {
  final String name;
  final String description;
  final IconData icon;
  const SalonService(this.name, this.description, this.icon);
}

/// Temporary built-in lists. Stage 3 moves services, hairstyles and stylists
/// into the database so the admin can edit them inside the app.
class Catalog {
  static const services = <SalonService>[
    // Taken from the services listed on salondelionne.ca
    SalonService(
        'Hairstyling',
        "Women's haircuts, rejuvenating wash and style, and nourishing hair treatments.",
        Icons.content_cut),
    SalonService(
        'Hair Colouring',
        'Root touch-ups to dimensional balayage, colour corrections, highlights and toner refresh.',
        Icons.palette_outlined),
    SalonService(
        'Extensions',
        'Beaded wefts, tape-ins, VLights and fusion extensions.',
        Icons.auto_awesome),
    SalonService(
        'Training',
        'Personalized 1:1 training with Amanda, tailored to how you like to learn.',
        Icons.school_outlined),
  ];

  /// Photos come from salondelionne.ca. Add more by dropping an image in
  /// assets/images/hairstyles/ and adding a line here.
  static const hairstyles = <Hairstyle>[
    Hairstyle('balayage', 'Balayage', 'assets/images/hairstyles/balayage.jpg'),
    Hairstyle('highlights', 'Lived-in Highlights',
        'assets/images/hairstyles/highlights.jpg'),
    Hairstyle('layered', 'Layered Cut & Curtain Bangs',
        'assets/images/hairstyles/layered_cut.jpg'),
  ];

  /// Placeholders until employees are managed in Stage 5.
  static const stylists = <Stylist>[
    Stylist('s1', 'Stylist 1'),
    Stylist('s2', 'Stylist 2'),
    Stylist('s3', 'Stylist 3'),
  ];

  /// Every possible start time (6:00 AM to 9:30 PM, every 30 min). Which of
  /// these a client can actually pick depends on each stylist's working
  /// hours, days off and existing bookings (see Availability).
  static final slots = [for (var m = 6 * 60; m < 22 * 60; m += 30) m];

  static Hairstyle? hairstyleById(String? id) {
    for (final h in hairstyles) {
      if (h.id == id) return h;
    }
    return null;
  }
}
