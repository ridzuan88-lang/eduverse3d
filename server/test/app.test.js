'use strict';
const assert = require('assert');
const WebSocket = require('ws');
const { createApp } = require('../app');
const { makeDb, makeAdmin } = require('./fakes');
const ECON = require('../config/economy.json');
const CAT = require('../config/catalog.json');

const tokens = {
  A: { uid: 'alice' }, B: { uid: 'bob' }, C: { uid: 'cara' },
  ADMIN: { uid: 'root', role: 'super_admin' }, DEV: { uid: 'dev1', role: 'world_dev' }, MOD: { uid: 'mod1', role: 'moderator' },
};
let T = 1_800_000_000_000; const T0 = Date.now(); // 2027-01-15; jam ujian bergerak maju dari tarikh asas
const db = makeDb();
const app = createApp({ admin: makeAdmin(tokens), db, env: { DEV_PUBLISH_CODE: 'sesame', HASH_SALT: 'x' }, now: () => T + (Date.now() - T0) });
let base;
const call = async (tok, method, path, body, hdr = {}) => {
  const r = await fetch(base + path, { method, headers: { 'Content-Type': 'application/json', ...(tok ? { Authorization: 'Bearer ' + tok } : {}), ...hdr }, body: method === 'POST' ? JSON.stringify(body || {}) : undefined });
  return { s: r.status, j: await r.json().catch(() => ({})) };
};
let n = 0, id = () => (++n).toString(16).padStart(8, '0');
const tx = (o = {}) => ({ id: id(), subject: 'math', year: 3, total: 8, c: { easy: 2, medium: 3, hard: 2 }, t: 70, win: false, ...o });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let pass = 0; const ok = (name) => { pass++; console.log('  ok -', name); };

