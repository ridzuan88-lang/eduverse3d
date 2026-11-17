class_name WorldExtras
extends Node
# Tambahan dunia: kawasan rumah & pembinaan, portal mini-game, papan notis, bangku, sembang/gelembung, masa & cuaca, dunia terbitan pembangun.

const PLOT_ORIGIN := Vector3(-100, 0, -100)
const PORTAL_POS := Vector3(-22, 0, 32)
const BOARDS := [Vector3(75, 0, 14), Vector3(-75, 0, 14), Vector3(14, 0, -85), Vector3(14, 0, 85), Vector3(85, 0, 85), Vector3(-84, 0, -90), Vector3(-16, 0, -16)]

var w = null
var cat: Dictionary = {}
var town: PlotLayer
var house: PlotLayer
var visit_layer: PlotLayer
var published: PlotLayer
var editor = null
var minigame = null
var dev = null
var visiting := ""
var env := {"time": 12.0, "weather": "clear"}
var _rain: CPUParticles3D = null

func setup(world) -> void:
    w = world
    cat = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/catalog.json"))
    var both: Array = []
    both.append_array(cat.house_items)
    both.append_array(cat.dev_objects)
    town = _layer(both, Vector3.ZERO)
    house = _layer(cat.house_items, PLOT_ORIGIN)
    visit_layer = _layer(cat.house_items, PLOT_ORIGIN)
    visit_layer.visible = false
    published = _layer(cat.dev_objects, Vector3.ZERO)
    _build_static()
    house.load_items(Game.d.house.items)
    Net.chat_received.connect(on_chat)
    _load_online()

func _layer(list: Array, pos: Vector3) -> PlotLayer:
    var l := PlotLayer.new()
    l.set_catalog(list)
    l.position = pos
    w.add_child(l)
    return l

func busy() -> bool:
    return minigame != null or editor != null

func dynamic_spots() -> Array:
    var out: Array = []
    out.append_array(town.spots())
    out.append_array(published.spots())
    if visiting != "":
        out.append_array(visit_layer.spots())
    else:
        out.append_array(house.spots())
    return out

# ---------- binaan statik ----------
func _build_static() -> void:
    # Portal mini-game
    w._building(PORTAL_POS.x, PORTAL_POS.z, Vector3(8, 6, 6), Color("00acc1"), "Portal Mini-game", "portal")
    # Kawasan rumah
    w._disc(PLOT_ORIGIN.x, PLOT_ORIGIN.z, 34, Color("c5e1a5"))
    w._box(PLOT_ORIGIN + Vector3(0, 0.12, 0), Vector3(24, 0.04, 24), Color("dcedc8"), false)
    for s in [[0.0, 12.0, 24.0, 0.3], [0.0, -12.0, 24.0, 0.3], [12.0, 0.0, 0.3, 24.0], [-12.0, 0.0, 0.3, 24.0]]:
        w._box(PLOT_ORIGIN + Vector3(s[0], 0.4, s[1]), Vector3(s[2], 0.8, s[3]), Color("8d6e63"), false)
    w._label("Kawasan Rumah", PLOT_ORIGIN + Vector3(0, 5, 16), 64)
    w.spots.append({"pos": PLOT_ORIGIN + Vector3(0, 0, 15), "kind": "plot", "arg": "", "title": "Rumah Saya"})
    w._sign(-30, -16, "^ Kawasan Rumah (Menu > Pergi ke)")
    # papan notis di setiap dunia
    for b in BOARDS:
        w._box(Vector3(b.x, 1.4, b.z), Vector3(3.2, 2.2, 0.3), Color("fb8c00"))
        w._label("Papan Notis", Vector3(b.x, 3.4, b.z), 48)
        w.spots.append({"pos": Vector3(b.x, 0, b.z + 2.0), "kind": "board", "arg": "", "title": "Papan Notis"})
    # bangku awam (boleh diduduki)
    var bench := []
    for p in [[0, -6, 0], [0, 6, 180], [-6, 0, 90], [6, 0, 270], [80, 20, 0], [-80, 20, 0], [10, -90, 0], [-10, 90, 180], [PLOT_ORIGIN.x + 16, PLOT_ORIGIN.z + 14, 0]]:
        bench.append({"id": "furn_bench", "x": p[0], "y": 0.0, "z": p[1], "ry": p[2], "s": 1.0})
    town.load_items(bench)

