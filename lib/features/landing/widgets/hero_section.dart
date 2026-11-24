import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/salon_assets.dart';
import '../../../core/config/salon_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/salon_image.dart';
import '../../../services/contact_launcher.dart';
import 'gallery_strip.dart';
import 'install_prompt.dart';
import 'qr_dialog.dart';

/// The whole landing page: moving photo background, welcome text, the
/// Book Appointment button, and the scrolling gallery strip along the bottom.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        const SalonImage(
          SalonAssets.landingBackground,
          alignment: Alignment(0, -0.4),
          label: 'Landing background image',
        ),
        const InstallAutoPrompt(), // offers "install the app" on phones
        // Dark warm overlay keeps text readable on any photo.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.charcoal.withValues(alpha: .35),
                AppColors.charcoal.withValues(alpha: .75),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      // Logo pinned to the top, text pushed to the bottom, so the
                      // middle of the photo (the face) stays clear.
                      child: IntrinsicHeight(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                width: 96,
                                height: 96,
                                decoration: const BoxDecoration(
                                  color: AppColors.cream,
                                  shape: BoxShape.circle,
                                ),
                                // Drawn on top so the image can't cover the ring.
                                foregroundDecoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.softPink,
                                    width: 3,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: const SalonImage(
                                  SalonAssets.logo,
                                  fit: BoxFit.contain,
                                  label: 'Logo',
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Welcome to',
                                    style: t.titleMedium?.copyWith(
                                      color: AppColors.softPink,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    SalonConfig.name,
                                    textAlign: TextAlign.center,
                                    style: t.displaySmall?.copyWith(
                                      color: AppColors.white,
                                      fontSize: 42,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 640,
                                    ),
                                    child: Text(
                                      SalonConfig.tagline,
                                      textAlign: TextAlign.center,
                                      style: t.bodyLarge?.copyWith(
                                        color: AppColors.cream,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  // Transparent button: just text and a white outline.
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.white,
                                      backgroundColor: Colors.transparent,
                                      side: const BorderSide(
                                        color: AppColors.white,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 36,
                                        vertical: 16,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () => context.go('/book'),
                                    child: const Text('Book Appointment'),
                                  ),
                                  const SizedBox(height: 22),
                                  // Contact info on the next line.
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _ContactLink(
                                        SalonConfig.phone,
                                        ContactLauncher.text,
                                      ),
                                      const _Dot(),
                                      _ContactLink(
                                        SalonConfig.websiteLabel,
                                        ContactLauncher.website,
                                      ),
                                      const _Dot(),
                                      _ContactLink(
                                        SalonConfig.instagramHandle,
                                        ContactLauncher.instagram,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Install / QR / Staff login sit just above the gallery thumbnails.
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const InstallButton(), // only on phones that can install
                    const QrButton(), // small QR icon, opens the big code
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Staff login',
                        style: TextStyle(
                          color: AppColors.cream.withValues(alpha: .8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const GalleryStrip(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ContactLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.cream,
            fontSize: 14,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => const Text(
    '•',
    style: TextStyle(color: AppColors.softPink, fontSize: 14),
  );
}
