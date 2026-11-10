#!/usr/bin/env python3
"""Menjana bank soalan permulaan: data/questions/<subjek>_d<tahun>.json  (36 fail).
Tambah soalan baru: ubah jadual di bawah atau tambah objek JSON terus ke fail (lihat GAME_CONTENT_GUIDE.md)."""
import json, os, random
random.seed(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "questions")
os.makedirs(OUT, exist_ok=True)
DIFFS = ["easy", "easy", "medium", "medium", "hard", "hard"]

def mk(subj, year, n, topic, diff, text, correct, wrongs, expl, xp=10):
    opts = [correct] + list(wrongs)[:3]
    random.shuffle(opts)
    return {"id": f"{subj}-{year}-{n:03d}", "subject": subj, "year": year, "topic": topic, "difficulty": diff,
            "type": "mcq", "question": text, "options": opts, "answer": opts.index(correct), "explanation": expl, "xp": xp}

def near(c, k=3):
    s = set()
    while len(s) < k:
        v = c + random.choice([-5, -3, -2, -1, 1, 2, 3, 5, 10])
        if v != c and v >= 0: s.add(v)
    return [str(x) for x in s]

def math_q(y, n):
    d = "easy" if n < 8 else "medium" if n < 16 else "hard"
    r = random.randint
    if y == 1:
        if d == "easy": a, b = r(1, 5), r(1, 5); t, c, e = f"Berapakah {a} + {b}?", a + b, "Tambah"
        elif d == "medium": a, b = r(5, 12), r(3, 8); t, c, e = f"Berapakah {a} + {b}?", a + b, "Tambah"
        else: a = r(10, 20); b = r(1, a); t, c, e = f"Berapakah {a} - {b}?", a - b, "Tolak"
        topic = "Operasi asas"
    elif y == 2:
        if d == "easy": a, b = r(10, 40), r(5, 30); t, c, e = f"Berapakah {a} + {b}?", a + b, "Tambah"
        elif d == "medium": a = r(40, 99); b = r(10, a); t, c, e = f"Berapakah {a} - {b}?", a - b, "Tolak"
        else: a, b = random.choice([2, 5, 10]), r(2, 9); t, c, e = f"Berapakah {a} x {b}?", a * b, "Darab"
        topic = "Tambah, tolak, darab"
    elif y == 3:
        if d == "easy": a, b = r(2, 9), r(2, 9); t, c, e = f"Berapakah {a} x {b}?", a * b, "Sifir"
        elif d == "medium": b, c0 = r(2, 9), r(2, 9); t, c, e = f"Berapakah {b*c0} / {b}?", c0, "Bahagi ialah songsangan darab"
        else: a, b = r(11, 30), r(2, 5); t, c, e = f"Berapakah {a} x {b}?", a * b, "Darab dua digit"
        topic = "Darab dan bahagi"
    elif y == 4:
        if d == "easy": a, b = r(11, 15), r(6, 12); t, c, e = f"Berapakah {a} x {b}?", a * b, "Darab"
        elif d == "medium": b = random.choice([2, 4, 5]); k = r(2, 10); t, c, e = f"1/{b} daripada {b*k} ialah?", k, "Bahagi dengan penyebut"
        else:
            a, b = r(1, 9), r(1, 9); c = f"{(a*10+b)/10 + 0:.1f}"; x, y2 = r(10, 30) / 10, r(10, 30) / 10
            t, c, e = f"Berapakah {x:.1f} + {y2:.1f}?", f"{x+y2:.1f}", "Tambah perpuluhan"
        topic = "Pecahan dan perpuluhan"
    elif y == 5:
        if d == "easy": a = r(2, 20) * 10; t, c, e = f"10% daripada {a} ialah?", a // 10, "10% = bahagi 10"
        elif d == "medium": den = r(5, 12); a, b = r(1, 4), r(1, 4); t, c, e = f"{a}/{den} + {b}/{den} = ?", f"{a+b}/{den}", "Tambah pengangka"
        else: p, l = r(3, 12), r(3, 12); t, c, e = f"Luas segi empat tepat panjang {p} cm dan lebar {l} cm (cm persegi)?", p * l, "Luas = panjang x lebar"
        topic = "Peratus, pecahan, luas"
    else:
        if d == "easy":
            import math as _m
            while True:
                a, b = r(1, 5), r(1, 5)
                if a != b and _m.gcd(a, b) == 1: break
            k = r(2, 5); t, c, e = f"Permudahkan nisbah {a*k}:{b*k}", f"{a}:{b}", "Bahagi dengan faktor sepunya"
        elif d == "medium": a, b, c0 = r(2, 9) * 3, r(2, 9) * 3, r(2, 9) * 3; t, c, e = f"Min bagi {a}, {b} dan {c0} (bundarkan ke nombor bulat)?", round((a + b + c0) / 3), "Min = jumlah / bilangan"
        else: b, h = r(2, 10) * 2, r(2, 10); t, c, e = f"Luas segi tiga tapak {b} cm dan tinggi {h} cm (cm persegi)?", b * h // 2, "Luas = 1/2 x tapak x tinggi"
        topic = "Nisbah, min, luas"
    if isinstance(c, str):
        if "/" in c:
            num, den = map(int, c.split("/")); w = [f"{num+1}/{den}", f"{max(1,num-1)}/{den}", f"{num}/{den+1}"]
        elif ":" in c:
            a2, b2 = map(int, c.split(":")); w = [f"{b2}:{a2}", f"{a2+1}:{b2}", f"{a2}:{b2+1}"]
        else:
            w = [f"{float(c)+d2:.1f}" for d2 in (0.1, -0.1, 1.0)]
    else:
        w = near(int(c))
    return mk("math", y, n, topic, d, t, str(c), w, e + ": jawapan ialah " + str(c) + ".")

