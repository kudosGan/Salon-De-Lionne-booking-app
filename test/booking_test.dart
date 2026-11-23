import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:salon_booking/features/booking/booking_page.dart';

Future<void> _pumpBooking(WidgetTester tester, {String? style}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: BookingPage(initialStyleId: style)));
  await tester.pump();
}

void main() {
  testWidgets('Empty form shows validation errors', (tester) async {
    await _pumpBooking(tester);
    await tester.tap(find.text('Send Booking Request'));
    await tester.pump();

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Please enter a valid phone number'), findsOneWidget);
    expect(find.text('Please choose a service'), findsOneWidget);
    expect(find.text('Please choose a time'), findsOneWidget);
  });

  testWidgets('Booking form shows an inline calendar', (tester) async {
    await _pumpBooking(tester);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });

  testWidgets('Preselected hairstyle from gallery is marked selected',
      (tester) async {
    await _pumpBooking(tester, style: 'balayage');
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('Email is optional but must be valid if given', (tester) async {
    await _pumpBooking(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email (optional)'), 'nope');
    await tester.tap(find.text('Send Booking Request'));
    await tester.pump();
    expect(find.text('Please enter a valid email'), findsOneWidget);
  });
}
