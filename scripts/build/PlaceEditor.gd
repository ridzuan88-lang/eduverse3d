class_name PlaceEditor
extends Node3D
# Editor penempatan objek untuk skrin sentuh: kursor grid digerakkan dengan anak panah, pilih katalog -> Letak; Pilih -> alih/putar/skala/padam;
# Buat Asal/Ulang; Simpan. Digunakan oleh pembinaan rumah (tanah terhad) DAN editor dunia pembangun (bebas, dengan paksi Y).
#
# cfg: kind "house"|"world", origin Vector3, half float, max_items int, catalog Array, y_edit bool, scale_min/max, title,
#      validate(it: Dictionary) -> String ("" = sah), on_save(items: Array) -> void, extra: Array[{text, cb}], buy(def) -> bool (rumah)

signal closed

var world = null
var layer: PlotLayer = null
var cfg: Dictionary = {}
var cur := Vector3.ZERO           # kedudukan kursor (tempatan kepada origin)
var step := 1.0
var rot_deg := 0
var scl := 1.0
var place_def: Dictionary = {}
var ghost: Node3D = null
var sel := -1                     # indeks item dipilih
var sel_box: MeshInstance3D = null
var undo: Array = []
var redo: Array = []
var dirty := false
var cam: Camera3D
var yaw := 0.6
var pitch := 0.9
var dist := 18.0
var ui: Control
var info: Label
var arrows := {}
var _rep := 0.0
var _drag := -1

func setup(w, l: PlotLayer, c: Dictionary) -> void:
    world = w
    layer = l
    cfg = c

func _ready() -> void:
    cam = Camera3D.new()
    cam.top_level = true
    cam.fov = 60.0
    add_child(cam)
    cam.make_current()
    cur = Vector3(0, 0, 0) if str(cfg.kind) == "house" else Vector3(world.player.global_position.x, 0, world.player.global_position.z) - cfg.origin
    cur = Vector3(snappedf(cur.x, step), snappedf(cur.y, step), snappedf(cur.z, step))
    world.editing = true
    world.player.carrying = true
    world.touch.enabled = false
    _build_ui()
    _update_cam()
    _refresh()

# ---------- UI ----------
func _b(text: String, sz := Vector2(120, 56), fs := 20) -> Button:
    var b := UI.btn(text, sz, fs)
    b.modulate = Color(1, 1, 1, 0.92)
    return b

func _build_ui() -> void:
    ui = Control.new()
    ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world.hud.add_child(ui)
    info = UI.lbl("", 20, Color("fff176"))
    info.position = Vector2(16, 8)
    ui.add_child(info)
    # D-pad kiri bawah
    var pad := GridContainer.new()
    pad.columns = 3
    pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    pad.position = Vector2(20, 480)
    ui.add_child(pad)
    var dirs := [["", ""], ["^", "u"], ["", ""], ["<", "l"], ["o", "c"], [">", "r"], ["", ""], ["v", "d"], ["", ""]]
    for d in dirs:
        if d[0] == "":
            var sp := Control.new()
            sp.custom_minimum_size = Vector2(72, 72)
            pad.add_child(sp)
        elif d[1] == "c":
            var cb := _b("Kamera", Vector2(72, 72), 13)
            cb.pressed.connect(func(): yaw += PI / 2.0)
            pad.add_child(cb)
        else:
            var ab := _b(str(d[0]), Vector2(72, 72), 30)
            pad.add_child(ab)
            arrows[str(d[1])] = ab
            ab.pressed.connect(_move.bind(str(d[1])))
    if bool(cfg.y_edit):
        var ud := VBoxContainer.new()
        ud.position = Vector2(250, 480)
        ui.add_child(ud)
        var up := _b("Naik", Vector2(90, 66), 18)
        up.pressed.connect(func(): _move("y+"))
        ud.add_child(up)
        var dn := _b("Turun", Vector2(90, 66), 18)
        dn.pressed.connect(func(): _move("y-"))
        ud.add_child(dn)
        arrows["y+"] = up
        arrows["y-"] = dn
    # butang tindakan kanan
    var g := GridContainer.new()
    g.columns = 3
    g.position = Vector2(700, 380)
    ui.add_child(g)
    var acts := [["Katalog", _open_catalog], ["Letak", _place], ["Pilih", _select], ["Putar", _rotate], ["Besar", _scale.bind(1.0)], ["Kecil", _scale.bind(-1.0)],
        ["Padam", _delete], ["Asal", _undo], ["Ulang", _redo], ["Zum +", func(): dist = maxf(dist - 3.0, 5.0); _update_cam()], ["Zum -", func(): dist = minf(dist + 3.0, 60.0); _update_cam()],
        ["Langkah", _cycle_step], ["Simpan", _save], ["Keluar", _exit]]
    for a in acts:
        var bb := _b(str(a[0]), Vector2(128, 54), 18)
        bb.pressed.connect(a[1])
        g.add_child(bb)
    var ex: Array = cfg.get("extra", [])
    if not ex.is_empty():
        var eg := HBoxContainer.new()
        eg.position = Vector2(16, 40)
        ui.add_child(eg)
        for e in ex:
            var eb := _b(str(e.text), Vector2(150, 44), 16)
            eb.pressed.connect(e.cb)
            eg.add_child(eb)

