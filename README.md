# EduVerse 3D - Dunia Ilmu (CheWanNinja)
Godot 4.3 (GDScript), pakej `com.chewanninja.eduverse3d`. Dunia terbuka 3D untuk Darjah 1-6, enam subjek, mod luar talian (AI) dan dalam talian (Firebase + pelayan permainan). Bukan penyokongan rasmi KPM.

## Langkah cepat (APK)
1. Muat naik SELURUH kandungan folder ini ke repo GitHub (termasuk `.github/`). **Padam folder lama `eduverse3d/` di dalam repo jika ada** (salinan lapuk dengan `project.godot` sendiri).
2. Edit `firebase_config.cfg` (lihat FIREBASE_SETUP.md) - boleh dibiarkan untuk luar talian sahaja.
3. Actions -> **Android Build** -> Run workflow. Ia menjalankan ujian pelayan, ujian asap Godot, kemudian eksport APK. Muat turun artifact `eduverse3d-apk`.

Dokumen lain: `FIREBASE_SETUP.md`, `MULTIPLAYER_SETUP.md`, `DEVELOPER_MODE.md`, `TESTING_CHECKLIST.md`, `BUILD_GUIDE.md`.

## Status ciri (jujur)
Legenda: **Ada** = dilaksanakan & diuji dengan cara yang dinyatakan | **Separa** = sebahagian | **Belum** = tiada kod (jangan anggap berfungsi).

| Ciri | Status | Nota |
|---|---|---|
| Sembang pantas (ayat pratetap BM/EN) | Ada | Diuji pada pelayan (2 klien WS simulasi) |
| Sembang teks bebas | Ada | Mati secara lalai; dibuka melalui "pintu ibu bapa" (soalan matematik). Penapis pelayan: nombor telefon, e-mel, pautan, alamat, kata kesat BM/EN, ugutan |
| Mesej peribadi (DM) | Tiada (sengaja) | Dimatikan untuk akaun kanak-kanak |
| Senyap / Sekat / Lapor | Ada | Lapor disimpan dengan 8 mesej terakhir sebagai bukti; moderator baca melalui panel Pentadbir |
| Gelembung ucapan, emote (9), duduk, baring | Ada | Diuji tanpa kepala; **rupa visual belum dilihat pada skrin sebenar** |
| Avatar lebih terperinci | Separa | Muka, kening, 5 gaya rambut, kasut, aksesori, peralihan animasi lembut. Masih gaya low-poly dari bentuk kod - **bukan realistik**; tiada model 3D luar |
| Animasi: idle, jalan, lari, pecut, lompat, jatuh, mendarat, duduk, baring, bawa objek, memandu, naik motosikal | Ada | "Bawa objek" = semasa memegang objek dalam editor. Penumpang/animasi masuk-keluar kenderaan: **Belum** |
| Papan notis | Ada | Berita/Misi/Acara/Pemain teratas/Pencapaian; cache luar talian; terbit melalui panel Pentadbir. 7 papan di dunia |
| Kelas + kod kelas | Ada | Guru/pentadbir cipta kelas dalam panel Pentadbir. Papan pemuka guru: **Belum** |
| Papan pendahulu (11 kategori) | Ada | Keseluruhan, Darjah, Kelas, 6 subjek, Mingguan, Bulanan. Hanya XP disahkan pelayan |
| Kuiz campuran dalam kedudukan subjek | Belum | Kuiz "campuran" hanya kira ke kedudukan keseluruhan |
| Ekonomi syiling (boleh ubah) | Ada | `data/config/economy.json`; had harian; anti-ternak soalan sama 24 jam |
| Pembelian syiling dengan wang sebenar | Tiada (sengaja) | |
| Pembelian disahkan pelayan | **Belum** | Perbelanjaan syiling ialah setempat (sejarah transaksi setempat). Ganjaran kuiz dikira & disahkan pelayan |
| Rumah pemain (tanah, bina, perabot, pintu/lampu/duduk/katil, kolam zon khas) | Ada | Simpan setempat + pelayan (disahkan katalog/sempadan/kolam/had). Privasi: peribadi/awam + lawat nama. "Rakan sahaja": **Belum** (tiada sistem rakan) |
| Kawalan bina: pilih, alih, putar, skala, letak, padam, buat asal/semula, grid | Ada | Anak panah atas skrin (bukan seret-terus) |
| Mini-game: Sasaran (latihan/masa/1v1 Robot) | Ada | Peluru cat, tiada keganasan |
| Mini-game: Lumba (5 litar, 4 kenderaan, 3-2-1, pusat semak berturutan, pusingan, kedudukan, ganjaran) | Ada | Lawan 3 Robot AI. Pengesahan masa mustahil (setempat) |
| Sasaran/lumba **berbilang pemain**, pasukan, bilik | **Belum** | Perlu pelayan berautoriti |
| Mini-game lain (halangan, harta karun, teka-teki...) | **Belum** | Disenaraikan "akan datang" |
| Kenderaan: kereta, motosikal, bas, go-kart, kenderaan fantasi | Ada | Basikal: **Belum** |
| Sistem penumpang | **Belum** | Perlu kenderaan berautoriti pelayan. Kenderaan dunia kini disimulasi setempat |
| Garaj / spawn kenderaan / simpan | Separa | Buka kunci kenderaan lumba dengan syiling; spawn bebas: **Belum** |
| Mod Pembangun (peranan disahkan pelayan) | Ada | super_admin / world_dev melalui Firebase custom claim; kod terbit tambahan pilihan |
| Editor dunia: letak/alih/putar/skala/padam, perpustakaan 32 objek, kamera bebas, terbang/tembus dinding, teleport, masa, cuaca | Ada | |
| Simpan draf / versi / terbit (dengan pengesahan) / pulih / eksport / import | Ada | Diuji pada pelayan; **laluan klien->pelayan penuh belum diuji dengan Firebase sebenar** |
| Editor rupa bumi (naik/turun/cat) | **Belum** | Ada objek bukit/gunung/tasik/sungai sebagai ganti |
| Editor jalan | Separa | Kepingan jalan modular, simpang, bulatan, kaki lima, papan tanda, lampu. Tiada had laju/penjana litar |
| Pilih berbilang objek, optimum perlanggaran | **Belum** | LOD asas: jarak penglihatan 170m |
| NPC berjalan, peta dunia, minimap | **Belum** | Navigasi melalui menu "Pergi ke" |
| Sembang suara | **Belum** | Reka bentuk: mesej sembang ialah acara berasingan; suara perlu perkhidmatan WebRTC berasingan + kawalan ibu bapa. Tiada kod suara |
| Mod luar talian | Ada | Skor/XP/syiling luar talian disimpan berasingan (`off_xp`), tidak dihantar, tidak masuk kedudukan |

