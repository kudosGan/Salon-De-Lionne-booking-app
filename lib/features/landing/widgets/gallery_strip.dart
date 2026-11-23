import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/config/salon_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/salon_image.dart';
import '../../../data/catalog.dart';

/// The strip shows exactly this many photos. Raise it if you add more images
/// to assets/images/gallery/ and want them to appear.
const int maxThumbnails = 5;

/// The hairstyles and salon photos, then any image you drop into
/// assets/images/gallery/ (picked up automatically, up to [maxThumbnails]).
final List<String> _baseImages = [
  for (final h in Catalog.hairstyles) h.asset,
  SalonAssets.aboutPhoto,
  SalonAssets.bottomStrip,
];

Future<List<String>> _loadGalleryImages() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final extra = manifest
      .listAssets()
      .where((a) =>
          a.startsWith('assets/images/gallery/') &&
          RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(a))
      .toList()
    ..sort();
  return [..._baseImages, ...extra].take(maxThumbnails).toList();
}

/// A relaxed row of small thumbnails that drifts slowly. Tap one to see it
/// large; tap anywhere to go back to the small strip.
class GalleryStrip extends StatefulWidget {
  const GalleryStrip({super.key});

  @override
  State<GalleryStrip> createState() => _GalleryStripState();
}

class _GalleryStripState extends State<GalleryStrip>
    with SingleTickerProviderStateMixin {
  static const _thumbWidth = 88.0;
  static const _thumbHeight = 112.0;
  static const _minGap = 28.0; // breathing room between thumbnails
  static const _pixelsPerSecond = 12.0; // slow drift

  List<String> _images = _baseImages.take(maxThumbnails).toList();
  final _scroll = ScrollController();
  late final AnimationController _anim;

  // Distance from the start of one thumbnail to the next. On wide screens it
  // grows so the five photos spread across the width instead of repeating.
  double _extent = _thumbWidth + _minGap;

  double get _loopWidth => _images.length * _extent;

  Duration get _loopDuration =>
      Duration(milliseconds: (_loopWidth / _pixelsPerSecond * 1000).round());

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: _loopDuration)
      ..addListener(_tick)
      ..repeat();
    _loadGalleryImages().then((list) {
      if (!mounted) return;
      setState(() => _images = list);
      _retime();
    }).catchError((_) {});
  }

  void _retime() {
    _anim.duration = _loopDuration;
    if (_anim.isAnimating) _anim.repeat();
  }

  void _tick() {
    // Moving exactly one full loop per cycle makes the restart invisible.
    if (_scroll.hasClients && _scroll.position.hasContentDimensions) {
      _scroll.jumpTo(_anim.value * _loopWidth);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(String asset) async {
    _anim.stop();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: .9),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(ctx).pop(), // click anywhere to close
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox.expand(
              child: SalonImage(asset, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: .85, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
    if (mounted) _anim.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _thumbHeight + 28,
      color: AppColors.charcoal.withValues(alpha: .45),
      // Pause while the mouse is over the strip so thumbnails are easy to hit.
      child: MouseRegion(
        onEnter: (_) => _anim.stop(),
        onExit: (_) {
          if (mounted && !_anim.isAnimating) _anim.repeat();
        },
        child: LayoutBuilder(builder: (context, c) {
          final wanted = c.maxWidth.isFinite && _images.isNotEmpty
              ? c.maxWidth / _images.length
              : 0.0;
          final extent =
              wanted > _thumbWidth + _minGap ? wanted : _thumbWidth + _minGap;
          if ((extent - _extent).abs() > .5) {
            _extent = extent;
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) _retime();
            });
          }
          return ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 14),
            itemBuilder: (context, index) {
              final asset = _images[index % _images.length];
              return SizedBox(
                width: _extent,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _open(asset),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: _thumbWidth,
                        height: _thumbHeight,
                        child: SalonImage(asset),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
