import 'package:material_ui/material_ui.dart';
import '../../../data/models.dart';

Color statusColor(AppointmentStatus s) => switch (s) {
      AppointmentStatus.pending => const Color(0xFFC9788A),
      AppointmentStatus.confirmed => const Color(0xFF5B8C5A),
      AppointmentStatus.declined => const Color(0xFFB5544B),
      AppointmentStatus.completed => const Color(0xFF4F6D7A),
      AppointmentStatus.cancelled => const Color(0xFF8A8480),
      AppointmentStatus.rescheduled => const Color(0xFFC08A3E),
    };

class StatusChip extends StatelessWidget {
  final AppointmentStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
