import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:salon_booking/app.dart';
import 'package:salon_booking/core/config/salon_config.dart';
import 'package:salon_booking/services/booking_link.dart';
import 'package:salon_booking/services/qr_share.dart';
import 'package:zxing2/qrcode.dart';

/// Reads a QR code out of PNG bytes, like a phone camera would.
String? scan(List<int> png) {
  final image = img.decodePng(Uint8List.fromList(png))!;
  final source = RGBLuminanceSource(
      image.width,
      image.height,
      image
          .convert(numChannels: 4)
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asInt32List());
  final bitmap = BinaryBitmap(HybridBinarizer(source));
  return QRCodeReader().decode(bitmap).text;
}

void main() {
  group('booking link', () {
    final site = Uri.parse('https://salon-de-lionne.web.app/#/book');

    test('a configured address always wins', () {
      expect(
          BookingLink.resolve(
              configured: ' https://book.example.com ', base: site, isWeb: true),
          'https://book.example.com');
    });

    test('a published website uses its own address', () {
      expect(BookingLink.resolve(configured: '', base: site, isWeb: true),
          'https://salon-de-lionne.web.app');
    });

    test('local testing and the phone app fall back to the salon website', () {
      for (final local in ['http://localhost:5000/', 'http://127.0.0.1:8080/', 'http://192.168.1.20:8080/']) {
        expect(
            BookingLink.resolve(configured: '', base: Uri.parse(local), isWeb: true),
            SalonConfig.website);
      }
      expect(BookingLink.resolve(configured: '', base: site, isWeb: false),
          SalonConfig.website);
    });

    test('share message names the salon and carries the link', () {
      final m = BookingLink.shareMessage('https://x.web.app');
      expect(m, contains(SalonConfig.name));
      expect(m, endsWith('https://x.web.app'));
    });
  });

  group('QR image', () {
    for (final url in [
      'https://salon-de-lionne.web.app',
      'https://www.salondelionne.ca',
      'https://salon-de-lionne-booking.firebaseapp.com/#/book?style=balayage',
    ]) {
      testWidgets('a scanner reads back $url', (tester) async {
        final png = (await tester.runAsync(() => renderQrPng(url)))!;
        // It is a real PNG...
        expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
        // ...and decoding it gives exactly the link.
        expect(scan(png), url);
      });
    }
  });

  group('landing page', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('small QR icon opens the big code with share options',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(const SalonApp());
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Scan to book'), findsNothing); // closed at first
      await tester.tap(find.byIcon(Icons.qr_code_2));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Scan to book'), findsOneWidget);
      expect(find.text('Share / save image'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Text message'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      // The code opens the published booking app, not the salon website.
      expect(find.text(SalonConfig.bookingUrl), findsOneWidget);
      expect(SalonConfig.bookingUrl, 'https://salon-de-lionne.web.app');
      expect(find.textContaining('Preview'), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Scan to book'), findsNothing);
    });
  });
}
