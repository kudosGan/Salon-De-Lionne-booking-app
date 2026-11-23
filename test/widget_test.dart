import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:salon_booking/app.dart';
import 'package:salon_booking/core/config/salon_config.dart';
import 'package:salon_booking/core/widgets/salon_image.dart';
import 'package:salon_booking/features/landing/widgets/gallery_strip.dart';

void main() {
  void phoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('Landing page shows salon name and booking button',
      (tester) async {
    phoneScreen(tester);
    await tester.pumpWidget(const SalonApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.text(SalonConfig.name), findsWidgets);
    expect(find.text('Book Appointment'), findsOneWidget);
  });

  testWidgets('Landing page has no services/about/contact sections',
      (tester) async {
    phoneScreen(tester);
    await tester.pumpWidget(const SalonApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Our Services'), findsNothing);
    expect(find.text('Hairstyle Gallery'), findsNothing);
    expect(find.text('About Us'), findsNothing);
    expect(find.text('Chat on WhatsApp'), findsNothing);
  });

  testWidgets('Tapping a gallery thumbnail opens it large; tap closes it',
      (tester) async {
    phoneScreen(tester);
    await tester.pumpWidget(const SalonApp());
    await tester.pump(const Duration(seconds: 1));

    final before = find.byType(SalonImage).evaluate().length;
    final thumb = find.descendant(
        of: find.byType(GalleryStrip), matching: find.byType(ClipRRect));
    await tester.tap(thumb.first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalonImage).evaluate().length, before + 1);

    // Click anywhere to close.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SalonImage).evaluate().length, before);
  });
}
