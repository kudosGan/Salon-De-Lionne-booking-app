import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:salon_booking/app.dart';
import 'package:salon_booking/services/install/install_policy.dart';

void main() {
  final now = DateTime(2026, 12, 1, 12);

  bool offer({
    bool standalone = false,
    bool mobile = true,
    DateTime? dismissed,
  }) =>
      shouldOfferInstall(
        isStandalone: standalone,
        isMobile: mobile,
        now: now,
        dismissedAt: dismissed,
      );

  group('when to offer the install', () {
    test('every phone visitor gets the offer', () {
      expect(offer(), isTrue);
    });

    test('never inside the installed app or on a computer', () {
      expect(offer(standalone: true), isFalse);
      expect(offer(mobile: false), isFalse);
    });

    test('"Not now" is respected for a week', () {
      expect(offer(dismissed: now.subtract(const Duration(days: 2))), isFalse);
      expect(offer(dismissed: now.subtract(const Duration(days: 8))), isTrue);
    });
  });

  testWidgets('outside a browser the landing page shows no install offer',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SalonApp());
    await tester.pump(const Duration(seconds: 4)); // past the 2.5 s delay
    expect(find.text('Install app'), findsNothing);
    expect(find.textContaining('Add Salon De Lionne'), findsNothing);
  });
}
