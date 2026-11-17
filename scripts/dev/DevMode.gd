class_name DevMode
extends Node
# Mod Pembangun / Mod Tuhan: HANYA untuk peranan super_admin / world_dev (disahkan PELAYAN melalui custom claim).
# Klien hanya memaparkan UI; semua simpan/terbit ditolak oleh pelayan jika peranan tiada. Tiada kata laluan/akaun perkhidmatan dalam APK.

var w = null
var ex = null     # WorldExtras
var editor = null
var last_draft := 0
var fly := false

static func allowed(role: String) -> bool:
    return role == "super_admin" or role == "world_dev"

func setup(world, extras) -> void:
    w = world
    ex = extras

func start() -> void:
    if not allowed(str(w.role)) or ex.busy() or not Api.can_go_online():
        w._toast("Mod Pembangun memerlukan peranan sah & Mod Dalam Talian")
        return
    var cat: Dictionary = ex.cat
    var cfg := {"kind": "world", "origin": Vector3.ZERO, "half": 240.0, "max_items": 3000, "catalog": cat.dev_objects, "y_edit": true,
        "scale_min": 0.2, "scale_max": 6.0, "title": "EDITOR DUNIA (pembangun)",
        "on_save": func(items: Array): save_draft(items),
        "extra": [
            {"text": "Versi", "cb": versions_panel}, {"text": "Eksport", "cb": export_world}, {"text": "Import", "cb": import_world},
            {"text": "Masa", "cb": time_panel}, {"text": "Cuaca", "cb": weather_panel}, {"text": "Ke kursor", "cb": teleport_to_cursor}]}
    editor = PlaceEditor.new()
    editor.setup(w, ex.published, cfg)
    ex.editor = editor
    w.add_child(editor)
    editor.closed.connect(func():
        ex.editor = null
        editor = null
        if editor == null:
            reload_live())
    w._toast("Mod Pembangun aktif. Simpan = draf; Terbit = LIVE (perlu pengesahan).")

func reload_live() -> void:
    Api.get_json("/world", func(ok: bool, d: Dictionary, _c: int):
        if ok:
            ex.published.load_items(d.get("objects", []))
            ex.apply_env(d.get("env", {})))

func save_draft(items: Array) -> void:
    Api.post_json("/admin/world/save", {"objects": items, "note": "draf " + Time.get_datetime_string_from_system(), "env": ex.env}, func(ok: bool, d: Dictionary, code: int):
        if ok:
            last_draft = int(d.version)
            w._toast("Draf v%d disimpan (BELUM live). Buka Versi untuk menerbitkan." % last_draft)
        else:
            w._toast("Gagal simpan (kod %d): %s" % [code, str(d.get("error", "ralat"))]))

func versions_panel() -> void:
    var v: VBoxContainer = w._open_panel("Versi dunia", 760)
    var body := Panels.scroll(v, 400)
    body.add_child(UI.lbl("Memuatkan...", 18))
    Api.get_json("/admin/world/versions", func(ok: bool, d: Dictionary, _c: int):
        if not is_instance_valid(body):
            return
        for c in body.get_children():
            c.queue_free()
        if not ok:
            body.add_child(Panels.wl("Gagal memuatkan (peranan/sambungan).", 18))
            return
        body.add_child(UI.lbl("LIVE sekarang: v%d" % int(d.live), 20, Color("a5d6a7")))
        for ver in d.versions:
            var row := HBoxContainer.new()
            var live: bool = int(ver.n) == int(d.live)
            row.add_child(UI.lbl("v%d  %d objek %s" % [int(ver.n), int(ver.count), "[LIVE]" if live else ""], 18, Color("a5d6a7") if live else Color.WHITE))
            var ld := UI.btn("Muat", Vector2(90, 40), 15)
            ld.pressed.connect(func(): load_version(int(ver.n)))
            row.add_child(ld)
            var pb := UI.btn("Terbit / Pulih", Vector2(150, 40), 15)
            pb.disabled = live
            pb.pressed.connect(func(): confirm_publish(int(ver.n)))
            row.add_child(pb)
            body.add_child(row))
    w._add_close(v)

func load_version(n: int) -> void:
    Api.get_json("/admin/world/get?version=%d" % n, func(ok: bool, d: Dictionary, _c: int):
        if ok:
            ex.published.load_items(d.objects)
            ex.apply_env(d.get("env", {}))
            if editor:
                editor.dirty = true
                editor.undo.clear()
            w._close_panel()
            w._toast("Versi v%d dimuat ke editor (belum diterbitkan)" % n)
        else:
            w._toast("Gagal memuat versi"))

