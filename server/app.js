// EduVerse 3D - pelayan: HTTP (sync, papan pendahulu, kelas, pengumuman, rumah, dunia) + WebSocket (bilik dunia, sembang).
// createApp({admin, db, env}) supaya boleh diuji dengan pangkalan data palsu (test/).
'use strict';
const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const safety = require('./lib/safety');
const eco = require('./lib/economy');
const { dayKey, weekKey, monthKey } = require('./lib/clock');
const ECON = require('./config/economy.json');
const SAFE = require('./config/safety.json');
const CAT = require('./config/catalog.json');

const ROLES = { SUPER: 'super_admin', DEV: 'world_dev', MOD: 'moderator' };
const MAX_ROOM = 8;
const MAX_WORLD_OBJECTS = 3000;
const ANIM_MAX = 22; // 0-8 gerakan, 10-18 emote, 19-20 kenderaan, 21 baring
const cleanName = (s) => String(s || '').replace(/[^A-Za-z0-9_]/g, '').slice(0, 16);
const int = (v, lo, hi) => Number.isInteger(v) && v >= lo && v <= hi;
const num = (v, lim) => (Number.isFinite(v) ? Math.max(-lim, Math.min(lim, v)) : 0);
const HOUSE_IDS = new Map(CAT.house_items.map((i) => [i.id, i]));
const DEV_IDS = new Set(CAT.dev_objects.map((i) => i.id));

