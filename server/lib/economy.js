// Pengiraan ganjaran DI PELAYAN. Klien hanya melapor kiraan jawapan betul; XP/syiling dikira semula di sini.
'use strict';
const { dayKey, weekKey, monthKey } = require('./clock');
const SUBJECTS = ['bm', 'en', 'math', 'sci', 'jawi', 'arab', 'mix'];
const DIFFS = ['easy', 'medium', 'hard'];
const int = (v, lo, hi) => Number.isInteger(v) && v >= lo && v <= hi;

// tx: {id, subject, year, total, c:{easy,medium,hard}, t:saat, win:boolean}
function validate(tx, cfg) {
  if (!tx || typeof tx !== 'object') return 'bad';
  if (!/^[0-9a-f]{8,32}$/.test(tx.id || '')) return 'id';
  if (!SUBJECTS.includes(tx.subject)) return 'subject';
  if (!int(tx.year, 1, 6)) return 'year';
  if (!int(tx.total, 1, 20)) return 'total';
  const c = tx.c || {};
  let sum = 0;
  for (const d of DIFFS) { if (!int(c[d] == null ? 0 : c[d], 0, tx.total)) return 'c'; sum += c[d] || 0; }
  if (sum > tx.total) return 'sum';
  if (typeof tx.t !== 'number' || !isFinite(tx.t) || tx.t < tx.total * cfg.caps.min_seconds_per_question || tx.t > 3600) return 'speed';
  return null;
}

function rawReward(tx, cfg) {
  const c = tx.c || {};
  let xp = 0, coins = 0, sum = 0;
  for (const d of DIFFS) { const n = c[d] || 0; sum += n; xp += n * cfg.xp_per_correct[d]; coins += n * cfg.coins_per_correct[d]; }
  xp += cfg.quiz_complete.xp; coins += cfg.quiz_complete.coins;
  const perfect = sum === tx.total;
  if (perfect) { xp += cfg.perfect_quiz.xp; coins += cfg.perfect_quiz.coins; }
  if (tx.win) { xp += cfg.win_vs_robot.xp; coins += cfg.win_vs_robot.coins; }
  if (sum >= Math.ceil(tx.total / 2) && tx.t / tx.total < cfg.speed_bonus.avg_seconds_below) xp += cfg.speed_bonus.xp;
  return { xp, coins, correct: sum, perfect };
}

// Mengubah `u` (dokumen pengguna dalam ingatan). Pulangkan {xp, coins, reason?}
function settle(u, tx, cfg, now) {
  const bad = validate(tx, cfg);
  if (bad) return { rejected: bad };
  const day = dayKey(now), wk = weekKey(now), mo = monthKey(now);
  u.day = u.day && u.day.d === day ? u.day : { d: day, coins: 0, quizzes: 0 };
  u.weekly = u.weekly && u.weekly.k === wk ? u.weekly : { k: wk, correct: 0, subj: [], cov: false, claimed: false };
  if (u.day.quizzes >= cfg.caps.max_quizzes_per_day_verified) return { rejected: 'daily_quizzes' };
  const r = rawReward(tx, cfg);
  let coins = Math.max(0, Math.min(r.coins, cfg.caps.daily_quiz_coins - u.day.coins));
  let xp = r.xp;
  // Liputan subjek mingguan: bonus sekali seminggu apabila cukup subjek berbeza dimainkan (bukan sekadar masa dalam talian)
  if (tx.subject !== 'mix' && r.correct > 0 && !u.weekly.subj.includes(tx.subject)) u.weekly.subj.push(tx.subject);
  if (!u.weekly.cov && u.weekly.subj.length >= cfg.weekly_coverage_bonus.subjects_needed) { u.weekly.cov = true; xp += cfg.weekly_coverage_bonus.xp; }
  u.weekly.correct += r.correct;
  u.day.coins += coins; u.day.quizzes += 1;
  u.xp = (u.xp || 0) + xp; u.coins = (u.coins || 0) + coins;
  u.correct = (u.correct || 0) + r.correct; u.total = (u.total || 0) + tx.total; u.quizzes = (u.quizzes || 0) + 1;
  if (r.perfect) u.perfect = (u.perfect || 0) + 1;
  u.secs = (u.secs || 0) + tx.t;
  u.year = tx.year;
  u.st = u.st || {};
  const s = u.st[tx.subject] = u.st[tx.subject] || { xp: 0, correct: 0, total: 0 };
  s.xp += xp; s.correct += r.correct; s.total += tx.total;
  u.wk = u.wk || {}; u.wk[wk] = (u.wk[wk] || 0) + xp;
  u.mo = u.mo || {}; u.mo[mo] = (u.mo[mo] || 0) + xp;
  // Ganjaran misi (dikira pelayan)
  let missions = 0;
  u.daily = u.daily && u.daily.d === day ? u.daily : { d: day, correct: 0, claimed: false };
  u.daily.correct += r.correct;
  if (!u.daily.claimed && u.daily.correct >= cfg.daily_mission.correct_needed) { u.daily.claimed = true; missions += cfg.daily_mission.coins; }
  if (!u.weekly.claimed && u.weekly.correct >= cfg.weekly_mission.correct_needed) { u.weekly.claimed = true; missions += cfg.weekly_mission.coins; }
  u.coins += missions; coins += missions;
  return { xp, coins, correct: r.correct, perfect: r.perfect, missions };
}

module.exports = { validate, rawReward, settle, SUBJECTS };