# ---------- data dalam talian ----------
func _load_online() -> void:
    Api.get_json("/me", func(ok: bool, d: Dictionary, _c: int):
        if ok and not bool(d.get("_cached", false)):
            w.role = str(d.get("role", "player"))
            Game.d.ver_xp = int(d.get("xp", 0))
            Game.d.ver_coins = int(d.get("coins", 0)), "me")
    Api.get_json("/world", func(ok: bool, d: Dictionary, _c: int):
        if ok:
            published.load_items(d.get("objects", []))
            apply_env(d.get("env", {})), "world")
    Api.get_json("/announcements", func(_ok: bool, _d: Dictionary, _c: int): pass, "ann")
    if Game.d.house.items.is_empty():
        Api.get_json("/house", func(ok: bool, d: Dictionary, _c: int):
            if ok and not bool(d.get("_cached", false)) and Game.d.house.items.is_empty() and d.get("items", []).size() > 0:
                Game.d.house.items = d.items
                Game.d.house.privacy = str(d.get("privacy", "private"))
                Game.save()
                house.load_items(Game.d.house.items))

# ---------- sembang ----------
func open_chat() -> void:
    if w.panel != null or w.quiz_open or editor != null:
        return
    var v: VBoxContainer = w._open_panel("Sembang", 760)
    Panels.chat(w, v)

func open_emotes() -> void:
    if w.panel != null or w.quiz_open or editor != null:
        return
    var v: VBoxContainer = w._open_panel("Emote", 680)
    Panels.emotes(w, v)

func on_chat(id: String, _name: String, text: String, _scope: String) -> void:
    var node: Node3D = null
    if id == Net.my_id:
        node = w.player
    elif w.remotes.has(id):
        node = w.remotes[id]
    if node:
        Bubble.say(node, text, 3.3 if id == Net.my_id else 3.6)

# ---------- masa & cuaca ----------
func apply_env(e: Dictionary) -> void:
    env = {"time": clampf(float(e.get("time", 12.0)), 0.0, 24.0), "weather": str(e.get("weather", "clear"))}
    var elev := sin((float(env.time) - 6.0) / 12.0 * PI)
    var day := clampf(elev, 0.0, 1.0)
    w.sun.rotation_degrees = Vector3(-lerpf(8.0, 70.0, day), 30, 0)
    var energy := 0.12 + 0.85 * day
    var fog := false
    if env.weather == "cloudy" or env.weather == "rain":
        energy *= 0.6
        fog = true
    w.sun.light_energy = energy
    w.env_res.ambient_light_energy = 0.28 + 0.3 * day
    w.env_res.fog_enabled = fog
    w.env_res.fog_density = 0.004 if env.weather == "cloudy" else 0.009
    w.env_res.fog_light_color = Color("9e9e9e")
    w.sky_mat.sky_top_color = Color("060a1c").lerp(Color("2b5fb8"), day)
    w.sky_mat.sky_horizon_color = Color("1a1f3a").lerp(Color("a5d6f7"), day)
    w.sky_mat.ground_horizon_color = w.sky_mat.sky_horizon_color
    _set_rain(env.weather == "rain")

func _set_rain(on: bool) -> void:
    if on and _rain == null:
        _rain = CPUParticles3D.new()
        _rain.amount = 350
        _rain.lifetime = 0.9
        _rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        _rain.emission_box_extents = Vector3(18, 0.1, 18)
        _rain.direction = Vector3(0, -1, 0)
        _rain.spread = 2.0
        _rain.initial_velocity_min = 24.0
        _rain.initial_velocity_max = 28.0
        _rain.gravity = Vector3.ZERO
        var bm := BoxMesh.new()
        bm.size = Vector3(0.02, 0.5, 0.02)
        _rain.mesh = bm
        _rain.position = Vector3(0, 12, 0)
        _rain.local_coords = false
        w.player.add_child(_rain)
    if _rain:
        _rain.emitting = on
    if not on and _rain:
        _rain.queue_free()
        _rain = null

# ---------- rumah ----------
func go_house() -> void:
    if w.player.riding != null:
        w._dismount()
    w.player.stand_up()
    w.player.position = PLOT_ORIGIN + Vector3(0, 2, 16)
    w.player.velocity = Vector3.ZERO