(async () => {
  await new Promise((r) => app.server.listen(0, r));
  base = 'http://127.0.0.1:' + app.server.address().port;

  // --- auth
  assert.strictEqual((await call(null, 'GET', '/health')).s, 200);
  assert.strictEqual((await call(null, 'GET', '/me')).s, 401);
  assert.strictEqual((await call('nope', 'GET', '/me')).s, 401); ok('auth wajib kecuali /health');

  // --- profil & nama unik/ditapis
  assert.strictEqual((await call('A', 'POST', '/profile', { name: 'Alice_01', year: 3 })).s, 200);
  assert.strictEqual((await call('B', 'POST', '/profile', { name: 'alice_01', year: 2 })).j.error, 'name_taken');
  assert.strictEqual((await call('B', 'POST', '/profile', { name: 'babi', year: 2 })).j.error, 'name_bad');
  assert.strictEqual((await call('B', 'POST', '/profile', { name: 'Bob_B', year: 3 })).s, 200);
  assert.strictEqual((await call('C', 'POST', '/profile', { name: 'Cara_C', year: 4 })).s, 200); ok('nama samaran unik & ditapis');

  // --- sync: pelayan kira semula ganjaran
  let r = await call('A', 'POST', '/sync', { txs: [{ ...tx(), xp: 99999, coins: 99999 }] });
  // 7 betul: xp = 2*10 + 3*15 + 2*20 = 105 + selesai 10 = 115 (purata 8.75s: tiada bonus laju) ; syiling = 10+30+30+20 = 90
  assert.strictEqual(r.j.accepted.length, 1);
  assert.strictEqual(r.j.xp, 115, 'xp dikira pelayan, bukan klien'); assert.strictEqual(r.j.coins, 90);
  ok('ganjaran dikira pelayan (nilai klien diabaikan)');
  const dup = { ...tx() };
  await call('A', 'POST', '/sync', { txs: [dup] });
  assert.deepStrictEqual((await call('A', 'POST', '/sync', { txs: [dup] })).j.duplicate, [dup.id]); ok('transaksi pendua ditolak');
  r = await call('A', 'POST', '/sync', { txs: [tx({ t: 3 }), tx({ subject: 'x' }), tx({ c: { easy: 9, medium: 0, hard: 0 } }), tx({ year: 9 })] });
  assert.strictEqual(r.j.rejected.length, 4); assert.strictEqual(r.j.accepted.length, 0); ok('terlalu laju / subjek / kiraan / tahun tidak sah ditolak');
  // sempurna + menang + laju
  r = await call('B', 'POST', '/sync', { txs: [tx({ total: 8, c: { easy: 0, medium: 0, hard: 8 }, t: 40, win: true, subject: 'sci' })] });
  // 8*20=160 + 10 + sempurna 20 + menang 10 + laju 5 = 205 ; syiling 120+20+30+5 = 175 (8 betul < 10 jadi belum ada misi harian)
  assert.strictEqual(r.j.xp, 205); assert.strictEqual(r.j.coins, 175);
  r = await call('B', 'POST', '/sync', { txs: [tx({ total: 8, c: { easy: 8, medium: 0, hard: 0 }, t: 80, subject: 'bm' })] });
  assert.strictEqual(r.j.coins, 40 + 20 + 30 + ECON.daily_mission.coins, 'misi harian dituntut apabila 10 betul dicapai'); ok('bonus sempurna/menang/laju + misi harian');
  // had syiling harian
  let total = 0;
  for (let i = 0; i < 12; i++) { r = await call('C', 'POST', '/sync', { txs: [tx({ total: 8, c: { easy: 0, medium: 0, hard: 8 }, t: 80, year: 4 })] }); total += r.j.coins; }
  assert.ok(total <= ECON.caps.daily_quiz_coins + ECON.daily_mission.coins + ECON.weekly_mission.coins, 'had harian: ' + total); ok('had syiling harian berkuat kuasa (' + total + ')');
  // hari baru -> had ditetapkan semula
  T += 86400000;
  r = await call('C', 'POST', '/sync', { txs: [tx({ total: 8, c: { easy: 0, medium: 0, hard: 8 }, t: 80, year: 4 })] });
  assert.ok(r.j.coins > 0); ok('had ditetapkan semula pada hari baru');

  // --- papan pendahulu
  r = await call('A', 'GET', '/leaderboard?type=global');
  assert.ok(r.j.list.length === 3 && r.j.list[0].xp >= r.j.list[1].xp);
  r = await call('A', 'GET', '/leaderboard?type=subject&subject=sci');
  assert.strictEqual(r.j.list.length, 1); assert.strictEqual(r.j.list[0].name, 'Bob_B');
  r = await call('A', 'GET', '/leaderboard?type=weekly'); assert.ok(r.j.list.length >= 2);
  r = await call('A', 'GET', '/leaderboard?type=monthly'); assert.ok(r.j.list.length >= 2);
  r = await call('A', 'GET', '/leaderboard?type=year&year=4'); assert.deepStrictEqual(r.j.list.map((x) => x.name), ['Cara_C']);
  db.opts.failCompositeIndex = true;
  r = await call('A', 'GET', '/leaderboard?type=year&year=3'); assert.ok(r.j.list.length === 2, 'jatuh balik tanpa indeks komposit'); db.opts.failCompositeIndex = false;
  assert.strictEqual((await call('A', 'GET', '/leaderboard?type=subject&subject=zzz')).s, 400); ok('papan pendahulu: global/subjek/mingguan/bulanan/tahun + fallback indeks');
  // minggu lain: mingguan kosong
  T += 8 * 86400000; r = await call('A', 'GET', '/leaderboard?type=weekly'); assert.strictEqual(r.j.list.length, 0); ok('papan mingguan bermula semula minggu baharu'); T -= 8 * 86400000;

  // --- kelas
  assert.strictEqual((await call('A', 'POST', '/admin/class', { name: 'Kelas A', year: 3 })).s, 403);
  r = await call('ADMIN', 'POST', '/admin/class', { name: 'Darjah 3 Bestari', year: 3 }); assert.strictEqual(r.j.code.length, 6);
  assert.strictEqual((await call('A', 'POST', '/class/join', { code: 'ZZZZZZ' })).s, 404);
  assert.strictEqual((await call('A', 'POST', '/class/join', { code: r.j.code.toLowerCase() })).s, 200);
  await call('B', 'POST', '/class/join', { code: r.j.code });
  const cid = (await call('A', 'GET', '/me')).j.class; assert.ok(cid);
  r = await call('A', 'GET', '/leaderboard?type=class&class=' + cid); assert.deepStrictEqual(r.j.list.map((x) => x.name).sort(), ['Alice_01', 'Bob_B']); ok('kelas: cipta (admin sahaja), sertai dengan kod, papan kelas');

  // --- pengumuman
  assert.strictEqual((await call('A', 'POST', '/admin/announcement', { title: 'x', kind: 'event' })).s, 403);
  assert.strictEqual((await call('MOD', 'POST', '/admin/announcement', { title: 'Peraduan Sains', body: 'Sabtu ini', kind: 'competition', days: 2 })).s, 200);
  assert.strictEqual((await call('MOD', 'POST', '/admin/announcement', { title: 'x', kind: 'hack' })).s, 400);
  assert.strictEqual((await call('A', 'GET', '/announcements')).j.list.length, 1);
  T += 3 * 86400000; assert.strictEqual((await call('A', 'GET', '/announcements')).j.list.length, 0); T -= 3 * 86400000; ok('pengumuman: peranan, tamat tempoh');

  // --- rumah
  const good = [{ id: 'bed1', x: 2, z: -3, r: 1, s: 1 }, { id: 'pool1', x: 0, z: 8, r: 0, s: 1 }, { id: 'door1', x: 1, z: 1, r: 0, s: 1, o: 1 }];
  assert.strictEqual((await call('A', 'POST', '/house', { items: good, privacy: 'public' })).s, 200);
  assert.strictEqual((await call('A', 'POST', '/house', { items: [{ id: 'pool1', x: 0, z: -8 }] })).j.error, 'pool_zone');
  assert.strictEqual((await call('A', 'POST', '/house', { items: [{ id: 'bed1', x: 99, z: 0 }] })).j.error, 'out_of_plot');
  assert.strictEqual((await call('A', 'POST', '/house', { items: [{ id: 'ufo', x: 0, z: 0 }] })).j.error, 'bad_item');
  assert.strictEqual((await call('A', 'POST', '/house', { items: [{ id: 'bed1', x: 0, z: 0, s: 50 }] })).j.error, 'scale');
  assert.strictEqual((await call('A', 'POST', '/house', { items: Array(151).fill({ id: 'rock1', x: 0, z: 0 }) })).j.error, 'too_many');
  assert.strictEqual((await call('B', 'GET', '/house?name=Alice_01')).j.items.length, 3);
  await call('A', 'POST', '/house', { items: good, privacy: 'private' });
  assert.strictEqual((await call('B', 'GET', '/house?name=Alice_01')).s, 403);
  assert.strictEqual((await call('A', 'GET', '/house')).j.items.length, 3); ok('rumah: pengesahan katalog/sempadan/kolam/skala/had + privasi');

  // --- dunia / Mod Pembangun
  const objs = [{ id: 'nat_tree0', x: 10, y: 0, z: 10, ry: 90, s: 1.5 }, { id: 'road_straight', x: 0, y: 0, z: 0, ry: 0, s: 1 }];
  assert.strictEqual((await call('A', 'POST', '/admin/world/save', { objects: objs })).s, 403);
  assert.strictEqual((await call('MOD', 'POST', '/admin/world/save', { objects: objs })).s, 403);
  r = await call('DEV', 'POST', '/admin/world/save', { objects: objs, note: 'v pertama', env: { time: 19.5, weather: 'rain' } }); assert.strictEqual(r.j.version, 1); assert.strictEqual(r.j.live, false);
  assert.strictEqual((await call('A', 'GET', '/world')).j.version, 0, 'draf tidak live');
  assert.strictEqual((await call('DEV', 'POST', '/admin/world/publish', { version: 1 })).j.error, 'confirm');
  assert.strictEqual((await call('DEV', 'POST', '/admin/world/publish', { version: 1, confirm: true })).j.error, 'dev_code');
  assert.strictEqual((await call('DEV', 'POST', '/admin/world/publish', { version: 1, confirm: true }, { 'X-Dev-Code': 'wrong' })).s, 403);
  assert.strictEqual((await call('A', 'POST', '/admin/world/publish', { version: 1, confirm: true }, { 'X-Dev-Code': 'sesame' })).s, 403);
  assert.strictEqual((await call('DEV', 'POST', '/admin/world/publish', { version: 1, confirm: true }, { 'X-Dev-Code': 'sesame' })).j.live, 1);
  assert.strictEqual((await call('A', 'GET', '/world')).j.objects.length, 2);
  assert.deepStrictEqual((await call('A', 'GET', '/world')).j.env, { time: 19.5, weather: 'rain' });
  assert.strictEqual((await call('DEV', 'POST', '/admin/world/save', { objects: [{ id: 'hax', x: 0, z: 0 }] })).j.error, 'bad_object');
  assert.strictEqual((await call('DEV', 'POST', '/admin/world/save', { objects: [{ id: 'nat_rock', x: 9999, z: 0 }] })).j.error, 'bad_value');
  r = await call('ADMIN', 'POST', '/admin/world/save', { objects: [objs[0]], note: 'v kedua' }); assert.strictEqual(r.j.version, 2);
  await call('ADMIN', 'POST', '/admin/world/publish', { version: 2, confirm: true }, { 'X-Dev-Code': 'sesame' });
  assert.strictEqual((await call('A', 'GET', '/world')).j.objects.length, 1);
  await call('ADMIN', 'POST', '/admin/world/publish', { version: 1, confirm: true }, { 'X-Dev-Code': 'sesame' }); // pulihkan
  assert.strictEqual((await call('A', 'GET', '/world')).j.objects.length, 2);
  r = await call('DEV', 'GET', '/admin/world/versions'); assert.strictEqual(r.j.live, 1); assert.strictEqual(r.j.versions.length, 2);
  assert.strictEqual((await call('A', 'GET', '/admin/world/versions')).s, 403); ok('Mod Pembangun: peranan sebelah pelayan, draf vs live, kod pengesahan, pulih versi');

  // --- WebSocket
  const open = (tok, name, extra = {}) => new Promise((res) => {
    const ws = new WebSocket('ws://127.0.0.1:' + app.server.address().port); ws.msgs = [];
    ws.on('message', (d) => { const m = JSON.parse(d); ws.msgs.push(m); if (m.t === 'w') ws.me = m; });
    ws.on('open', () => { ws.send(JSON.stringify({ t: 'join', token: tok, name, avatar: {}, room: 'tst', ...extra })); setTimeout(() => res(ws), 120); });
  });
  const wa = await open('A', 'Alice_01', { ft: true }), wb = await open('B', 'Bob_B', { ft: false }), wc = await open('C', 'Cara_C');
  assert.ok(wa.me && wb.me && wc.me);
  const st = (w, x, z) => w.send(JSON.stringify({ t: 's', x, y: 1, z, r: 0, a: 0, v: 0 }));
  st(wa, 0, 0); st(wb, 5, 0); st(wc, 200, 0); await sleep(150);
  const got = (w, t) => w.msgs.filter((m) => m.t === t);
  wb.send(JSON.stringify({ t: 'q', i: 0 })); await sleep(100);
  assert.strictEqual(got(wa, 'c').length, 1); assert.strictEqual(got(wa, 'c')[0].m, 'Hai!'); assert.strictEqual(got(wc, 'c').length, 0, 'jauh tidak nampak sembang dekat'); ok('WS: sembang pantas dihantar kepada pemain berdekatan sahaja');
  await sleep(1600); wb.send(JSON.stringify({ t: 'q', i: 2, s: 'r' })); await sleep(100);
  assert.strictEqual(got(wc, 'c').length, 1); ok('WS: sembang bilik sampai kepada semua');
  await sleep(1600); wb.send(JSON.stringify({ t: 'c', text: 'hello' })); await sleep(100);
  assert.strictEqual(got(wb, 'cr').pop().why, 'text_off'); ok('WS: teks bebas dimatikan secara lalai');
  await sleep(1600); wa.send(JSON.stringify({ t: 'c', text: 'Jom main bola' })); await sleep(100);
  assert.strictEqual(got(wb, 'c').pop().m, 'Jom main bola');
  await sleep(1600); wa.send(JSON.stringify({ t: 'c', text: 'kau bodoh' })); await sleep(100);
  assert.strictEqual(got(wa, 'cr').pop().why, 'bad');
  await sleep(1600); wa.send(JSON.stringify({ t: 'c', text: 'call 0123456789' })); await sleep(100);
  assert.strictEqual(got(wa, 'cr').pop().why, 'personal'); ok('WS: teks ditapis (kata kesat, maklumat peribadi)');
  wa.send(JSON.stringify({ t: 'q', i: 1 })); wa.send(JSON.stringify({ t: 'q', i: 1 })); await sleep(100);
  assert.ok(got(wa, 'cr').some((m) => m.why === 'rate')); ok('WS: had kadar mesej');
  // animasi/emote melalui keadaan `a` (sah 0-22) + lencana tahap & kelas
  wb.send(JSON.stringify({ t: 's', x: 5, y: 1, z: 0, r: 0, a: 13, v: 0 })); await sleep(150);
  let pl = [...wa.msgs].reverse().find((m) => m.t === 'p').list.find((p) => p.n === 'Bob_B');
  assert.strictEqual(pl.a, 13); assert.ok(pl.lv >= 1); assert.strictEqual(pl.cl, 'Darjah 3 Bestari'.slice(0, 14));
  wb.send(JSON.stringify({ t: 's', x: 5, y: 1, z: 0, r: 0, a: 99, v: 0 })); await sleep(150);
  pl = [...wa.msgs].reverse().find((m) => m.t === 'p').list.find((p) => p.n === 'Bob_B'); assert.strictEqual(pl.a, 0); ok('WS: kod animasi disahkan, lencana tahap/kelas disiar');
  // pintu ibu bapa: hidupkan teks bebas selepas sertai
  await sleep(1600); wb.send(JSON.stringify({ t: 'cfg', ft: true })); wb.send(JSON.stringify({ t: 'c', text: 'hello semua' })); await sleep(100);
  assert.strictEqual(got(wa, 'c').pop().m, 'hello semua'); ok('WS: tetapan teks boleh dikemas kini semasa sesi');
  // lapor
  const bobId = [...wa.msgs].reverse().find((m) => m.t === 'p').list.find((p) => p.n === 'Bob_B').id;
  wa.send(JSON.stringify({ t: 'rep', id: bobId, why: 'bully' })); await sleep(100);
  assert.ok(got(wa, 'repok').length === 1);
  const rep = await call('MOD', 'GET', '/admin/reports'); assert.strictEqual(rep.j.list[0].targetName, 'Bob_B'); assert.ok(rep.j.list[0].recent.length >= 1);
  assert.strictEqual((await call('A', 'GET', '/admin/reports')).s, 403); ok('WS: laporan pemain disimpan bersama bukti sembang, moderator sahaja boleh baca');
  // sekat
  const wd = await open('ADMIN', 'Root', { blocks: [wa.me.u] }); st(wd, 0, 1); await sleep(1600);
  wa.send(JSON.stringify({ t: 'q', i: 4, s: 'r' })); await sleep(100);
  assert.ok(!got(wd, 'c').some((m) => m.m === 'Hore!'), 'pemain disekat tidak sampai'); ok('WS: pemain yang disekat tidak menerima mesej');
  [wa, wb, wc, wd].forEach((w) => w.close());
  app.close();
  console.log(`\napp.test.js: ${pass} kumpulan ujian lulus`);
  process.exit(0);
})().catch((e) => { console.error('GAGAL:', e); process.exit(1); });
