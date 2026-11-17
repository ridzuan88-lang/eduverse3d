# Pelayan permainan (`server/`)
Node 18+; `cd server && npm install && npm start`. Env:
| Env | Wajib | Guna |
|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | ya | JSON akaun perkhidmatan |
| `PORT` | tidak | lalai 8080 |
| `HASH_SALT` | disyorkan | rentetan rawak panjang untuk ID pemain tanpa nama (blok/lapor) |
| `DEV_PUBLISH_CODE` | pilihan | pengesahan tambahan untuk menerbitkan/memulih dunia (pembangun masukkan kod dalam panel; TIDAK disimpan dalam APK) |

## Antara muka
HTTP (Bearer token Firebase): `GET /health` (tanpa auth), `/me`, `POST /profile`, `POST /sync`, `GET /leaderboard`, `POST /class/join|leave`, `GET /announcements`, `GET|POST /house`, `GET /world`; admin: `POST /admin/class`, `/admin/announcement[/delete]`, `GET /admin/reports`, `GET /admin/world/versions|get`, `POST /admin/world/save|publish`.
WebSocket: `join{token,name,avatar,room,ft,blocks}`; `s` (keadaan, 10 Hz); `q` (ayat pantas), `c` (teks), `cfg`, `rep`. Server -> klien: `w`, `p`, `c`, `cr` (ditolak + sebab), `repok`.
Bilik awam maks 8 pemain; bilik peribadi mengikut kod. Sembang "dekat" ikut jarak (30 unit, boleh ubah dalam `safety.json`) atau "seluruh bilik".

## Deploy & kos
Contoh Render.com (root `server`, `npm install`, `npm start`; gunakan `wss://` dalam `firebase_config.cfg`). Pelan percuma tidur selepas ~15 minit; untuk pengguna sebenar gunakan pelan berbayar/VPS kecil. Trafik ~ 8 pemain x 10 mesej/s per bilik; satu contoh kecil boleh menampung beberapa bilik, tetapi **belum diukur** - lakukan ujian beban.
Satu proses sahaja: bilik disimpan dalam ingatan (tiada penskalaan mendatar tanpa kerja tambahan).

## Ujian
`npm test` menggunakan Firestore/Auth tiruan dalam ingatan (`server/test/fakes.js`). Ini menguji logik, BUKAN Firebase sebenar. **Jangan dakwa multiplayer berfungsi sebelum diuji pada dua peranti** (TESTING_CHECKLIST.md).

## Selepas ubah konfigurasi
Ubah `data/config/*.json` -> `./tools/sync_config.sh` -> commit `server/config/` (CI gagal jika tidak selari).
