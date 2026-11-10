# Tambah kandungan
Fail: `data/questions/<subjek>_d<tahun>.json` (subjek: bm, en, math, sci, jawi, arab). Setiap soalan: id unik, subject, year, topic, difficulty (easy|medium|hard), type "mcq", question, options (4), answer (indeks), explanation, xp (10).
`tools/gen_questions.py` menjana bank permulaan (324 soalan) - ubah jadual atau tambah objek JSON terus. Soalan Bahasa Melayu/Inggeris berjawapan satu perkataan juga muncul sebagai Susun Huruf.
Semak ketepatan kandungan (terutama Jawi/Arab) dengan guru sebelum diedarkan. Untuk Arab/Jawi, letak fon (cth. Noto Naskh Arabic) di `assets/fonts/` dan tetapkan sebagai fon lalai jika glyph tidak muncul pada telefon.
