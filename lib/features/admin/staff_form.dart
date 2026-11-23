import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import 'staff_tab.dart';

/// Add or edit a stylist: profile, schedule, days off and login.
class StaffFormPage extends StatefulWidget {
  final AdminRepository repo;
  final StaffMember? member; // null = adding a new stylist
  const StaffFormPage({super.key, required this.repo, this.member});

  @override
  State<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends State<StaffFormPage> {
  late final bool _isNew = widget.member == null;
  late final String _id = widget.member?.id ??
      's${DateTime.now().microsecondsSinceEpoch}';

  late final _name = TextEditingController(text: widget.member?.name ?? '');
  late final _specialties =
      TextEditingController(text: widget.member?.specialties ?? '');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late Uint8List? _photo = widget.member?.photo;
  late final Set<int> _days = {...(widget.member?.workDays ?? {1, 2, 3, 4, 5, 6})};
  late int _start = widget.member?.startMinutes ?? 540;
  late int _end = widget.member?.endMinutes ?? 1080;
  late List<DateTime> _daysOff = [...(widget.member?.daysOff ?? [])];
  late bool _active = widget.member?.active ?? true;
  bool _saving = false;
  bool _hidePw = true;

  /// Time choices: 6:00 AM to 10:00 PM, every 30 minutes.
  static final _times = [for (var m = 6 * 60; m <= 22 * 60; m += 30) m];

  @override
  void dispose() {
    for (final c in [_name, _specialties, _username, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickPhoto() async {
    try {
      final f = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) _toast('Could not open your photos.');
    }
  }

  Future<void> _addDayOff() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (d == null) return;
    final day = DateTime(d.year, d.month, d.day);
    if (!_daysOff.contains(day)) {
      setState(() => _daysOff = [..._daysOff, day]..sort());
    }
  }

  Future<void> _save() async {
    if (_password.text != _confirm.text) {
      _toast('The two passwords do not match.');
      return;
    }
    setState(() => _saving = true);
    final m = StaffMember(
      id: _id,
      name: _name.text,
      photo: _photo,
      specialties: _specialties.text,
      workDays: _days,
      startMinutes: _start,
      endMinutes: _end,
      daysOff: _daysOff,
      active: _active,
      username: widget.member?.username,
    );
    String? error;
    try {
      error = await widget.repo.saveStaff(m,
          isNew: _isNew, username: _username.text, password: _password.text);
    } catch (_) {
      error = 'Could not save. Please try again.';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      _toast(error);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.member!.name}?'),
        content: const Text(
            'This removes the stylist and their login. It only works if they '
            'have no appointments. Otherwise use the Active switch to '
            'deactivate them instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    final error = await widget.repo.deleteStaff(_id);
    if (!mounted) return;
    if (error != null) {
      _toast(error);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasLogin = widget.member?.username != null;

    Widget block(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleLarge),
                  const SizedBox(height: 14),
                  ...children,
                ],
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: Text(_isNew ? 'Add stylist' : 'Edit stylist'),
        actions: [
          if (!_isNew)
            IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              block('Profile', [
                Center(
                  child: Stack(
                    children: [
                      StaffAvatar(photo: _photo, name: _name.text, radius: 48),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.brown,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            color: AppColors.white,
                            icon: const Icon(Icons.camera_alt),
                            onPressed: _pickPhoto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _specialties,
                  decoration: const InputDecoration(
                      labelText: 'Specialties',
                      hintText: 'e.g. Balayage, extensions, cuts'),
                ),
                if (!_isNew)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text(
                        'Inactive stylists are hidden from booking and cannot log in.'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
              ]),
              block('Working days & hours', [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(dayNames[d - 1]),
                      selected: _days.contains(d),
                      selectedColor: AppColors.softPink,
                      onSelected: (on) => setState(
                          () => on ? _days.add(d) : _days.remove(d)),
                    ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _start,
                      decoration: const InputDecoration(labelText: 'Starts'),
                      items: [
                        for (final m in _times)
                          DropdownMenuItem(value: m, child: Text(formatSlot(m))),
                      ],
                      onChanged: (v) => setState(() => _start = v ?? _start),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _end,
                      decoration: const InputDecoration(labelText: 'Ends'),
                      items: [
                        for (final m in _times)
                          DropdownMenuItem(value: m, child: Text(formatSlot(m))),
                      ],
                      onChanged: (v) => setState(() => _end = v ?? _end),
                    ),
                  ),
                ]),
              ]),
              block('Days off', [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final d in _daysOff)
                    InputChip(
                      label: Text(formatDate(d)),
                      onDeleted: () => setState(() => _daysOff.remove(d)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Add day off'),
                    onPressed: _addDayOff,
                  ),
                ]),
              ]),
              block('Login', [
                if (hasLogin) ...[
                  Text('Username: ${widget.member!.username}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                ] else ...[
                  const Text(
                      'Optional. Give this stylist a username and password so '
                      'they can log in and see their own appointments.',
                      style: TextStyle(color: AppColors.brown)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _password,
                  obscureText: _hidePw,
                  decoration: InputDecoration(
                    labelText: 'Change password',
                    helperText: hasLogin
                        ? 'Leave both password boxes empty to keep the current password.'
                        : '8 or more characters.',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      icon: Icon(_hidePw
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hidePw = !_hidePw),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirm,
                  obscureText: _hidePw,
                  decoration:
                      const InputDecoration(labelText: 'Confirm password'),
                ),
              ]),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isNew ? 'Add stylist' : 'Save changes'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