func _refresh() -> void:
    var nm := "-" if place_def.is_empty() else str(place_def.name)
    var s := "%s  |  Objek: %d/%d  |  Kursor %s  |  Langkah %.0f  |  Putaran %d  |  Skala %.1f" % [cfg.title, layer.items.size(), int(cfg.max_items), str(cur.snapped(Vector3.ONE * 0.01)), step, rot_deg, scl]
    if sel >= 0:
        s += "\nDIPILIH: " + str(layer.items[sel].id) + "  (anak panah = alih)"
    else:
        s += "\nBina: " + nm
    if str(cfg.kind) == "house":
        s += "   Syiling: %d" % int(Game.d.coins)
    info.text = s
    _update_ghost()

func _cycle_step() -> void:
    var opts := [1.0, 0.5] if str(cfg.kind) == "house" else [1.0, 5.0, 10.0]
    var i := opts.find(step)
    step = opts[(i + 1) % opts.size()]
    _refresh()

# ---------- kamera ----------
func _update_cam() -> void:
    var focus: Vector3 = cfg.origin + cur
    var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, -pitch).rotated(Vector3.UP, yaw)
    cam.global_position = focus + off
    cam.look_at(focus, Vector3.UP)

func _input(e: InputEvent) -> void:
    var vs := get_viewport().get_visible_rect().size
    if e is InputEventScreenTouch:
        if e.pressed and e.position.x > vs.x * 0.35 and e.position.y < vs.y * 0.5 and _drag == -1:
            _drag = e.index
        elif not e.pressed and e.index == _drag:
            _drag = -1
    elif e is InputEventScreenDrag and e.index == _drag:
        yaw -= e.relative.x * 0.006
        pitch = clampf(pitch + e.relative.y * 0.006, 0.25, 1.45)
        _update_cam()

func _process(dt: float) -> void:
    # tekan-tahan anak panah mengulang
    var held := ""
    for k in arrows:
        if (arrows[k] as Button).get_draw_mode() == BaseButton.DRAW_PRESSED:
            held = k
    if held != "":
        _rep -= dt
        if _rep <= 0.0:
            _rep = 0.14
            _move(held)
    else:
        _rep = 0.35
    if sel_box and sel >= 0 and sel < layer.nodes.size():
        sel_box.global_position = (layer.nodes[sel] as Node3D).global_position + Vector3(0, 0.6, 0)

# ---------- pergerakan ----------
func _axis(dir: String) -> Vector3:
    var f := Vector3(-sin(yaw), 0, -cos(yaw))
    var r := Vector3(cos(yaw), 0, -sin(yaw))
    var v := Vector3.ZERO
    match dir:
        "u": v = f
        "d": v = -f
        "r": v = r
        "l": v = -r
        "y+": return Vector3(0, step, 0)
        "y-": return Vector3(0, -step, 0)
    if absf(v.x) > absf(v.z):
        return Vector3(signf(v.x) * step, 0, 0)
    return Vector3(0, 0, signf(v.z) * step)

func _move(dir: String) -> void:
    var d := _axis(dir)
    if sel >= 0:
        _push_undo()
        var it: Dictionary = layer.items[sel]
        var np := Vector3(float(it.x) + d.x, float(it.get("y", 0.0)) + d.y, float(it.z) + d.z)
        var test := it.duplicate()
        test.x = np.x
        test.z = np.z
        if cfg.kind == "world":
            test.y = np.y
        var err := _check(test)
        if err != "":
            _toast(err)
            undo.pop_back()
            return
        it.x = np.x
        it.z = np.z
        if cfg.kind == "world":
            it.y = np.y
        _rebuild_one(sel)
        cur = Vector3(np.x, np.y, np.z)
    else:
        cur += d
        var h: float = cfg.half
        cur.x = clampf(cur.x, -h, h)
        cur.z = clampf(cur.z, -h, h)
        if not bool(cfg.y_edit):
            cur.y = 0.0
        else:
            cur.y = clampf(cur.y, -5.0, 100.0)
    _update_cam()
    _refresh()

