# EduVerse 3D - Dunia Ilmu (CheWanNinja)
Godot 4.3 (GDScript), pakej `com.chewanninja.eduverse3d`. Dunia terbuka 3D untuk Darjah 1-6, enam subjek, mod luar talian (AI) dan dalam talian (Firebase + pelayan permainan).
Bukan penyokongan rasmi KPM.

## Langkah cepat (APK)
1. Cipta repo GitHub, muat naik SELURUH kandungan folder ini (termasuk `.github/`).
2. Edit `firebase_config.cfg` (lihat FIREBASE_SETUP.md) - boleh dibiarkan jika mahu luar talian sahaja.
3. Actions -> **Android Build** -> Run workflow.
4. Muat turun artifact `eduverse3d-apk`, pasang di telefon (benarkan "install unknown apps").

## Status sebenar (v1)
LENGKAP & diuji (headless, Godot 4.3): skrip dihuraikan tanpa ralat; aliran luar talian -> dunia -> kedai -> kuiz AI -> simpan XP/syiling -> baris gilir sync berfungsi; 36 fail soalan (324 soalan) sah.
TIDAK diuji: eksport APK (perlu Android SDK; dijalankan dalam GitHub Actions), kawalan sentuh pada telefon sebenar, paparan Jawi/Arab pada Android, Firebase, pelayan, multiplayer dua peranti.
Belum ada: sistem rakan, lapor/sekat pemain, pertandingan multiplayer (1v1, pasukan, dll.), papan pendahulu harian/mingguan/bulanan/subjek, Realtime Database (kehadiran dibuat melalui pelayan), model 3D/tekstur sebenar (semua bentuk dijana kod), seret-dan-lepas/padanan gambar.
Sebahagian sudah ada: papan pendahulu keseluruhan (XP disahkan pelayan), mesej pratetap, bilik peribadi mengikut kod, haiwan peliharaan, misi harian, peti harta parkour.
