extends Node3D
# Dunia terbuka: EduTown + Pulau Matematik + Kerajaan Bahasa + Dunia Sains + Dunia Jawi & Arab + Dunia Pengembaraan.

signal back_to_menu

const PlayerScript := preload("res://scripts/player/Player.gd")
const TouchScript := preload("res://scripts/ui/TouchUI.gd")
const QuizScript := preload("res://scripts/education/Quiz.gd")
const SPAWN := Vector3(0, 2, 10)
const PARKOUR_START := Vector3(100, 2, 116)
const TELEPORTS := {
    "EduTown": Vector3(0, 2, 10), "Pulau Matematik": Vector3(90, 2, 14),
    "Kerajaan Bahasa": Vector3(-90, 2, 14), "Dunia Sains": Vector3(0, 2, -86),
    "Dunia Jawi & Arab": Vector3(0, 2, 86), "Dunia Pengembaraan": Vector3(100, 2, 116),
}

var player
var touch
var hud: CanvasLayer
var info_l: Label
var prompt_l: Label
var coin_l: Label
var spots: Array = []
var near: Dictionary = {}
var panel: Control = null
var remotes := {}
var pet: Node3D = null
var pet_idx := -1
var quiz_open := false
var _t := 0.0
var _net_t := 0.0
var _info_t := 0.0

func _ready() -> void:
    _env()
    _town()
    _zones()
    _trees()
    _parkour()
    hud = CanvasLayer.new()
    add_child(hud)
    touch = TouchScript.new()
    hud.add_child(touch)
    touch.interact.connect(_interact)
    touch.menu.connect(open_menu)
    info_l = UI.lbl("", 20)
    info_l.position = Vector2(16, 10)
    hud.add_child(info_l)
    prompt_l = UI.lbl("", 26, Color("fff176"))
    prompt_l.position = Vector2(440, 600)
    hud.add_child(prompt_l)
    player = PlayerScript.new()
    add_child(player)
    player.position = SPAWN
    player.setup(touch)
    var today := Time.get_date_string_from_system()
    if Game.d.last_login != today:
        Game.d.last_login = today
        Game.d.coins = int(Game.d.coins) + 10
        Game.save()
        _toast("Ganjaran log masuk harian: +10 syiling!")
        Game.tone([660, 784, 988])

# ---------- pembinaan dunia ----------
func _env() -> void:
    var we := WorldEnvironment.new()
    var env := Environment.new()
    var sky := Sky.new()
    sky.sky_material = ProceduralSkyMaterial.new()
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(1, 1, 1)
    env.ambient_light_energy = 0.55
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, 30, 0)
    sun.light_energy = 0.9
    add_child(sun)
    _box(Vector3(0, -0.5, 0), Vector3(500, 1, 500), Color("7ec850"))

