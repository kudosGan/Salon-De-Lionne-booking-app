import 'package:material_ui/material_ui.dart';
import 'core/config/salon_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class SalonApp extends StatelessWidget {
  const SalonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: SalonConfig.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
