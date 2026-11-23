import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/config/salon_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import '../../data/report.dart';
import '../../services/file_share.dart';
import '../../services/report_export.dart';
import '../../services/sheets_sync.dart';
import 'widgets/status_chip.dart';

/// Monthly report: numbers, simple bar charts, a table, CSV/Excel export and
/// the Google Sheets copy.
class ReportsTab extends StatefulWidget {
  final AdminRepository repo;
  const ReportsTab({super.key, required this.repo});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  MonthlyReport? _report;

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final y = _year, m = _month;
    final r = await widget.repo.report(y, m);
    if (mounted && y == _year && m == _month) setState(() => _report = r);
  }

  void _setMonth(int year, int month) {
    // Month arithmetic: month 0 / 13 roll over into the neighbouring year.
    final d = DateTime(year, month);
    setState(() {
      _year = d.year;
      _month = d.month;
      _report = null;
    });
    _load();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _exportCsv(MonthlyReport r) async {
    try {
      await shareTextFile(
        fileName: '${ReportExport.fileBase(r.year, r.month)}.csv',
        content: ReportExport.csv(r.appointments),
        mimeType: 'text/csv',
      );
    } catch (_) {
      if (mounted) _toast('Could not create the CSV file.');
    }
  }

  Future<void> _exportExcel(MonthlyReport r) async {
    try {
      await shareBytesFile(
        fileName: '${ReportExport.fileBase(r.year, r.month)}.xlsx',
        bytes: ReportExport.xlsx(r),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (_) {
      if (mounted) _toast('Could not create the Excel file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = _report;
    final nowYear = DateTime.now().year;
    final years = [for (var y = nowYear - 4; y <= nowYear + 1; y++) y];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ---- month and year selector ----
        Row(children: [
          IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _setMonth(_year, _month - 1)),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _month,
              key: ValueKey('m$_month'),
              decoration: const InputDecoration(labelText: 'Month'),
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(monthName(m))),
              ],
              onChanged: (v) => _setMonth(_year, v ?? _month),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<int>(
              initialValue: _year,
              key: ValueKey('y$_year'),
              decoration: const InputDecoration(labelText: 'Year'),
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (v) => _setMonth(v ?? _year, _month),
            ),
          ),
          IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _setMonth(_year, _month + 1)),
        ]),
        const SizedBox(height: 16),
        if (r == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Text('${monthName(r.month)} ${r.year}', style: t.headlineSmall),
          const SizedBox(height: 12),
          _Summary(r),
          const SizedBox(height: 20),
          _BarList(title: 'Appointments per stylist', rows: r.perStylist),
          _BarList(title: 'Appointments per service', rows: r.perService),
          _BarList(title: 'Appointments per hairstyle', rows: r.perHairstyle),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
                'Charts count booked appointments (not declined or cancelled).',
                style: TextStyle(color: AppColors.brown, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          Text('Appointments this month', style: t.titleLarge),
          const SizedBox(height: 8),
          _Table(r),
          const SizedBox(height: 20),
          Text('Export', style: t.titleLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: r.appointments.isEmpty ? null : () => _exportCsv(r),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Export CSV'),
            ),
            OutlinedButton.icon(
              onPressed: r.appointments.isEmpty ? null : () => _exportExcel(r),
              icon: const Icon(Icons.grid_on),
              label: const Text('Export Excel'),
            ),
          ]),
          if (SalonConfig.showGoogleSheets) ...[
            const SizedBox(height: 28),
            SheetsCard(repo: widget.repo, report: r),
          ],
          const SizedBox(height: 30),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final MonthlyReport r;
  const _Summary(this.r);

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, int value) => SizedBox(
          width: 150,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontSize: 28)),
                  Text(label, style: const TextStyle(color: AppColors.brown)),
                ],
              ),
            ),
          ),
        );
    return Wrap(spacing: 10, runSpacing: 10, children: [
      tile('Total appointments', r.total),
      tile('Confirmed', r.count(AppointmentStatus.confirmed)),
      tile('Completed', r.count(AppointmentStatus.completed)),
      tile('Cancelled', r.count(AppointmentStatus.cancelled)),
      tile('Pending requests', r.count(AppointmentStatus.pending)),
      tile('Declined', r.count(AppointmentStatus.declined)),
      tile('Rescheduled', r.count(AppointmentStatus.rescheduled)),
      tile('New clients', r.newClients),
      tile('Returning clients', r.returningClients),
    ]);
  }
}

