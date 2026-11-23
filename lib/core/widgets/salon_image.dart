import 'package:material_ui/material_ui.dart';
import '../theme/app_colors.dart';

/// Shows one of YOUR asset images. If the file has not been added yet, shows a
/// soft branded placeholder instead of crashing. Never loads stock images.
class SalonImage extends StatelessWidget {
  final String asset;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final String? label;
  final IconData placeholderIcon;

  const SalonImage(
    this.asset, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.label,
    this.placeholderIcon = Icons.content_cut,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      errorBuilder: (context, error, stack) => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.blush, AppColors.beige],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(placeholderIcon, color: AppColors.brown.withValues(alpha: .5)),
            if (label != null) ...[
              const SizedBox(height: 6),
              Text(label!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.brown, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
