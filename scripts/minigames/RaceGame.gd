class_name RaceGame
extends Node3D
# Arena Lumba: pilih kenderaan & litar, kira detik 3-2-1, pusat semak BERTURUTAN, pusingan, lawan Robot AI, kedudukan, ganjaran.
# Lumba berbilang pemain dalam talian: BELUM ada (perlu pelayan berautoriti + anti-tipu pelayan) - lihat README.

signal finished(result: Dictionary)

const CENTER := Vector3(170, 0, -150)
const TRACKS := {
    "pemula": {"name": "Litar Pemula", "laps": 2, "width": 16.0},
    "mahir": {"name": "Litar Mahir", "laps": 2, "width": 13.0},
    "bandar": {"name": "Litar Bandar", "laps": 2, "width": 15.0},
    "alam": {"name": "Litar Alam", "laps": 2, "width": 15.0},
    "halangan": {"name": "Litar Halangan", "laps": 2, "width": 17.0},
}
var world = null
var track_id := "pemula"
var kind := 2
var wps: Array = []         # Vector3 pusat semak/titik laluan
var racers: Array = []      # {v: Vehicle, ai: bool, name, wp: int, lap: int, done: bool, t: float, cps: int, skill: float}
var state := "count"        # count | race | over
var t_count := 3.9
var t_race := 0.0
var _lbl: Label
var _pos_lbl: Label
var _extras: Array = []
var _rng := RandomNumberGenerator.new()
var _min_time := 0.0

func setup(w, track: String, vehicle_kind: int) -> void:
    world = w
    track_id = track
    kind = vehicle_kind

func _wp_list(id: String) -> Array:
    var out: Array = []
    var n := 24
    match id:
        "pemula":
            for i in n:
                var a := float(i) * TAU / n
                out.append(Vector3(cos(a) * 70.0, 0, sin(a) * 45.0))
        "mahir":
            n = 40
            for i in n:
                var a := float(i) * TAU / n
                var r := 60.0 + 18.0 * sin(a * 3.0)
                out.append(Vector3(cos(a) * r * 1.1, 0, sin(a) * r * 0.75))
        "bandar":
            var pts := [Vector2(-70, -40), Vector2(0, -40), Vector2(0, -10), Vector2(60, -10), Vector2(60, 50), Vector2(10, 50), Vector2(10, 25), Vector2(-70, 25)]
            for i in pts.size():
                var a: Vector2 = pts[i]
                var b: Vector2 = pts[(i + 1) % pts.size()]
                var steps := maxi(int(a.distance_to(b) / 14.0), 1)
                for k in steps:
                    var p := a.lerp(b, float(k) / steps)
                    out.append(Vector3(p.x, 0, p.y))
        "alam":
            n = 36
            for i in n:
                var a := float(i) * TAU / n
                var r := 55.0 + 20.0 * sin(a * 2.0) + 8.0 * cos(a * 5.0)
                out.append(Vector3(cos(a) * r * 1.2, 0, sin(a) * r * 0.8))
        "halangan":
            for i in n:
                var a := float(i) * TAU / n
                out.append(Vector3(cos(a) * 72.0, 0, sin(a) * 48.0))
    return out

func _ready() -> void:
    _rng.randomize()
    wps = _wp_list(track_id)
    _build_track()
    _min_time = _track_length() * float(TRACKS[track_id].laps) / (float(Vehicle_max(kind)) * 1.3)
    var start: Vector3 = CENTER + wps[0]
    var dir: Vector3 = (wps[1] - wps[0]).normalized()
    var yaw := atan2(dir.x, dir.z)
    var side := Vector3(dir.z, 0, -dir.x)
    var names := ["Anda", "Robot Biru", "Robot Hijau", "Robot Kuning"]
    var kinds := [kind, 2, 4, 1]
    for i in 4:
        var v = world.VehicleScript.new()
        world.add_child(v)
        var grid: Vector3 = start - dir * (float(i / 2) * 7.0) + side * (4.0 if i % 2 == 0 else -4.0)
        v.setup(int(kinds[i]), grid + Vector3(0, 0.2, 0), yaw)
        v.set_meta("race", true)
        var ai := i > 0
        racers.append({"v": v, "ai": ai, "name": names[i], "wp": 1, "lap": 0, "done": false, "t": 0.0, "cps": 0, "skill": _rng.randf_range(0.82, 0.95)})
        if ai:
            v.driver = self    # pemandu maya
            v.max_speed = v._max * float(racers[i].skill)
        _extras.append(v)
    var pl: Dictionary = racers[0]
    world.player.global_position = pl.v.global_position
    world._mount(pl.v)
    _lbl = UI.lbl("", 80, Color("fff176"))
    _lbl.position = Vector2(560, 120)
    world.hud.add_child(_lbl)
    _pos_lbl = UI.lbl("", 26, Color("fff176"))
    _pos_lbl.position = Vector2(300, 10)
    world.hud.add_child(_pos_lbl)
    var exit := UI.btn("KELUAR", Vector2(130, 50), 18)
    exit.name = "RaceExit"
    exit.position = Vector2(16, 60)
    exit.pressed.connect(func(): _end(true))
    world.hud.add_child(exit)

