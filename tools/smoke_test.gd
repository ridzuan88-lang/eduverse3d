extends Node
# Ujian asap tanpa kepala:  godot --headless --path . res://tools/SmokeTest.tscn   (perlu `godot --headless --import` dahulu)
# 1) semua skrip dimuat tanpa ralat huraian  2) penapis sembang  3) ekonomi  4) pemisahan luar talian/dalam talian  5) (jika wujud) ujian tambahan

var fails := 0
var passed := 0

func ok(c: bool, msg: String) -> void:
    if c:
        passed += 1
    else:
        fails += 1
        printerr("GAGAL: ", msg)

func _scan(dir: String, out: Array) -> void:
    for f in DirAccess.get_files_at(dir):
        if f.ends_with(".gd"):
            out.append(dir.path_join(f))
    for d in DirAccess.get_directories_at(dir):
        _scan(dir.path_join(d), out)

func _ready() -> void:
    var scripts: Array = []
    _scan("res://scripts", scripts)
    for p in scripts:
        var s = load(p)
        ok(s != null and s is GDScript, "muat " + p)
    print("skrip dimuat: ", scripts.size())
    _test_safety()
    _test_economy()
    _test_separation()
    _test_avatar()
    for extra in ["res://tools/smoke_extra.gd"]:
        if ResourceLoader.exists(extra):
            await load(extra).new().run(self)
    print("LULUS: %d  GAGAL: %d" % [passed, fails])
    get_tree().quit(1 if fails > 0 else 0)

func _test_safety() -> void:
    for t in ["Hai kawan!", "Jom main lumba kereta", "Terima kasih ya", "I got 8 out of 10!", "Siapa nak belajar sains?", "Saya suka matematik", "Class assignment", "Assistant", "Hit the target", "Saya suka kelas"]:
        ok(Safety.check(t).ok, "sepatutnya lulus: " + t)
    var bad := {"call me 0123456789": "personal", "+60 12-345 6789": "personal", "email saya a@b.com": "personal", "lawati www.example.com": "personal",
        "kosong satu dua tiga empat lima enam": "personal", "add my instagram": "personal", "alamat rumah saya di lorong 5": "personal",
        "kau bodoh": "bad", "you are stupid": "bad", "st.u.p.i.d": "bad", "b4b1": "bad", "stuuuupid": "bad", "f u c k": "bad",
        "aku bunuh kau": "threat", "go die": "threat", "i will kill you": "threat", "": "empty", "   ": "empty"}
    for t in bad:
        var r := Safety.check(t)
        ok(not r.ok and r.reason == bad[t], "sepatutnya ditolak (%s): %s -> %s" % [bad[t], t, str(r)])
    ok(Safety.check("a".repeat(61)).reason == "long", "terlalu panjang")

func _test_economy() -> void:
    var res := [
        {"id": "t1", "diff": "easy", "right": true, "secs": 9.0}, {"id": "t2", "diff": "medium", "right": true, "secs": 9.0},
        {"id": "t3", "diff": "hard", "right": true, "secs": 9.0}, {"id": "t4", "diff": "hard", "right": false, "secs": 9.0}]
    Game.d = Game.fresh()
    var r := Economy.quiz_rewards(res, false)
    # xp = 10+15+20 + selesai 10 = 55 (purata 9s: tiada bonus laju) ; syiling = 5+10+15 + 20 = 50
    ok(int(r.xp) == 55 and int(r.coins) == 50, "ganjaran kuiz: " + str(r))
    ok(not bool(r.perfect), "tidak sempurna")
    # soalan sama dalam 24 jam -> tiada ganjaran
    var r2 := Economy.quiz_rewards(res, false)
    ok(int(r2.repeats) == 3 and int(r2.xp) == 10, "anti-ternak soalan: " + str(r2))
    # had harian syiling kuiz
    Game.d = Game.fresh()
    Game.d.eco = {"date": Economy.day_key(), "quiz": 395, "pickup": 0, "mini": 0}
    var r3 := Economy.quiz_rewards([{"id": "z1", "diff": "hard", "right": true, "secs": 5.0}], true)
    ok(int(r3.coins) == 5 and bool(r3.capped), "had harian syiling: " + str(r3))
    # had kutip syiling
    Game.d = Game.fresh()
    var got := 0
    for i in 200:
        got += Economy.pickup_coin()
    ok(got == int(Economy.cfg.caps.daily_pickup_coins), "had kutip syiling: %d" % got)
    ok(Economy.week_key() > 2000, "kunci minggu")

func _test_separation() -> void:
    Game.d = Game.fresh()
    Game.online_mode = false
    var res := [{"id": "s1", "diff": "easy", "right": true, "secs": 4.0}]
    var rw := Economy.quiz_rewards(res, false)
    Game.add_result("math", 3, res, false, rw)
    ok(Game.d.queue.is_empty(), "keputusan luar talian TIDAK masuk baris gilir sync")
    ok(int(Game.d.off_xp) == int(rw.xp) and int(Game.d.xp) == int(rw.xp), "XP luar talian direkod berasingan")
    ok(int(Game.d.ver_xp) == 0, "XP disahkan kekal 0")
    Game.d.uid = "u1"
    Game.online_mode = true
    Auth.id_token = "tok"
    res = [{"id": "s2", "diff": "hard", "right": true, "secs": 4.0}]
    rw = Economy.quiz_rewards(res, false)
    Game.add_result("math", 3, res, false, rw)
    ok(Game.d.queue.size() == 1 and int(Game.d.queue[0].c.hard) == 1 and not Game.d.queue[0].has("xp"), "keputusan dalam talian dihantar sebagai kiraan sahaja: " + str(Game.d.queue))
    Auth.id_token = ""
    Game.online_mode = false
    Game.d = Game.fresh()

func _test_avatar() -> void:
    # semua gabungan penting dibina & dianimasi tanpa ralat
    var n := 0
    for face in 4:
        for style in 5:
            for acc in 4:
                var m := Avatar.build({"gender": face % 2, "skin": style % 5, "shirt": face, "hair": style, "hat": acc, "pack": face % 3, "face": face, "style": style, "shoes": style, "acc": acc})
                for st in [0, 1, 2, 3, 4, 5, 6, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]:
                    Avatar.animate(m, 1.0, st, 0.1)
                m.free()
                n += 1
    ok(n == 80, "avatar dibina & dianimasi")
    var m2 := Avatar.build({})
    for i in 30:
        Avatar.animate(m2, float(i) * 0.1, 14, 0.05)
    ok(absf(float(m2.get_node("Body/LegL").rotation.x) + 1.5) < 0.05, "peralihan lembut mencapai pose duduk")
    for i in 60:
        Avatar.animate(m2, float(i) * 0.1, 21, 0.05)
    ok(absf(float(m2.get_node("Body").rotation.x) + PI / 2.0) < 0.05, "pose baring")
    m2.free()
