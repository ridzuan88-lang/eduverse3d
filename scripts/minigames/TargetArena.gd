class_name TargetArena
extends Node3D
# Arena Sasaran: tembak sasaran berwarna dengan peluru cat (tiada senjata sebenar/keganasan). Mod: latihan, cabaran masa, 1 lawan 1 (Robot AI).
# Pelbagai pemain/pasukan: BELUM ada (perlu pelayan berautoriti) - lihat README.

signal finished(result: Dictionary)

const DURATION := 60.0
const CENTER := Vector3(-170, 0, -150)
var world = null
var mode := "time"          # practice | time | vs
var player = null
var targets: Array = []     # {n: Node3D, kind: "n|f|b", vel: Vector3, life: float, r: float}
var shots: Array = []       # {n: Node3D, v: Vector3, t: float}
var score := 0
var ai_score := 0
var left := DURATION
var hits := 0
var shots_fired := 0
var running := false
var _ai_t := 2.0
var _spawn_t := 0.0
var _cd := 0.0
var _hud: Label
var _btn: Button
var _rng := RandomNumberGenerator.new()

func setup(w, m: String) -> void:
    world = w
    mode = m
    player = w.player

func _ready() -> void:
    _rng.randomize()
    Avatar.part(self, Avatar.cyl(30, 30, 0.2), Color("7e57c2"), CENTER + Vector3(0, 0.1, 0))
    Avatar.part(self, Avatar.cyl(26, 26, 0.22), Color("b39ddb"), CENTER + Vector3(0, 0.11, 0))
    var wall := StaticBody3D.new()   # dinding bulat rendah supaya tidak jatuh
    add_child(wall)
    for i in 24:
        var a := float(i) * TAU / 24.0
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(8, 4, 1)
        cs.shape = bs
        cs.position = CENTER + Vector3(cos(a) * 29.0, 2, sin(a) * 29.0)
        cs.rotation.y = -a + PI / 2.0
        wall.add_child(cs)
        Avatar.part(self, Avatar.box(Vector3(8, 1.2, 0.6)), Color.from_hsv(float(i) / 24.0, 0.6, 1.0), cs.position - Vector3(0, 1.4, 0)).rotation.y = cs.rotation.y
    player.global_position = CENTER + Vector3(0, 1.5, 22)
    player.velocity = Vector3.ZERO
    # HUD
    _hud = UI.lbl("", 26, Color("fff176"))
    _hud.position = Vector2(300, 10)
    world.hud.add_child(_hud)
    _btn = UI.btn("TEMBAK", Vector2(190, 120), 30)
    _btn.modulate = Color(1, 0.7, 0.7, 0.9)
    _btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world.hud.add_child(_btn)
    _place_btn()
    world.hud.get_viewport().size_changed.connect(_place_btn)
    var ch := UI.lbl("+", 46, Color(1, 1, 1, 0.8))
    ch.name = "Crosshair"
    ch.set_anchors_preset(Control.PRESET_CENTER)
    ch.position -= Vector2(14, 28)
    ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world.hud.add_child(ch)
    var exit := UI.btn("KELUAR", Vector2(130, 50), 18)
    exit.name = "ExitBtn"
    exit.position = Vector2(16, 60)
    exit.pressed.connect(func(): _end(true))
    world.hud.add_child(exit)
    running = true
    left = DURATION if mode != "practice" else 9999.0
    world._toast("Sasar & tembak! Seret skrin untuk membidik.")

func _place_btn() -> void:
    var s = world.hud.get_viewport().get_visible_rect().size
    _btn.position = Vector2(s.x - 400, s.y - 150)

func _unhandled_input(e: InputEvent) -> void:
    if not running:
        return
    if e is InputEventScreenTouch and e.pressed and _btn.get_global_rect().grow(10).has_point(e.position):
        _shoot()
    elif e is InputEventKey and e.pressed and e.keycode == KEY_F:
        _shoot()
    elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _btn.get_global_rect().has_point(e.position):
        _shoot()