func Vehicle_max(k: int) -> float:
    return float(world.VehicleScript.KINDS[k].max)

func _track_length() -> float:
    var l := 0.0
    for i in wps.size():
        l += (wps[i] as Vector3).distance_to(wps[(i + 1) % wps.size()])
    return l

func _build_track() -> void:
    var width: float = TRACKS[track_id].width
    var road_col := Color("616161") if track_id != "alam" else Color("8d6e63")
    for i in wps.size():
        var a: Vector3 = CENTER + wps[i]
        var b: Vector3 = CENTER + wps[(i + 1) % wps.size()]
        var mid := (a + b) / 2.0
        var seg := Avatar.part(self, Avatar.box(Vector3(width, 0.1, a.distance_to(b) + 2.0)), road_col, mid + Vector3(0, 0.06, 0))
        seg.rotation.y = atan2(b.x - a.x, b.z - a.z)
        if i % 2 == 0:
            Avatar.part(self, Avatar.box(Vector3(0.5, 0.02, 3.0)), Color.WHITE, mid + Vector3(0, 0.13, 0)).rotation.y = seg.rotation.y
        if i % 3 == 0:   # tanda tepi (jalur merah/putih)
            var sd := Vector3(cos(seg.rotation.y), 0, -sin(seg.rotation.y))
            for sgn in [-1.0, 1.0]:
                Avatar.part(self, Avatar.box(Vector3(0.6, 0.3, 3.0)), Color("e53935") if (i / 3) % 2 == 0 else Color.WHITE, mid + sd * (width / 2.0 + 0.4) * sgn + Vector3(0, 0.15, 0)).rotation.y = seg.rotation.y
    # garisan mula
    var d0: Vector3 = (wps[1] - wps[0]).normalized()
    var line := Avatar.part(self, Avatar.box(Vector3(width, 0.02, 1.2)), Color.WHITE, CENTER + wps[0] + Vector3(0, 0.15, 0))
    line.rotation.y = atan2(d0.x, d0.z)
    # hiasan mengikut litar
    if track_id == "bandar":
        for i in 14:
            var p: Vector3 = CENTER + wps[(i * 3) % wps.size()] + Vector3(_rng.randf_range(14, 22) * (1 if i % 2 == 0 else -1), 0, _rng.randf_range(-6, 6))
            Avatar.part(self, Avatar.box(Vector3(8, _rng.randf_range(6, 16), 8)), Color.from_hsv(_rng.randf(), 0.3, 0.9), p + Vector3(0, 4, 0))
    elif track_id == "alam":
        for i in 30:
            var p: Vector3 = CENTER + wps[(i * 2) % wps.size()] + Vector3(_rng.randf_range(10, 18) * (1 if i % 2 == 0 else -1), 0, _rng.randf_range(-6, 6))
            Avatar.part(self, Avatar.cyl(0.3, 0.3, 2.0), Color("6d4c41"), p + Vector3(0, 1, 0))
            Avatar.part(self, Avatar.sph(1.5), Color("2e9e4a"), p + Vector3(0, 3.2, 0))
    elif track_id == "halangan":
        for i in range(2, wps.size(), 2):
            var a: Vector3 = CENTER + wps[i]
            var nx: Vector3 = (wps[(i + 1) % wps.size()] - wps[i]).normalized()
            var sd := Vector3(nx.z, 0, -nx.x)
            var ob := StaticBody3D.new()
            ob.position = a + sd * (width * 0.25 * (1.0 if (i / 2) % 2 == 0 else -1.0)) + Vector3(0, 0.6, 0)
            var cs := CollisionShape3D.new()
            var bs := BoxShape3D.new()
            bs.size = Vector3(2.2, 1.2, 2.2)
            cs.shape = bs
            ob.add_child(cs)
            Avatar.part(ob, Avatar.box(Vector3(2.2, 1.2, 2.2)), Color("ff7043"), Vector3.ZERO)
            add_child(ob)
    # papan pusat semak (hanya penanda visual; pengesanan ikut urutan dalam kod)
    for i in range(0, wps.size(), maxi(wps.size() / 6, 1)):
        var p: Vector3 = CENTER + wps[i]
        var d := ((wps[(i + 1) % wps.size()] as Vector3) - (wps[i] as Vector3)).normalized()
        var sd := Vector3(d.z, 0, -d.x)
        for sgn in [-1.0, 1.0]:
            Avatar.part(self, Avatar.box(Vector3(0.4, 4, 0.4)), Color("00e676"), p + sd * (width / 2.0 + 1.0) * sgn + Vector3(0, 2, 0))