func confirm_publish(n: int) -> void:
    w._close_panel()
    var v: VBoxContainer = w._open_panel("Sahkan penerbitan", 620)
    v.add_child(Panels.wl("Terbitkan versi v%d sebagai dunia LIVE? Semua pemain akan melihat perubahan ini. (Pulihkan = terbitkan versi lama.)" % n, 22, Color("ffcc80"), 580))
    var yes := UI.btn("Ya, terbitkan v%d" % n, Vector2(320, 56), 22)
    yes.pressed.connect(func():
        Api.post_json("/admin/world/publish", {"version": n, "confirm": true}, func(ok: bool, d: Dictionary, code: int):
            w._close_panel()
            w._toast("v%d kini LIVE" % n if ok else "Ditolak (kod %d): %s" % [code, str(d.get("error", ""))])))
    v.add_child(yes)
    w._add_close(v, "Batal")

func export_world() -> void:
    var txt := JSON.stringify({"objects": ex.published.items, "env": ex.env})
    DisplayServer.clipboard_set(txt)
    var f := FileAccess.open("user://world_export.json", FileAccess.WRITE)
    if f:
        f.store_string(txt)
    w._toast("Dunia dieksport (%d objek) ke papan klip & user://world_export.json" % ex.published.items.size())

func import_world() -> void:
    var j = JSON.parse_string(DisplayServer.clipboard_get())
    if not (j is Dictionary) or not (j.get("objects") is Array):
        w._toast("Papan klip tiada konfigurasi dunia yang sah")
        return
    var good: Array = []
    for o in j.objects:
        if o is Dictionary and ex.published.catalog_by_id.has(str(o.get("id", ""))) and absf(float(o.get("x", 0))) <= 240.0 and absf(float(o.get("z", 0))) <= 240.0:
            good.append(o)
    if good.size() > 3000:
        good = good.slice(0, 3000)
    ex.published.load_items(good)
    ex.apply_env(j.get("env", {}))
    if editor:
        editor.dirty = true
    w._toast("%d objek diimport (belum disimpan ke pelayan)" % good.size())

func time_panel() -> void:
    var v: VBoxContainer = w._open_panel("Masa dunia", 560)
    var lab := UI.lbl("Jam: %.1f" % float(ex.env.time), 22)
    v.add_child(lab)
    var sl := HSlider.new()
    sl.min_value = 0.0
    sl.max_value = 24.0
    sl.step = 0.5
    sl.value = float(ex.env.time)
    sl.custom_minimum_size = Vector2(500, 36)
    sl.value_changed.connect(func(x: float):
        lab.text = "Jam: %.1f" % x
        ex.apply_env({"time": x, "weather": ex.env.weather}))
    v.add_child(sl)
    w._add_close(v)

func weather_panel() -> void:
    var v: VBoxContainer = w._open_panel("Cuaca", 460)
    for p in [["Cerah", "clear"], ["Mendung", "cloudy"], ["Hujan", "rain"]]:
        var b := UI.btn(str(p[0]), Vector2(300, 52))
        b.pressed.connect(func(): ex.apply_env({"time": ex.env.time, "weather": str(p[1])}))
        v.add_child(b)
    w._add_close(v)

func teleport_to_cursor() -> void:
    if editor == null:
        return
    var target: Vector3 = editor.cfg.origin + editor.cur + Vector3(0, 2.5, 0)
    editor.cleanup()
    editor.closed.emit()
    w.player.position = target
    w.player.velocity = Vector3.ZERO

# Butang tambahan di panel Pentadbir
func panel(body: VBoxContainer, st: Label) -> void:
    var dev := UI.btn("Masuk editor dunia", Vector2(300, 52))
    dev.pressed.connect(func():
        w._close_panel()
        start())
    body.add_child(dev)
    var fb := UI.btn("Mod Terbang / tembus dinding: " + ("HIDUP" if fly else "MATI"), Vector2(420, 48), 18)
    fb.pressed.connect(func():
        fly = not fly
        w.player.set_fly(fly)
        fb.text = "Mod Terbang / tembus dinding: " + ("HIDUP" if fly else "MATI")
        st.text = "Terbang: Lompat = naik, Lari = turun.")
    body.add_child(fb)
    var row := HBoxContainer.new()
    var xe := LineEdit.new()
    xe.placeholder_text = "X"
    xe.custom_minimum_size = Vector2(100, 44)
    var ze := LineEdit.new()
    ze.placeholder_text = "Z"
    ze.custom_minimum_size = Vector2(100, 44)
    row.add_child(xe)
    row.add_child(ze)
    var go := UI.btn("Teleport", Vector2(140, 44), 16)
    go.pressed.connect(func():
        w.player.position = Vector3(clampf(float(xe.text), -240.0, 240.0), 3.0, clampf(float(ze.text), -240.0, 240.0))
        w.player.velocity = Vector3.ZERO)
    row.add_child(go)
    body.add_child(row)
