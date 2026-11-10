extends CanvasLayer
# Mini-game soalan berpilihan bermasa melawan Robot AI (luar talian) + Susun Huruf untuk perkataan tunggal.

signal closed

const ROUNDS := 8
const TIME := 20.0

var subject := "mix"
var year := 1
var diff := 0
var qs: Array = []
var order: Array = []
var i := 0
var score := 0
var ai_score := 0
var correct := 0
var xp_sum := 0
var left := 0.0
var running := false
var ai_time := 5.0
var ai_acc := 0.65
var head: Label
var qlab: Label
var bar: ProgressBar
var fb: Label
var nxt: Button
var grid: GridContainer
var opts: Array = []
var box: VBoxContainer
var scr_box: VBoxContainer
var scr_word: Label
var scr_target := ""
var scr_buttons: Array = []
var _scramble := false

func setup(s: String, y: int, d: int) -> void:
    subject = s
    year = y
    diff = d
    ai_acc = [0.65, 0.45, 0.65, 0.85][d]
    qs = QBank.pick(s, y, d, ROUNDS)

func _ready() -> void:
    layer = 20
    var bg := ColorRect.new()
    bg.color = Color("14235c")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var cc := CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(cc)
    box = VBoxContainer.new()
    box.custom_minimum_size = Vector2(1000, 0)
    box.add_theme_constant_override("separation", 12)
    cc.add_child(box)
    head = UI.lbl("", 22)
    box.add_child(head)
    qlab = UI.lbl("", 32)
    qlab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    qlab.custom_minimum_size = Vector2(1000, 100)
    qlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(qlab)
    bar = ProgressBar.new()
    bar.custom_minimum_size = Vector2(1000, 20)
    bar.show_percentage = false
    box.add_child(bar)
    grid = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 12)
    box.add_child(grid)
    for k in 4:
        var b := UI.btn("", Vector2(492, 74), 26)
        b.pressed.connect(_answer.bind(k))
        grid.add_child(b)
        opts.append(b)
    scr_box = VBoxContainer.new()
    scr_box.add_theme_constant_override("separation", 10)
    box.add_child(scr_box)
    fb = UI.lbl("", 20, Color("ffe082"))
    fb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    fb.custom_minimum_size = Vector2(1000, 60)
    box.add_child(fb)
    nxt = UI.btn("Seterusnya", Vector2(260, 54))
    nxt.pressed.connect(_next)
    box.add_child(nxt)
    if qs.is_empty():
        head.text = "Tiada soalan untuk pilihan ini."
        grid.hide()
        bar.hide()
        nxt.text = "Tutup"
        nxt.pressed.disconnect(_next)
        nxt.pressed.connect(_close)
        return
    _show()

func _is_word(a: String) -> bool:
    if a.length() < 3 or a.length() > 10:
        return false
    for c in a:
        if not "abcdefghijklmnopqrstuvwxyz".contains(c):
            return false
    return true

func _show() -> void:
    var q: Dictionary = qs[i]
    head.text = "%s  |  Soalan %d/%d  |  Anda %d  -  Robot %d" % [QBank.subject_name(q.subject), i + 1, qs.size(), score, ai_score]
    qlab.text = str(q.question)
    order = range(q.options.size())
    order.shuffle()
    var ans := str(q.options[int(q.answer)])
    _scramble = (i % 3 == 2) and (q.subject == "bm" or q.subject == "en") and _is_word(ans)
    for c in scr_box.get_children():
        c.queue_free()
    scr_buttons.clear()
    grid.visible = not _scramble
    for k in 4:
        opts[k].visible = k < order.size()
        if k < order.size():
            opts[k].text = str(q.options[order[k]])
            opts[k].disabled = false
            opts[k].modulate = Color.WHITE
    if _scramble:
        _build_scramble(ans)
        qlab.text = str(q.question) + "\n(Susun huruf untuk menjawab)"
    fb.text = ""
    nxt.visible = false
    left = TIME
    running = true
    ai_time = randf_range(3.0, 10.0)

