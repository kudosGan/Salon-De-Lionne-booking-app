import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../features/admin/admin_home.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_page.dart';
import '../../features/booking/booking_page.dart';
import '../../features/booking/booking_received_page.dart';
import '../../features/landing/landing_page.dart';
import '../../features/employee/employee_home.dart';

/// All screens are registered here. Later stages replace the placeholders.
/// The redirect below is what keeps clients out of admin pages and
/// employees out of admin functions.
final appRouter = GoRouter(
  refreshListenable: auth,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final s = auth.session;

    if (loc.startsWith('/admin') && !(s?.isAdmin ?? false)) return '/login';
    if (loc.startsWith('/employee') && s == null) return '/login';
    if (loc.startsWith('/employee') && s!.isAdmin) return '/admin';
    if (loc == '/login' && s != null) return s.isAdmin ? '/admin' : '/employee';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (c, s) => const LandingPage()),
    GoRoute(
      path: '/book',
      builder: (c, s) =>
          BookingPage(initialStyleId: s.uri.queryParameters['style']),
    ),
    GoRoute(
      path: '/book/received',
      redirect: (c, s) => s.extra is BookingRequest ? null : '/book',
      builder: (c, s) => BookingReceivedPage(request: s.extra as BookingRequest),
    ),
    GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
    GoRoute(path: '/admin', builder: (c, s) => const AdminHome()),
    GoRoute(path: '/employee', builder: (c, s) => const EmployeeHome()),
  ],
);
