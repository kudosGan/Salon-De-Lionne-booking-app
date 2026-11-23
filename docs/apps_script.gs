// Paste this into Extensions > Apps Script in your Google Sheet.
const SECRET = 'change-this-secret-word';

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    if (data.secret !== SECRET) return out({ ok: false, error: 'Wrong secret word.' });

    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let added = 0, updated = 0;
    const byMonth = {};
    (data.rows || []).forEach(r => (byMonth[r.month] = byMonth[r.month] || []).push(r));

    Object.keys(byMonth).forEach(month => {
      let sheet = ss.getSheetByName(month) || ss.insertSheet(month);
      const width = data.headers.length + 1; // column A holds the appointment id
      if (sheet.getLastRow() === 0) {
        sheet.getRange(1, 1, 1, width).setValues([['ID'].concat(data.headers)]);
        sheet.setFrozenRows(1);
      }
      const last = sheet.getLastRow();
      const ids = last > 1 ? sheet.getRange(2, 1, last - 1, 1).getValues().map(x => String(x[0])) : [];
      byMonth[month].forEach(r => {
        const row = [r.id].concat(r.values);
        const at = ids.indexOf(String(r.id));
        if (at >= 0) {
          sheet.getRange(at + 2, 1, 1, width).setValues([row]);
          updated++;
        } else {
          sheet.appendRow(row);
          ids.push(String(r.id));
          added++;
        }
      });
    });
    return out({ ok: true, added: added, updated: updated });
  } catch (err) {
    return out({ ok: false, error: String(err) });
  }
}

function out(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
