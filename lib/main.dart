import 'package:material_ui/material_ui.dart';
import 'app.dart';
import 'data/admin_repository.dart';
import 'data/booking_repository.dart';
import 'data/db/app_database.dart';
import 'data/sqlite_booking_repository.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDatabase.open();
    bookingRepository = SqliteBookingRepository(db);
    adminRepository = AdminRepository(db);
    auth.service = AuthService(db);
  } catch (e) {
    // The app still runs, but bookings will NOT be saved. Fix the cause shown.
    debugPrint('DATABASE FAILED TO OPEN, using temporary memory storage: $e');
  }
  runApp(const SalonApp());
}