# ---------- ghost ----------
func _item_from_ghost() -> Dictionary:
    var it := {"id": str(place_def.id), "x": cur.x, "z": cur.z, "s": scl}
    if cfg.kind == "house":
        it["r"] = (rot_deg / 90) % 4
        it["o"] = 0
    else:
        it["y"] = cur.y
        it["ry"] = rot_deg
    return it

func _update_ghost() -> void:
    if ghost:
        ghost.queue_free()
        ghost = null
    if place_def.is_empty() or sel >= 0:
        return
    ghost = ObjectFactory.build(place_def, 0)
    for c in ghost.get_children():
        if c is StaticBody3D:
            c.queue_free()
    ghost.position = cfg.origin + cur
    ghost.rotation.y = deg_to_rad(float(rot_deg))
    ghost.scale = Vector3.ONE * scl
    var ok := _check(_item_from_ghost()) == ""
    var gm := StandardMaterial3D.new()
    gm.albedo_color = Color(0.3, 1.0, 0.4, 0.55) if ok else Color(1.0, 0.3, 0.3, 0.55)
    gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _tint(ghost, gm)
    add_child(ghost)

func _tint(n: Node, m: Material) -> void:
    for c in n.get_children():
        if c is MeshInstance3D:
            c.material_override = m
        _tint(c, m)

# ---------- semakan ----------
func _footprint(it: Dictionary) -> Vector2:
    var def: Dictionary = layer.catalog_by_id.get(str(it.id), {})
    if def.is_empty():
        return Vector2.ZERO
    var s := float(it.get("s", 1.0))
    var w := float(def.size[0]) * s
    var d := float(def.size[2]) * s
    var yaw_d := float(it.ry) if it.has("ry") else float(int(it.get("r", 0))) * 90.0
    var q := int(round(yaw_d / 90.0)) % 2
    return Vector2(d, w) / 2.0 if q == 1 else Vector2(w, d) / 2.0

func _check(it: Dictionary) -> String:
    var h: float = cfg.half
    var fp := _footprint(it)
    if cfg.kind == "house":
        if absf(float(it.x)) + fp.x > h + 0.01 or absf(float(it.z)) + fp.y > h + 0.01:
            return "Di luar tanah anda"
    else:
        if absf(float(it.x)) > h or absf(float(it.z)) > h:
            return "Di luar sempadan dunia"
    var s := float(it.get("s", 1.0))
    if s < float(cfg.scale_min) - 0.001 or s > float(cfg.scale_max) + 0.001:
        return "Saiz di luar had"
    if cfg.has("validate"):
        return str((cfg.validate as Callable).call(it))
    return ""

func _toast(t: String) -> void:
    world._toast(t)

# ---------- tindakan ----------
func _push_undo() -> void:
    undo.append(layer.items.duplicate(true))
    if undo.size() > 40:
        undo.pop_front()
    redo.clear()
    dirty = true

func _rebuild_one(i: int) -> void:
    if i < 0 or i >= layer.items.size():
        return
    if i < layer.nodes.size() and is_instance_valid(layer.nodes[i]):
        layer.nodes[i].queue_free()
    var n := layer.make_node(layer.items[i])
    layer.nodes[i] = n
    layer.add_child(n)

func _place() -> void:
    if sel >= 0:
        _deselect()
        return
    if place_def.is_empty():
        _toast("Pilih objek dari Katalog dahulu")
        return
    if layer.items.size() >= int(cfg.max_items):
        _toast("Had objek dicapai")
        return
    var it := _item_from_ghost()
    var err := _check(it)
    if err != "":
        _toast(err)
        Game.tone([240, 180])
        return
    _push_undo()
    layer.items.append(it)
    var n := layer.make_node(it)
    layer.nodes.append(n)
    layer.add_child(n)
    Game.tone([523, 659], 0.06)
    _refresh()

func _select() -> void:
    if sel >= 0:
        _deselect()
        return
    var best := -1
    var bd := 3.5
    for i in layer.items.size():
        var it: Dictionary = layer.items[i]
        var d := Vector2(float(it.x) - cur.x, float(it.z) - cur.z).length()
        if d < bd:
            bd = d
            best = i
    if best < 0:
        _toast("Tiada objek berhampiran kursor")
        return
    sel = best
    var it2: Dictionary = layer.items[sel]
    cur = Vector3(float(it2.x), float(it2.get("y", 0.0)), float(it2.z))
    rot_deg = int(it2.ry) if it2.has("ry") else int(it2.get("r", 0)) * 90
    scl = float(it2.get("s", 1.0))
    if sel_box == null:
        sel_box = MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(1.0, 0.12, 1.0)
        sel_box.mesh = bm
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(1, 0.9, 0.2, 0.7)
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        sel_box.material_override = m
        add_child(sel_box)
    _update_cam()
    _refresh()

