# Salon De Lionne – appointment booking app

Flutter / Dart, Material 3, local SQLite storage. Clients book without an
account; the owner and stylists log in to manage appointments.

## Run it

```
flutter pub get
flutter run -d chrome        # or an Android device/emulator
flutter test                 # 82 tests
flutter analyze
```

On Windows, if `flutter` is not found, open a new terminal (Flutter is in
`C:\src\flutter\bin`). Plugins need Windows **Developer Mode** (Settings → For
developers). Keep the project **outside OneDrive** if builds complain about
locked files.

## First use

1. Open the site, click **Staff login** (top right), and create the **admin
   account** (there is no default password).
2. ☰ → **Staff**: rename or deactivate the three "Stylist 1/2/3" placeholders
   and add real stylists with logins, hours and days off.
3. Make a test booking from the landing page, then confirm it in ☰ →
   **Appointments** and try the WhatsApp message.

## What is where

| Folder | Contents |
|---|---|
| `lib/core/config/salon_config.dart` | **Salon name, phone, email, address, website, hours.** One place. |
| `lib/data/catalog.dart` | Services, hairstyles (and the placeholder stylists). |
| `lib/data/db/app_database.dart` | The database tables and upgrades. |
| `lib/data/*_repository.dart` | All reading/writing of bookings, staff, reports. |
| `lib/features/landing`, `booking` | What clients see. |
| `lib/features/admin`, `employee`, `calendar`, `shared` | Owner and stylist screens. |
| `lib/services` | WhatsApp, calendar files, CSV/Excel, Google Sheets. |
| `lib/features/ai_agent` | Version 2 groundwork (contract only, no AI yet). |
| `assets/images` | Your photos. See `assets/README.md`. |
| `docs/google_sheets.md` | 5-minute Google Sheets setup. |
| `tool/optimize_images.dart` | Shrinks big photos (originals go to `design_source/`). |

## Build for release

```
flutter build web --release        # output: build/web  (upload to any web host)
flutter build apk --release        # needs Android Studio / Android SDK
```

Before publishing, replace the **placeholders**: opening hours in
`salon_config.dart`, the stylist names, and (optionally) add a signing key for
Android (https://docs.flutter.dev/deployment/android).

## Important limitation: data is stored on each device

Version 1 keeps bookings in SQLite **inside the device or browser that runs the
app**. So a booking a client makes on their own phone is saved on *their*
phone, and the salon will not see it. It works as intended when the app runs on
**one device the salon controls** (for example a tablet or computer at the
salon, where clients and staff both use the same app). To take bookings from
clients' own devices, the data must live on a shared server. The screens talk
to a repository interface (`lib/data/booking_repository.dart`), so a server
version can replace the SQLite one without redesigning the app.

## Google Sheets (switched off for now)

The sync is built and tested but hidden. To turn it on later, set
`showGoogleSheets = true` in `lib/core/config/salon_config.dart` and follow
`docs/google_sheets.md`. CSV and Excel export work without it.

## Other notes

- Logins are lost when the page is reloaded (kept in memory only).
- Passwords are stored as salted hashes. Five wrong tries lock login for 30 s,
  doubling each further miss.
- Reminders and notifications are created while the app is open. There is no
  background service, and WhatsApp messages are sent by tapping Send in
  WhatsApp itself.
- The Google font files are downloaded when the page loads (needs internet).
