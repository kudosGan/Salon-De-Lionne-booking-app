import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/models.dart';
import 'status_chip.dart';

class AppointmentCard extends StatelessWidget {
  final BookingRequest appointment;
  final VoidCallback onTap;
  const AppointmentCard(
      {super.key, required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blush,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(_mon(a.date.month),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.brown)),
                    Text('${a.date.day}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal)),
                    Text(formatSlot(a.slotMinutes),
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.clientName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                        [a.serviceName, if (a.hairstyle != null) a.hairstyle!.name]
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(a.stylist?.name ?? 'No stylist assigned',
                        style: TextStyle(
                            color: a.stylist == null
                                ? const Color(0xFFB5544B)
                                : AppColors.brown,
                            fontSize: 12)),
                  ],
                ),
              ),
              StatusChip(a.status),
            ],
          ),
        ),
      ),
    );
  }

  static String _mon(int m) => const [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
      ][m - 1];
}
