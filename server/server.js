// Pelayan EduVerse 3D: WebSocket (bilik dunia, maks 8 pemain) + HTTP (/sync, /leaderboard, /health).
// Env: FIREBASE_SERVICE_ACCOUNT (JSON penuh akaun perkhidmatan), PORT.
const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const admin = require('firebase-admin');

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
const db = admin.firestore();
const SUBJECTS = new Set(['bm', 'en', 'math', 'sci', 'jawi', 'arab', 'mix']);
const PRESETS = ['Hai!', 'Terima kasih!', 'Bagus!', 'Jom main!', 'Hore!', 'Selamat tinggal!'];
const MAX_ROOM = 8;

const cleanName = (s) => String(s || '').replace(/[^A-Za-z0-9_]/g, '').slice(0, 16);
const send = (res, code, obj) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(obj)); };
const authReq = (req) => admin.auth().verifyIdToken((req.headers.authorization || '').replace('Bearer ', ''));
const readBody = (req) => new Promise((ok, no) => {
  let s = '';
  req.on('data', (c) => { s += c; if (s.length > 60000) { req.destroy(); no(new Error('big')); } });
  req.on('end', () => { try { ok(JSON.parse(s || '{}')); } catch (e) { no(e); } });
});
const int = (v, lo, hi) => Number.isInteger(v) && v >= lo && v <= hi;

const server = http.createServer(async (req, res) => {
  try {
    if (req.url === '/health') return send(res, 200, { ok: true });
    if (req.url === '/leaderboard') {
      await authReq(req);
      const snap = await db.collection('users').orderBy('xp', 'desc').limit(20).get();
      return send(res, 200, { list: snap.docs.map((d) => ({ name: d.get('name') || '?', xp: d.get('xp') || 0, level: Math.floor((d.get('xp') || 0) / 100) + 1 })) });
    }
    if (req.url === '/sync' && req.method === 'POST') {
      const u = await authReq(req);
      const b = await readBody(req);
      const out = { accepted: [], duplicate: [], rejected: [] };
      let gain = 0;
      for (const t of (Array.isArray(b.txs) ? b.txs : []).slice(0, 50)) {
        const ok = t && /^[0-9a-f]{8,32}$/.test(t.id || '') && SUBJECTS.has(t.subject) && int(t.year, 1, 6) &&
          int(t.total, 1, 20) && int(t.correct, 0, t.total) && int(t.xp, 0, t.correct * 10 + 20);
        if (!ok) { out.rejected.push(t && t.id ? t.id : ''); continue; }
        try {
          await db.collection('tx').doc(`${u.uid}_${t.id}`).create({ uid: u.uid, subject: t.subject, year: t.year, correct: t.correct, total: t.total, xp: t.xp, at: admin.firestore.FieldValue.serverTimestamp() });
          gain += t.xp; out.accepted.push(t.id);
        } catch (e) { if (e.code === 6) out.duplicate.push(t.id); else throw e; }
      }
      const upd = { xp: admin.firestore.FieldValue.increment(gain) };
      const nm = cleanName(b.name);
      if (nm) upd.name = nm;
      if (gain > 0 || nm) await db.collection('users').doc(u.uid).set(upd, { merge: true });
      return send(res, 200, out);
    }
    send(res, 404, {});
  } catch (e) {
    send(res, String(e.code || '').startsWith('auth') ? 401 : 400, { error: 'ralat' });
  }
});

// ---- WebSocket: bilik dunia ----
const wss = new WebSocketServer({ server, maxPayload: 2048 });
const rooms = new Map(); // nama -> Map(id -> pemain)

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
const num = (v, lim) => (Number.isFinite(v) ? Math.max(-lim, Math.min(lim, v)) : 0);
const avatar = (a) => { const o = {}; for (const k of ['gender', 'skin', 'shirt', 'hair', 'hat', 'pack', 'pet']) o[k] = int(a && a[k], 0, 9) ? a[k] : 0; return o; };

wss.on('connection', (ws) => {
  let me = null, room = null, joining = false;
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });
  ws.on('message', async (raw) => {
    let m; try { m = JSON.parse(raw); } catch { return; }
    if (!me) {
      if (m.t !== 'join' || joining) return;
      joining = true;
      let u;
      try { u = await admin.auth().verifyIdToken(m.token); } catch { ws.send(JSON.stringify({ t: 'err', m: 'auth' })); return ws.close(); }
      room = assignRoom(m.room);
      if (!room) { ws.send(JSON.stringify({ t: 'err', m: 'full' })); return ws.close(); }
      me = { id: crypto.randomBytes(4).toString('hex'), uid: u.uid, n: cleanName(m.name) || 'Pemain', av: avatar(m.avatar), x: 0, y: 2, z: 10, r: 0, a: 0, m: '', mt: 0 };
      for (const [id, p] of rooms.get(room)) if (p.uid === u.uid) { p.ws.close(); rooms.get(room).delete(id); }
      me.ws = ws;
      rooms.get(room).set(me.id, me);
      ws.send(JSON.stringify({ t: 'w', id: me.id }));
      return;
    }
    if (m.t === 's') { me.x = num(m.x, 600); me.y = num(m.y, 100); me.z = num(m.z, 600); me.r = num(m.r, 7); me.a = int(m.a, 0, 3) ? m.a : 0; }
    else if (m.t === 'e' && int(m.i, 0, PRESETS.length - 1)) { me.m = PRESETS[m.i]; me.mt = Date.now(); }
  });
  ws.on('close', () => { if (me && room && rooms.has(room)) { rooms.get(room).delete(me.id); if (rooms.get(room).size === 0 && room.startsWith('p-')) rooms.delete(room); } });
});

setInterval(() => {
  const now = Date.now();
  for (const [, players] of rooms) {
    if (!players.size) continue;
    const list = [...players.values()].map((p) => ({ id: p.id, n: p.n, av: p.av, x: p.x, y: p.y, z: p.z, r: p.r, a: p.a, m: now - p.mt < 3000 ? p.m : '' }));
    const msg = JSON.stringify({ t: 'p', list });
    for (const p of players.values()) if (p.ws.readyState === 1) p.ws.send(msg);
  }
}, 100);
setInterval(() => { wss.clients.forEach((c) => { if (!c.isAlive) return c.terminate(); c.isAlive = false; c.ping(); }); }, 15000);

server.listen(process.env.PORT || 8080, () => console.log('EduVerse server siap'));
