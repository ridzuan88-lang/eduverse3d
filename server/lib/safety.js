// Penapis sembang: maklumat peribadi, kata kesat/ejekan, ugutan. Digunakan oleh pelayan (wajib) dan disalin logiknya di klien (Safety.gd).
// Penapis kata kunci TIDAK sempurna - kekalkan laporan pemain + semakan moderator.
'use strict';

function normalize(s) {
  return String(s || '')
    .toLowerCase()
    .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[@4]/g, 'a').replace(/[3]/g, 'e').replace(/[1!|]/g, 'i').replace(/[0]/g, 'o').replace(/[$5]/g, 's').replace(/7/g, 't')
    .replace(/[^a-z\s]/g, ' ')
    .replace(/(.)\1{2,}/g, '$1$1')   // huruf berulang: "stuuuupid" -> "stuupid"
    .replace(/\s+/g, ' ').trim();
}
// Versi tanpa ruang untuk menangkap "s.t.u.p.i.d" (substring hanya untuk perkataan panjang, elak positif palsu)
function squash(s) { return normalize(s).replace(/\s/g, '').replace(/(.)\1+/g, '$1'); }
// Gabungkan jujukan huruf tunggal: "f u c k" -> "fuck"
function joinSingles(norm) {
  const out = []; let run = [];
  for (const tok of norm.split(' ')) {
    if (tok.length === 1) { run.push(tok); continue; }
    if (run.length) { out.push(run.join('')); run = []; }
    out.push(tok);
  }
  if (run.length) out.push(run.join(''));
  return out.join(' ');
}

function hasWord(norm, word) {
  const w = normalize(word);
  if (w.includes(' ')) return norm.includes(w);
  return new RegExp('(^|\\s)' + w + '(s|es|lah|nya)?(\\s|$)').test(norm);
}

function check(text, cfg) {
  const raw = String(text == null ? '' : text);
  const t = raw.replace(/\s+/g, ' ').trim();
  if (!t) return { ok: false, reason: 'empty' };
  if (t.length > cfg.max_len) return { ok: false, reason: 'long' };
  // Maklumat peribadi: e-mel, URL, nombor telefon (>=7 digit selepas buang pemisah), digit dieja
  if (/[^\s@]+\s*(@|\(at\)|\[at\])\s*[^\s@]+/i.test(t) && /\./.test(t)) return { ok: false, reason: 'personal' };
  if (/(https?:\/\/|www\.|\.com\b|\.my\b|\.net\b|\.org\b|bit\.ly)/i.test(t)) return { ok: false, reason: 'personal' };
  const digits = t.replace(/[\s().\-+_]/g, '');
  if (/\d{7,}/.test(digits)) return { ok: false, reason: 'personal' };
  if ((t.match(/\d/g) || []).length >= 8) return { ok: false, reason: 'personal' };
  const norm = normalize(t);
  if (/\b(kosong|satu|dua|tiga|empat|lima|enam|tujuh|lapan|sembilan|zero|one|two|three|four|five|six|seven|eight|nine)(\s+(kosong|satu|dua|tiga|empat|lima|enam|tujuh|lapan|sembilan|zero|one|two|three|four|five|six|seven|eight|nine)){5,}/.test(norm)) return { ok: false, reason: 'personal' };
  for (const c of cfg.personal_info_cues) if (norm.includes(normalize(c))) return { ok: false, reason: 'personal' };
  for (const p of cfg.threat_phrases) if (norm.includes(normalize(p))) return { ok: false, reason: 'threat' };
  const sq = squash(t);
  const joined = joinSingles(norm);
  for (const w of cfg.blocked_words) {
    if (hasWord(norm, w) || hasWord(joined, w)) return { ok: false, reason: 'bad' };
    const ws = squash(w);
    if (ws.length >= 5 && sq.includes(ws)) return { ok: false, reason: 'bad' };
  }
  return { ok: true, text: t };
}

module.exports = { check, normalize };
