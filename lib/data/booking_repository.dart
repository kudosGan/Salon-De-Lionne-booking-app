import 'catalog.dart';
import 'models.dart';

/// Where bookings are stored. Screens only talk to this interface.
/// Real app: SqliteBookingRepository. Tests: InMemoryBookingRepository.
abstract class BookingRepository {
  Future<BookingRequest> submit(BookingRequest request);

  /// Photos are skipped by default because they are large; load them for one
  /// appointment with [photosOf].
  Future<List<BookingRequest>> all({bool withPhotos = false});
  Future<List<ReferencePhoto>> photosOf(String appointmentId);

  /// Active stylists a client can choose from.
  Future<List<Stylist>> stylists();

  /// Start times still free on [date]: inside the stylist's working hours,
  /// not on a day off, and not already taken. [stylistId] null = any stylist.
  Future<Set<int>> availableSlots(DateTime date,
      {String? stylistId, String? exceptAppointmentId});
}

class InMemoryBookingRepository implements BookingRepository {
  final _items = <BookingRequest>[];

  @override
  Future<BookingRequest> submit(BookingRequest request) async {
    _items.add(request);
    return request;
  }

  @override
  Future<List<BookingRequest>> all({bool withPhotos = false}) async =>
      List.unmodifiable(_items);

  @override
  Future<List<ReferencePhoto>> photosOf(String appointmentId) async =>
      _items.where((r) => r.id == appointmentId).firstOrNull?.photos ?? [];

  @override
  Future<List<Stylist>> stylists() async => Catalog.stylists;

  @override
  Future<Set<int>> availableSlots(DateTime date,
          {String? stylistId, String? exceptAppointmentId}) async =>
      {for (final m in Catalog.slots) if (m >= 540 && m < 1080) m};
}

/// main() swaps this for the SQLite version once the database is open.
BookingRepository bookingRepository = InMemoryBookingRepository();
