import 'package:material_ui/material_ui.dart';
import 'widgets/hero_section.dart';

/// One screen only: moving photo background, welcome, Book Appointment, and
/// the scrolling gallery along the bottom.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: HeroSection());
  }
}
