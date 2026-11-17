'use strict';
// Waktu Malaysia (UTC+8) untuk sempadan harian/mingguan/bulanan.
const MY = 8 * 3600 * 1000;
function my(now) { return new Date((now == null ? Date.now() : now) + MY); }
function dayKey(now) { return my(now).toISOString().slice(0, 10); }
function monthKey(now) { const d = my(now); return `m${d.getUTCFullYear()}_${String(d.getUTCMonth() + 1).padStart(2, '0')}`; }
function weekKey(now) { // minggu ISO
  const d = my(now);
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const n = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - n);
  const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  const w = Math.ceil(((t - y0) / 86400000 + 1) / 7);
  return `w${t.getUTCFullYear()}_${String(w).padStart(2, '0')}`;
}
module.exports = { dayKey, weekKey, monthKey };
