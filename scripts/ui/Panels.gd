class_name Panels
extends RefCounted
# Panel UI sosial: sembang, emote, papan notis, papan pendahulu, kelas, profil, pentadbir. `w` = nod World; `v` = VBox dari w._open_panel().

const KINDS_NEWS := ["announcement", "server", "update", "reward"]
const KIND_LABEL := {"announcement": "Pengumuman", "server": "Pelayan", "update": "Kemas kini", "reward": "Ganjaran Istimewa", "mission": "Misi", "competition": "Pertandingan", "event": "Acara"}

static func scroll(v: VBoxContainer, h := 360) -> VBoxContainer:
    var sc := ScrollContainer.new()
    sc.custom_minimum_size = Vector2(v.custom_minimum_size.x, h)
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    v.add_child(sc)
    var inner := VBoxContainer.new()
    inner.custom_minimum_size.x = v.custom_minimum_size.x - 24
    inner.add_theme_constant_override("separation", 6)
    sc.add_child(inner)
    return inner

static func wl(text: String, fs := 20, col := Color.WHITE, wd := 700) -> Label:
    var l := UI.lbl(text, fs, col)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size.x = wd
    return l

# ---------------- Sembang ----------------
static func chat(w, v: VBoxContainer) -> void:
    if not Net.is_ready():
        v.add_child(wl("Sembang hanya tersedia dalam Mod Dalam Talian apabila bersambung ke pelayan.", 22))
        w._add_close(v)
        return
    var scope: String = str(Game.d.chat_scope)
    var status := UI.lbl("", 18, Color("ffcc80"))
    var logbox := scroll(v, 120)
    for e in Net.chat_log.slice(-6):
        logbox.add_child(wl("%s: %s" % [e.n, e.m], 18, Color("e0e0e0"), 640))
    var sb := UI.btn("", Vector2(380, 46), 18)
    var upd := func(): sb.text = "Jarak: Berdekatan" if Game.d.chat_scope == "n" else "Jarak: Seluruh bilik"
    upd.call()
    sb.pressed.connect(func():
        Game.d.chat_scope = "r" if Game.d.chat_scope == "n" else "n"
        upd.call())
    v.add_child(sb)
    var grid := GridContainer.new()
    grid.columns = 4
    var qp: Array = Safety.cfg().quick_phrases
    for i in qp.size():
        var b := UI.btn(str(qp[i]), Vector2(168, 44), 16)
        b.pressed.connect(func(): Net.send_quick(i, str(Game.d.chat_scope)))
        grid.add_child(b)
    v.add_child(grid)
    if bool(Game.d.chat_text):
        var row := HBoxContainer.new()
        var le := LineEdit.new()
        le.placeholder_text = "Tulis mesej (maks %d aksara)" % int(Safety.cfg().max_len)
        le.max_length = int(Safety.cfg().max_len)
        le.custom_minimum_size = Vector2(480, 46)
        row.add_child(le)
        var send := UI.btn("Hantar", Vector2(120, 46), 18)
        send.pressed.connect(func():
            var r := Safety.check(le.text)
            if not r.ok:
                status.text = Safety.why_text(str(r.reason))
                return
            Net.send_chat(str(r.text), str(Game.d.chat_scope))
            le.text = ""
            status.text = "")
        row.add_child(send)
        v.add_child(row)
        var off := UI.btn("Matikan sembang teks", Vector2(260, 42), 16)
        off.pressed.connect(func():
            Game.d.chat_text = false
            Game.save()
            Net.send_cfg_text(false)
            w._close_panel())
        v.add_child(off)
    else:
        var on := UI.btn("Buka sembang teks (pintu ibu bapa)", Vector2(380, 42), 16)
        on.pressed.connect(func(): parent_gate(w))
        v.add_child(on)
        v.add_child(wl("Sembang teks dimatikan secara lalai. Mesej ditapis; maklumat peribadi tidak dibenarkan.", 15, Color("b0bec5")))
    v.add_child(status)
    var cb := func(why: String): status.text = Safety.why_text(why)
    Net.chat_rejected.connect(cb)
    v.tree_exited.connect(func(): Net.chat_rejected.disconnect(cb))
    # pemain berdekatan: senyap / sekat / lapor
    v.add_child(UI.lbl("Pemain dalam bilik:", 18, Color("ffd54f")))
    var pl := scroll(v, 130)
    for id in Net.remote:
        var r: Dictionary = Net.remote[id]
        var h := HBoxContainer.new()
        h.add_child(UI.lbl(str(r.n), 18))
        var mu := UI.btn("Senyap" if not Net.muted.has(r.u) else "Buka", Vector2(90, 38), 15)
        mu.pressed.connect(func():
            if Net.muted.has(r.u):
                Net.muted.erase(r.u)
            else:
                Net.muted[r.u] = true
            mu.text = "Senyap" if not Net.muted.has(r.u) else "Buka")
        h.add_child(mu)
        var bl := UI.btn("Sekat", Vector2(80, 38), 15)
        bl.pressed.connect(func():
            Net.block(str(r.u))
            bl.disabled = true)
        h.add_child(bl)
        for rp in [["Buli", "bully"], ["Kesat", "bad"], ["Peribadi", "personal"]]:
            var rb := UI.btn("Lapor: " + rp[0], Vector2(130, 38), 14)
            rb.pressed.connect(func():
                Net.report(str(id), str(rp[1]))
                status.text = "Laporan dihantar kepada moderator. Terima kasih."
                rb.disabled = true)
            h.add_child(rb)
        pl.add_child(h)
    if Net.remote.is_empty():
        pl.add_child(UI.lbl("(tiada pemain lain sekarang)", 16, Color("90a4ae")))
    w._add_close(v)

