import 'dart:typed_data';

/// The six appointment statuses used across the whole app.
enum AppointmentStatus {
  pending('Pending Confirmation'),
  confirmed('Confirmed'),
  declined('Declined'),
  completed('Completed'),
  cancelled('Cancelled'),
  rescheduled('Rescheduled');

  final String label;
  const AppointmentStatus(this.label);
}

class Hairstyle {
  final String id;
  final String name;
  final String asset;
  const Hairstyle(this.id, this.name, this.asset);
}

class Stylist {
  final String id;
  final String name;
  const Stylist(this.id, this.name);
}

/// A stylist as managed by the admin (profile, schedule and login).
class StaffMember {
  final String id;
  final String name;
  final Uint8List? photo;
  final String specialties;
  final Set<int> workDays; // 1 = Monday ... 7 = Sunday
  final int startMinutes;
  final int endMinutes;
  final List<DateTime> daysOff;
  final bool active;
  final String? username; // null = no login yet

  const StaffMember({
    required this.id,
    required this.name,
    this.photo,
    this.specialties = '',
    this.workDays = const {1, 2, 3, 4, 5, 6},
    this.startMinutes = 540,
    this.endMinutes = 1080,
    this.daysOff = const [],
    this.active = true,
    this.username,
  });
}

/// One 30-minute slot a stylist has switched off.
class BlockedSlot {
  final String stylistId;
  final DateTime date;
  final int slot;
  const BlockedSlot(this.stylistId, this.date, this.slot);
}

/// A client reference photo. Stage 3 saves the bytes to local storage and
/// keeps only the file path in the database.
class ReferencePhoto {
  final String name;
  final Uint8List bytes;
  const ReferencePhoto(this.name, this.bytes);
}

class BookingRequest {
  final String id;
  final String? clientId; // set once saved in the database
  final String clientName;
  final String phone;
  final String? email;
  final DateTime date; // date only
  final int slotMinutes; // minutes after midnight, e.g. 840 = 2:00 PM
  final Stylist? stylist; // null = Any Available Stylist
  final String serviceName;
  final Hairstyle? hairstyle;
  final String notes;
  final List<ReferencePhoto> photos;
  final AppointmentStatus status;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  const BookingRequest({
    required this.id,
    this.clientId,
    required this.clientName,
    required this.phone,
    this.email,
    required this.date,
    required this.slotMinutes,
    this.stylist,
    required this.serviceName,
    this.hairstyle,
    this.notes = '',
    this.photos = const [],
    this.status = AppointmentStatus.pending,
    required this.createdAt,
    this.confirmedAt,
  });

  BookingRequest copyWith({String? clientId, AppointmentStatus? status}) =>
      BookingRequest(
        id: id,
        clientId: clientId ?? this.clientId,
        clientName: clientName,
        phone: phone,
        email: email,
        date: date,
        slotMinutes: slotMinutes,
        stylist: stylist,
        serviceName: serviceName,
        hairstyle: hairstyle,
        notes: notes,
        photos: photos,
        status: status ?? this.status,
        createdAt: createdAt,
        confirmedAt: confirmedAt,
      );
}