function createApp({ admin, db, env = process.env, now = () => Date.now() }) {
  const salt = env.HASH_SALT || 'eduverse-default-salt-change-me';
  const uhash = (uid) => crypto.createHash('sha256').update(salt + uid).digest('hex').slice(0, 10);
  const send = (res, code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(obj)); };
  const readBody = (req) => new Promise((ok, no) => {
    let s = '';
    req.on('data', (c) => { s += c; if (s.length > 900000) { req.destroy(); no(new Error('big')); } });
    req.on('end', () => { try { ok(JSON.parse(s || '{}')); } catch (e) { no(e); } });
  });
  class HttpErr extends Error { constructor(code, msg) { super(msg); this.code = code; } }
  const authReq = async (req) => {
    const tok = (req.headers.authorization || '').replace('Bearer ', '');
    if (!tok) throw new HttpErr(401, 'auth');
    try { return await admin.auth().verifyIdToken(tok); } catch { throw new HttpErr(401, 'auth'); }
  };
  const needRole = (u, roles) => { if (!roles.includes(u.role)) throw new HttpErr(403, 'forbidden'); };
  const devCodeOk = (req) => {
    const want = env.DEV_PUBLISH_CODE;
    if (!want) return true; // pengesahan tambahan pilihan
    const got = String(req.headers['x-dev-code'] || '');
    const a = Buffer.from(got), b = Buffer.from(want);
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  };
  const hits = new Map(); // had kadar HTTP ringkas
  const limit = (key, max, ms) => {
    const t = now(); const arr = (hits.get(key) || []).filter((x) => t - x < ms);
    if (arr.length >= max) throw new HttpErr(429, 'slow');
    arr.push(t); hits.set(key, arr);
  };
  const users = () => db.collection('users');

  // ---------- papan pendahulu ----------
  const lbCache = new Map();
  async function leaderboard(q) {
    const type = q.get('type') || 'global';
    const subject = q.get('subject') || '';
    const year = parseInt(q.get('year') || '0', 10);
    const cls = q.get('class') || '';
    let field = 'xp', where = null;
    if (type === 'global') { /* xp */ }
    else if (type === 'year') { if (!int(year, 1, 6)) throw new HttpErr(400, 'year'); where = ['year', year]; }
    else if (type === 'class') { if (!/^[A-Za-z0-9]{4,20}$/.test(cls)) throw new HttpErr(400, 'class'); where = ['class', cls]; }
    else if (type === 'subject') { if (!['bm', 'en', 'math', 'sci', 'jawi', 'arab'].includes(subject)) throw new HttpErr(400, 'subject'); field = `st.${subject}.xp`; }
    else if (type === 'weekly') field = `wk.${weekKey(now())}`;
    else if (type === 'monthly') field = `mo.${monthKey(now())}`;
    else throw new HttpErr(400, 'type');
    const key = [type, subject, year, cls, field].join('|');
    const c = lbCache.get(key);
    if (c && now() - c.at < 30000) return c.list;
    let snap;
    const base = users();
    try {
      snap = where ? await base.where(where[0], '==', where[1]).orderBy(field, 'desc').limit(20).get()
        : await base.orderBy(field, 'desc').limit(20).get();
    } catch (e) {
      if (!where) throw e; // indeks komposit belum dicipta: jatuh balik isih dalam ingatan (lihat firebase/firestore.indexes.json)
      snap = await base.where(where[0], '==', where[1]).limit(300).get();
    }
    let rows = snap.docs.map((d) => d.data());
    const val = (r) => field.split('.').reduce((o, k) => (o == null ? 0 : o[k]), r) || 0;
    rows = rows.filter((r) => val(r) > 0).sort((a, b) => val(b) - val(a)).slice(0, 20);
    const list = rows.map((r, i) => ({
      rank: i + 1, name: r.name || '?', xp: val(r), level: Math.floor((r.xp || 0) / 100) + 1,
      acc: r.total ? Math.round(100 * (r.correct || 0) / r.total) : 0, q: r.total || 0,
    }));
    lbCache.set(key, { at: now(), list });
    return list;
  }

  // ---------- penghala HTTP ----------
  const routes = {
    'GET /health': async () => ({ ok: true }),

    'GET /me': async (req, u) => {
      const s = await users().doc(u.uid).get();
      const d = s.exists ? s.data() : {};
      return { uid: u.uid, role: u.role || 'player', name: d.name || '', year: d.year || 1, xp: d.xp || 0, coins: d.coins || 0,
        class: d.class || '', className: d.className || '', correct: d.correct || 0, total: d.total || 0, st: d.st || {}, serverTime: now() };
    },

    'POST /profile': async (req, u, b) => {
      limit('prof' + u.uid, 6, 60000);
      const name = cleanName(b.name);
      if (name.length < 3) throw new HttpErr(400, 'name');
      const sc = safety.check(name, SAFE);
      if (!sc.ok || /\d{5,}/.test(name)) throw new HttpErr(400, 'name_bad');
      const year = int(b.year, 1, 6) ? b.year : 1;
      const key = name.toLowerCase();
      await db.runTransaction(async (t) => {
        const nref = db.collection('names').doc(key);
        const uref = users().doc(u.uid);
        const [ns, us] = await Promise.all([t.get(nref), t.get(uref)]);
        if (ns.exists && ns.data().uid !== u.uid) throw new HttpErr(409, 'name_taken');
        const old = us.exists ? (us.data().name || '') : '';
        if (old && old.toLowerCase() !== key) t.delete(db.collection('names').doc(old.toLowerCase()));
        t.set(nref, { uid: u.uid });
        t.set(uref, { ...(us.exists ? us.data() : {}), name, year });
      });
      return { ok: true, name, year };
    },

    'POST /sync': async (req, u, b) => {
      limit('sync' + u.uid, 20, 60000);
      const list = (Array.isArray(b.txs) ? b.txs : []).slice(0, 20);
      const out = { accepted: [], duplicate: [], rejected: [], xp: 0, coins: 0 };
      let totals = {};
      await db.runTransaction(async (t) => {
        out.accepted = []; out.duplicate = []; out.rejected = []; out.xp = 0; out.coins = 0;
        const uref = users().doc(u.uid);
        const us = await t.get(uref);
        const doc = us.exists ? us.data() : {};
        const valid = list.filter((x) => x && typeof x.id === 'string');
        const refs = valid.map((x) => db.collection('tx').doc(`${u.uid}_${String(x.id).replace(/[^0-9a-f]/g, '')}`));
        const snaps = refs.length ? await t.getAll(...refs) : [];
        valid.forEach((x, i) => {
          if (snaps[i].exists) { out.duplicate.push(x.id); return; }
          const r = eco.settle(doc, x, ECON, now());
          if (r.rejected) { out.rejected.push(x.id); return; }
          t.create(refs[i], { uid: u.uid, subject: x.subject, year: x.year, total: x.total, c: x.c || {}, t: x.t, xp: r.xp, coins: r.coins, at: now() });
          out.accepted.push(x.id); out.xp += r.xp; out.coins += r.coins;
        });
        // buang kunci mingguan/bulanan lama supaya dokumen tidak membesar
        for (const k of Object.keys(doc.wk || {}).sort().slice(0, -12)) delete doc.wk[k];
        for (const k of Object.keys(doc.mo || {}).sort().slice(0, -12)) delete doc.mo[k];
        const nm = cleanName(b.name);
        if (!doc.name && nm) doc.name = nm; // nama sebenar ditetapkan melalui /profile
        if (out.accepted.length || !us.exists) t.set(uref, doc);
        totals = { xp: doc.xp || 0, coins: doc.coins || 0 };
      });
      lbCache.clear();
      return { ...out, totals };
    },

    'GET /leaderboard': async (req, u, b, q) => ({ list: await leaderboard(q) }),

    'POST /class/join': async (req, u, b) => {
      limit('cj' + u.uid, 8, 60000);
      const code = String(b.code || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
      if (code.length < 4) throw new HttpErr(400, 'code');
      const snap = await db.collection('classes').where('code', '==', code).limit(1).get();
      if (snap.empty) throw new HttpErr(404, 'class_not_found');
      const c = snap.docs[0];
      const cd = c.data();
      await users().doc(u.uid).set({ class: c.id, className: cd.name }, { merge: true });
      return { ok: true, id: c.id, name: cd.name, year: cd.year };
    },
    'POST /class/leave': async (req, u) => { await users().doc(u.uid).set({ class: '', className: '' }, { merge: true }); return { ok: true }; },
    'POST /admin/class': async (req, u, b) => {
      needRole(u, [ROLES.SUPER, ROLES.MOD]);
      const name = String(b.name || '').replace(/[^\w \-]/g, '').slice(0, 30).trim();
      if (!name || !int(b.year, 1, 6)) throw new HttpErr(400, 'bad');
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      let code = '';
      for (let i = 0; i < 6; i++) code += alphabet[crypto.randomInt(alphabet.length)];
      const ref = await db.collection('classes').add({ name, year: b.year, code, by: u.uid, at: now() });
      return { ok: true, id: ref.id, code, name };
    },

    'GET /announcements': async () => {
      const snap = await db.collection('announcements').orderBy('at', 'desc').limit(40).get();
      const t = now();
      const list = snap.docs.map((d) => ({ id: d.id, ...d.data() })).filter((a) => !a.until || a.until > t)
        .slice(0, 25).map((a) => ({ id: a.id, title: a.title, body: a.body, kind: a.kind, at: a.at }));
      return { list, serverTime: t };
    },
    'POST /admin/announcement': async (req, u, b) => {
      needRole(u, [ROLES.SUPER, ROLES.DEV, ROLES.MOD]);
      const kinds = ['announcement', 'mission', 'competition', 'event', 'update', 'reward', 'server'];
      const title = String(b.title || '').trim().slice(0, 60), body = String(b.body || '').trim().slice(0, 400);
      if (!title || !kinds.includes(b.kind)) throw new HttpErr(400, 'bad');
      const days = int(b.days, 1, 90) ? b.days : 14;
      const ref = await db.collection('announcements').add({ title, body, kind: b.kind, at: now(), until: now() + days * 86400000, by: u.uid });
      return { ok: true, id: ref.id };
    },
    'POST /admin/announcement/delete': async (req, u, b) => {
      needRole(u, [ROLES.SUPER, ROLES.DEV, ROLES.MOD]);
      await db.collection('announcements').doc(String(b.id || '')).delete();
      return { ok: true };
    },
    'GET /admin/reports': async (req, u) => {
      needRole(u, [ROLES.SUPER, ROLES.MOD]);
      const snap = await db.collection('reports').orderBy('at', 'desc').limit(30).get();
      return { list: snap.docs.map((d) => ({ id: d.id, ...d.data() })) };
    },

    // ---------- rumah pemain ----------
    'GET /house': async (req, u, b, q) => {
      const name = q.get('name');
      let uid = u.uid;
      if (name) {
        const ns = await db.collection('names').doc(cleanName(name).toLowerCase()).get();
        if (!ns.exists) throw new HttpErr(404, 'none');
        uid = ns.data().uid;
      }
      const s = await db.collection('houses').doc(uid).get();
      if (!s.exists) return { items: [], privacy: 'private', owner: uid === u.uid };
      const h = s.data();
      if (uid !== u.uid && h.privacy !== 'public') throw new HttpErr(403, 'private');
      return { items: h.items, privacy: h.privacy, owner: uid === u.uid, name: h.name };
    },
    'POST /house': async (req, u, b) => {
      limit('house' + u.uid, 10, 60000);
      const privacy = ['private', 'public'].includes(b.privacy) ? b.privacy : 'private';
      const arr = Array.isArray(b.items) ? b.items : null;
      if (!arr || arr.length > CAT.max_items) throw new HttpErr(400, 'too_many');
      const items = [];
      for (const it of arr) {
        const def = it && HOUSE_IDS.get(it.id);
        if (!def) throw new HttpErr(400, 'bad_item');
        const x = Number(it.x), z = Number(it.z), s = Number(it.s == null ? 1 : it.s);
        if (![x, z, s].every(Number.isFinite) || Math.abs(x) > CAT.plot_half || Math.abs(z) > CAT.plot_half) throw new HttpErr(400, 'out_of_plot');
        if (s < CAT.scale_min || s > CAT.scale_max) throw new HttpErr(400, 'scale');
        if (def.pool && !(x >= CAT.pool_zone.x[0] && x <= CAT.pool_zone.x[1] && z >= CAT.pool_zone.z[0] && z <= CAT.pool_zone.z[1])) throw new HttpErr(400, 'pool_zone');
        items.push({ id: def.id, x: Math.round(x * 100) / 100, z: Math.round(z * 100) / 100, r: [0, 1, 2, 3].includes(it.r) ? it.r : 0, s: Math.round(s * 100) / 100, o: it.o ? 1 : 0 });
      }
      const us = await users().doc(u.uid).get();
      await db.collection('houses').doc(u.uid).set({ items, privacy, name: (us.exists && us.data().name) || '', at: now() });
      return { ok: true, count: items.length };
    },

    // ---------- dunia & Mod Pembangun ----------
    'GET /world': async () => {
      const meta = await db.collection('worlds').doc('meta').get();
      const live = meta.exists ? meta.data().live : 0;
      if (!live) return { version: 0, objects: [], env: { time: 12, weather: 'clear' } };
      const w = await db.collection('worlds').doc('v' + live).get();
      return { version: live, objects: w.exists ? w.data().objects : [], env: (w.exists && w.data().env) || { time: 12, weather: 'clear' } };
    },
    'GET /admin/world/versions': async (req, u) => {
      needRole(u, [ROLES.SUPER, ROLES.DEV]);
      const meta = await db.collection('worlds').doc('meta').get();
      const snap = await db.collection('worlds').orderBy('n', 'desc').limit(30).get();
      return { live: meta.exists ? meta.data().live : 0, versions: snap.docs.filter((d) => d.id !== 'meta').map((d) => { const x = d.data(); return { n: x.n, note: x.note, at: x.at, count: x.objects.length }; }) };
    },
    'GET /admin/world/get': async (req, u, b, q) => {
      needRole(u, [ROLES.SUPER, ROLES.DEV]);
      const n = parseInt(q.get('version') || '0', 10);
      const w = await db.collection('worlds').doc('v' + n).get();
      if (!w.exists) throw new HttpErr(404, 'none');
      return { version: n, objects: w.data().objects, env: w.data().env || { time: 12, weather: 'clear' } };
    },
    'POST /admin/world/save': async (req, u, b) => {
      needRole(u, [ROLES.SUPER, ROLES.DEV]);
      limit('wsave' + u.uid, 20, 60000);
      const arr = Array.isArray(b.objects) ? b.objects : null;
      if (!arr || arr.length > MAX_WORLD_OBJECTS) throw new HttpErr(400, 'too_many');
      const objects = [];
      for (const o of arr) {
        if (!o || !DEV_IDS.has(o.id)) throw new HttpErr(400, 'bad_object');
        const x = Number(o.x), y = Number(o.y || 0), z = Number(o.z), ry = Number(o.ry || 0), s = Number(o.s == null ? 1 : o.s);
        if (![x, y, z, ry, s].every(Number.isFinite) || Math.abs(x) > 240 || Math.abs(z) > 240 || y < -20 || y > 120 || s < 0.2 || s > 6) throw new HttpErr(400, 'bad_value');
        objects.push({ id: o.id, x: Math.round(x * 100) / 100, y: Math.round(y * 100) / 100, z: Math.round(z * 100) / 100, ry: Math.round(ry), s: Math.round(s * 100) / 100 });
      }
      const e = b.env || {};
      const env = { time: Number.isFinite(e.time) ? Math.max(0, Math.min(24, e.time)) : 12, weather: ['clear', 'cloudy', 'rain'].includes(e.weather) ? e.weather : 'clear' };
      let n = 0;
      await db.runTransaction(async (t) => {
        const mref = db.collection('worlds').doc('meta');
        const m = await t.get(mref);
        n = (m.exists ? m.data().latest || 0 : 0) + 1;
        t.set(mref, { ...(m.exists ? m.data() : { live: 0 }), latest: n });
        t.set(db.collection('worlds').doc('v' + n), { n, objects, env, note: String(b.note || '').slice(0, 80), by: u.uid, at: now() });
      });
      return { ok: true, version: n, live: false };
    },
    // Menerbitkan = menetapkan versi sebagai LIVE. Memulihkan versi lama = menerbitkan versi lama. Perlukan pengesahan eksplisit.
    'POST /admin/world/publish': async (req, u, b) => {
      needRole(u, [ROLES.SUPER, ROLES.DEV]);
      if (b.confirm !== true) throw new HttpErr(400, 'confirm');
      if (!devCodeOk(req)) throw new HttpErr(403, 'dev_code');
      const n = int(b.version, 1, 1e6) ? b.version : 0;
      const w = await db.collection('worlds').doc('v' + n).get();
      if (!w.exists) throw new HttpErr(404, 'none');
      const mref = db.collection('worlds').doc('meta');
      const m = await mref.get();
      await mref.set({ ...(m.exists ? m.data() : {}), live: n, published_by: u.uid, published_at: now() });
      return { ok: true, live: n };
    },
  };

  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://x');
      const fn = routes[`${req.method} ${url.pathname}`];
      if (!fn) return send(res, 404, { error: 'none' });
      let u = null;
      if (url.pathname !== '/health') {
        u = await authReq(req);
        limit('ip' + u.uid, 120, 60000);
      }
      const body = req.method === 'POST' ? await readBody(req) : {};
      send(res, 200, await fn(req, u, body, url.searchParams));
    } catch (e) {
      const code = e instanceof HttpErr ? e.code : 400;
      if (!(e instanceof HttpErr)) console.error('ralat:', e && e.message);
      send(res, code, { error: e instanceof HttpErr ? e.message : 'ralat' });
    }
  });

  // ---------- WebSocket ----------
  const wss = new WebSocketServer({ server, maxPayload: 2048 });
  const rooms = new Map();
  const chatLog = new Map(); // bilik -> 30 mesej terakhir (bukti laporan)
  function assignRoom(code) {
    if (code && code !== 'public') {
      if (!/^[A-Za-z0-9]{3,10}$/.test(code)) return null;
      const name = 'p-' + code;
      if (!rooms.has(name)) rooms.set(name, new Map());
      return rooms.get(name).size < MAX_ROOM ? name : null;
    }
    for (let i = 1; ; i++) {
      const name = 'w-' + i;
      if (!rooms.has(name)) rooms.set(name, new Map());
      if (rooms.get(name).size < MAX_ROOM) return name;
    }
  }
  const avatar = (a) => { const o = {}; for (const k of ['gender', 'skin', 'shirt', 'hair', 'hat', 'pack', 'pet', 'face', 'style', 'shoes', 'acc']) o[k] = a && int(a[k], 0, 9) ? a[k] : 0; return o; };

  wss.on('connection', (ws) => {
    let me = null, room = null, joining = false;
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });
    const reply = (o) => { if (ws.readyState === 1) ws.send(JSON.stringify(o)); };
    ws.on('message', async (raw) => {
      let m; try { m = JSON.parse(raw); } catch { return; }
      if (!me) {
        if (m.t !== 'join' || joining) return;
        joining = true;
        let u;
        try { u = await admin.auth().verifyIdToken(m.token); } catch { reply({ t: 'err', m: 'auth' }); return ws.close(); }
        room = assignRoom(m.room);
        if (!room) { reply({ t: 'err', m: 'full' }); return ws.close(); }
        let prof = {};
        try { const ps = await users().doc(u.uid).get(); if (ps.exists) prof = ps.data(); } catch { /* papar tanpa lencana */ }
        me = { id: crypto.randomBytes(4).toString('hex'), uid: u.uid, u: uhash(u.uid), n: cleanName(m.name) || 'Pemain', av: avatar(m.avatar),
          lv: Math.floor((prof.xp || 0) / 100) + 1, cl: String(prof.className || '').slice(0, 14),
          x: 0, y: 2, z: 10, r: 0, a: 0, v: 0, ft: m.ft === true, blocks: new Set((Array.isArray(m.blocks) ? m.blocks : []).slice(0, 50).map(String)),
          last: 0, strikes: [], lockUntil: 0, ws };
        for (const [id, p] of rooms.get(room)) if (p.uid === u.uid) { p.ws.close(); rooms.get(room).delete(id); }
        rooms.get(room).set(me.id, me);
        reply({ t: 'w', id: me.id, u: me.u, radius: SAFE.chat_radius });
        return;
      }
      const tnow = now();
      if (m.t === 's') {
        me.x = num(m.x, 600); me.y = num(m.y, 100); me.z = num(m.z, 600); me.r = num(m.r, 7);
        me.a = int(m.a, 0, ANIM_MAX) ? m.a : 0; me.v = int(m.v, 0, 5) ? m.v : 0;
      } else if (m.t === 'cfg') {
        me.ft = m.ft === true; // tetapan sembang teks (selepas pintu ibu bapa di klien; BUKAN sempadan keselamatan sebenar - lihat README)
      } else if (m.t === 'q' || m.t === 'c') {
        if (tnow < me.lockUntil) return reply({ t: 'cr', why: 'locked' });
        if (tnow - me.last < SAFE.rate_limit_ms) {
          me.strikes = me.strikes.filter((x) => tnow - x < 30000); me.strikes.push(tnow);
          if (me.strikes.length >= 6) me.lockUntil = tnow + 60000;
          return reply({ t: 'cr', why: 'rate' });
        }
        let text;
        if (m.t === 'q') {
          text = SAFE.quick_phrases[m.i];
          if (!text) return;
        } else {
          if (!me.ft) return reply({ t: 'cr', why: 'text_off' });
          const r = safety.check(m.text, SAFE);
          if (!r.ok) {
            me.strikes = me.strikes.filter((x) => tnow - x < 60000); me.strikes.push(tnow);
            if (me.strikes.length >= 3) { me.lockUntil = tnow + 120000; flag(me, room, String(m.text).slice(0, 80), r.reason); }
            return reply({ t: 'cr', why: r.reason });
          }
          text = r.text;
        }
        me.last = tnow;
        const log = chatLog.get(room) || []; log.push({ u: me.u, n: me.n, m: text, at: tnow }); if (log.length > 30) log.shift(); chatLog.set(room, log);
        const radius = m.s === 'r' ? Infinity : SAFE.chat_radius;
        for (const p of rooms.get(room).values()) {
          if (p.blocks.has(me.u)) continue;
          if (Math.hypot(p.x - me.x, p.z - me.z) > radius) continue;
          reply2(p, { t: 'c', id: me.id, u: me.u, n: me.n, m: text, s: m.s === 'r' ? 'r' : 'n' });
        }
      } else if (m.t === 'rep') {
        limit('rep' + me.uid, 5, 300000);
        const target = [...rooms.get(room).values()].find((p) => p.id === m.id);
        if (!target || target.id === me.id) return;
        const reason = ['bully', 'bad', 'personal', 'other'].includes(m.why) ? m.why : 'other';
        db.collection('reports').add({ at: tnow, reporter: me.uid, target: target.uid, targetName: target.n, targetHash: target.u, room, reason,
          recent: (chatLog.get(room) || []).filter((x) => x.u === target.u).slice(-8) }).catch(() => {});
        reply({ t: 'repok' });
      }
    });
    ws.on('close', () => { if (me && room && rooms.has(room)) { rooms.get(room).delete(me.id); if (rooms.get(room).size === 0) { chatLog.delete(room); if (room.startsWith('p-')) rooms.delete(room); } } });
  });
  function reply2(p, o) { if (p.ws.readyState === 1) p.ws.send(JSON.stringify(o)); }
  function flag(me, room, text, reason) { db.collection('reports').add({ at: now(), reporter: 'auto', target: me.uid, targetName: me.n, targetHash: me.u, room, reason: 'auto_' + reason, recent: [{ m: text }] }).catch(() => {}); }

  const tick = setInterval(() => {
    for (const [, players] of rooms) {
      if (!players.size) continue;
      const list = [...players.values()].map((p) => ({ id: p.id, u: p.u, n: p.n, lv: p.lv, cl: p.cl, av: p.av, x: p.x, y: p.y, z: p.z, r: p.r, a: p.a, v: p.v }));
      const msg = JSON.stringify({ t: 'p', list });
      for (const p of players.values()) if (p.ws.readyState === 1) p.ws.send(msg);
    }
  }, 100);
  const ping = setInterval(() => { wss.clients.forEach((c) => { if (!c.isAlive) return c.terminate(); c.isAlive = false; c.ping(); }); }, 15000);
  const close = () => { clearInterval(tick); clearInterval(ping); wss.clients.forEach((c) => c.terminate()); wss.close(); server.close(); };
  return { server, wss, close, rooms };
}

module.exports = { createApp, ROLES };