static func parent_gate(w) -> void:
    var a := randi_range(6, 9)
    var b := randi_range(6, 9)
    w._close_panel()
    var v: VBoxContainer = w._open_panel("Pintu Ibu Bapa", 560)
    v.add_child(wl("Untuk membuka sembang teks, ibu bapa/penjaga perlu menjawab: %d + %d = ?" % [a, b], 22, Color.WHITE, 540))
    var le := LineEdit.new()
    le.custom_minimum_size = Vector2(200, 50)
    v.add_child(le)
    var st := UI.lbl("", 18, Color("ffcc80"))
    v.add_child(st)
    var ok := UI.btn("Buka", Vector2(200, 52))
    ok.pressed.connect(func():
        if le.text.strip_edges() == str(a + b):
            Game.d.chat_text = true
            Game.save()
            Net.send_cfg_text(true)
            w._close_panel()
        else:
            st.text = "Jawapan salah.")
    v.add_child(ok)
    w._add_close(v, "Batal")

# ---------------- Emote ----------------
static func emotes(w, v: VBoxContainer) -> void:
    var g := GridContainer.new()
    g.columns = 3
    for e in Avatar.EMOTES:
        if int(e[0]) == Avatar.A_SIT:
            continue
        var b := UI.btn(str(e[1]), Vector2(200, 60), 22)
        b.pressed.connect(func():
            w._close_panel()
            w.player.play_emote(int(e[0])))
        g.add_child(b)
    v.add_child(g)
    v.add_child(wl("Duduk: dekati bangku/kerusi/sofa dan tekan AMBIL. Bergerak untuk berhenti beremosi.", 16, Color("b0bec5"), 620))
    w._add_close(v)

# ---------------- Papan Notis ----------------
static func board(w, v: VBoxContainer) -> void:
    var tabs := HBoxContainer.new()
    v.add_child(tabs)
    var body := scroll(v, 380)
    var names := ["Berita", "Misi", "Acara", "Pendahulu", "Pencapaian"]
    for i in names.size():
        var b := UI.btn(names[i], Vector2(140, 44), 18)
        b.pressed.connect(func(): _board_tab(w, body, i))
        tabs.add_child(b)
    _board_tab(w, body, 0)
    w._add_close(v)

