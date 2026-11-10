extends Node
# Skrin: pelancaran -> pilih mod -> (log masuk) -> profil -> dunia 3D.

const WorldScript := preload("res://scripts/world/World.gd")
var ui: CanvasLayer
var world = null

func _ready() -> void:
    get_tree().quit_on_go_back = false
    RenderingServer.set_default_clear_color(Color("1b2a6b"))
    ui = CanvasLayer.new()
    add_child(ui)
    _splash()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if world != null and is_instance_valid(world):
            world.on_back()
        else:
            _mode()

func _screen(title: String, sub := "") -> VBoxContainer:
    for c in ui.get_children():
        c.queue_free()
    var bg := ColorRect.new()
    bg.color = Color("1b2a6b")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.add_child(bg)
    var cc := CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui.add_child(cc)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 12)
    v.custom_minimum_size.x = 600
    cc.add_child(v)
    var t := UI.lbl(title, 46, Color("ffd54f"))
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(t)
    if sub != "":
        var s := UI.lbl(sub, 22)
        s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(s)
    return v

func _splash() -> void:
    _screen("EduVerse 3D", "Dunia Ilmu  -  CheWanNinja")
    await get_tree().create_timer(1.4).timeout
    _mode()

func _mode() -> void:
    var v := _screen("EduVerse 3D", "Dunia Ilmu  -  oleh CheWanNinja")
    var on := UI.btn("MOD DALAM TALIAN (Online)", Vector2(600, 84), 28)
    on.pressed.connect(_login)
    v.add_child(on)
    var label := "MOD LUAR TALIAN (Offline)"
    if str(Game.d.name) != "":
        label += "\nTeruskan: " + str(Game.d.name)
    var off := UI.btn(label, Vector2(600, 96), 28)
    off.pressed.connect(_offline)
    v.add_child(off)
    var n := UI.lbl("Mod luar talian boleh dimainkan tanpa internet. Mod dalam talian memerlukan akaun.", 18)
    n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(n)

func _offline() -> void:
    Game.online_mode = false
    Net.stop()
    if str(Game.d.name) == "":
        _profile()
    else:
        _start_world(false)

func _field(v: VBoxContainer, hint: String, secret := false) -> LineEdit:
    var e := LineEdit.new()
    e.placeholder_text = hint
    e.secret = secret
    e.custom_minimum_size.y = 54
    e.add_theme_font_size_override("font_size", 22)
    v.add_child(e)
    return e

func _login() -> void:
    var v := _screen("Log Masuk", "Akaun dalam talian")
    var em := _field(v, "E-mel (ibu bapa / penjaga)")
    var pw := _field(v, "Kata laluan (min. 6 aksara)", true)
    var chk := CheckBox.new()
    chk.text = "Ibu bapa/penjaga bersetuju (diperlukan untuk daftar akaun)"
    v.add_child(chk)
    var st := UI.lbl("", 18, Color("ffcc80"))
    st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(st)
    var row := HBoxContainer.new()
    v.add_child(row)
    var b1 := UI.btn("Log masuk", Vector2(190, 54))
    b1.pressed.connect(_do_auth.bind(0, em, pw, chk, st))
    row.add_child(b1)
    var b2 := UI.btn("Daftar", Vector2(190, 54))
    b2.pressed.connect(_do_auth.bind(1, em, pw, chk, st))
    row.add_child(b2)
    var b3 := UI.btn("Lupa kata laluan", Vector2(210, 54), 18)
    b3.pressed.connect(_do_auth.bind(2, em, pw, chk, st))
    row.add_child(b3)
    if str(Game.d.refresh_token) != "":
        var rb := UI.btn("Teruskan sesi terakhir", Vector2(600, 54))
        rb.pressed.connect(_do_auth.bind(3, em, pw, chk, st))
        v.add_child(rb)
    var back := UI.btn("Kembali", Vector2(200, 50))
    back.pressed.connect(_mode)
    v.add_child(back)
    var priv := UI.lbl("Privasi: kami hanya simpan e-mel (untuk log masuk), nama samaran dan kemajuan permainan. Tiada iklan. Tiada sembang bebas.", 16)
    priv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(priv)

func _do_auth(kind: int, em: LineEdit, pw: LineEdit, chk: CheckBox, st: Label) -> void:
    var mail := em.text.strip_edges()
    if kind != 3 and not mail.contains("@"):
        st.text = "Sila masukkan e-mel yang sah."
        return
    if (kind == 0 or kind == 1) and pw.text.length() < 6:
        st.text = "Kata laluan sekurang-kurangnya 6 aksara."
        return
    if kind == 1 and not chk.button_pressed:
        st.text = "Kebenaran ibu bapa/penjaga diperlukan untuk mendaftar."
        return
    st.text = "Sila tunggu..."
    Auth.result.connect(_on_auth.bind(st, kind), CONNECT_ONE_SHOT)
    match kind:
        0: Auth.login(mail, pw.text)
        1: Auth.register(mail, pw.text)
        2: Auth.reset(mail)
        3: Auth.resume()

func _on_auth(ok: bool, msg: String, st: Label, kind: int) -> void:
    if is_instance_valid(st):
        st.text = msg
    if ok and kind != 2:
        Game.online_mode = true
        Game.d.uid = Auth.uid
        Game.save()
        if str(Game.d.name) == "":
            _profile()
        else:
            _start_world(false)

func _profile() -> void:
    var v := _screen("Profil Pemain", "Pilih nama samaran dan tahun persekolahan")
    var nm := _field(v, "Nama samaran (3-16: huruf/nombor/_). Jangan guna nama sebenar.")
    nm.max_length = 16
    var yr := OptionButton.new()
    for k in range(1, 7):
        yr.add_item("Darjah %d" % k)
    yr.custom_minimum_size.y = 54
    yr.add_theme_font_size_override("font_size", 22)
    v.add_child(yr)
    var st := UI.lbl("", 18, Color("ffcc80"))
    v.add_child(st)
    var go := UI.btn("Mula!", Vector2(240, 60), 26)
    go.pressed.connect(_save_profile.bind(nm, yr, st))
    v.add_child(go)

func _save_profile(nm: LineEdit, yr: OptionButton, st: Label) -> void:
    var rx := RegEx.new()
    rx.compile("^[A-Za-z0-9_]{3,16}$")
    if rx.search(nm.text) == null:
        st.text = "Nama samaran: 3-16 aksara, hanya huruf, nombor dan _."
        return
    Game.d.name = nm.text
    Game.d.year = yr.selected + 1
    Game.save()
    _start_world(true)

func _start_world(first: bool) -> void:
    for c in ui.get_children():
        c.queue_free()
    world = WorldScript.new()
    add_child(world)
    world.back_to_menu.connect(_exit_world)
    if Game.online_mode:
        Net.start(Auth.server_url, Auth.id_token, "public")
        Sync.sync_now()
    if first:
        world.open_shop()

func _exit_world() -> void:
    Net.stop()
    if world != null:
        world.queue_free()
        world = null
    _mode()