# Jadual pasangan (soalan, jawapan): satu kumpulan setiap peringkat (Darjah 1-2, 3-4, 5-6). Jawapan dalam satu kumpulan sejenis.
Q = lambda p, items: [(p.format(k), v) for k, v in items]
T = {
 "bm": ("Bahasa Melayu", [
  ("Antonim", Q("Lawan bagi '{}' ialah?", [("besar","kecil"),("panas","sejuk"),("tinggi","rendah"),("siang","malam"),("cantik","hodoh"),("laju","perlahan"),("tebal","nipis"),("kenyang","lapar")])),
  ("Simpulan bahasa", Q("Maksud simpulan bahasa '{}' ialah?", [("panjang tangan","suka mencuri"),("ringan tulang","rajin"),("besar kepala","sombong"),("berat tulang","malas"),("buah hati","kekasih"),("kepala batu","degil"),("makan angin","bersiar-siar"),("mulut manis","pandai bercakap manis")])),
  ("Peribahasa", Q("Maksud peribahasa '{}' ialah?", [("Bagai aur dengan tebing","saling bergantung"),("Alah bisa tegal biasa","perkara biasa dilakukan menjadi mudah"),("Bagai kucing dengan anjing","selalu bergaduh"),("Berat sama dipikul, ringan sama dijinjing","bekerjasama dalam susah dan senang"),("Hendak seribu daya","sentiasa ada jalan jika berusaha"),("Bersatu teguh, bercerai roboh","perpaduan membawa kekuatan"),("Malu bertanya sesat jalan","orang tidak bertanya tidak akan tahu"),("Rajin pangkal pandai","kerajinan membawa kepada kepandaian")]))]),
 "en": ("Bahasa Inggeris", [
  ("Opposites", Q("What is the opposite of '{}'?", [("hot","cold"),("big","small"),("up","down"),("day","night"),("happy","sad"),("fast","slow"),("open","close"),("tall","short")])),
  ("Plurals", Q("What is the plural of '{}'?", [("child","children"),("mouse","mice"),("foot","feet"),("tooth","teeth"),("man","men"),("woman","women"),("leaf","leaves"),("goose","geese")])),
  ("Past tense", Q("What is the past tense of '{}'?", [("go","went"),("eat","ate"),("see","saw"),("buy","bought"),("swim","swam"),("write","wrote"),("take","took"),("bring","brought")]))]),
 "sci": ("Sains", [
  ("Deria dan anggota", Q("{} digunakan untuk?", [("Mata","melihat"),("Hidung","menghidu"),("Telinga","mendengar"),("Lidah","merasa"),("Kulit","menyentuh"),("Kaki","berjalan"),("Tangan","memegang"),("Gigi","mengunyah")])),
  ("Sistem Suria", Q("{}", [("Planet terbesar dalam Sistem Suria?","Musytari"),("Planet paling hampir dengan Matahari?","Utarid"),("Planet yang dikenali sebagai Planet Merah?","Marikh"),("Planet tempat kita tinggal?","Bumi"),("Planet yang mempunyai cincin yang jelas?","Zuhal"),("Planet paling jauh dari Matahari?","Neptun"),("Planet paling panas?","Zuhrah"),("Planet ketujuh dari Matahari?","Uranus")])),
  ("Sistem badan", Q("{} ialah sebahagian sistem?", [("Jantung","peredaran darah"),("Paru-paru","pernafasan"),("Perut","pencernaan"),("Otak","saraf"),("Tulang","rangka"),("Buah pinggang","perkumuhan"),("Trakea","pernafasan"),("Tulang belakang","rangka")]))]),
 "jawi": ("Jawi", [
  ("Huruf Jawi", Q("Apakah nama huruf Jawi ini?  {}", [("ا","Alif"),("ب","Ba"),("ت","Ta"),("ج","Jim"),("د","Dal"),("ر","Ra"),("س","Sin"),("م","Mim")])),
  ("Huruf Jawi tambahan", Q("Apakah nama huruf Jawi ini?  {}", [("ڠ","Nga"),("ڤ","Pa"),("چ","Cha"),("ݢ","Ga"),("ڽ","Nya"),("ۏ","Va"),("ك","Kaf"),("ي","Ya")])),
  ("Baca Jawi", Q("Apakah perkataan Rumi bagi  {}", [("رومه","rumah"),("ماكن","makan"),("ايكن","ikan"),("بولن","bulan"),("بوكو","buku"),("سكوله","sekolah"),("كوچيڠ","kucing"),("ڤنسيل","pensel")]))]),
 "arab": ("Bahasa Arab", [
  ("Huruf Hijaiyah", Q("Apakah nama huruf Hijaiyah ini?  {}", [("ا","Alif"),("ب","Ba'"),("ت","Ta'"),("ث","Tha'"),("ج","Jim"),("ح","Ha'"),("خ","Kho'"),("د","Dal")])),
  ("Kosa kata", Q("Apakah maksud perkataan Arab ini?  {}", [("كتاب","buku"),("قلم","pen"),("باب","pintu"),("بيت","rumah"),("مدرسة","sekolah"),("ماء","air"),("شمس","matahari"),("قمر","bulan")])),
  ("Kosa kata 2", Q("Apakah maksud perkataan Arab ini?  {}", [("أب","ayah"),("أم","ibu"),("معلم","guru"),("طالب","pelajar"),("مسجد","masjid"),("سيارة","kereta"),("كرسي","kerusi"),("مكتب","meja")]))]),
}

total = 0
for y in range(1, 7):
    tier = (y - 1) // 2
    for code in ["bm", "en", "sci", "jawi", "arab"]:
        topic, items = T[code][1][tier]
        sl = items[0:6] if y % 2 == 1 else items[2:8]
        answers = sorted({a for _, a in items})
        qs = []
        for n, (qt, ans) in enumerate(sl):
            wrongs = random.sample([a for a in answers if a != ans], 3)
            qs.append(mk(code, y, n, topic[0] if False else T[code][1][tier][0], DIFFS[n], qt, ans, wrongs, f"Jawapan: {ans}."))
        json.dump(qs, open(os.path.join(OUT, f"{code}_d{y}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        total += len(qs)
    qs = [math_q(y, n) for n in range(24)]
    json.dump(qs, open(os.path.join(OUT, f"math_d{y}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    total += len(qs)
print("Jumlah soalan:", total)
