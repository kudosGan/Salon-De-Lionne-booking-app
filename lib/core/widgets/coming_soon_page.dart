import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

/// Temporary page for screens built in later stages.
class ComingSoonPage extends StatelessWidget {
  final String title;
  final String stage;
  const ComingSoonPage({super.key, required this.title, required this.stage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$title is built in $stage.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }
}
