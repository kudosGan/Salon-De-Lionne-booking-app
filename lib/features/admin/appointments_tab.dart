import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import 'appointment_detail.dart';
import 'widgets/appointment_card.dart';

class AppointmentsTab extends StatefulWidget {
  final AdminRepository repo;
  final AppointmentStatus? initialFilter;

  /// Set when a stylist (not the admin) is looking: shows only their
  /// appointments and limits what they can do.
  final String? forStylist;
  const AppointmentsTab(
      {super.key, required this.repo, this.initialFilter, this.forStylist});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  late AppointmentStatus? _filter = widget.initialFilter;
  List<BookingRequest>? _items;

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(covariant AppointmentsTab old) {
    super.didUpdateWidget(old);
    if (old.initialFilter != widget.initialFilter) {
      _filter = widget.initialFilter;
      _load();
    }
  }

  @override
  void dispose() {
    widget.repo.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await widget.repo
        .appointments(status: _filter, forStylist: widget.forStylist);
    if (mounted) setState(() => _items = list);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('All'),
                selected: _filter == null,
                selectedColor: AppColors.softPink,
                onSelected: (_) => setState(() {
                  _filter = null;
                  _load();
                }),
              ),
            ),
            for (final s in AppointmentStatus.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.label.replaceAll(' Confirmation', '')),
                  selected: _filter == s,
                  selectedColor: AppColors.softPink,
                  onSelected: (_) => setState(() {
                    _filter = s;
                    _load();
                  }),
                ),
              ),
          ]),
        ),
        Expanded(
          child: items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? const Center(
                      child: Text('No appointments here yet.',
                          style: TextStyle(color: AppColors.brown)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: items.length,
                        itemBuilder: (context, i) => AppointmentCard(
                          appointment: items[i],
                          onTap: () => showAppointmentDetail(
                              context, widget.repo, items[i],
                              asStylistId: widget.forStylist),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