func _shoot() -> void:
    if _cd > 0.0 or not running:
        return
    _cd = 0.25
    shots_fired += 1
    var cam: Camera3D = player.cam
    var dir := -cam.global_transform.basis.z
    var start: Vector3 = player.global_position + Vector3(0, 1.4, 0) + dir * 0.8
    var n := Avatar.part(self, Avatar.sph(0.2), Color.from_hsv(_rng.randf(), 0.8, 1.0), start)
    shots.append({"n": n, "v": dir * 45.0, "t": 1.6})
    Game.tone([880], 0.05)

func _spawn_target() -> void:
    var a := _rng.randf() * TAU
    var d := _rng.randf_range(10.0, 24.0)
    var kind := "n"
    var roll := _rng.randf()
    if roll > 0.88:
        kind = "b"
    elif roll > 0.6:
        kind = "f"
    var col := Color("ef5350")
    var r := 1.1
    var vel := Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
    var life := 12.0
    if kind == "f":
        col = Color("42a5f5")
        r = 0.9
        vel = Vector3(_rng.randf_range(-7, 7), 0, _rng.randf_range(-7, 7))
    elif kind == "b":
        col = Color("ffc107")
        r = 0.8
        vel = Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
        life = 4.0
    var n := Avatar.part(self, Avatar.sph(r), col, CENTER + Vector3(cos(a) * d, _rng.randf_range(1.5, 6.0), sin(a) * d - 4.0))
    targets.append({"n": n, "kind": kind, "vel": vel, "life": life, "r": r})

func _points(kind: String) -> int:
    return 50 if kind == "b" else (20 if kind == "f" else 10)

func _process(dt: float) -> void:
    if not running:
        return
    _cd = maxf(_cd - dt, 0.0)
    if mode != "practice":
        left -= dt
        if left <= 0.0:
            _end(false)
            return
    _spawn_t -= dt
    if _spawn_t <= 0.0 and targets.size() < 7:
        _spawn_t = 0.7
        _spawn_target()
    for t in targets.duplicate():
        var n: Node3D = t.n
        n.position += t.vel * dt
        var off := n.position - CENTER
        if Vector2(off.x, off.z).length() > 26.0:
            t.vel = -t.vel
        t.life -= dt
        if t.life <= 0.0:
            n.queue_free()
            targets.erase(t)
    for s in shots.duplicate():
        var n: Node3D = s.n
        n.position += s.v * dt
        s.t -= dt
        var gone: bool = s.t <= 0.0
        for t in targets.duplicate():
            if n.position.distance_to(t.n.position) < float(t.r) + 0.25:
                score += _points(str(t.kind))
                hits += 1
                Game.tone([660, 990], 0.06)
                t.n.queue_free()
                targets.erase(t)
                gone = true
                break
        if gone:
            n.queue_free()
            shots.erase(s)
    if mode == "vs":
        _ai_t -= dt
        if _ai_t <= 0.0:
            _ai_t = _rng.randf_range(1.0, 2.2)
            if _rng.randf() < 0.65:
                ai_score += [10, 10, 20, 50][_rng.randi() % 4]
    var txt := "Skor: %d" % score
    if mode == "vs":
        txt += "   Robot: %d" % ai_score
    if mode != "practice":
        txt += "   Masa: %d" % int(ceil(left))
    else:
        txt += "   (latihan - tiada ganjaran)"
    _hud.text = txt

func _end(aborted: bool) -> void:
    if not running:
        return
    running = false
    for n in ["Crosshair", "ExitBtn"]:
        var c = world.hud.get_node_or_null(n)
        if c:
            c.queue_free()
    _btn.queue_free()
    _hud.queue_free()
    var won := mode == "vs" and score > ai_score
    var coins := 0
    var m: Dictionary = Economy.cfg.minigame
    if mode != "practice" and not aborted:
        coins = int(m.target_participation_coins) + (int(m.target_win_coins) if (won or (mode == "time" and score >= 200)) else 0)
        coins = Economy.minigame_coins(coins)
        Game.add_coins(coins, "minigame", "sasaran")
    if mode != "practice" and not aborted and score > int(Game.d.mg.target_best):
        Game.d.mg.target_best = score
    Game.save()
    var res := {"score": score, "ai": ai_score, "won": won, "coins": coins, "hits": hits, "shots": shots_fired, "mode": mode, "aborted": aborted}
    finished.emit(res)
    queue_free()
