import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

class Session {
  final String userId;
  final String username;
  final String role; // 'admin' or 'employee'
  final String? stylistId;
  const Session(this.userId, this.username, this.role, this.stylistId);

  bool get isAdmin => role == 'admin';
}

/// Creates logins and checks passwords. Passwords are never stored: only a
/// random salt and a slow, repeated SHA-256 hash of salt + password.
class AuthService {
  final Database db;
  AuthService(this.db);

  static const minPasswordLength = 8;
  static const _rounds = 20000;

  static String newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hashPassword(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    for (var i = 0; i < _rounds; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  Future<bool> hasAdmin() async {
    final r = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM users WHERE role = 'admin'");
    return (r.first['n'] as int) > 0;
  }

  /// First-run only: refuses if an admin already exists.
  Future<Session> createFirstAdmin(String username, String password) async {
    if (await hasAdmin()) throw StateError('An admin account already exists.');
    return _createUser(username, password, 'admin', null);
  }

  /// Used by Stage 5 when the admin adds a stylist login.
  Future<Session> createEmployee(
          String username, String password, String stylistId,
          {DatabaseExecutor? on}) =>
      _createUser(username, password, 'employee', stylistId, on: on);

  static void checkPassword(String password) {
    if (password.length < minPasswordLength) {
      throw ArgumentError(
          'Password must be at least $minPasswordLength characters.');
    }
  }

  Future<Session> _createUser(
      String username, String password, String role, String? stylistId,
      {DatabaseExecutor? on}) async {
    final name = username.trim();
    if (name.length < 3) throw ArgumentError('Username is too short.');
    if (password.length < minPasswordLength) {
      throw ArgumentError('Password must be at least $minPasswordLength characters.');
    }
    final salt = newSalt();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await (on ?? db).insert('users', {
      'id': id,
      'username': name,
      'password_hash': hashPassword(password, salt),
      'salt': salt,
      'role': role,
      'stylist_id': stylistId,
      'created_at': DateTime.now().toIso8601String(),
    });
    return Session(id, name, role, stylistId);
  }

  /// Returns null for a wrong username OR password (never says which).
  Future<Session?> login(String username, String password) async {
    final rows = await db.query('users',
        where: 'username = ? AND active = 1',
        whereArgs: [username.trim()],
        limit: 1);
    if (rows.isEmpty) {
      // Do the same amount of work so timing does not reveal valid usernames.
      hashPassword(password, 'x');
      return null;
    }
    final u = rows.first;
    final ok =
        hashPassword(password, u['salt'] as String) == u['password_hash'];
    if (!ok) return null;
    return Session(u['id'] as String, u['username'] as String,
        u['role'] as String, u['stylist_id'] as String?);
  }
}
