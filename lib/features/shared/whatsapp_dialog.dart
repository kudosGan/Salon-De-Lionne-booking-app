import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../../services/contact_launcher.dart';
import '../../services/message_templates.dart';

/// Shows the ready-made message to the client. The salon taps Send in
/// WhatsApp itself. [onOpened] runs after WhatsApp was opened (used to mark
/// a reminder as sent).
Future<void> showWhatsAppDialog(
  BuildContext context,
  BookingRequest appointment,
  MessageKind kind, {
  Future<void> Function()? onOpened,
}) {
  final text = MessageTemplates.build(kind, appointment);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
          'WhatsApp ${kind.label.toLowerCase()} to ${appointment.clientName}'),
      content: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.blush,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(text, style: const TextStyle(height: 1.4)),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Not now')),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Message copied.')));
            }
          },
          child: const Text('Copy'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp),
          icon: const Icon(Icons.chat),
          label: const Text('Open WhatsApp'),
          onPressed: () async {
            try {
              await ContactLauncher.whatsappTo(appointment.phone, text);
              await onOpened?.call();
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (_) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Could not open WhatsApp. Use Copy instead.')));
              }
            }
          },
        ),
      ],
    ),
  );
}