static func _clear(b: VBoxContainer) -> void:
    for c in b.get_children():
        c.queue_free()

static func _board_tab(w, body: VBoxContainer, i: int) -> void:
    _clear(body)
    match i:
        0, 2:
            var l := UI.lbl("Memuatkan...", 18)
            body.add_child(l)
            Api.get_json("/announcements", func(ok: bool, d: Dictionary, _c: int):
                if not is_instance_valid(body):
                    return
                _clear(body)
                if not ok:
                    body.add_child(wl("Tiada sambungan dan tiada data tersimpan. Sambung ke internet untuk berita terkini.", 18))
                    return
                if bool(d.get("_cached", false)):
                    body.add_child(wl("(Luar talian - pengumuman terakhir dimuat turun)", 15, Color("ffcc80")))
                var n := 0
                for a in d.get("list", []):
                    var news := KINDS_NEWS.has(str(a.kind))
                    if (i == 0 and news) or (i == 2 and not news and a.kind != "mission"):
                        n += 1
                        body.add_child(UI.lbl("[%s] %s" % [KIND_LABEL.get(str(a.kind), "Notis"), a.title], 20, Color("ffd54f")))
                        body.add_child(wl(str(a.body), 18, Color("e0e0e0"), 680))
                if n == 0:
                    body.add_child(UI.lbl("Tiada notis buat masa ini.", 18)), "ann")
        1:
            _missions(w, body)
        3:
            body.add_child(UI.lbl("Memuatkan...", 18))
            Api.get_json("/leaderboard?type=global", func(ok: bool, d: Dictionary, _c: int):
                if not is_instance_valid(body):
                    return
                _clear(body)
                if not ok:
                    body.add_child(wl("Kedudukan memerlukan sambungan dalam talian.", 18))
                    return
                body.add_child(UI.lbl("Pemain Teratas" + (" (data lama)" if d.get("_cached", false) else ""), 22, Color("ffd54f")))
                for e in d.get("list", []).slice(0, 10):
                    body.add_child(UI.lbl("%d. %s - Tahap %d - %d XP" % [int(e.rank), e.name, int(e.level), int(e.xp)], 19)), "lb_global")
        4:
            body.add_child(UI.lbl("Pencapaian anda", 22, Color("ffd54f")))
            for a in achievements():
                body.add_child(UI.lbl(("[x] " if a[1] else "[ ] ") + str(a[0]), 19, Color("a5d6a7") if a[1] else Color("b0bec5")))

static func achievements() -> Array:
    return [["Kemenangan Pertama", int(Game.d.wins) >= 1], ["Kumpul 100 XP", int(Game.d.xp) >= 100], ["Kumpul 1000 XP", int(Game.d.xp) >= 1000],
        ["Simpan 100 syiling", int(Game.d.coins) >= 100], ["Menang 10 kali", int(Game.d.wins) >= 10], ["Ada rumah dihias (5 benda)", Game.d.house.items.size() >= 5],
        ["Pecah rekod sasaran 200", int(Game.d.mg.target_best) >= 200]]