func _deselect() -> void:
    sel = -1
    if sel_box:
        sel_box.queue_free()
        sel_box = null
    _refresh()

func _rotate() -> void:
    var stp := 90 if cfg.kind == "house" else 15
    if sel >= 0:
        _push_undo()
        var it: Dictionary = layer.items[sel]
        var nr := (rot_deg + stp) % 360
        var test := it.duplicate()
        if test.has("ry"):
            test.ry = nr
        else:
            test.r = (nr / 90) % 4
        var err := _check(test)
        if err != "":
            _toast(err)
            undo.pop_back()
            return
        rot_deg = nr
        if it.has("ry"):
            it.ry = nr
        else:
            it.r = (nr / 90) % 4
        _rebuild_one(sel)
    else:
        rot_deg = (rot_deg + stp) % 360
    _refresh()

func _scale(dir: float) -> void:
    var ns := clampf(snappedf(scl + dir * 0.25, 0.05), float(cfg.scale_min), float(cfg.scale_max))
    if sel >= 0:
        _push_undo()
        var it: Dictionary = layer.items[sel]
        var test := it.duplicate()
        test.s = ns
        var err := _check(test)
        if err != "":
            _toast(err)
            undo.pop_back()
            return
        it.s = ns
        scl = ns
        _rebuild_one(sel)
    else:
        scl = ns
    _refresh()

func _delete() -> void:
    if sel < 0:
        _toast("Pilih objek dahulu (butang Pilih)")
        return
    _push_undo()
    layer.items.remove_at(sel)
    if sel < layer.nodes.size():
        layer.nodes[sel].queue_free()
        layer.nodes.remove_at(sel)
    _deselect()

func _undo() -> void:
    if undo.is_empty():
        return
    redo.append(layer.items.duplicate(true))
    layer.items = undo.pop_back()
    layer.rebuild()
    sel = -1
    _deselect()

func _redo() -> void:
    if redo.is_empty():
        return
    undo.append(layer.items.duplicate(true))
    layer.items = redo.pop_back()
    layer.rebuild()
    _deselect()

func _save() -> void:
    (cfg.on_save as Callable).call(layer.items)
    dirty = false
    _toast("Disimpan")
    Game.tone([660, 880])

func _exit() -> void:
    if dirty:
        # simpan automatik supaya tiada kerja hilang (rumah); editor dunia hanya simpan setempat/draf apabila ditekan Simpan
        if cfg.kind == "house":
            _save()
        else:
            _toast("Perubahan belum disimpan ke pelayan (tekan Simpan Draf)")
    cleanup()
    closed.emit()

func cleanup() -> void:
    world.editing = false
    world.player.carrying = false
    if world.player.cam:
        world.player.cam.make_current()
    if ui:
        ui.queue_free()
    queue_free()

# ---------- katalog ----------
func _open_catalog() -> void:
    _deselect()
    var v: VBoxContainer = world._open_panel("Katalog", 640)
    var cats := ["Semua"]
    for d in cfg.catalog:
        if not cats.has(str(d.cat)):
            cats.append(str(d.cat))
    var ob := OptionButton.new()
    for c in cats:
        ob.add_item(str(c))
    ob.custom_minimum_size = Vector2(260, 44)
    var se := LineEdit.new()
    se.placeholder_text = "Cari..."
    se.custom_minimum_size = Vector2(260, 44)
    var row := HBoxContainer.new()
    row.add_child(ob)
    row.add_child(se)
    v.add_child(row)
    var list := Panels.scroll(v, 330)
    var fill := func():
        for c in list.get_children():
            c.queue_free()
        var q := se.text.strip_edges().to_lower()
        for d in cfg.catalog:
            if ob.selected > 0 and str(d.cat) != cats[ob.selected]:
                continue
            if q != "" and not str(d.name).to_lower().contains(q):
                continue
            var owned := true
            var label := str(d.name)
            if cfg.kind == "house":
                owned = Game.d.owned.has("f_" + str(d.id))
                label += "   (dimiliki)" if owned else "   (%d syiling)" % int(d.price)
            var b := UI.btn(label, Vector2(600, 46), 20)
            b.pressed.connect(func():
                if cfg.kind == "house" and not owned:
                    if not Game.spend(int(d.price), "perabot " + str(d.id)):
                        world._toast("Syiling tidak cukup")
                        Game.tone([240, 180])
                        return
                    Game.d.owned.append("f_" + str(d.id))
                    Game.save()
                place_def = d
                scl = 1.0
                world._close_panel()
                _refresh())
            list.add_child(b)
    ob.item_selected.connect(func(_i): fill.call())
    se.text_changed.connect(func(_t): fill.call())
    fill.call()
    world._add_close(v)
