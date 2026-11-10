extends Node3D
# Dunia terbuka: EduTown + Pulau Matematik + Kerajaan Bahasa + Dunia Sains + Dunia Jawi & Arab + Dunia Pengembaraan.

signal back_to_menu

const PlayerScript := preload("res://scripts/player/Player.gd")
const TouchScript := preload("res://scripts/ui/TouchUI.gd")
const QuizScript := preload("res://scripts/education/Quiz.gd")
const VehicleScript := preload("res://scripts/world/Vehicle.gd")
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
var vehicles: Array = []
var coins: Array = []
var pads: Array = []
var clouds: Array = []
var zone_now := ""
var _save_t := 0.0
var _t := 0.0
var _net_t := 0.0
var _info_t := 0.0

func _ready() -> void:
    _env()
    _town()
    _zones()
    _trees()
    _parkour()
    _decor()
    _vehicles()
    _coins()
    _pads()
    _clouds()
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
    near = _find_near()
    prompt_l.text = "" if (near.is_empty() or panel != null or quiz_open) else "Tekan AMBIL: " + str(near.title)
    player.respawn = PARKOUR_START if (player.position.x > 60.0 and player.position.z > 60.0) else SPAWN
    _update_pet(dt)
    _update_extras(dt)
    if Game.online_mode:
        _net_t += dt
        if _net_t > 0.1:
            _net_t = 0.0
            Net.send_state(player.position, player.model.rotation.y, player.anim_state, player.riding.kind if player.riding != null else 0)
        _update_remotes(dt)
    _info_t -= dt
    if _info_t <= 0.0:
        _info_t = 0.4
        var st := ("  [%s | %d pemain]" % [Net.status, Net.remote.size() + 1]) if Game.online_mode else "  [luar talian]"
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
        var vk := int(r.get("v", 0))
        if int(n.get_meta("v", 0)) != vk:
            n.set_meta("v", vk)
            var old := mm.get_node_or_null("Veh")
            if old:
                old.queue_free()
            if vk > 0:
                var vm := VehicleScript.build_model(vk)
                vm.name = "Veh"
                vm.position.y = -float(VehicleScript.KINDS[vk].seat)
                mm.add_child(vm)
        Avatar.animate(mm, _t, 0 if vk > 0 else int(r.a))
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
        "vehicle": _mount(near.node)
        "dismount": _dismount()

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
        v.add_child(UI.lbl("Dalam talian: %s | bilik: %s | pemain: %d | sync tertunda: %d" % [Net.status, Net.room, Net.remote.size() + 1, Game.d.queue.size()], 18, Color("a5d6a7")))
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
    if player.riding != null:
        _dismount()
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

# ---------- hiasan, kenderaan & benda interaktif ----------
func _glow(c: Color) -> StandardMaterial3D:
    var m := Avatar.mat(c)
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = 1.4
    return m

func _lamp(x: float, z: float) -> void:
    Avatar.part(self, Avatar.cyl(0.1, 0.12, 4.0), Color("424242"), Vector3(x, 2.0, z))
    var b := MeshInstance3D.new()
    b.mesh = Avatar.sph(0.35)
    b.material_override = _glow(Color("ffee58"))
    b.position = Vector3(x, 4.1, z)
    add_child(b)

func _decor() -> void:
    for r in [[45.0, 0.0, 90.0, 0.3], [-45.0, 0.0, 90.0, 0.3], [0.0, -50.0, 0.3, 100.0], [0.0, 50.0, 0.3, 100.0], [55.0, 100.0, 110.0, 0.3]]:
        _box(Vector3(r[0], 0.07, r[1]), Vector3(r[2], 0.02, r[3]), Color("ffd54f"), false)
    for i in range(1, 7):
        _lamp(i * 16.0, 4.2)
        _lamp(-i * 16.0, 4.2)
        _lamp(4.2, i * 16.0)
        _lamp(4.2, -i * 16.0)
    var hc := [Color("ffab91"), Color("fff59d"), Color("a5d6a7"), Color("90caf9"), Color("ce93d8"), Color("ffcc80")]
    var hp := [Vector2(35, -22), Vector2(-35, -22), Vector2(35, 22), Vector2(-35, 22), Vector2(62, -20), Vector2(-62, -20),
        Vector2(62, 22), Vector2(-62, 22), Vector2(-20, 62), Vector2(20, 62), Vector2(-20, -62), Vector2(20, -62)]
    for i in hp.size():
        var p: Vector2 = hp[i]
        _box(Vector3(p.x, 2.0, p.y), Vector3(6, 4, 6), hc[i % hc.size()])
        var roof := MeshInstance3D.new()
        var pm := PrismMesh.new()
        pm.size = Vector3(7, 2.2, 7)
        roof.mesh = pm
        roof.material_override = Avatar.mat(Color("c62828"))
        roof.position = Vector3(p.x, 5.1, p.y)
        add_child(roof)
        _box(Vector3(p.x, 1.0, p.y + 3.02), Vector3(1.2, 2, 0.1), Color("5d4037"), false)
    _box(Vector3(12, 3.3, 26), Vector3(5, 0.2, 2.5), Color("0277bd"), false)
    _box(Vector3(9.8, 1.6, 26), Vector3(0.15, 3.2, 0.15), Color("616161"), false)
    _box(Vector3(14.2, 1.6, 26), Vector3(0.15, 3.2, 0.15), Color("616161"), false)
    _label("Perhentian Bas", Vector3(12, 5.0, 26), 56)
    var cm := Avatar.mat(Color(1, 1, 1))
    cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    for i in 14:
        var c := Node3D.new()
        c.position = Vector3(rng.randf_range(-240, 240), rng.randf_range(40, 65), rng.randf_range(-240, 240))
        for k in 3:
            var m := MeshInstance3D.new()
            m.mesh = Avatar.sph(6.0)
            m.material_override = cm
            m.scale = Vector3(1.6, 0.5, 1.0)
            m.position = Vector3((k - 1) * 7.0, rng.randf_range(-1, 1), 0)
            c.add_child(m)
        add_child(c)
        clouds.append(c)