static func _missions(w, body: VBoxContainer) -> void:
    var cfg: Dictionary = Economy.cfg
    var dl := Game.daily()
    var dm: Dictionary = cfg.daily_mission
    var c := mini(int(dl.correct), int(dm.correct_needed))
    body.add_child(UI.lbl("Misi harian: jawab %d soalan betul  (%d/%d)" % [int(dm.correct_needed), c, int(dm.correct_needed)], 20))
    var claim := UI.btn("Tuntut %d syiling" % int(dm.coins), Vector2(300, 48))
    claim.disabled = c < int(dm.correct_needed) or bool(dl.claimed)
    claim.pressed.connect(func():
        dl.claimed = true
        Game.add_coins(int(dm.coins), "misi", "harian")
        Game.save()
        claim.disabled = true
        Game.tone([660, 784, 988]))
    body.add_child(claim)
    var wk := Economy.weekly()
    var wm: Dictionary = cfg.weekly_mission
    var wc := mini(int(wk.correct), int(wm.correct_needed))
    body.add_child(UI.lbl("Misi mingguan: %d soalan betul  (%d/%d)" % [int(wm.correct_needed), wc, int(wm.correct_needed)], 20))
    var wcl := UI.btn("Tuntut %d syiling" % int(wm.coins), Vector2(300, 48))
    wcl.disabled = wc < int(wm.correct_needed) or bool(wk.claimed)
    wcl.pressed.connect(func():
        wk.claimed = true
        Game.add_coins(int(wm.coins), "misi", "mingguan")
        Game.save()
        wcl.disabled = true
        Game.tone([660, 784, 988, 1175]))
    body.add_child(wcl)
    body.add_child(wl("Hadiah bonus: kuiz selesai / kuiz sempurna / lawan Robot. Had harian syiling kuiz %d." % int(cfg.caps.daily_quiz_coins), 16, Color("b0bec5")))
    body.add_child(UI.lbl("Syiling kuiz hari ini: %d / %d" % [int(Economy.state().quiz), int(cfg.caps.daily_quiz_coins)], 17, Color("ffd54f")))

# ---------------- Papan Pendahulu ----------------
const LB_CATS := [["Keseluruhan", "type=global"], ["Darjah saya", "year"], ["Kelas saya", "class"], ["Matematik", "type=subject&subject=math"],
    ["Sains", "type=subject&subject=sci"], ["Bahasa Melayu", "type=subject&subject=bm"], ["Bahasa Inggeris", "type=subject&subject=en"],
    ["Jawi", "type=subject&subject=jawi"], ["Bahasa Arab", "type=subject&subject=arab"], ["Mingguan", "type=weekly"], ["Bulanan", "type=monthly"]]

static func leaderboard(w, v: VBoxContainer) -> void:
    v.add_child(UI.lbl("XP disahkan pelayan: %d   |   XP luar talian (tidak dikira): %d" % [int(Game.d.ver_xp), int(Game.d.off_xp)], 18, Color("ffd54f")))
    var ob := OptionButton.new()
    for c in LB_CATS:
        ob.add_item(str(c[0]))
    ob.custom_minimum_size = Vector2(300, 46)
    v.add_child(ob)
    var body := scroll(v, 330)
    var load_cat := func(i: int):
        _clear(body)
        var q: String = LB_CATS[i][1]
        if q == "year":
            q = "type=year&year=%d" % int(Game.d.year)
        elif q == "class":
            var cid := str(Api.cached("me").get("class", ""))
            if cid == "":
                body.add_child(wl("Anda belum menyertai kelas. Buka Menu > Kelas dan masukkan kod kelas.", 18))
                return
            q = "type=class&class=" + cid
        body.add_child(UI.lbl("Memuatkan...", 18))
        Api.get_json("/leaderboard?" + q, func(ok: bool, d: Dictionary, _c: int):
            if not is_instance_valid(body):
                return
            _clear(body)
            if not ok:
                body.add_child(wl("Kedudukan sah memerlukan Mod Dalam Talian. Skor luar talian tidak masuk kedudukan sehingga disahkan pelayan.", 18))
                return
            if bool(d.get("_cached", false)):
                body.add_child(UI.lbl("(data lama - luar talian)", 15, Color("ffcc80")))
            var list: Array = d.get("list", [])
            if list.is_empty():
                body.add_child(UI.lbl("Belum ada pemain dalam kategori ini.", 18))
            for e in list:
                var me: bool = str(e.name) == str(Game.d.name)
                body.add_child(UI.lbl("%d. %s  -  %d XP  -  ketepatan %d%% (%d soalan)" % [int(e.rank), e.name, int(e.xp), int(e.acc), int(e.q)], 18, Color("ffd54f") if me else Color.WHITE)), "lb_" + q.md5_text().substr(0, 10))
    ob.item_selected.connect(load_cat)
    load_cat.call(0)
    v.add_child(wl("Kedudukan berdasarkan jawapan betul, tahap kesukaran, kelajuan dan keluasan subjek - bukan masa dalam talian.", 14, Color("b0bec5")))
    w._add_close(v)

