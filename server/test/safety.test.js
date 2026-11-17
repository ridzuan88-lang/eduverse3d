'use strict';
const assert = require('assert');
const { check } = require('../lib/safety');
const cfg = require('../config/safety.json');
const ok = (s) => assert.strictEqual(check(s, cfg).ok, true, 'sepatutnya LULUS: ' + s);
const no = (s, why) => { const r = check(s, cfg); assert.strictEqual(r.ok, false, 'sepatutnya DITOLAK: ' + s); if (why) assert.strictEqual(r.reason, why, s + ' -> ' + r.reason); };
// Lulus
['Hai kawan!', 'Jom main lumba kereta', 'Terima kasih ya', 'I got 8 out of 10!', 'Siapa nak belajar sains?', 'Hello everyone', 'Saya suka matematik', 'Kelas 3 Bestari hebat'].forEach(ok);
// Maklumat peribadi
no('call me 0123456789', 'personal'); no('no saya 012 345 6789', 'personal'); no('+60 12-345 6789', 'personal');
no('email saya a@b.com', 'personal'); no('lawati www.example.com', 'personal'); no('kosong satu dua tiga empat lima enam', 'personal');
no('add my instagram', 'personal'); no('alamat rumah saya di lorong 5', 'personal'); no('my address is 5 Jalan', 'personal');
// Kata kesat / ejekan (termasuk helah)
no('kau bodoh', 'bad'); no('you are stupid', 'bad'); no('st.u.p.i.d', 'bad'); no('b4b1', 'bad'); no('stuuuupid', 'bad'); no('you idiot', 'bad'); no('f u c k', 'bad');
// Ugutan
no('aku bunuh kau', 'threat'); no('go die', 'threat'); no('i will kill you', 'threat');
// Panjang / kosong
no('', 'empty'); no('   ', 'empty'); no('a'.repeat(61), 'long');
// Tiada positif palsu pada perkataan biasa
['Saya suka kelas', 'Class assignment', 'Assistant', 'Passport kita', 'Hit the target'].forEach(ok);
console.log('safety.test.js: semua lulus');
