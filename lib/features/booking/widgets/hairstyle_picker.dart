import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/salon_image.dart';
import '../../../data/catalog.dart';
import '../../../data/models.dart';

/// Browse the salon's hairstyles and tap one to select it (tap again to clear).
class HairstylePicker extends StatelessWidget {
  final Hairstyle? selected;
  final ValueChanged<Hairstyle?> onChanged;

  const HairstylePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final h in Catalog.hairstyles)
          _Tile(
            style: h,
            isSelected: selected?.id == h.id,
            onTap: () => onChanged(selected?.id == h.id ? null : h),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final Hairstyle style;
  final bool isSelected;
  final VoidCallback onTap;
  const _Tile(
      {required this.style, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 104,
        height: 136,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.brown : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SalonImage(style.asset, label: style.name),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  color: AppColors.charcoal.withValues(alpha: .65),
                  child: Text(style.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              if (isSelected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.brown,
                    child: Icon(Icons.check, size: 14, color: AppColors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
