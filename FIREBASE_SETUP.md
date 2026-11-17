# Firebase
1. console.firebase.google.com -> projek baharu -> Authentication -> aktifkan Email/Password.
2. Project settings -> Web API key -> letak di `firebase_config.cfg` (`api_key`). (Kunci web memang boleh ada dalam APK; keselamatan datang daripada peraturan + pelayan.)
3. Firestore Database (mod production) -> tab Rules -> salin `firebase/firestore.rules` (klien tidak boleh menulis; hanya pelayan melalui Admin SDK).
4. **Indeks**: salin `firebase/firestore.indexes.json` (`firebase deploy --only firestore:indexes`) untuk papan Darjah/Kelas. Tanpa indeks pelayan jatuh balik kepada isihan dalam ingatan (maks 300 pemain) - berfungsi tetapi tidak sesuai untuk ramai.
5. Realtime Database tidak digunakan (`firebase/database.rules.json` menolak semua akses).
6. Project settings -> Service accounts -> Generate key -> letak JSON penuh sebagai env `FIREBASE_SERVICE_ACCOUNT` pada pelayan SAHAJA. Jangan letak dalam repo/APK.

## Peranan (Mod Pembangun / Moderator)
Peranan ialah Firebase **custom claim** `role` = `super_admin` | `world_dev` | `moderator`. Pelayan menyemaknya pada setiap permintaan; butang dalam APK tidak memberi kuasa.
```
FIREBASE_SERVICE_ACCOUNT='{...}' node tools/set_role.js emel@anda.com super_admin
```
(Jalankan di komputer anda selepas `cd server && npm install`.) Pengguna perlu log keluar & masuk semula. Kebenaran: super_admin = semua; world_dev = editor dunia + pengumuman; moderator = pengumuman, laporan, cipta kelas.

## Koleksi Firestore (ditulis oleh pelayan)
`users` (profil, xp, st.<subjek>, wk.<minggu>, mo.<bulan>, kelas), `names` (tempahan nama samaran), `tx` (rekod ganjaran kuiz), `classes`, `announcements`, `reports`, `houses`, `worlds` (versi dunia + `meta.live`).

## Kos
Spark percuma cukup untuk ujian. Sumber kos: baca papan pendahulu (cache 30s di pelayan), tulis `users` setiap kuiz, `worlds` (dokumen sehingga ~250KB). Pantau kuota Firestore sebelum pelancaran awam.
