extends CharacterBody3D
# Pengawal orang ketiga: berjalan, berlari, melompat, kamera orbit + zum.

const WALK := 5.0
const RUN := 9.0
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
var _jump_req := false
var _t := 0.0

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
    touch.zoom.connect(func(dl: float): dist = clampf(dist + dl, 3.5, 14.0))
    rebuild_model()

func rebuild_model() -> void:
    var ry := 0.0
    if model:
        ry = model.rotation.y
        model.queue_free()
    model = Avatar.build(Game.d.avatar)
    model.rotation.y = ry
    add_child(model)

func _physics_process(dt: float) -> void:
    _t += dt
    var inp := Vector2.ZERO
    var run := false
    var active := true
    if ui:
        active = ui.enabled
        inp = ui.move
        run = ui.run
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
    var dir := Vector3(inp.x, 0.0, inp.y).rotated(Vector3.UP, yaw)
    var spd := RUN if run else WALK
    velocity.x = dir.x * spd
    velocity.z = dir.z * spd
    if is_on_floor():
        velocity.y = 0.0
        if _jump_req or jump_key:
            velocity.y = JUMP
    else:
        velocity.y -= GRAV * dt
    _jump_req = false
    move_and_slide()
    if position.y < -30.0:
        position = respawn
        velocity = Vector3.ZERO
    var moving := inp.length() > 0.1
    if moving:
        model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), clampf(12.0 * dt, 0.0, 1.0))
    anim_state = 0
    if moving:
        anim_state = 2 if run else 1
    Avatar.animate(model, _t, anim_state)
    var focus := global_position + Vector3(0, 1.6, 0)
    var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, -pitch).rotated(Vector3.UP, yaw)
    cam.global_position = focus + off
    cam.look_at(focus, Vector3.UP)
