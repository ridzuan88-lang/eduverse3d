# Firebase
1. console.firebase.google.com -> projek baharu -> Authentication -> aktifkan Email/Password.
2. Project settings -> Web API key -> letak di `firebase_config.cfg` (`api_key`). Jangan reka kunci.
3. Firestore Database (mod production) -> salin `firebase/firestore.rules` ke tab Rules. Klien TIDAK boleh menulis; hanya pelayan (Admin SDK).
4. Realtime Database tidak digunakan v1 (`firebase/database.rules.json` menolak semua akses).
5. Project settings -> Service accounts -> Generate key (JSON) -> letak sebagai env `FIREBASE_SERVICE_ACCOUNT` pada pelayan SAHAJA. Jangan masuk dalam repo/APK.
Kos: pelan Spark percuma cukup untuk ujian (had harian Firestore terpakai).
