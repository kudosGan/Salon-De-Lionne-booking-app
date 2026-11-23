import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/config/salon_config.dart';
import '../core/theme/app_colors.dart';
import 'booking_link.dart';

/// Black-on-white QR painter. Medium error correction keeps it scannable even
/// if it is printed small or slightly smudged.
QrPainter qrPainter(String data) => QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
      dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
      gapless: true,
    );

/// A ready-to-post PNG: white card, QR code with a clear border, and a short
/// caption underneath.
Future<Uint8List> renderQrPng(String data,
    {double qrSize = 900, double margin = 90}) async {
  final captionHeight = 230.0;
  final width = qrSize + margin * 2;
  final height = qrSize + margin * 2 + captionHeight;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

  canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFFFFFFF));
  canvas.save();
  canvas.translate(margin, margin);
  qrPainter(data).paint(canvas, Size(qrSize, qrSize));
  canvas.restore();

  void caption(String text, double top, double size, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: AppColors.charcoal, fontSize: size, fontWeight: weight)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width - margin);
    tp.paint(canvas, Offset((width - tp.width) / 2, top));
  }

  final top = qrSize + margin * 2 - 30;
  caption('Scan to book an appointment', top, 54, FontWeight.w700);
  caption(SalonConfig.name, top + 80, 46, FontWeight.w400);

  final image = await recorder.endRecording().toImage(width.round(), height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Opens the phone's share sheet with the QR image and a message, so it can
/// be sent by text message, WhatsApp, email, saved to Photos, etc.
/// In a browser it downloads the image instead.
Future<void> shareQrImage(String url) async {
  final png = await renderQrPng(url);
  await SharePlus.instance.share(ShareParams(
    text: BookingLink.shareMessage(url),
    files: [XFile.fromData(png, mimeType: 'image/png')],
    fileNameOverrides: ['book-salon-de-lionne.png'],
  ));
}
