extends Control
# Kawalan sentuh: joystick terapung (kiri), seret kamera (kanan), butang Lompat/Lari/Ambil/Menu/Zum.

signal jump
signal interact
signal menu
signal zoom(delta: float)

var enabled := true:
    set(v):
        enabled = v
        if not v:
            move = Vector2.ZERO
            _joy = -1
            _cam = -1
        for b in _b.values():
            b.visible = v
        queue_redraw()
var move := Vector2.ZERO
var run := false
var cam := Vector2.ZERO
var _joy := -1
var _cam := -1
var _o := Vector2.ZERO
var _p := Vector2.ZERO
var _b := {}

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _mk("jump", "LOMPAT", Vector2(150, 150))
    _mk("run", "LARI", Vector2(130, 90))
    _mk("act", "AMBIL", Vector2(170, 90))
    _mk("menu", "MENU", Vector2(120, 60))
    _mk("zin", "+", Vector2(60, 60))
    _mk("zout", "-", Vector2(60, 60))
    get_viewport().size_changed.connect(_layout)
    _layout()

func _vs() -> Vector2:
    return get_viewport_rect().size

func set_riding(b: bool) -> void:
    _b.act.text = "TURUN" if b else "AMBIL"
    _b.jump.text = "BREK" if b else "LOMPAT"

func _mk(id: String, text: String, sz: Vector2) -> void:
    var b := UI.btn(text, sz, 22)
    b.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.size = sz
    b.modulate = Color(1, 1, 1, 0.8)
    add_child(b)
    _b[id] = b

func _layout() -> void:
    var s := _vs()
    _b.jump.position = Vector2(s.x - 190, s.y - 190)
    _b.run.position = Vector2(s.x - 160, s.y - 300)
    _b.act.position = Vector2(s.x - 380, s.y - 130)
    _b.menu.position = Vector2(s.x - 140, 20)
    _b.zin.position = Vector2(s.x - 140, 100)
    _b.zout.position = Vector2(s.x - 70, 100)

func _hit(p: Vector2) -> String:
    for k in _b:
        if _b[k].visible and _b[k].get_global_rect().grow(8).has_point(p):
            return k
    return ""

func _press(k: String) -> void:
    match k:
        "jump": jump.emit()
        "act": interact.emit()
        "menu": menu.emit()
        "zin": zoom.emit(-1.0)
        "zout": zoom.emit(1.0)
        "run":
            run = not run
            _b.run.modulate = Color(0.6, 1, 0.6, 0.95) if run else Color(1, 1, 1, 0.8)

func _input(e: InputEvent) -> void:
    if not enabled or not is_visible_in_tree():
        return
    if e is InputEventScreenTouch:
        if e.pressed:
            var k := _hit(e.position)
            if k != "":
                _press(k)
            elif e.position.x < _vs().x * 0.45 and _joy == -1:
                _joy = e.index
                _o = e.position
                _p = e.position
                queue_redraw()
            elif _cam == -1:
                _cam = e.index
        else:
            if e.index == _joy:
                _joy = -1
                move = Vector2.ZERO
                queue_redraw()
            elif e.index == _cam:
                _cam = -1
    elif e is InputEventScreenDrag:
        if e.index == _joy:
            _p = e.position
            move = ((_p - _o) / 60.0).limit_length(1.0)
            queue_redraw()
        elif e.index == _cam:
            cam += e.relative

func _draw() -> void:
    if not enabled:
        return
    if _joy != -1:
        draw_circle(_o, 70, Color(1, 1, 1, 0.15))
        draw_circle(_o + (_p - _o).limit_length(70.0), 30, Color(1, 1, 1, 0.45))
    else:
        draw_circle(Vector2(160, _vs().y - 160), 70, Color(1, 1, 1, 0.07))
