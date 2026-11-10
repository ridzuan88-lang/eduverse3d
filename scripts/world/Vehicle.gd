extends CharacterBody3D
# Kenderaan boleh dipandu: 1 = motosikal, 2 = kereta, 3 = bas terbuka.

const KINDS := {
    1: {"name": "Motosikal", "size": Vector3(0.7, 0.9, 1.8), "seat": 0.55, "max": 20.0, "acc": 14.0, "turn": 2.2, "reach": 3.2},
    2: {"name": "Kereta", "size": Vector3(2.0, 0.7, 3.8), "seat": 0.6, "max": 24.0, "acc": 12.0, "turn": 1.8, "reach": 4.2},
    3: {"name": "Bas", "size": Vector3(2.6, 0.9, 8.0), "seat": 1.0, "max": 15.0, "acc": 7.0, "turn": 1.0, "reach": 6.5},
}

var kind := 1
var input := Vector2.ZERO
var driver = null
var speed := 0.0
var brake_t := 0.0
var seat_h := 0.55
var reach := 3.0
var label_name := ""
var spawn := Vector3.ZERO
var _max := 20.0
var _acc := 12.0
var _turn := 2.0

static func _wheel(p: Node3D, pos: Vector3, r: float, w: float) -> void:
    var m := Avatar.part(p, Avatar.cyl(r, r, w), Color("212121"), pos)
    m.rotation.z = PI / 2.0

static func build_model(k: int) -> Node3D:
    var r := Node3D.new()
    match k:
        1:
            Avatar.part(r, Avatar.box(Vector3(0.35, 0.35, 1.2)), Color("e53935"), Vector3(0, 0.55, 0))
            Avatar.part(r, Avatar.box(Vector3(0.5, 0.12, 0.5)), Color("212121"), Vector3(0, 0.76, -0.15))
            Avatar.part(r, Avatar.box(Vector3(0.7, 0.06, 0.06)), Color("9e9e9e"), Vector3(0, 0.98, 0.55))
            Avatar.part(r, Avatar.sph(0.12), Color("fff176"), Vector3(0, 0.75, 0.85))
            _wheel(r, Vector3(0, 0.35, 0.75), 0.35, 0.15)
            _wheel(r, Vector3(0, 0.35, -0.75), 0.35, 0.15)
        2:
            Avatar.part(r, Avatar.box(Vector3(1.9, 0.5, 3.6)), Color("1e88e5"), Vector3(0, 0.55, 0))
            Avatar.part(r, Avatar.box(Vector3(1.7, 0.1, 0.9)), Color("0d47a1"), Vector3(0, 0.85, 1.2))
            Avatar.part(r, Avatar.box(Vector3(1.7, 0.55, 0.06)), Color("b3e5fc"), Vector3(0, 1.1, 0.5))
            Avatar.part(r, Avatar.box(Vector3(1.4, 0.15, 0.7)), Color("37474f"), Vector3(0, 0.85, -0.3))
            Avatar.part(r, Avatar.sph(0.18), Color("fff176"), Vector3(-0.6, 0.65, 1.8))
            Avatar.part(r, Avatar.sph(0.18), Color("fff176"), Vector3(0.6, 0.65, 1.8))
            for sx in [-1.0, 1.0]:
                for sz in [-1.2, 1.2]:
                    _wheel(r, Vector3(sx * 1.0, 0.38, sz), 0.38, 0.25)
        3:
            Avatar.part(r, Avatar.box(Vector3(2.6, 0.9, 8.0)), Color("fbc02d"), Vector3(0, 0.45, 0))
            Avatar.part(r, Avatar.box(Vector3(2.7, 0.15, 8.1)), Color("f57f17"), Vector3(0, 3.3, 0))
            for sx in [-1.2, 1.2]:
                for sz in [-3.8, 3.8]:
                    Avatar.part(r, Avatar.box(Vector3(0.12, 2.4, 0.12)), Color("f57f17"), Vector3(sx, 2.1, sz))
            Avatar.part(r, Avatar.box(Vector3(2.5, 1.6, 0.06)), Color("b3e5fc"), Vector3(0, 2.1, 3.9))
            Avatar.part(r, Avatar.box(Vector3(2.2, 0.2, 0.7)), Color("5d4037"), Vector3(0, 1.0, -1.5))
            Avatar.part(r, Avatar.box(Vector3(2.2, 0.2, 0.7)), Color("5d4037"), Vector3(0, 1.0, -2.8))
            Avatar.part(r, Avatar.sph(0.2), Color("fff176"), Vector3(-0.9, 0.6, 4.0))
            Avatar.part(r, Avatar.sph(0.2), Color("fff176"), Vector3(0.9, 0.6, 4.0))
            for sx in [-1.3, 1.3]:
                for sz in [-2.8, 2.8]:
                    _wheel(r, Vector3(sx, 0.5, sz), 0.5, 0.3)
    return r

func setup(k: int, pos: Vector3, yaw := 0.0) -> void:
    kind = k
    var d: Dictionary = KINDS[k]
    seat_h = d.seat
    reach = d.reach
    _max = d.max
    _acc = d.acc
    _turn = d.turn
    label_name = d.name
    position = pos
    spawn = pos
    rotation.y = yaw
    var sz: Vector3 = d.size
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = sz
    cs.shape = bs
    cs.position.y = sz.y / 2.0
    add_child(cs)
    add_child(build_model(k))
    var l := Label3D.new()
    l.text = label_name
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.font_size = 48
    l.pixel_size = 0.01
    l.outline_size = 12
    l.position = Vector3(0, 4.2 if k == 3 else 2.4, 0)
    add_child(l)

func _physics_process(dt: float) -> void:
    var thr := 0.0
    var steer := 0.0
    if driver != null:
        thr = -input.y
        steer = input.x
    brake_t = maxf(brake_t - dt, 0.0)
    if brake_t > 0.0:
        speed = move_toward(speed, 0.0, 40.0 * dt)
    elif absf(thr) > 0.05:
        speed = clampf(speed + thr * _acc * dt, -_max * 0.4, _max)
    else:
        speed = move_toward(speed, 0.0, 6.0 * dt)
    if absf(speed) > 0.5:
        rotation.y -= steer * _turn * dt * clampf(speed / 6.0, -1.0, 1.0)
    var f := Vector3(0, 0, 1).rotated(Vector3.UP, rotation.y)
    velocity.x = f.x * speed
    velocity.z = f.z * speed
    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= 25.0 * dt
    move_and_slide()
    if is_on_wall():
        speed *= 0.6
    if position.y < -20.0:
        position = spawn
        speed = 0.0
        velocity = Vector3.ZERO
