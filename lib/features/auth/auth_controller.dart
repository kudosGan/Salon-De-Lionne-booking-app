import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'auth_service.dart';

/// Who is logged in right now. The router listens to this to protect pages.
class AuthController extends ChangeNotifier {
  AuthController({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  AuthService? service; // null if the database could not be opened
  Session? _session;
  Session? get session => _session;

  // Slows down password guessing: after 5 wrong tries in a row the login is
  // locked for 30 seconds, doubling each further miss (up to 5 minutes).
  static const _freeTries = 5;
  int _failures = 0;
  DateTime? _lockedUntil;

  /// How long login is locked for, or null if it is open.
  Duration? get lockRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(_now());
    return left.isNegative || left == Duration.zero ? null : left;
  }

  Future<bool> needsSetup() async =>
      service != null && !(await service!.hasAdmin());

  Future<bool> login(String username, String password) async {
    if (lockRemaining != null) return false;
    final s = await service?.login(username, password);
    if (s == null) {
      _failures++;
      if (_failures >= _freeTries) {
        final seconds = min(300, 30 * (1 << (_failures - _freeTries)));
        _lockedUntil = _now().add(Duration(seconds: seconds));
      }
      return false;
    }
    _failures = 0;
    _lockedUntil = null;
    _session = s;
    notifyListeners();
    return true;
  }

  Future<void> createFirstAdmin(String username, String password) async {
    _session = await service!.createFirstAdmin(username, password);
    notifyListeners();
  }

  void logout() {
    _session = null;
    notifyListeners();
  }
}

final AuthController auth = AuthController();