# ---------------- Kelas ----------------
static func class_panel(w, v: VBoxContainer) -> void:
    var cur := UI.lbl("Memuatkan...", 20, Color("ffd54f"))
    v.add_child(cur)
    var refresh := func():
        Api.get_json("/me", func(ok: bool, d: Dictionary, _c: int):
            if not is_instance_valid(cur):
                return
            if ok and str(d.get("className", "")) != "":
                cur.text = "Kelas anda: " + str(d.className)
            else:
                cur.text = "Anda belum menyertai mana-mana kelas." if ok else "Perlukan sambungan dalam talian.", "me")
    refresh.call()
    var le := LineEdit.new()
    le.placeholder_text = "Kod kelas (cth. K7M2QX)"
    le.max_length = 10
    le.custom_minimum_size = Vector2(300, 50)
    v.add_child(le)
    var st := UI.lbl("", 18, Color("ffcc80"))
    var go := UI.btn("Sertai kelas", Vector2(240, 50))
    go.pressed.connect(func():
        st.text = "Sila tunggu..."
        Api.post_json("/class/join", {"code": le.text}, func(ok: bool, d: Dictionary, _c: int):
            if ok:
                st.text = "Berjaya menyertai: " + str(d.name)
                refresh.call()
            else:
                st.text = "Kod tidak sah atau tiada sambungan."))
    v.add_child(go)
    var leave := UI.btn("Keluar kelas", Vector2(240, 46), 18)
    leave.pressed.connect(func():
        Api.post_json("/class/leave", {}, func(ok: bool, _d: Dictionary, _c: int):
            st.text = "Telah keluar kelas." if ok else "Gagal."
            refresh.call()))
    v.add_child(leave)
    v.add_child(wl("Kelas dicipta oleh guru/pentadbir yang dibenarkan. Papan kelas boleh dilihat di Papan Pendahulu. (Papan pemuka guru: ciri masa depan.)", 15, Color("b0bec5"), 640))
    v.add_child(st)
    w._add_close(v)

# ---------------- Profil ----------------
static func profile(w, v: VBoxContainer) -> void:
    v.add_child(UI.lbl("%s   -   Darjah %d   -   Tahap %d" % [Game.d.name, int(Game.d.year), Game.level()], 22, Color("ffd54f")))
    v.add_child(UI.lbl("Syiling (dompet): %d      Kemenangan: %d" % [int(Game.d.coins), int(Game.d.wins)], 20))
    v.add_child(UI.lbl("XP jumlah: %d   (disahkan pelayan: %d,  luar talian: %d)" % [int(Game.d.xp), int(Game.d.ver_xp), int(Game.d.off_xp)], 18))
    var body := scroll(v, 250)
    var l := UI.lbl("Memuatkan data pelayan...", 18)
    body.add_child(l)
    Api.get_json("/me", func(ok: bool, d: Dictionary, _c: int):
        if not is_instance_valid(body):
            return
        _clear(body)
        if not ok:
            body.add_child(wl("Statistik subjek memerlukan sambungan dalam talian.", 18))
        else:
            var acc := 0
            if int(d.total) > 0:
                acc = int(round(100.0 * float(d.correct) / float(d.total)))
            body.add_child(UI.lbl("Betul: %d / %d soalan   Ketepatan: %d%%" % [int(d.correct), int(d.total), acc], 19))
            body.add_child(UI.lbl("Kelas: %s" % (str(d.className) if str(d.className) != "" else "-"), 19))
            body.add_child(UI.lbl("Prestasi subjek:", 19, Color("ffd54f")))
            for k in d.st:
                var s: Dictionary = d.st[k]
                var a := int(round(100.0 * float(s.correct) / maxf(float(s.total), 1.0)))
                body.add_child(UI.lbl("  %s: %d XP, ketepatan %d%%" % [QBank.subject_name(str(k)), int(s.xp), a], 18))
        body.add_child(UI.lbl("Pencapaian:", 19, Color("ffd54f")))
        for a2 in achievements():
            body.add_child(UI.lbl(("  [x] " if a2[1] else "  [ ] ") + str(a2[0]), 17)), "me")
    w._add_close(v)