func open_house_panel() -> void:
    var v: VBoxContainer = w._open_panel("Rumah Saya", 700)
    var n: int = Game.d.house.items.size()
    v.add_child(UI.lbl("Objek: %d / %d    Privasi: %s" % [n, int(cat.max_items), "Awam" if Game.d.house.privacy == "public" else "Peribadi"], 20, Color("ffd54f")))
    if visiting != "":
        v.add_child(Panels.wl("Anda sedang melawat rumah: " + visiting, 20, Color("a5d6a7")))
        var back := UI.btn("Selesai melawat", Vector2(280, 52))
        back.pressed.connect(func():
            end_visit()
            w._close_panel())
        v.add_child(back)
    else:
        var eb := UI.btn("Bina / Hias rumah", Vector2(320, 56), 24)
        eb.pressed.connect(func():
            w._close_panel()
            start_house_editor())
        v.add_child(eb)
        var pb := UI.btn("", Vector2(320, 48), 18)
        var upd := func(): pb.text = "Privasi: Awam (sesiapa boleh lawat)" if Game.d.house.privacy == "public" else "Privasi: Peribadi (hanya anda)"
        upd.call()
        pb.pressed.connect(func():
            Game.d.house.privacy = "private" if Game.d.house.privacy == "public" else "public"
            Game.save()
            _upload_house()
            upd.call())
        v.add_child(pb)
        var fb := UI.btn("Rakan sahaja (akan datang)", Vector2(320, 44), 16)
        fb.disabled = true
        v.add_child(fb)
    v.add_child(UI.lbl("Lawat rumah awam pemain lain:", 19))
    var row := HBoxContainer.new()
    var le := LineEdit.new()
    le.placeholder_text = "Nama samaran"
    le.max_length = 16
    le.custom_minimum_size = Vector2(300, 46)
    row.add_child(le)
    var st := UI.lbl("", 18, Color("ffcc80"))
    var vb := UI.btn("Lawat", Vector2(120, 46), 18)
    vb.pressed.connect(func(): visit(le.text, st))
    row.add_child(vb)
    v.add_child(row)
    v.add_child(st)
    v.add_child(Panels.wl("Rumah disimpan di peranti ini; dalam talian ia juga disimpan di pelayan (disahkan: katalog, sempadan tanah, kolam di zon khas, had objek).", 15, Color("b0bec5"), 660))
    w._add_close(v)

func visit(nm: String, st: Label) -> void:
    if not Api.can_go_online():
        st.text = "Perlukan Mod Dalam Talian."
        return
    st.text = "Memuatkan..."
    Api.get_json("/house?name=" + nm.strip_edges().uri_encode(), func(ok: bool, d: Dictionary, code: int):
        if not is_instance_valid(st):
            return
        if not ok:
            st.text = "Rumah peribadi." if code == 403 else "Pemain/rumah tidak dijumpai."
            return
        visiting = nm.strip_edges()
        house.visible = false
        visit_layer.visible = true
        visit_layer.load_items(d.get("items", []))
        go_house()
        w._close_panel())

func end_visit() -> void:
    visiting = ""
    visit_layer.visible = false
    house.visible = true

func start_house_editor() -> void:
    if busy() or w.panel != null:
        return
    go_house()
    var pz: Dictionary = cat.pool_zone
    var cfg := {"kind": "house", "origin": PLOT_ORIGIN, "half": float(cat.plot_half), "max_items": int(cat.max_items), "catalog": cat.house_items,
        "y_edit": false, "scale_min": float(cat.scale_min), "scale_max": float(cat.scale_max), "title": "Bina Rumah",
        "validate": func(it: Dictionary) -> String:
            var def: Dictionary = house.catalog_by_id.get(str(it.id), {})
            if bool(def.get("pool", false)):
                if float(it.x) < pz.x[0] or float(it.x) > pz.x[1] or float(it.z) < pz.z[0] or float(it.z) > pz.z[1]:
                    return "Kolam hanya di zon kolam (bahagian belakang tanah)"
            return "",
        "on_save": func(items: Array):
            Game.d.house.items = items.duplicate(true)
            Game.save()
            _upload_house()}
    editor = PlaceEditor.new()
    editor.setup(w, house, cfg)
    w.add_child(editor)
    editor.closed.connect(func():
        editor = null)

func _upload_house() -> void:
    if Api.can_go_online():
        Api.post_json("/house", {"items": Game.d.house.items, "privacy": Game.d.house.privacy}, func(ok: bool, d: Dictionary, _c: int):
            w._toast("Rumah disimpan ke pelayan" if ok else "Pelayan menolak rumah: " + str(d.get("error", "ralat"))))