func _build_scramble(ans: String) -> void:
    scr_target = ans
    scr_word = UI.lbl("_ ".repeat(ans.length()), 44, Color("ffd54f"))
    scr_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    scr_box.add_child(scr_word)
    var letters: Array = Array(ans.split(""))
    letters.shuffle()
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    scr_box.add_child(row)
    for l in letters:
        var b := UI.btn(l.to_upper(), Vector2(70, 70), 30)
        b.pressed.connect(_scr_pick.bind(b, l))
        row.add_child(b)
        scr_buttons.append(b)
    var clr := UI.btn("Padam", Vector2(160, 48), 20)
    clr.pressed.connect(_scr_clear)
    scr_box.add_child(clr)
    scr_word.set_meta("built", "")

func _scr_pick(b: Button, l: String) -> void:
    if not running:
        return
    b.disabled = true
    var cur: String = scr_word.get_meta("built") + l
    scr_word.set_meta("built", cur)
    scr_word.text = " ".join(cur.split("")) + (" _".repeat(scr_target.length() - cur.length()))
    if cur.length() == scr_target.length():
        _resolve_scramble(cur == scr_target)

func _scr_clear() -> void:
    if not running:
        return
    scr_word.set_meta("built", "")
    scr_word.text = "_ ".repeat(scr_target.length())
    for b in scr_buttons:
        b.disabled = false

func _process(dt: float) -> void:
    if running:
        left -= dt
        bar.value = maxf(left, 0.0) / TIME * 100.0
        if left <= 0.0:
            _resolve(-1)

func _answer(k: int) -> void:
    if running:
        _resolve(k)

func _resolve_scramble(right: bool) -> void:
    _finish_q(right, -1 if right else -2)

func _resolve(k: int) -> void:
    var q: Dictionary = qs[i]
    var right := k >= 0 and int(order[k]) == int(q.answer)
    _finish_q(right, k)

func _finish_q(right: bool, k: int) -> void:
    running = false
    var q: Dictionary = qs[i]
    var elapsed := TIME - maxf(left, 0.0)
    for b in opts:
        b.disabled = true
    if not _scramble:
        opts[order.find(int(q.answer))].modulate = Color("66ff88")
        if k >= 0 and not right:
            opts[k].modulate = Color("ff6b6b")
    else:
        for b in scr_buttons:
            b.disabled = true
    var pts := 0
    if right:
        correct += 1
        xp_sum += int(q.xp)
        pts = 10 + (5 if elapsed < ai_time else 0)
        score += pts
        Game.tone([660, 880])
    else:
        Game.tone([240, 180])
    var ai_ok := randf() < ai_acc
    if ai_ok:
        ai_score += 10 + (5 if ai_time < elapsed else 0)
    var verdict := "Salah."
    if right:
        verdict = "Betul! +%d" % pts
    elif left <= 0.0:
        verdict = "Masa tamat!"
    fb.text = verdict + "  " + str(q.explanation) + "\nRobot menjawab " + ("betul" if ai_ok else "salah") + "."
    nxt.text = "Seterusnya" if i < qs.size() - 1 else "Lihat Keputusan"
    nxt.visible = true

func _next() -> void:
    i += 1
    if i >= qs.size():
        _end()
    else:
        _show()

func _end() -> void:
    var win := score > ai_score
    var xp := xp_sum + (20 if win else 0)
    var coins := correct * 2 + (5 if win else 0)
    Game.add_result(subject, year, correct, qs.size(), xp, coins, win)
    Game.tone([523, 659, 784, 1047] if win else [392, 330])
    for c in box.get_children():
        c.queue_free()
    var title := "KAMU MENANG!" if win else ("SERI" if score == ai_score else "Robot menang - cuba lagi!")
    box.add_child(UI.lbl(title, 48, Color("ffd54f")))
    box.add_child(UI.lbl("Betul: %d / %d" % [correct, qs.size()], 30))
    box.add_child(UI.lbl("Skor anda %d  -  Robot %d" % [score, ai_score], 30))
    box.add_child(UI.lbl("Ganjaran: +%d XP   +%d syiling" % [xp, coins], 30, Color("a5d6a7")))
    var cb := UI.btn("Tutup", Vector2(260, 60), 26)
    cb.pressed.connect(_close)
    box.add_child(cb)

func _close() -> void:
    closed.emit()
    queue_free()
