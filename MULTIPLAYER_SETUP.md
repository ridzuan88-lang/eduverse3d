# Pelayan permainan (`server/`)
Node 18+, `npm install`, env `FIREBASE_SERVICE_ACCOUNT` (JSON), `npm start`. Endpoint: WebSocket (bilik dunia maks 8, bilik peribadi mengikut kod), `GET /health`, `GET /leaderboard`, `POST /sync`.
Deploy contoh: Render.com Web Service (root `server`, build `npm install`, start `npm start`). Pelan percuma tidur selepas ~15 minit tidak aktif (sambungan pertama lambat) dan ada had jam; untuk anak-anak ramai gunakan pelan berbayar/VPS kecil. Gunakan `wss://` dalam `firebase_config.cfg`.
Pengesahan sync: token Firebase disahkan, ID transaksi unik (anti-pendua), had XP munasabah per kuiz. Ini pengesahan kemungkinan, BUKAN kuiz berautoriti pelayan sepenuhnya - sebab itu skor luar talian hanya menambah XP keseluruhan.
JANGAN dakwa multiplayer berfungsi sebelum diuji pada dua peranti.
