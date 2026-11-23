const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December'
];
const _days = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];

/// "just now", "5 min ago", "3 h ago", "2 days ago", else the date.
String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  return '${shortMonth(t.month)} ${t.day}';
}

String monthName(int month) => _months[month - 1];
String shortMonth(int month) => _months[month - 1].substring(0, 3);
String dayName(int weekday) => _days[weekday - 1];
String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

String formatDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';

/// 840 -> "2:00 PM"
String formatSlot(int minutes) {
  final h24 = minutes ~/ 60;
  final m = minutes % 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final suffix = h24 >= 12 ? 'PM' : 'AM';
  return '$h12:${m.toString().padLeft(2, '0')} $suffix';
}