## Perubahan tingkah laku (perlu tahu)
- XP/syiling luar talian **tidak lagi** dimasukkan ke kedudukan global (sebelum ini baris gilir sync memuat naik keputusan luar talian apabila log masuk). Baris gilir lama dibuang oleh pelayan.
- Pelayan **mengira semula** XP/syiling daripada kiraan jawapan betul mengikut kesukaran (klien tidak boleh menghantar XP sendiri).
- Syiling kutipan dunia ada had harian (60); kuiz (400); mini-game (150). Soalan yang sama dijawab betul dalam 24 jam tiada ganjaran.
- Nama samaran dalam talian ditempah di pelayan (unik + ditapis).
- `server.js` di akar dibuang (salinan sama dengan `server/server.js`).

## Had keselamatan yang JUJUR
- Soalan & jawapan ada dalam APK, jadi klien yang diubah suai boleh menipu bilangan jawapan betul. Pelayan hanya menyemak kemunasabahan (kelajuan minimum, had harian, ID unik). Anti-tipu sebenar memerlukan pelayan menghantar soalan & menyemak jawapan (belum ada).
- "Pintu ibu bapa" ialah halangan ringan, bukan keselamatan; tetapan teks bebas dihantar oleh klien. Untuk produksi, simpan persetujuan ibu bapa pada akaun ibu bapa di pelayan.
- Penapis kata kunci tidak sempurna. Sentiasa semak laporan; tambah perkataan dalam `data/config/safety.json` (kemudian `tools/sync_config.sh`).
- Belum ada semakan privasi/undang-undang (PDPA/COPPA) - lakukan sebelum pelancaran kepada kanak-kanak.

## Ujian
- Pelayan: `cd server && npm install && npm test` (23 kumpulan: auth, ganjaran, had, papan pendahulu, kelas, pengumuman, rumah, dunia/peranan, sembang WS).
- Godot (tanpa kepala): `godot --headless --import` kemudian `godot --headless res://tools/SmokeTest.tscn` (127 semakan: semua skrip dimuat, penapis klien = pelayan, ekonomi, pemisahan luar/dalam talian, avatar, dunia, duduk, editor rumah, pintu/lampu/katil, panel, cuaca, 2 mini-game x 5 litar). Mesej `mesh_get_surface_count` ialah bunyi pemapar tiruan Godot tanpa kepala (juga muncul pada kod asal).
- **Belum diuji**: eksport APK, sentuhan pada telefon, paparan/susun atur UI pada pelbagai nisbah skrin (kedudukan butang editor ditetapkan untuk 1280x720 melintang), Firebase sebenar, dua peranti.
