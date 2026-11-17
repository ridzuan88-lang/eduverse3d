'use strict';
// Pangkalan data Firestore + Auth palsu dalam ingatan (cukup untuk ujian logik pelayan; BUKAN pengganti ujian Firebase sebenar).
const clone = (o) => (o === undefined ? undefined : JSON.parse(JSON.stringify(o)));
const getField = (o, path) => path.split('.').reduce((x, k) => (x == null ? undefined : x[k]), o);

function makeDb() {
  const store = new Map();
  let auto = 0;
  const opts = { failCompositeIndex: false };
  class Snap { constructor(id, data) { this.id = id; this._d = data; this.exists = data !== undefined; } data() { return clone(this._d); } }
  class DocRef {
    constructor(col, id) { this.col = col; this.id = id; this.path = col + '/' + id; }
    async get() { return new Snap(this.id, store.get(this.path)); }
    async set(d, o) { store.set(this.path, o && o.merge ? { ...(store.get(this.path) || {}), ...clone(d) } : clone(d)); }
    async create(d) { if (store.has(this.path)) { const e = new Error('exists'); e.code = 6; throw e; } store.set(this.path, clone(d)); }
    async delete() { store.delete(this.path); }
  }
  class Query {
    constructor(col, w = [], ob = null, lim = 1e9) { this.col = col; this.w = w; this.ob = ob; this.lim = lim; }
    where(f, op, v) { return new Query(this.col, [...this.w, [f, v]], this.ob, this.lim); }
    orderBy(f, dir) { return new Query(this.col, this.w, [f, dir || 'asc'], this.lim); }
    limit(n) { return new Query(this.col, this.w, this.ob, n); }
    async get() {
      if (opts.failCompositeIndex && this.w.length && this.ob) { const e = new Error('index'); e.code = 9; throw e; }
      let docs = [...store.entries()].filter(([p]) => p.startsWith(this.col + '/') && !p.slice(this.col.length + 1).includes('/'))
        .map(([p, d]) => ({ id: p.slice(this.col.length + 1), d }));
      for (const [f, v] of this.w) docs = docs.filter((x) => getField(x.d, f) === v);
      if (this.ob) {
        docs = docs.filter((x) => getField(x.d, this.ob[0]) !== undefined);
        docs.sort((a, b) => { const A = getField(a.d, this.ob[0]), B = getField(b.d, this.ob[0]); return (A < B ? -1 : A > B ? 1 : 0) * (this.ob[1] === 'desc' ? -1 : 1); });
      }
      docs = docs.slice(0, this.lim).map((x) => new Snap(x.id, x.d));
      return { docs, empty: docs.length === 0, size: docs.length };
    }
  }
  class Col extends Query {
    constructor(name) { super(name); }
    doc(id) { return new DocRef(this.col, id); }
    async add(d) { const id = 'auto' + (++auto); await new DocRef(this.col, id).set(d); return { id }; }
  }
  return {
    _store: store, opts,
    collection: (n) => new Col(n),
    async runTransaction(fn) {
      const writes = [];
      const t = {
        get: (ref) => ref.get(), getAll: (...refs) => Promise.all(refs.map((r) => r.get())),
        set: (r, d, o) => writes.push(() => r.set(d, o)), create: (r, d) => writes.push(() => r.create(d)), delete: (r) => writes.push(() => r.delete()),
      };
      const out = await fn(t);
      for (const w of writes) await w();
      return out;
    },
  };
}

function makeAdmin(tokens) {
  return { auth: () => ({ verifyIdToken: async (t) => { if (!tokens[t]) { const e = new Error('bad'); e.code = 'auth/x'; throw e; } return tokens[t]; } }) };
}
module.exports = { makeDb, makeAdmin };