/// One-series horizontal bars. The count is printed on every row, so the
/// numbers never depend on colour or on hovering.
class _BarList extends StatelessWidget {
  final String title;
  final List<CountRow> rows;
  const _BarList({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final max = rows.isEmpty ? 1 : rows.first.count; // rows are sorted
    final total = rows.fold<int>(0, (s, r) => s + r.count);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text('No appointments this month.',
                  style: TextStyle(color: AppColors.brown)),
            for (final r in rows)
              Tooltip(
                message:
                    '${r.label}: ${r.count} (${(r.count * 100 / total).round()}%)',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(
                      width: 120,
                      child: Text(r.label,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        final w = (c.maxWidth * r.count / max).clamp(4.0, c.maxWidth);
                        return Container(
                          height: 12,
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: AppColors.beige.withValues(alpha: .45),
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4)),
                          ),
                          child: Container(
                            width: w,
                            decoration: const BoxDecoration(
                              color: AppColors.brown,
                              // Rounded data end, flat on the baseline side.
                              borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(4)),
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text('${r.count}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  final MonthlyReport r;
  const _Table(this.r);

  static const _limit = 200;

  @override
  Widget build(BuildContext context) {
    if (r.appointments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No appointments this month.',
              style: TextStyle(color: AppColors.brown)),
        ),
      );
    }
    final shown = r.appointments.take(_limit).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 44,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Time')),
                DataColumn(label: Text('Client')),
                DataColumn(label: Text('Service / style')),
                DataColumn(label: Text('Stylist')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final a in shown)
                  DataRow(cells: [
                    DataCell(Text('${shortMonth(a.date.month)} ${a.date.day}')),
                    DataCell(Text(formatSlot(a.slotMinutes))),
                    DataCell(Text(a.clientName)),
                    DataCell(Text(serviceAndStyle(a))),
                    DataCell(Text(a.stylist?.name ?? 'Unassigned')),
                    DataCell(StatusChip(a.status)),
                  ]),
              ],
            ),
          ),
          if (r.appointments.length > _limit)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  'Showing the first $_limit of ${r.appointments.length}. Export to see all.',
                  style: const TextStyle(color: AppColors.brown, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// Google Sheets connection: link, secret word, test and sync.
class SheetsCard extends StatefulWidget {
  final AdminRepository repo;
  final MonthlyReport report;
  const SheetsCard({super.key, required this.repo, required this.report});

  @override
  State<SheetsCard> createState() => _SheetsCardState();
}

class _SheetsCardState extends State<SheetsCard> {
  static const _urlKey = 'sheets_url';
  static const _secretKey = 'sheets_secret';

  final _url = TextEditingController();
  final _secret = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _result;
  bool _resultOk = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _url.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _url.text = await widget.repo.getSetting(_urlKey) ?? '';
    _secret.text = await widget.repo.getSetting(_secretKey) ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await widget.repo.setSetting(_urlKey, _url.text.trim());
    await widget.repo.setSetting(_secretKey, _secret.text.trim());
    if (mounted) {
      setState(() {
        _result = 'Saved.';
        _resultOk = true;
      });
    }
  }

  Future<void> _sync(List<BookingRequest> rows, String what) async {
    setState(() {
      _busy = true;
      _result = null;
    });
    await _save();
    final res = await SheetsSync.push(
        url: _url.text, secret: _secret.text, appointments: rows);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _resultOk = res.ok;
      _result = res.ok
          ? (res.confirmed
              ? 'Synced $what: ${res.added} added, ${res.updated} updated.'
              : res.message)
          : res.message;
    });
  }

  Future<void> _copyScript() async {
    final script = await rootBundle.loadString('docs/apps_script.gs');
    await Clipboard.setData(ClipboardData(text: script));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Script copied. Paste it into Extensions > Apps Script.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = widget.report;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Google Sheets', style: t.titleLarge),
            const SizedBox(height: 4),
            const Text(
                'Keep a copy of your appointments in a Google Sheet for reporting. '
                'Each month gets its own tab. The app stays your main database.',
                style: TextStyle(color: AppColors.brown)),
            const SizedBox(height: 14),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                  labelText: 'Web app link',
                  hintText: 'https://script.google.com/macros/s/…/exec'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secret,
              obscureText: _hide,
              decoration: InputDecoration(
                labelText: 'Secret word',
                suffixIcon: IconButton(
                  icon: Icon(_hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(
                onPressed: _busy || r.appointments.isEmpty
                    ? null
                    : () => _sync(r.appointments,
                        '${monthName(r.month)} ${r.year}'),
                child: Text(_busy ? 'Syncing…' : 'Sync this month'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async => _sync(
                        await widget.repo.bookings.all(), 'all appointments'),
                child: const Text('Sync everything'),
              ),
              TextButton(onPressed: _save, child: const Text('Save')),
              TextButton.icon(
                onPressed: _copyScript,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy script'),
              ),
            ]),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(_result!,
                  style: TextStyle(
                      color: _resultOk
                          ? const Color(0xFF3F7A3E)
                          : Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 10),
            const Text(
                'First time? Follow docs/google_sheets.md (5 minutes). Syncing '
                'twice never duplicates rows.',
                style: TextStyle(color: AppColors.brown, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