# ---------------- Pentadbir ----------------
static func admin(w, v: VBoxContainer) -> void:
    var role: String = str(w.role)
    v.add_child(UI.lbl("Peranan (disahkan pelayan): " + role, 20, Color("a5d6a7")))
    var st := UI.lbl("", 18, Color("ffcc80"))
    st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    st.custom_minimum_size.x = 700
    var body := scroll(v, 380)
    body.add_child(UI.lbl("Terbitkan pengumuman", 22, Color("ffd54f")))
    var t := LineEdit.new()
    t.placeholder_text = "Tajuk (maks 60)"
    t.max_length = 60
    body.add_child(t)
    var tb := LineEdit.new()
    tb.placeholder_text = "Isi (maks 400)"
    tb.max_length = 400
    body.add_child(tb)
    var kind := OptionButton.new()
    var kinds := ["announcement", "mission", "competition", "event", "update", "reward", "server"]
    for k in kinds:
        kind.add_item(str(KIND_LABEL[k]))
    body.add_child(kind)
    var pub := UI.btn("Terbit", Vector2(200, 48))
    pub.pressed.connect(func():
        Api.post_json("/admin/announcement", {"title": t.text, "body": tb.text, "kind": kinds[kind.selected], "days": 14}, func(ok: bool, _d: Dictionary, code: int):
            st.text = "Diterbitkan." if ok else "Gagal (kod %d) - peranan tidak mencukupi atau tiada sambungan." % code))
    body.add_child(pub)
    if role == "super_admin" or role == "moderator":
        body.add_child(UI.lbl("Cipta kelas", 22, Color("ffd54f")))
        var cn := LineEdit.new()
        cn.placeholder_text = "Nama kelas (cth. 3 Bestari)"
        body.add_child(cn)
        var cy := OptionButton.new()
        for y in range(1, 7):
            cy.add_item("Darjah %d" % y)
        body.add_child(cy)
        var cc := UI.btn("Cipta", Vector2(200, 48))
        cc.pressed.connect(func():
            Api.post_json("/admin/class", {"name": cn.text, "year": cy.selected + 1}, func(ok: bool, d: Dictionary, _c: int):
                st.text = ("Kod kelas: %s  (berikan kepada murid)" % d.code) if ok else "Gagal mencipta kelas."))
        body.add_child(cc)
        var rep := UI.btn("Lihat laporan pemain", Vector2(280, 48), 18)
        rep.pressed.connect(func():
            Api.get_json("/admin/reports", func(ok: bool, d: Dictionary, _c: int):
                if not ok:
                    st.text = "Gagal memuatkan laporan."
                    return
                var txt := ""
                for r in d.list.slice(0, 8):
                    txt += "%s -> %s (%s)\n" % [r.targetName, r.reason, str(r.recent.size()) + " mesej bukti"]
                st.text = txt if txt != "" else "Tiada laporan."))
        body.add_child(rep)
    if role == "super_admin" or role == "world_dev":
        body.add_child(UI.lbl("Mod Pembangun (editor dunia)", 22, Color("ffd54f")))
        var code := LineEdit.new()
        code.placeholder_text = "Kod pengesahan terbit (jika ditetapkan di pelayan)"
        code.secret = true
        code.text_changed.connect(func(t: String): Api.dev_code = t)
        body.add_child(code)
        w.dev.panel(body, st)
    v.add_child(st)
    w._add_close(v)
