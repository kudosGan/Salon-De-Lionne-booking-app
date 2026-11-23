import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

/// Saves/shares a small file. On a phone this opens the share sheet
/// (choose Calendar, WhatsApp, Mail, Drive...). In a browser it downloads it.
Future<void> shareBytesFile(
    {required String fileName,
    required List<int> bytes,
    required String mimeType}) {
  return SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: mimeType)],
    fileNameOverrides: [fileName],
  ));
}

Future<void> shareTextFile(
    {required String fileName,
    required String content,
    String mimeType = 'text/plain'}) {
  return shareBytesFile(
      fileName: fileName, bytes: utf8.encode(content), mimeType: mimeType);
}