func _clouds() -> void:
    pass

func _vehicles() -> void:
    var defs := [[1, -4.0, 18.0, 0.0], [2, 4.0, 18.0, 0.0], [3, 0.0, 34.0, 0.0],
        [2, 80.0, 18.0, 1.57], [1, -80.0, 18.0, 0.0], [3, 12.0, -84.0, 0.0],
        [2, 0.0, 80.0, 0.0], [1, 108.0, 110.0, 0.0]]
    for d in defs:
        var v := VehicleScript.new()
        add_child(v)
        v.setup(int(d[0]), Vector3(d[1], 0.1, d[2]), float(d[3]))
        vehicles.append(v)

func _coins() -> void:
    var cm := _glow(Color("ffc107"))
    var mesh := Avatar.cyl(0.45, 0.45, 0.1)
    var pts: Array = []
    for i in range(1, 8):
        pts.append(Vector3(i * 12.0, 1.3, 0))
        pts.append(Vector3(-i * 12.0, 1.3, 0))
        pts.append(Vector3(0, 1.3, -i * 12.0))
        pts.append(Vector3(0, 1.3, i * 12.0))
    for c in [Vector2(0, 0), Vector2(90, 0), Vector2(-90, 0), Vector2(0, -100), Vector2(0, 100), Vector2(100, 100)]:
        for k in 6:
            var a := k * TAU / 6.0
            pts.append(Vector3(c.x + cos(a) * 16.0, 1.3, c.y + sin(a) * 16.0))
    for i in range(1, 9):
        pts.append(Vector3(100.0 + sin(i * 1.3) * 2.5, i + 2.2, 115.0 - i * 5.0))
    for p in pts:
        var pivot := Node3D.new()
        pivot.position = p
        var m := MeshInstance3D.new()
        m.mesh = mesh
        m.material_override = cm
        m.rotation.x = PI / 2.0
        pivot.add_child(m)
        add_child(pivot)
        coins.append({"n": pivot, "t": 0.0})

func _pads() -> void:
    var pm := _glow(Color("00e676"))
    for p in [Vector2(22, -8), Vector2(-22, -8), Vector2(80, -22), Vector2(-80, -22), Vector2(22, -96), Vector2(-22, 100), Vector2(92, 104)]:
        var n := _box(Vector3(p.x, 0.1, p.y), Vector3(3, 0.2, 3), Color("00c853"), false)
        n.get_child(0).material_override = pm
        _label("Papan Lompat", Vector3(p.x, 2.2, p.y), 40)
        pads.append(Vector3(p.x, 0, p.y))

func _find_near() -> Dictionary:
    if player.riding != null:
        return {"kind": "dismount", "title": "Turun dari kenderaan"}
    var best := {}
    var bd := 99.0
    for s in spots:
        var d: float = player.position.distance_to(s.pos)
        if d < 5.0 and d < bd:
            bd = d
            best = s
    for v in vehicles:
        if v.driver != null:
            continue
        var d2: float = player.position.distance_to(v.position)
        if d2 < v.reach and d2 < bd:
            bd = d2
            best = {"kind": "vehicle", "title": "Naik " + v.label_name, "node": v}
    return best

func _mount(v) -> void:
    if v == null or v.driver != null:
        return
    v.driver = player
    player.set_riding(v)
    touch.set_riding(true)
    Game.tone([330, 440])

func _dismount() -> void:
    var v = player.riding
    if v == null:
        return
    v.driver = null
    v.input = Vector2.ZERO
    var side := 1.4 + float(v.reach) * 0.4
    player.set_riding(null)
    player.position = v.position + Vector3(side, 0.6, 0).rotated(Vector3.UP, v.rotation.y)
    touch.set_riding(false)

func _update_extras(dt: float) -> void:
    for c in clouds:
        c.position.x += dt * 2.0
        if c.position.x > 260.0:
            c.position.x = -260.0
    var pp: Vector3 = player.position
    for c in coins:
        var n: Node3D = c.n
        n.rotation.y += dt * 2.5
        if c.t > 0.0:
            c.t -= dt
            if c.t <= 0.0:
                n.visible = true
        elif Vector2(n.position.x, n.position.z).distance_to(Vector2(pp.x, pp.z)) < 1.8 and absf(n.position.y - pp.y) < 3.0:
            c.t = 45.0
            n.visible = false
            Game.d.coins = int(Game.d.coins) + 1
            _save_t = 3.0
            Game.tone([988, 1319], 0.07)
    if _save_t > 0.0:
        _save_t -= dt
        if _save_t <= 0.0:
            Game.save()
    if player.riding == null and player.is_on_floor():
        for p in pads:
            if Vector2(p.x, p.z).distance_to(Vector2(pp.x, pp.z)) < 1.8:
                player.boost = 16.0
                Game.tone([440, 660, 880], 0.08)
                break
    var zones := {"EduTown": Vector2(0, 0), "Pulau Matematik": Vector2(90, 0), "Kerajaan Bahasa": Vector2(-90, 0),
        "Dunia Sains": Vector2(0, -100), "Dunia Jawi & Arab": Vector2(0, 100), "Dunia Pengembaraan": Vector2(100, 100)}
    var here := ""
    for k in zones:
        if Vector2(pp.x, pp.z).distance_to(zones[k]) < 38.0:
            here = k
    if here != zone_now:
        zone_now = here
        if here != "":
            _toast("Selamat datang ke " + here)
