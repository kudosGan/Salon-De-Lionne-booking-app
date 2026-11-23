import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/booking_repository.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import 'widgets/hairstyle_picker.dart';
import 'widgets/reference_photos_field.dart';

/// Client booking form. No account needed.
class BookingPage extends StatefulWidget {
  final String? initialStyleId;
  const BookingPage({super.key, this.initialStyleId});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();

  late DateTime _date = _today();
  List<Stylist> _stylists = Catalog.stylists;
  int? _slot;
  Set<int>? _available; // null while loading
  bool _slotError = false;
  Stylist? _stylist; // null = Any Available Stylist
  String? _service;
  Hairstyle? _hairstyle;
  List<ReferencePhoto> _photos = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hairstyle = Catalog.hairstyleById(widget.initialStyleId);
    bookingRepository.stylists().then((list) {
      if (mounted) setState(() => _stylists = list);
    });
    _loadSlots();
  }

  /// Only times the chosen stylist (or any stylist) is really free are shown.
  Future<void> _loadSlots() async {
    final date = _date;
    final stylistId = _stylist?.id;
    setState(() => _available = null);
    final slots =
        await bookingRepository.availableSlots(date, stylistId: stylistId);
    // Ignore the answer if the client already picked something else.
    if (!mounted || date != _date || stylistId != _stylist?.id) return;
    setState(() {
      _available = slots;
      if (_slot != null && !slots.contains(_slot)) _slot = null;
    });
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onDateChanged(DateTime picked) {
    setState(() {
      _date = picked;
      // A time chosen earlier may now be in the past (if "today").
      if (_slot != null && _isPast(_slot!)) _slot = null;
    });
    _loadSlots();
  }

  bool _isPast(int slot) {
    final d = _date;
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    return isToday && slot <= now.hour * 60 + now.minute;
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _slotError = _slot == null);
    if (!valid || _slot == null) return;

    setState(() => _saving = true);
    try {
      final request = await bookingRepository.submit(BookingRequest(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        clientName: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        date: _date,
        slotMinutes: _slot!,
        stylist: _stylist,
        serviceName: _service!,
        hairstyle: _hairstyle,
        notes: _notes.text.trim(),
        photos: _photos,
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      context.go('/book/received', extra: request);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sorry, we could not save your request. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book an Appointment'),
        backgroundColor: AppColors.cream,
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Tell us what you have in mind',
                    style: t.headlineSmall),
                const SizedBox(height: 6),
                const Text(
                    'No account needed. Send your request and the salon will '
                    'confirm it with you.'),
                const SizedBox(height: 20),
                _Block(
                  title: 'Your details',
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full name *'),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Phone number *'),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        return digits.length < 7
                            ? 'Please enter a valid phone number'
                            : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Email (optional)'),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return null;
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                            ? null
                            : 'Please enter a valid email';
                      },
                    ),
                  ],
                ),
                _Block(
                  title: 'Service & stylist',
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _service,
                      decoration: const InputDecoration(labelText: 'Hair service *'),
                      items: [
                        for (final s in Catalog.services)
                          DropdownMenuItem(value: s.name, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _service = v),
                      validator: (v) => v == null ? 'Please choose a service' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _stylist?.id ?? 'any',
                      decoration:
                          const InputDecoration(labelText: 'Preferred stylist'),
                      items: [
                        const DropdownMenuItem(
                            value: 'any', child: Text('Any Available Stylist')),
                        for (final s in _stylists)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) {
                        setState(() => _stylist =
                            _stylists.where((s) => s.id == v).firstOrNull);
                        _loadSlots();
                      },
                    ),
                  ],
                ),
                _Block(
                  title: 'Date & time',
                  children: [
                    CalendarDatePicker(
                      initialDate: _date,
                      firstDate: _today(),
                      lastDate: _today().add(const Duration(days: 120)),
                      onDateChanged: _onDateChanged,
                    ),
                    const SizedBox(height: 8),
                    Text('Preferred time on ${formatDate(_date)} *',
                        style: t.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (_available == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else if (_available!.where((m) => !_isPast(m)).isEmpty)
                      const Text(
                          'No times are available on this day. Please try '
                          'another date or stylist.',
                          style: TextStyle(color: AppColors.brown))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in Catalog.slots)
                            if (_available!.contains(m) && !_isPast(m))
                              ChoiceChip(
                                label: Text(formatSlot(m)),
                                selected: _slot == m,
                                onSelected: (_) => setState(() {
                                  _slot = m;
                                  _slotError = false;
                                }),
                                selectedColor: AppColors.softPink,
                              ),
                        ],
                      ),
                    if (_slotError)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Please choose a time',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12)),
                      ),
                  ],
                ),
                _Block(
                  title: 'Choose your style',
                  subtitle: 'Tap a hairstyle you like, or skip if unsure.',
                  children: [
                    HairstylePicker(
                      selected: _hairstyle,
                      onChanged: (h) => setState(() => _hairstyle = h),
                    ),
                  ],
                ),
                _Block(
                  title: 'Reference photos',
                  subtitle: 'Upload photos of the look you want (up to 5).',
                  children: [
                    ReferencePhotosField(
                      photos: _photos,
                      onChanged: (p) => setState(() => _photos = p),
                    ),
                  ],
                ),
                _Block(
                  title: 'Additional notes',
                  children: [
                    TextFormField(
                      controller: _notes,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          hintText: 'Hair length, allergies, anything we should know…'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send Booking Request'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _Block({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: AppColors.brown)),
              ],
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
