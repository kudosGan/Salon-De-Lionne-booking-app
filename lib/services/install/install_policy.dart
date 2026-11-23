/// When to offer "install the app" to a visitor.
///
/// * Never inside the installed app, or on a computer (the offer is for phones).
/// * Every phone visitor gets it: with Chrome's one-tap button when the browser
///   allows it, otherwise with manual steps (iPhone, or an Android browser
///   that cannot install by itself, such as a link opened inside another app).
/// * After "Not now", stay quiet for a week.
const installReminderGap = Duration(days: 7);

bool shouldOfferInstall({
  required bool isStandalone,
  required bool isMobile,
  required DateTime now,
  DateTime? dismissedAt,
}) {
  if (isStandalone || !isMobile) return false;
  if (dismissedAt != null && now.difference(dismissedAt) < installReminderGap) {
    return false;
  }
  return true;
}