# ---------- portal mini-game ----------
func open_portal() -> void:
    var v: VBoxContainer = w._open_panel("Portal Mini-game", 760)
    var body := Panels.scroll(v, 420)
    body.add_child(UI.lbl("Arena Sasaran (peluru cat, tiada keganasan)", 22, Color("ffd54f")))
    for m in [["Latihan solo (tiada ganjaran)", "practice"], ["Cabaran masa 60 saat", "time"], ["1 lawan 1 - Robot AI", "vs"]]:
        var b := UI.btn(str(m[0]), Vector2(420, 50), 20)
        b.pressed.connect(func():
            w._close_panel()
            start_target(str(m[1])))
        body.add_child(b)
    body.add_child(UI.lbl("Rekod terbaik: %d mata" % int(Game.d.mg.target_best), 17))
    body.add_child(UI.lbl("Arena Lumba (lawan 3 Robot, pusat semak berturutan)", 22, Color("ffd54f")))
    var tr := OptionButton.new()
    var ids := RaceGame.TRACKS.keys()
    for t in ids:
        tr.add_item(str(RaceGame.TRACKS[t].name))
    tr.custom_minimum_size = Vector2(300, 46)
    body.add_child(tr)
    var vo := OptionButton.new()
    var vk := [2, 1, 4, 5]
    var vprice := {2: 0, 1: 0, 4: 60, 5: 150}
    var vlab := func():
        vo.clear()
        for k in vk:
            var owned: bool = int(vprice[k]) == 0 or Game.d.owned.has("veh%d" % k)
            vo.add_item(str(Vehicle.KINDS[k].name) + ("" if owned else "  (%d syiling)" % int(vprice[k])))
    vlab.call()
    vo.custom_minimum_size = Vector2(300, 46)
    body.add_child(vo)
    var rb := UI.btn("Mula lumba", Vector2(300, 52), 22)
    var st := UI.lbl("", 18, Color("ffcc80"))
    rb.pressed.connect(func():
        var k: int = vk[vo.selected]
        var owned: bool = int(vprice[k]) == 0 or Game.d.owned.has("veh%d" % k)
        if not owned:
            if not Game.spend(int(vprice[k]), "kenderaan %d" % k):
                st.text = "Syiling tidak cukup untuk membuka kenderaan ini."
                return
            Game.d.owned.append("veh%d" % k)
            Game.save()
            vlab.call()
            vo.select(vk.find(k))
            st.text = "Kenderaan dibuka! Tekan Mula lumba lagi."
            return
        w._close_panel()
        start_race(str(ids[tr.selected]), k))
    body.add_child(rb)
    body.add_child(st)
    body.add_child(UI.lbl("Akan datang (belum ada): lumba & tembak berbilang pemain, pasukan, halangan, harta karun, teka-teki.", 15, Color("b0bec5")))
    body.add_child(Panels.wl("Kuiz Matematik/Sains/Bahasa ialah cabaran pembelajaran sedia ada di bangunan sekolah dan pusat subjek.", 15, Color("b0bec5"), 700))
    w._add_close(v)

func start_target(mode: String) -> void:
    if busy():
        return
    minigame = TargetArena.new()
    minigame.setup(w, mode)
    w.add_child(minigame)
    minigame.finished.connect(_mini_done)

func start_race(track: String, kind: int) -> void:
    if busy():
        return
    minigame = RaceGame.new()
    minigame.setup(w, track, kind)
    w.add_child(minigame)
    minigame.finished.connect(_mini_done)

func _mini_done(r: Dictionary) -> void:
    minigame = null
    w.player.position = PORTAL_POS + Vector3(0, 2, 10)
    w.player.velocity = Vector3.ZERO
    var v: VBoxContainer = w._open_panel("Keputusan", 560)
    if r.has("rank"):
        if bool(r.aborted):
            v.add_child(UI.lbl("Lumba dihentikan.", 24))
        else:
            v.add_child(UI.lbl("Tempat ke-%d   Masa %.1f saat" % [int(r.rank), float(r.time)], 28, Color("ffd54f")))
            if bool(r.valid):
                v.add_child(UI.lbl("+%d syiling   +%d XP" % [int(r.coins), int(r.xp)], 24, Color("a5d6a7")))
            else:
                v.add_child(Panels.wl("Masa tidak sah (terlalu pantas/tidak lengkap) - tiada ganjaran.", 18, Color("ff8a80")))
    else:
        if bool(r.aborted):
            v.add_child(UI.lbl("Permainan dihentikan.", 24))
        else:
            var t := "Skor: %d" % int(r.score)
            if r.mode == "vs":
                t += "   Robot: %d  ->  %s" % [int(r.ai), "MENANG!" if bool(r.won) else "kalah"]
            v.add_child(UI.lbl(t, 28, Color("ffd54f")))
            v.add_child(UI.lbl("Tepat: %d / %d tembakan" % [int(r.hits), int(r.shots)], 20))
            if r.mode != "practice":
                v.add_child(UI.lbl("+%d syiling" % int(r.coins), 24, Color("a5d6a7")))
    v.add_child(Panels.wl("Keputusan mini-game ialah setempat dan tidak masuk kedudukan sah.", 15, Color("b0bec5"), 520))
    w._add_close(v)
