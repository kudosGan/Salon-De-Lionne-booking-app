// VERSION 2 GROUNDWORK (no AI is built yet).
//
// This file defines how a future chat assistant plugs into the app without
// changing the existing screens:
//
//  * [SalonKnowledge]  - the ONLY facts the assistant may use.
//  * [SalonAssistant]  - the interface an AI implementation will fulfil.
//  * [BookingGateway]  - how the assistant sends a booking request. It always
//                        goes in as "Pending Confirmation" and passes the same
//                        availability rules as the website form. Only if the
//                        admin switches on the setting [autoConfirmSetting]
//                        could a later version confirm on its own (it is OFF
//                        by default and nothing here confirms anything).
import '../../core/config/salon_config.dart';
import '../../data/booking_repository.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';

/// Facts the assistant is allowed to state. Anything missing here must be
/// answered with "I don't have that - I'll ask the salon", never guessed.
class SalonKnowledge {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String website;
  final Map<String, String> hours;
  final List<String> services;
  final List<String> hairstyles;
  final List<String> stylists;

  const SalonKnowledge({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.website,
    required this.hours,
    required this.services,
    required this.hairstyles,
    required this.stylists,
  });

  /// Built from the same settings and catalog the rest of the app uses.
  /// Prices are deliberately absent: none are stored yet, so the assistant
  /// must not quote any.
  static Future<SalonKnowledge> load(BookingRepository repo) async => SalonKnowledge(
        name: SalonConfig.name,
        address: SalonConfig.address,
        phone: SalonConfig.phone,
        email: SalonConfig.email,
        website: SalonConfig.website,
        hours: SalonConfig.hours,
        services: [for (final s in Catalog.services) '${s.name}: ${s.description}'],
        hairstyles: [for (final h in Catalog.hairstyles) h.name],
        stylists: [for (final s in await repo.stylists()) s.name],
      );

  /// Plain-text facts to give a language model as its only source of truth.
  String toPromptText() => [
        'You are the friendly assistant for $name. Use ONLY these facts.',
        'If something is not listed (for example prices), say you do not have '
            'it and offer to pass the question to the salon. Never invent '
            'prices, services, hours, availability or policies.',
        'Address: $address',
        'Phone (text only): $phone',
        'Email: $email',
        'Website: $website',
        'Opening hours: ${hours.entries.map((e) => '${e.key} ${e.value}').join('; ')}',
        'Services: ${services.join(' | ')}',
        'Hairstyles shown: ${hairstyles.join(', ')}',
        'Stylists: ${stylists.join(', ')}',
      ].join('\n');
}

class ChatTurn {
  final bool fromClient;
  final String text;
  const ChatTurn(this.fromClient, this.text);
}

/// What the assistant has collected so far from the client.
class BookingDraft {
  final String clientName;
  final String phone;
  final String serviceName;
  final Hairstyle? hairstyle;
  final DateTime date;
  final int slotMinutes;
  final Stylist? stylist; // null = any available stylist
  final String notes;

  const BookingDraft({
    required this.clientName,
    required this.phone,
    required this.serviceName,
    required this.date,
    required this.slotMinutes,
    this.hairstyle,
    this.stylist,
    this.notes = '',
  });
}

/// A later version implements this with a language model.
abstract class SalonAssistant {
  Future<String> reply(List<ChatTurn> history, SalonKnowledge knowledge);
}

class BookingRejected implements Exception {
  final String reason;
  const BookingRejected(this.reason);
  @override
  String toString() => reason;
}

/// The one door through which an assistant may create bookings.
class BookingGateway {
  /// Admin setting (off unless explicitly enabled; nothing reads it yet).
  static const autoConfirmSetting = 'ai_auto_confirm';

  final BookingRepository repo;
  BookingGateway(this.repo);

  /// Saves the draft as a Pending request. Refuses times that are not free.
  Future<BookingRequest> submit(BookingDraft d) async {
    final free =
        await repo.availableSlots(d.date, stylistId: d.stylist?.id);
    if (!free.contains(d.slotMinutes)) {
      throw const BookingRejected(
          'That time is not available. Please offer another time.');
    }
    return repo.submit(BookingRequest(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      clientName: d.clientName.trim(),
      phone: d.phone.trim(),
      date: d.date,
      slotMinutes: d.slotMinutes,
      stylist: d.stylist,
      serviceName: d.serviceName,
      hairstyle: d.hairstyle,
      notes: d.notes,
      status: AppointmentStatus.pending, // never anything else from here
      createdAt: DateTime.now(),
    ));
  }
}
