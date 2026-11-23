# Sending appointments to Google Sheets (monthly reporting)

The app keeps all bookings in its own database. A Google Sheet is an extra
copy for reports. You set it up once (about 5 minutes):

1. Create a new Google Sheet (for example "Salon appointments").
2. In the sheet choose **Extensions → Apps Script**.
3. Delete the sample code and paste the script from `apps_script.gs`
   (the app also has a **Copy script** button on the Reports page).
4. At the top of the script, change `SECRET` to a private word only you know.
5. Click **Deploy → New deployment → type: Web app**.
   - Execute as: **Me**
   - Who has access: **Anyone**
   Click **Deploy**, approve the permissions, and copy the **Web app URL**
   (it ends with `/exec`).
6. In the app: **Reports → Google Sheets**, paste the URL and the same secret
   word, press **Save**, then **Sync this month**.

Each month gets its own tab ("2026-12"). Syncing again updates existing rows
(matched by appointment id), so nothing is duplicated.

Notes
- Anyone who has both the URL and the secret can add rows to the sheet. Keep
  them private and change the secret if it leaks (redeploy after editing).
- The sheet is a reporting copy. Changes you make in the sheet do not flow back
  into the app.