func _process(dt: float) -> void:
    if state == "count":
        t_count -= dt
        var c := int(ceil(t_count - 0.9))
        _lbl.text = str(c) if c > 0 else "GO!"
        for r in racers:
            r.v.brake_t = 0.2   # tahan di garisan mula
        if t_count <= 0.9:
            state = "race"
            _lbl.text = "GO!"
            get_tree().create_timer(0.8).timeout.connect(func(): if is_instance_valid(_lbl): _lbl.text = "")
        return
    if state != "race":
        return
    t_race += dt
    var laps: int = TRACKS[track_id].laps
    for r in racers:
        if r.done:
            continue
        var v: Node3D = r.v
        var target: Vector3 = CENTER + wps[r.wp]
        var flat := Vector3(v.position.x, 0, v.position.z)
        if flat.distance_to(Vector3(target.x, 0, target.z)) < 11.0:
            # pusat semak dilalui BERTURUTAN sahaja (tiada jalan pintas)
            r.cps += 1
            r.wp = (r.wp + 1) % wps.size()
            if not r.ai:
                v.spawn = v.position + Vector3(0, 0.5, 0)
            if r.wp == 1 and r.cps >= wps.size():
                r.lap += 1
                r.cps = 0
                if r.lap >= laps:
                    r.done = true
                    r.t = t_race
                    r.v.input = Vector2.ZERO
        if r.ai and not r.done:
            var f := Vector3(0, 0, 1).rotated(Vector3.UP, v.rotation.y)
            var d := (Vector3(target.x, 0, target.z) - flat)
            var ang := f.signed_angle_to(d, Vector3.UP)
            v.input = Vector2(clampf(-ang * 2.2, -1.0, 1.0), -1.0 if absf(ang) < 0.9 else -0.5)
        # di luar jalan: perlahan
        if not r.done and _off_road(v.position):
            v.speed *= (1.0 - 1.2 * dt)
    var player_done: bool = racers[0].done
    _pos_lbl.text = "Kedudukan: %d/4   Pusingan: %d/%d   Masa: %.1fs" % [_rank_of(0), mini(int(racers[0].lap) + 1, laps), laps, t_race]
    if player_done:
        _end(false)

func _off_road(p: Vector3) -> bool:
    var width: float = TRACKS[track_id].width
    var best := 1e9
    for i in wps.size():
        var a: Vector3 = CENTER + wps[i]
        var b: Vector3 = CENTER + wps[(i + 1) % wps.size()]
        var ab := b - a
        var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
        best = minf(best, p.distance_to(a + ab * tt))
    return best > width / 2.0 + 1.0

func _progress(i: int) -> float:
    var r: Dictionary = racers[i]
    if r.done:
        return 1e6 - float(r.t)
    var target: Vector3 = CENTER + wps[r.wp]
    return float(r.lap) * 10000.0 + float(r.cps) * 100.0 - (r.v.position as Vector3).distance_to(target) * 0.1

func _rank_of(i: int) -> int:
    var rk := 1
    for j in racers.size():
        if j != i and _progress(j) > _progress(i):
            rk += 1
    return rk

func _end(aborted: bool) -> void:
    if state == "over":
        return
    state = "over"
    var rank := _rank_of(0)
    var valid := not aborted and t_race >= _min_time   # masa mustahil pantas = tidak sah
    var m: Dictionary = Economy.cfg.minigame
    var coins := 0
    var xp := 0
    if valid:
        coins = Economy.minigame_coins(int(m.race_coins[rank - 1]))
        xp = int(m.race_xp[rank - 1])
        Game.add_coins(coins, "minigame", "lumba " + track_id)
        Game.d.xp = int(Game.d.xp) + xp
        Game.d.off_xp = int(Game.d.off_xp) + xp
        var best: Dictionary = Game.d.mg.race_best
        if not best.has(track_id) or t_race < float(best[track_id]):
            best[track_id] = snappedf(t_race, 0.01)
    Game.save()
    if world.player.riding != null:
        world._dismount()
    for n in ["RaceExit"]:
        var c = world.hud.get_node_or_null(n)
        if c:
            c.queue_free()
    _lbl.queue_free()
    _pos_lbl.queue_free()
    for v in _extras:
        if is_instance_valid(v):
            v.queue_free()
    finished.emit({"rank": rank, "time": t_race, "coins": coins, "xp": xp, "valid": valid, "aborted": aborted, "track": track_id})
    queue_free()
