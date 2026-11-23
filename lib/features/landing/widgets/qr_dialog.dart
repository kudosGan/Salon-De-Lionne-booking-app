import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/config/salon_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/booking_link.dart';
import '../../../services/contact_launcher.dart';
import '../../../services/qr_share.dart';

/// Small round QR icon for the landing page. Tap it to open the big QR code.
class QrButton extends StatelessWidget {
  const QrButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Scan to book',
      child: Material(
        color: AppColors.cream.withValues(alpha: .9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showQrDialog(context),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.qr_code_2, size: 24, color: AppColors.charcoal),
          ),
        ),
      ),
    );
  }
}

Future<void> showQrDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (_) => const _QrDialog(),
    );

class _QrDialog extends StatelessWidget {
  const _QrDialog();

  @override
  Widget build(BuildContext context) {
    final url = BookingLink.current();
    final message = BookingLink.shareMessage(url);
    final t = Theme.of(context).textTheme;
    final screen = MediaQuery.sizeOf(context);
    final qrSize = (screen.width * .72).clamp(180.0, 300.0);

    void say(String text) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));

    Future<void> attempt(Future<void> Function() action, String failure) async {
      try {
        await action();
      } catch (_) {
        say(failure);
      }
    }

    return Dialog(
      backgroundColor: AppColors.cream,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: screen.height * .92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Text('Scan to book', style: t.headlineSmall),
              const SizedBox(height: 2),
              Text(SalonConfig.name,
                  style: const TextStyle(color: AppColors.brown)),
              const SizedBox(height: 16),
              // White card with a clear border so any phone camera can read it.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.beige),
                ),
                child: CustomPaint(
                  size: Size(qrSize, qrSize),
                  painter: qrPainter(url),
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.brown)),
              if (!BookingLink.isLive) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.blush,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                      'Preview: this code opens the salon website for now. '
                      'Once the app is published online, it will open the '
                      'booking app automatically.',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        attempt(() => shareQrImage(url), 'Could not share the image.'),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Share / save image'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
                    onPressed: () => attempt(
                        () => ContactLauncher.whatsappShare(message),
                        'Could not open WhatsApp.'),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => attempt(
                        () => ContactLauncher.smsShare(message),
                        'Could not open the messages app.'),
                    icon: const Icon(Icons.sms_outlined, size: 18),
                    label: const Text('Text message'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      say('Link copied.');
                    },
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Copy link'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