func _box(pos: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
    var n: Node3D = StaticBody3D.new() if solid else Node3D.new()
    n.position = pos
    var mi := MeshInstance3D.new()
    mi.mesh = Avatar.box(size)
    mi.material_override = Avatar.mat(color)
    n.add_child(mi)
    if solid:
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = size
        cs.shape = sh
        n.add_child(cs)
    add_child(n)
    return n

func _disc(x: float, z: float, r: float, color: Color) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = Avatar.cyl(r, r, 0.1)
    mi.material_override = Avatar.mat(color)
    mi.position = Vector3(x, 0.05, z)
    add_child(mi)

func _road(x: float, z: float, sx: float, sz: float) -> void:
    _box(Vector3(x, 0.03, z), Vector3(sx, 0.06, sz), Color("9e9e9e"), false)

func _label(text: String, pos: Vector3, fs := 72) -> void:
    var l := Label3D.new()
    l.text = text
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.font_size = fs
    l.pixel_size = 0.01
    l.outline_size = 16
    l.position = pos
    add_child(l)

func _building(x: float, z: float, size: Vector3, color: Color, title: String, kind: String, arg := "") -> void:
    _box(Vector3(x, size.y / 2.0, z), size, color)
    _box(Vector3(x, size.y + 0.4, z), Vector3(size.x + 1, 0.8, size.z + 1), color.darkened(0.35))
    _label(title, Vector3(x, size.y + 2.6, z))
    spots.append({"pos": Vector3(x, 0, z + size.z / 2.0 + 1.5), "kind": kind, "arg": arg, "title": title})

func _sign(x: float, z: float, text: String) -> void:
    _box(Vector3(x, 1.5, z), Vector3(0.3, 3, 0.3), Color("6d4c41"))
    _label(text, Vector3(x, 3.6, z), 56)

func _town() -> void:
    _disc(0, 0, 38, Color("a5d6a7"))
    _box(Vector3(0, 0.4, 0), Vector3(4, 0.8, 4), Color("4fc3f7"))
    _building(-14, -12, Vector3(8, 6, 6), Color("e53935"), "Kedai Avatar & Haiwan", "shop")
    _building(0, -18, Vector3(10, 5, 5), Color("fb8c00"), "Papan Misi", "board")
    _building(14, -12, Vector3(8, 6, 6), Color("8e24aa"), "Papan Pendahulu", "rank")
    _building(-14, 14, Vector3(9, 7, 7), Color("1e88e5"), "Sekolah EduTown (Campuran)", "quiz", "mix")
    _building(14, 14, Vector3(9, 5, 9), Color("43a047"), "Gelanggang Cabaran AI", "quiz", "mix:3")
    _sign(30, 4, "Pulau Matematik >>")
    _sign(-30, 4, "<< Kerajaan Bahasa")
    _sign(4, -30, "^ Dunia Sains")
    _sign(4, 30, "v Dunia Jawi & Arab")
    _sign(26, 26, "Dunia Pengembaraan >>")

func _zones() -> void:
    _road(45, 0, 90, 6)
    _road(-45, 0, 90, 6)
    _road(0, -50, 6, 100)
    _road(0, 50, 6, 100)
    _road(55, 100, 110, 6)
    _disc(90, 0, 34, Color("ffcc80"))
    _building(85, -8, Vector3(8, 8, 6), Color("ef6c00"), "Menara Nombor (Matematik)", "quiz", "math")
    _building(97, 8, Vector3(8, 5, 6), Color("f9a825"), "Gelanggang Matematik (Susah)", "quiz", "math:3")
    _disc(-90, 0, 34, Color("90caf9"))
    _building(-95, -8, Vector3(8, 6, 6), Color("1565c0"), "Pusat Bahasa Melayu", "quiz", "bm")
    _building(-85, 8, Vector3(8, 6, 6), Color("00838f"), "English Centre", "quiz", "en")
    _disc(0, -100, 34, Color("80cbc4"))
    _building(0, -100, Vector3(10, 6, 6), Color("00897b"), "Makmal Sains", "quiz", "sci")
    _building(-13, -95, Vector3(7, 4, 5), Color("558b2f"), "Taman Sains (Mudah)", "quiz", "sci:1")
    _disc(0, 100, 34, Color("ce93d8"))
    _building(-10, 100, Vector3(8, 6, 6), Color("6a1b9a"), "Pusat Jawi", "quiz", "jawi")
    _building(10, 100, Vector3(8, 6, 6), Color("2e7d32"), "Pusat Bahasa Arab", "quiz", "arab")
    _disc(100, 100, 34, Color("fff59d"))
    _label("Dunia Pengembaraan: panjat parkour ke puncak untuk peti harta!", Vector3(100, 6, 124), 48)

func _trees() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var trunk := Avatar.cyl(0.25, 0.3, 2.0)
    var leaf := Avatar.sph(1.5)
    var tm := Avatar.mat(Color("6d4c41"))
    var lm := Avatar.mat(Color("2e9e4a"))
    var centers := [Vector2(0, 0), Vector2(90, 0), Vector2(-90, 0), Vector2(0, -100), Vector2(0, 100), Vector2(100, 100)]
    var n := 0
    while n < 90:
        var p := Vector2(rng.randf_range(-220, 220), rng.randf_range(-220, 220))
        var ok := true
        for c in centers:
            if p.distance_to(c) < 42.0:
                ok = false
        if (absf(p.y) < 6.0 and absf(p.x) < 100.0) or (absf(p.x) < 6.0 and absf(p.y) < 105.0) or (absf(p.y - 100.0) < 6.0 and p.x > 0.0 and p.x < 110.0):
            ok = false
        if not ok:
            continue
        n += 1
        var a := MeshInstance3D.new()
        a.mesh = trunk
        a.material_override = tm
        a.position = Vector3(p.x, 1.0, p.y)
        add_child(a)
        var b := MeshInstance3D.new()
        b.mesh = leaf
        b.material_override = lm
        b.position = Vector3(p.x, 3.3, p.y)
        add_child(b)

func _parkour() -> void:
    _box(Vector3(100, 0.5, 115), Vector3(6, 1, 6), Color("66bb6a"))
    var last := Vector3.ZERO
    for i in range(1, 9):
        var pos := Vector3(100.0 + sin(i * 1.3) * 2.5, i * 1.0 + 0.7, 115.0 - i * 5.0)
        _box(pos, Vector3(4, 0.6, 4), Color.from_hsv(i / 8.0, 0.7, 1.0))
        last = pos
    _box(last + Vector3(0, 0.8, 0), Vector3(1.2, 1.0, 1.2), Color("ffc107"))
    spots.append({"pos": last + Vector3(0, 0.5, 0), "kind": "chest", "arg": "", "title": "Peti Harta"})

# ---------- gelung ----------
func _process(dt: float) -> void:
    _t += dt
    var best := {}
    var bd := 5.0
    for s in spots:
        var d: float = player.position.distance_to(s.pos)
        if d < bd:
            bd = d
            best = s
    near = best
    prompt_l.text = "" if (near.is_empty() or panel != null or quiz_open) else "Tekan AMBIL: " + str(near.title)
    player.respawn = PARKOUR_START if (player.position.x > 60.0 and player.position.z > 60.0) else SPAWN
    _update_pet(dt)
    if Game.online_mode:
        _net_t += dt
        if _net_t > 0.1:
            _net_t = 0.0
            Net.send_state(player.position, player.model.rotation.y, player.anim_state)
        _update_remotes(dt)
    _info_t -= dt
    if _info_t <= 0.0:
        _info_t = 0.4
        var st := ("  [%s]" % Net.status) if Game.online_mode else "  [luar talian]"
        info_l.text = "%s  Darjah %d  Tahap %d  XP %d  Syiling %d%s" % [Game.d.name, int(Game.d.year), Game.level(), int(Game.d.xp), int(Game.d.coins), st]

func _update_pet(dt: float) -> void:
    var want := int(Game.d.avatar.pet)
    if want != pet_idx:
        if pet:
            pet.queue_free()
            pet = null
        pet_idx = want
        if want > 0:
            pet = Avatar.build_pet(want)
            add_child(pet)
            pet.position = player.position + Vector3(1.4, 0, 1.2)
    if pet:
        var target: Vector3 = player.position + Vector3(1.4, 0, 1.2).rotated(Vector3.UP, player.yaw)
        pet.position = pet.position.lerp(target, clampf(dt * 4.0, 0.0, 1.0))
        pet.position.y = player.position.y + absf(sin(_t * 6.0)) * 0.08
        if pet.position.distance_to(player.position) > 0.3:
            pet.look_at(Vector3(player.position.x, pet.position.y, player.position.z), Vector3.UP)

func _update_remotes(dt: float) -> void:
    for id in Net.remote.keys():
        var r: Dictionary = Net.remote[id]
        var n: Node3D = remotes.get(id)
        var av: Dictionary = r.get("av", {})
        var key := JSON.stringify(av)
        if n == null or n.get_meta("av") != key:
            if n:
                n.queue_free()
            n = Node3D.new()
            n.set_meta("av", key)
            var m := Avatar.build(av)
            m.name = "Model"
            n.add_child(m)
            var l := Label3D.new()
            l.text = str(r.get("n", "?"))
            l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            l.font_size = 48
            l.pixel_size = 0.01
            l.outline_size = 12
            l.position = Vector3(0, 2.9, 0)
            n.add_child(l)
            var msg := Label3D.new()
            msg.name = "Msg"
            msg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            msg.font_size = 56
            msg.pixel_size = 0.01
            msg.outline_size = 12
            msg.modulate = Color("fff176")
            msg.position = Vector3(0, 3.5, 0)
            n.add_child(msg)
            add_child(n)
            n.position = Vector3(r.x, r.y, r.z)
            remotes[id] = n
        n.position = n.position.lerp(Vector3(r.x, r.y, r.z), clampf(dt * 12.0, 0.0, 1.0))
        var mm: Node3D = n.get_node("Model")
        mm.rotation.y = lerp_angle(mm.rotation.y, float(r.r), clampf(dt * 10.0, 0.0, 1.0))
        Avatar.animate(mm, _t, int(r.a))
        n.get_node("Msg").text = str(r.get("m", ""))
    for id in remotes.keys():
        if not Net.remote.has(id):
            remotes[id].queue_free()
            remotes.erase(id)

func _toast(msg: String) -> void:
    var l := UI.lbl(msg, 26, Color("fff176"))
    l.position = Vector2(300, 70)
    hud.add_child(l)
    var tw := create_tween()
    tw.tween_interval(2.6)
    tw.tween_callback(l.queue_free)

# ---------- interaksi & panel ----------
func on_back() -> void:
    if quiz_open:
        return
    if panel != null:
        _close_panel()
    else:
        open_menu()

func _interact() -> void:
    if panel != null or quiz_open or near.is_empty():
        return
    match near.kind:
        "shop": open_shop()
        "board": _panel_board()
        "rank": _panel_rank()
        "quiz": _panel_quiz(str(near.arg), str(near.title))
        "chest": _chest()

func _open_panel(title: String, w := 760, side := false) -> VBoxContainer:
    _close_panel()
    touch.enabled = false
    panel = Control.new()
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(panel)
    var pc := PanelContainer.new()
    pc.add_theme_stylebox_override("panel", UI.box(Color("1f2a5a"), 20))
    if side:
        var hb := HBoxContainer.new()
        hb.set_anchors_preset(Control.PRESET_FULL_RECT)
        hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var sp := Control.new()
        sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hb.add_child(sp)
        hb.add_child(pc)
        panel.add_child(hb)
    else:
        var bg := ColorRect.new()
        bg.color = Color(0, 0, 0, 0.45)
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        panel.add_child(bg)
        var cc := CenterContainer.new()
        cc.set_anchors_preset(Control.PRESET_FULL_RECT)
        cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(cc)
        cc.add_child(pc)
    var mc := MarginContainer.new()
    for s in ["left", "right", "top", "bottom"]:
        mc.add_theme_constant_override("margin_" + s, 18)
    pc.add_child(mc)
    var v := VBoxContainer.new()
    v.custom_minimum_size.x = w
    v.add_theme_constant_override("separation", 8)
    mc.add_child(v)
    v.add_child(UI.lbl(title, 32, Color("ffd54f")))
    return v

func _add_close(v: VBoxContainer, text := "Tutup") -> void:
    var b := UI.btn(text, Vector2(200, 52))
    b.pressed.connect(_close_panel)
    v.add_child(b)

func _close_panel() -> void:
    if panel != null:
        panel.queue_free()
        panel = null
        _sanitize_avatar()
        Game.save()
    if touch != null and not quiz_open:
        touch.enabled = true

func _sanitize_avatar() -> void:
    for k in ["hat", "pack", "pet"]:
        if not Game.d.owned.has(k + str(int(Game.d.avatar[k]))):
            Game.d.avatar[k] = 0
    if player:
        player.rebuild_model()

func open_shop() -> void:
    var v := _open_panel("Kedai Avatar & Haiwan", 560, true)
    coin_l = UI.lbl("", 22, Color("ffd54f"))
    v.add_child(coin_l)
    _avatar_row(v, "Jantina", "gender", ["Lelaki", "Perempuan"], [], "")
    _avatar_row(v, "Kulit", "skin", ["1", "2", "3", "4", "5"], [], "")
    _avatar_row(v, "Baju", "shirt", ["Merah", "Biru", "Hijau", "Kuning", "Ungu", "Oren"], [], "")
    _avatar_row(v, "Rambut", "hair", ["Hitam", "Coklat", "Kuning", "Merah", "Kelabu"], [], "")
    _avatar_row(v, "Topi", "hat", Avatar.HATS, Avatar.HAT_PRICE, "hat")
    _avatar_row(v, "Beg", "pack", Avatar.PACKS, Avatar.PACK_PRICE, "pack")
    _avatar_row(v, "Haiwan", "pet", Avatar.PETS, Avatar.PET_PRICE, "pet")
    _add_close(v, "Siap")

func _avatar_row(parent: Node, title: String, key: String, names: Array, prices: Array, prefix: String) -> void:
    var h := HBoxContainer.new()
    parent.add_child(h)
    var t := UI.lbl(title, 22)
    t.custom_minimum_size.x = 100
    h.add_child(t)
    var prev := UI.btn("<", Vector2(52, 46))
    var val := UI.lbl("", 22)
    val.custom_minimum_size.x = 150
    val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var nxt := UI.btn(">", Vector2(52, 46))
    var act := UI.btn("", Vector2(130, 46), 20)
    h.add_child(prev)
    h.add_child(val)
    h.add_child(nxt)
    h.add_child(act)
    prev.pressed.connect(_row_step.bind(-1, val, act, key, names, prices, prefix))
    nxt.pressed.connect(_row_step.bind(1, val, act, key, names, prices, prefix))
    act.pressed.connect(_row_buy.bind(val, act, key, names, prices, prefix))
    _row_refresh(val, act, key, names, prices, prefix)

func _row_step(dir: int, val: Label, act: Button, key: String, names: Array, prices: Array, prefix: String) -> void:
    Game.d.avatar[key] = posmod(int(Game.d.avatar[key]) + dir, names.size())
    _row_refresh(val, act, key, names, prices, prefix)

func _row_refresh(val: Label, act: Button, key: String, names: Array, prices: Array, prefix: String) -> void:
    var i := int(Game.d.avatar[key])
    val.text = str(names[i])
    var owned: bool = prices.is_empty() or Game.d.owned.has(prefix + str(i))
    act.visible = not owned
    if not owned:
        act.text = "Beli %d" % int(prices[i])
    if coin_l:
        coin_l.text = "Syiling: %d" % int(Game.d.coins)
    if player:
        player.rebuild_model()

func _row_buy(val: Label, act: Button, key: String, names: Array, prices: Array, prefix: String) -> void:
    var i := int(Game.d.avatar[key])
    var cost := int(prices[i])
    if int(Game.d.coins) >= cost:
        Game.d.coins = int(Game.d.coins) - cost
        Game.d.owned.append(prefix + str(i))
        Game.save()
        Game.tone([660, 880, 990])
    else:
        Game.tone([240, 180])
        _toast("Syiling tidak cukup")
    _row_refresh(val, act, key, names, prices, prefix)

func _panel_quiz(arg: String, title: String) -> void:
    var parts := arg.split(":")
    var subj := parts[0]
    var v := _open_panel(title, 640)
    v.add_child(UI.lbl("Darjah %d  -  %s  -  lawan Robot AI" % [int(Game.d.year), QBank.subject_name(subj)], 22))
    var levels := [[0, "Semua tahap"], [1, "Mudah"], [2, "Sederhana"], [3, "Susah"]]
    if parts.size() > 1:
        levels = [[int(parts[1]), "Mula (tahap " + ["", "Mudah", "Sederhana", "Susah"][int(parts[1])] + ")"]]
    for lv in levels:
        var b := UI.btn(str(lv[1]), Vector2(300, 56))
        b.pressed.connect(_start_quiz.bind(subj, int(lv[0])))
        v.add_child(b)
    _add_close(v)

func _start_quiz(subj: String, diff: int) -> void:
    quiz_open = true
    _close_panel()
    touch.enabled = false
    hud.visible = false
    var q := QuizScript.new()
    q.setup(subj, int(Game.d.year), diff)
    add_child(q)
    q.closed.connect(_quiz_closed)

func _quiz_closed() -> void:
    quiz_open = false
    hud.visible = true
    touch.enabled = true

func _panel_board() -> void:
    var v := _open_panel("Papan Misi")
    var dl := Game.daily()
    var c := mini(int(dl.correct), 10)
    v.add_child(UI.lbl("Misi harian: jawab 10 soalan dengan betul  (%d/10)" % c, 22))
    var claim := UI.btn("Tuntut 20 syiling", Vector2(300, 52))
    claim.disabled = c < 10 or bool(dl.claimed)
    claim.pressed.connect(_claim_daily.bind(claim))
    v.add_child(claim)
    v.add_child(UI.lbl("Tahap %d  |  XP %d  |  Kemenangan %d" % [Game.level(), int(Game.d.xp), int(Game.d.wins)], 22, Color("ffd54f")))
    v.add_child(UI.lbl("Pencapaian", 24))
    var ach := [["Kemenangan Pertama", int(Game.d.wins) >= 1], ["Kumpul 100 XP", int(Game.d.xp) >= 100], ["Simpan 100 syiling", int(Game.d.coins) >= 100]]
    for a in ach:
        v.add_child(UI.lbl(("[x] " if a[1] else "[ ] ") + str(a[0]), 20))
    _add_close(v)

func _claim_daily(btn: Button) -> void:
    var dl := Game.daily()
    if bool(dl.claimed) or int(dl.correct) < 10:
        return
    dl.claimed = true
    Game.d.coins = int(Game.d.coins) + 20
    Game.save()
    btn.disabled = true
    Game.tone([660, 784, 988])

func _chest() -> void:
    var dl := Game.daily()
    if bool(dl.chest):
        _toast("Peti sudah dibuka hari ini. Datang semula esok!")
        return
    dl.chest = true
    Game.d.coins = int(Game.d.coins) + 15
    Game.save()
    Game.tone([660, 784, 988, 1175])
    _toast("Peti harta: +15 syiling!")

func _panel_rank() -> void:
    var v := _open_panel("Papan Pendahulu")
    v.add_child(UI.lbl("Anda: %s  -  Tahap %d  -  %d XP" % [Game.d.name, Game.level(), int(Game.d.xp)], 22, Color("ffd54f")))
    if not Game.online_mode or Auth.id_token == "":
        var l := UI.lbl("Log masuk dalam Mod Dalam Talian untuk melihat kedudukan sah. Skor luar talian tidak masuk papan pendahulu sehingga disahkan oleh pelayan.", 20)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        v.add_child(l)
        _add_close(v)
        return
    var status := UI.lbl("Memuatkan...", 20)
    v.add_child(status)
    _add_close(v)
    var r := HTTPRequest.new()
    add_child(r)
    r.request_completed.connect(_rank_done.bind(r, status, v))
    r.request(Auth.http_url + "/leaderboard", ["Authorization: Bearer " + Auth.id_token])

func _rank_done(res: int, code: int, _h: PackedStringArray, body: PackedByteArray, r: HTTPRequest, status: Label, v: VBoxContainer) -> void:
    r.queue_free()
    if not is_instance_valid(status):
        return
    var j = JSON.parse_string(body.get_string_from_utf8())
    if res != HTTPRequest.RESULT_SUCCESS or code != 200 or not (j is Dictionary):
        status.text = "Gagal memuatkan papan pendahulu."
        return
    status.text = "Top 20 (XP disahkan pelayan)"
    var i := 1
    for e in j.get("list", []):
        var row := UI.lbl("%d. %s  -  Tahap %d  -  %d XP" % [i, e.get("name", "?"), int(e.get("level", 1)), int(e.get("xp", 0))], 19)
        v.add_child(row)
        v.move_child(row, v.get_child_count() - 2)
        i += 1

func open_menu() -> void:
    if panel != null or quiz_open:
        return
    var v := _open_panel("Menu", 700)
    var vol := HSlider.new()
    vol.min_value = 0.0
    vol.max_value = 1.0
    vol.step = 0.05
    vol.value = Game.volume
    vol.custom_minimum_size = Vector2(300, 30)
    vol.value_changed.connect(Game.set_volume)
    var hv := HBoxContainer.new()
    hv.add_child(UI.lbl("Bunyi (0 = senyap)  ", 20))
    hv.add_child(vol)
    v.add_child(hv)
    var ob := OptionButton.new()
    for i in range(1, 7):
        ob.add_item("Darjah %d" % i)
    ob.selected = clampi(int(Game.d.year) - 1, 0, 5)
    ob.custom_minimum_size = Vector2(200, 46)
    ob.item_selected.connect(_set_year)
    var hy := HBoxContainer.new()
    hy.add_child(UI.lbl("Tahun persekolahan  ", 20))
    hy.add_child(ob)
    v.add_child(hy)
    v.add_child(UI.lbl("Pergi ke:", 20))
    var grid := GridContainer.new()
    grid.columns = 3
    v.add_child(grid)
    for k in TELEPORTS:
        var b := UI.btn(k, Vector2(210, 48), 18)
        b.pressed.connect(_teleport.bind(TELEPORTS[k]))
        grid.add_child(b)
    if Game.online_mode:
        v.add_child(UI.lbl("Dalam talian: %s  |  menunggu sync: %d" % [Net.status, Game.d.queue.size()], 18, Color("a5d6a7")))
        var hr := HBoxContainer.new()
        var code := LineEdit.new()
        code.placeholder_text = "Kod bilik peribadi (3-10 huruf/nombor)"
        code.custom_minimum_size = Vector2(340, 46)
        code.max_length = 10
        hr.add_child(code)
        var jb := UI.btn("Sertai", Vector2(120, 46), 18)
        jb.pressed.connect(_join_room.bind(code))
        hr.add_child(jb)
        var pb := UI.btn("Bilik awam", Vector2(150, 46), 18)
        pb.pressed.connect(_join_room.bind(null))
        hr.add_child(pb)
        v.add_child(hr)
        var he := HBoxContainer.new()
        for i in Net.PRESETS.size():
            var eb := UI.btn(Net.PRESETS[i], Vector2(100, 44), 16)
            eb.pressed.connect(Net.send_emote.bind(i))
            he.add_child(eb)
        v.add_child(he)
        var sb := UI.btn("Segerak sekarang", Vector2(240, 46), 18)
        sb.pressed.connect(Sync.sync_now)
        v.add_child(sb)
    var hb := HBoxContainer.new()
    var cb := UI.btn("Sambung main", Vector2(220, 52))
    cb.pressed.connect(_close_panel)
    hb.add_child(cb)
    var xb := UI.btn("Simpan & Keluar", Vector2(220, 52))
    xb.pressed.connect(_exit)
    hb.add_child(xb)
    v.add_child(hb)

func _set_year(i: int) -> void:
    Game.d.year = i + 1
    Game.save()

func _teleport(pos: Vector3) -> void:
    player.position = pos
    player.velocity = Vector3.ZERO
    _close_panel()

func _join_room(code) -> void:
    var c := "public"
    if code != null:
        var t: String = code.text.strip_edges()
        if t.length() < 3:
            _toast("Kod bilik terlalu pendek")
            return
        c = t
    Net.start(Auth.server_url, Auth.id_token, c)
    _close_panel()

func _exit() -> void:
    Game.save()
    Net.stop()
    back_to_menu.emit()
