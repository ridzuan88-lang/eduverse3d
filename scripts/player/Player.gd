extends CharacterBody3D
# Pengawal orang ketiga: berjalan, berlari, melompat, kamera orbit + zum, dan menunggang kenderaan.

const WALK := 5.0
const RUN := 9.0
const SPRINT := 11.5
const JUMP := 7.5
const GRAV := 20.0

var ui = null
var cam: Camera3D
var model: Node3D
var yaw := 0.0
var pitch := 0.4
var dist := 7.0
var anim_state := 0
var respawn := Vector3(0, 2, 10)
var riding = null
var boost := 0.0
var emote := 0
var emote_t := 0.0
var sitting := false
var seat_lie := false
var seat_yaw := 0.0
var carrying := false
var fly := false
var _air_t := 0.0
var _land_t := 0.0
var _run_t := 0.0
var _jump_req := false
var _t := 0.0
var _free_t := 0.0

func setup(touch) -> void:
    ui = touch
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.4
    cap.height = 1.9
    cs.shape = cap
    cs.position.y = 0.95
    add_child(cs)
    cam = Camera3D.new()
    cam.top_level = true
    cam.fov = 70.0
    add_child(cam)
    cam.current = true
    touch.jump.connect(func(): _jump_req = true)
    touch.zoom.connect(func(dl: float): dist = clampf(dist + dl, 3.5, 16.0))
    rebuild_model()

func set_riding(v) -> void:
    riding = v
    collision_layer = 0 if v != null else 1
    dist = 10.0 if v != null else 7.0
    if v == null:
        velocity = Vector3.ZERO

func set_fly(on: bool) -> void:
    fly = on
    collision_mask = 0 if on else 1
    velocity = Vector3.ZERO

func play_emote(code: int) -> void:
    if riding != null or sitting:
        return
    if code == Avatar.A_SIT:
        return   # duduk dikendalikan oleh tempat duduk sebenar (bangku/kerusi), bukan emote bebas
    emote = code
    emote_t = 8.0

func sit_on(seat: Vector3, yaw: float, lie := false) -> void:
    sitting = true
    seat_lie = lie
    seat_yaw = yaw
    emote = 0
    collision_layer = 0
    velocity = Vector3.ZERO
    global_position = seat + Vector3(0, 0.0 if lie else -0.58, 0)
    model.rotation.y = yaw
    if ui:
        ui.set_sitting(true)

func stand_up() -> void:
    if not sitting:
        return
    sitting = false
    collision_layer = 1
    var fwd := Vector3(0, 0, 1.3).rotated(Vector3.UP, seat_yaw)
    global_position += fwd + Vector3(0, 0.7 if not seat_lie else 0.9, 0)
    velocity = Vector3.ZERO
    if ui:
        ui.set_sitting(false)

func rebuild_model() -> void:
    var ry := 0.0
    if model:
        ry = model.rotation.y
        model.queue_free()
    model = Avatar.build(Game.d.avatar)
    model.rotation.y = ry
    add_child(model)

func _update_cam() -> void:
    var focus := global_position + Vector3(0, 1.6, 0)
    var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, -pitch).rotated(Vector3.UP, yaw)
    cam.global_position = focus + off
    cam.look_at(focus, Vector3.UP)

func _physics_process(dt: float) -> void:
    _t += dt
    _free_t = maxf(_free_t - dt, 0.0)
    var inp := Vector2.ZERO
    var run := false
    var active := true
    if ui:
        active = ui.enabled
        inp = ui.move
        run = ui.run
        if ui.cam.length() > 0.0:
            _free_t = 1.5
        yaw -= ui.cam.x * 0.006
        pitch = clampf(pitch + ui.cam.y * 0.006, -0.1, 1.2)
        ui.cam = Vector2.ZERO
    var jump_key := false
    if active:
        inp += Vector2(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
            int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
        inp += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
        yaw += (int(Input.is_key_pressed(KEY_Q)) - int(Input.is_key_pressed(KEY_E))) * dt * 2.0
        run = run or Input.is_key_pressed(KEY_SHIFT)
        jump_key = Input.is_key_pressed(KEY_SPACE)
    inp = inp.limit_length(1.0)
    if sitting:
        velocity = Vector3.ZERO
        anim_state = Avatar.A_LIE if seat_lie else Avatar.A_SIT
        Avatar.animate(model, _t, anim_state, dt)
        _update_cam()
        _jump_req = false
        return
    if emote != 0:
        emote_t -= dt
        if emote_t <= 0.0 or inp.length() > 0.2 or _jump_req or jump_key:
            emote = 0
    if riding != null:
        riding.input = inp
        if _jump_req or jump_key:
            riding.brake_t = 0.5
        _jump_req = false
        global_position = riding.global_position + Vector3(0, riding.seat_h, 0)
        velocity = Vector3.ZERO
        model.rotation.y = riding.rotation.y
        anim_state = 0
        anim_state = Avatar.A_RIDE if int(riding.kind) == 1 else Avatar.A_DRIVE
        Avatar.animate(model, _t, anim_state, dt)
        if _free_t <= 0.0:
            yaw = lerp_angle(yaw, riding.rotation.y + PI, clampf(2.5 * dt, 0.0, 1.0))
        _update_cam()
        return
    var dir := Vector3(inp.x, 0.0, inp.y).rotated(Vector3.UP, yaw)
    if fly:
        var vy := 0.0
        if _jump_req or jump_key:
            vy = 10.0
        elif run:
            vy = -10.0
        _jump_req = false
        velocity = Vector3(dir.x * 14.0, vy, dir.z * 14.0)
        move_and_slide()
        if inp.length() > 0.1:
            model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), clampf(12.0 * dt, 0.0, 1.0))
        anim_state = Avatar.A_JUMP
        Avatar.animate(model, _t, anim_state, dt)
        _update_cam()
        return
    _run_t = _run_t + dt if (run and inp.length() > 0.5) else 0.0
    var spd := WALK
    if run:
        spd = SPRINT if _run_t > 1.5 else RUN
    velocity.x = dir.x * spd
    velocity.z = dir.z * spd
    if is_on_floor():
        if _air_t > 0.35:
            _land_t = 0.22
        _air_t = 0.0
        velocity.y = 0.0
        if _jump_req or jump_key:
            velocity.y = JUMP
        if boost > 0.0:
            velocity.y = boost
            boost = 0.0
    else:
        _air_t += dt
        velocity.y -= GRAV * dt
    _jump_req = false
    _land_t = maxf(_land_t - dt, 0.0)
    move_and_slide()
    if position.y < -30.0:
        position = respawn
        velocity = Vector3.ZERO
    var moving := inp.length() > 0.1
    if moving:
        model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), clampf(12.0 * dt, 0.0, 1.0))
    anim_state = Avatar.A_IDLE
    if moving:
        anim_state = Avatar.A_SPRINT if _run_t > 1.5 else (Avatar.A_RUN if run else Avatar.A_WALK)
    if carrying and anim_state <= Avatar.A_WALK:
        anim_state = Avatar.A_CARRY
    if emote != 0:
        anim_state = emote
    if not is_on_floor() and _air_t > 0.12:
        anim_state = Avatar.A_JUMP if velocity.y > 0.5 else Avatar.A_FALL
    elif _land_t > 0.0:
        anim_state = Avatar.A_LAND
    Avatar.animate(model, _t, anim_state, dt)
    _update_cam()
