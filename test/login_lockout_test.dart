import 'package:flutter_test/flutter_test.dart';
import 'package:salon_booking/data/db/app_database.dart';
import 'package:salon_booking/features/auth/auth_controller.dart';
import 'package:salon_booking/features/auth/auth_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AuthController controller;
  late DateTime now;

  setUp(() async {
    final db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    final service = AuthService(db);
    await service.createFirstAdmin('owner', 'correct-horse');
    now = DateTime(2026, 12, 1, 9);
    controller = AuthController(clock: () => now)..service = service;
  });
  tearDown(() => controller.service!.db.close());

  test('five wrong passwords lock login, even for the right password',
      () async {
    for (var i = 0; i < 5; i++) {
      expect(await controller.login('owner', 'wrong-$i'), isFalse);
    }
    expect(controller.lockRemaining, isNotNull);
    expect(await controller.login('owner', 'correct-horse'), isFalse);
    expect(controller.session, isNull);
  });

  test('login works again after the wait', () async {
    for (var i = 0; i < 5; i++) {
      await controller.login('owner', 'nope');
    }
    now = now.add(const Duration(seconds: 31));
    expect(controller.lockRemaining, isNull);
    expect(await controller.login('owner', 'correct-horse'), isTrue);
    expect(controller.session?.isAdmin, isTrue);
  });

  test('the wait doubles on further misses and a success resets it', () async {
    for (var i = 0; i < 5; i++) {
      await controller.login('owner', 'nope');
    }
    expect(controller.lockRemaining!.inSeconds, 30);
    now = now.add(const Duration(seconds: 31));
    await controller.login('owner', 'nope'); // 6th miss
    expect(controller.lockRemaining!.inSeconds, 60);

    now = now.add(const Duration(seconds: 61));
    expect(await controller.login('owner', 'correct-horse'), isTrue);
    controller.logout();
    await controller.login('owner', 'nope');
    expect(controller.lockRemaining, isNull); // counter was reset
  });

  test('a few typos do not lock anyone out', () async {
    for (var i = 0; i < 4; i++) {
      await controller.login('owner', 'typo');
    }
    expect(controller.lockRemaining, isNull);
    expect(await controller.login('owner', 'correct-horse'), isTrue);
  });
}
