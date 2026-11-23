import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/config/salon_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/models.dart';
import '../../services/contact_launcher.dart';

/// Shown after the client submits. Status is Pending Confirmation.
class BookingReceivedPage extends StatelessWidget {
  final BookingRequest request;
  const BookingReceivedPage({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 110,
                  child: Text(k,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.brown))),
              Expanded(child: Text(v)),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                const Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.blush,
                    child: Icon(Icons.check_rounded,
                        size: 44, color: AppColors.brown),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Request received!',
                    textAlign: TextAlign.center, style: t.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  'Thank you, ${request.clientName.split(' ').first}. Your '
                  'booking request is waiting for approval from '
                  '${SalonConfig.name}. We will confirm it with you shortly.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text(request.status.label),
                            backgroundColor: AppColors.softPink,
                            side: BorderSide.none,
                          ),
                        ),
                        row('Date', formatDate(request.date)),
                        row('Time', formatSlot(request.slotMinutes)),
                        row('Service', request.serviceName),
                        if (request.hairstyle != null)
                          row('Style', request.hairstyle!.name),
                        row('Stylist',
                            request.stylist?.name ?? 'Any Available Stylist'),
                        if (request.photos.isNotEmpty)
                          row('Photos', '${request.photos.length} uploaded'),
                        if (request.notes.isNotEmpty) row('Notes', request.notes),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to Home'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ContactLauncher.whatsapp(
                      'Hello! I just sent a booking request for '
                      '${formatDate(request.date)} at '
                      '${formatSlot(request.slotMinutes)}.'),
                  icon: const Icon(Icons.chat),
                  label: const Text('Message us on WhatsApp'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
