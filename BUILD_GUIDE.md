# Bina APK
Workflow `android-build.yml` (manual) menggunakan imej `barichello/godot-ci:4.3`, menjalankan `tools/ci_prepare.sh` (templates, SDK, keystore debug), import, `--export-debug "Android"`, dan memuat naik `eduverse3d.apk` serta `export.log`.
Jika gagal: buka log langkah "Prepare Godot + Android" - ralat dicetak dengan jelas (SDK/JDK/templates tiada).
Release bertandatangan: tambah secrets `KEYSTORE_BASE64`, `KEYSTORE_ALIAS`, `KEYSTORE_PASSWORD`, jalankan **Android Release**.
Ujian tempatan: Godot 4.3, buka folder, F5 (WASD, Shift lari, Space lompat, Q/E kamera).
