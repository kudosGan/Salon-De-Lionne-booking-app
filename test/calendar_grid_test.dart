import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:salon_booking/data/models.dart';
import 'package:salon_booking/features/calendar/month_grid.dart';
import 'package:salon_booking/features/calendar/week_grid.dart';

BookingRequest _a(String name, DateTime date, int slot,
        {AppointmentStatus s = AppointmentStatus.confirmed, String id = 'x'}) =>
    BookingRequest(
      id: id,
      clientName: name,
      phone: '1',
      date: date,
      slotMinutes: slot,
      stylist: const Stylist('s1', 'Amy'),
      serviceName: 'Hairstyling',
      status: s,
      createdAt: DateTime(2026, 11, 1),
    );

Future<void> _pump(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: size.width, height: size.height, child: child))));
}

void main() {
  final monday = DateTime(2026, 12, 7);
  final thursday = DateTime(2026, 12, 10);

  List<BookingRequest> on(DateTime d) => [
        if (d == thursday) ...[
          _a('Sarah Lee', d, 840, id: '1'),
          _a('Maya Chen', d, 840, id: '2'), // same time, other client
          _a('Priya Rao', d, 600, s: AppointmentStatus.pending, id: '3'),
        ],
        if (d == monday) _a('Zoe Park', d, 540, id: '4'),
      ];

  group('week grid', () {
    for (final size in [
      const Size(320, 480), // very small phone
      const Size(390, 700), // normal phone
      const Size(1100, 800), // desktop
    ]) {
      testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} without scrolling or overflow',
          (tester) async {
        List<BookingRequest>? tapped;
        DateTime? day;
        await _pump(
            tester,
            WeekGrid(
              weekStart: monday,
              from: 540,
              to: 1080,
              appointmentsOn: on,
              onTapAppointments: (l) => tapped = l,
              onTapDay: (d) => day = d,
            ),
            size);

        expect(tester.takeException(), isNull); // no overflow errors
        expect(find.byType(Scrollable), findsNothing); // nothing scrolls
        // The two 2 PM clients share ONE block, labelled with "+1".
        expect(find.textContaining('+1'), findsOneWidget);

        // Tapping the shared block returns both appointments.
        await tester.tap(find.textContaining('+1'));
        expect(tapped!.map((a) => a.id), ['1', '2']);

        // Tapping the heading of Thursday jumps to that day.
        await tester.tap(find.text('10'));
        expect(day, thursday);
      });
    }

    testWidgets('a single appointment shows the first name', (tester) async {
      await _pump(
          tester,
          WeekGrid(
            weekStart: monday,
            from: 540,
            to: 1080,
            appointmentsOn: on,
            onTapAppointments: (_) {},
            onTapDay: (_) {},
          ),
          const Size(1100, 800));
      expect(find.textContaining('Zoe'), findsOneWidget);
      expect(find.textContaining('Priya'), findsOneWidget);
    });
  });

  group('month grid', () {
    for (final size in [const Size(320, 480), const Size(390, 700), const Size(1100, 800)]) {
      testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} without scrolling or overflow',
          (tester) async {
        DateTime? tapped;
        await _pump(
            tester,
            MonthGrid(
                month: DateTime(2026, 12),
                appointmentsOn: on,
                onTapDay: (d) => tapped = d),
            size);
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        // All 31 days are on screen at once.
        for (final d in [1, 15, 31]) {
          expect(find.text('$d'), findsWidgets);
        }
        await tester.tap(find.text('10').first);
        expect(tapped, thursday);
      });
    }

    testWidgets('roomy cells list appointments, small cells use dots',
        (tester) async {
      await _pump(
          tester,
          MonthGrid(month: DateTime(2026, 12), appointmentsOn: on, onTapDay: (_) {}),
          const Size(1100, 800));
      expect(find.textContaining('Sarah'), findsOneWidget);
      expect(find.textContaining('2p'), findsWidgets);

      await _pump(
          tester,
          MonthGrid(month: DateTime(2026, 12), appointmentsOn: on, onTapDay: (_) {}),
          const Size(320, 480));
      await tester.pump();
      expect(find.textContaining('Sarah'), findsNothing); // dots only
    });
  });
}
