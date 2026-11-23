import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../../core/config/salon_assets.dart';
import '../../../core/config/salon_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/salon_image.dart';
import '../../../services/install/install_service.dart' as install;

/// True when this visitor could install the app right now (ignoring "Not now").
bool _installPossible() => install.shouldOfferInstall(
      isStandalone: install.isStandalone,
      isMobile: install.isMobile,
      now: DateTime.now(),
    );

/// Small pill on the landing page, shown only where installing is possible.
class InstallButton extends StatelessWidget {
  const InstallButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: install.installChanges,
      builder: (context, _, _) {
        if (!_installPossible()) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: AppColors.cream.withValues(alpha: .9),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => showInstallSheet(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_for_offline_outlined,
                      size: 18, color: AppColors.charcoal),
                  SizedBox(width: 6),
                  Text('Install app',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Invisible helper: a moment after the landing page opens on a phone, it
/// offers the install sheet (once a week at most).
class InstallAutoPrompt extends StatefulWidget {
  const InstallAutoPrompt({super.key});

  @override
  State<InstallAutoPrompt> createState() => _InstallAutoPromptState();
}

class _InstallAutoPromptState extends State<InstallAutoPrompt> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    install.startInstallWatcher();
    install.installChanges.addListener(_schedule);
    _schedule();
  }

  int _waits = 0;

  void _schedule() {
    _timer?.cancel();
    // Wait a moment so the page is visible first and Chrome has had time to
    // say whether it can install.
    _timer = Timer(const Duration(milliseconds: 2500), _maybeShow);
  }

  void _maybeShow() {
    if (_shown || !mounted) return;
    // Chrome on Android can take a few seconds to say "this can be installed".
    // Give it up to ~6 more seconds before falling back to the manual version.
    if (install.isAndroid && !install.canPrompt && _waits < 3) {
      _waits++;
      _timer = Timer(const Duration(seconds: 2), _maybeShow);
      return;
    }
    final offer = install.shouldOfferInstall(
      isStandalone: install.isStandalone,
      isMobile: install.isMobile,
      now: DateTime.now(),
      dismissedAt: install.readInstallDismissed(),
    );
    if (!offer) return;
    _shown = true;
    showInstallSheet(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    install.installChanges.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<void> showInstallSheet(BuildContext context) async {
  var installed = false;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.cream,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _InstallSheet(onInstalled: () => installed = true),
  );
  // Closing without installing = "Not now": do not nag for a week.
  if (!installed) install.writeInstallDismissed(DateTime.now());
}

class _InstallSheet extends StatelessWidget {
  final VoidCallback onInstalled;
  const _InstallSheet({required this.onInstalled});

  // Rebuilds by itself if Chrome's "can install" message arrives while the
  // sheet is open, switching the manual steps to the Install button.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: install.installChanges,
        builder: (context, _, _) => _body(context),
      );

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Real iPhones never offer the one-tap box, so they always get the steps.
    final canOneTap = install.canPrompt && !install.isIos;
    final onIphone = install.isIos;

    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: AppColors.softPink,
              child: Text('$n',
                  style: const TextStyle(fontSize: 12, color: AppColors.charcoal)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ]),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.softPink, width: 3),
              ),
              clipBehavior: Clip.antiAlias,
              child: const SalonImage(SalonAssets.logo, fit: BoxFit.contain),
            ),
            const SizedBox(height: 14),
            Text('Add ${SalonConfig.name} to your phone',
                textAlign: TextAlign.center, style: t.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'It gets its own icon on your home screen and opens like an '
                'app. No store download.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.brown, height: 1.4)),
            const SizedBox(height: 16),
            if (canOneTap)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Install'),
                  onPressed: () async {
                    final ok = await install.promptInstall();
                    if (ok) onInstalled();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              )
            else if (onIphone) ...[
              // iPhone / iPad: Apple only allows installing from the Share menu.
              Align(
                alignment: Alignment.centerLeft,
                child: Text('On iPhone:', style: t.titleMedium),
              ),
              const SizedBox(height: 4),
              step(1, 'Tap the Share button (the square with an arrow) in Safari.'),
              step(2, 'Scroll down and tap "Add to Home Screen".'),
              step(3, 'Tap "Add". The logo icon appears on your home screen.'),
              const SizedBox(height: 6),
              const Text(
                  'Seeing this inside WhatsApp or Instagram? Tap ⋯ and choose '
                  '"Open in Safari" first.',
                  style: TextStyle(fontSize: 12, color: AppColors.brown)),
            ] else ...[
              // Android where this browser cannot show its own install box
              // (a link opened inside another app, Samsung Internet, etc.).
              // Chrome can, so send them there with one tap.
              if (install.isAndroid) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open in Chrome to install'),
                    onPressed: install.openInChrome,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                    'In Chrome you will see an Install button. If you do not, '
                    'tap the ⋮ menu (top right), then "Install app" or "Add to '
                    'Home screen".',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.brown)),
              ] else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('To install:', style: t.titleMedium),
                ),
                const SizedBox(height: 4),
                step(1, 'Open this page in Chrome, Edge or Safari.'),
                step(2, 'Open the browser menu.'),
                step(3, 'Tap "Install app" or "Add to Home screen".'),
              ],
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(canOneTap ? 'Not now' : 'Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
