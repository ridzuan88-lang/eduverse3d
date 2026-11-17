extends Node
# Simpanan setempat (JSON), XP, syiling, baris gilir sync, bunyi.

const SAVE_PATH := "user://eduverse_save.json"

var d: Dictionary = {}
var online_mode := false
var volume := 0.8
var _music: AudioStreamPlayer

func _ready() -> void:
    load_save()
    _start_music()

func fresh() -> Dictionary:
    return {
        "name": "", "year": 1,
        "avatar": {"gender": 0, "skin": 0, "shirt": 0, "hair": 0, "hat": 0, "pack": 0, "pet": 0, "face": 0, "style": 0, "shoes": 0, "acc": 0},
        "owned": ["hat0", "pack0", "pet0", "acc0"],
        # xp/coins = dompet setempat (dipaparkan & dibelanjakan). off_xp = bahagian diperoleh LUAR TALIAN (tidak disahkan, TIDAK masuk kedudukan).
        # ver_xp/ver_coins = jumlah yang disahkan pelayan (satu-satunya yang dipakai papan pendahulu).
        "xp": 0, "coins": 20, "wins": 0, "last_login": "", "off_xp": 0, "off_quizzes": 0, "ver_xp": 0, "ver_coins": 0,
        "daily": {"date": "", "correct": 0, "claimed": false, "chest": false},
        "weekly": {"k": -1, "correct": 0, "claimed": false},
        "eco": {"date": "", "quiz": 0, "pickup": 0, "mini": 0},
        "seen": {}, "txlog": [], "blocked": [], "chat_text": false, "chat_scope": "n",
        "house": {"items": [], "privacy": "private"}, "cache_ann": [],
        "mg": {"target_best": 0, "race_best": {}},
        "queue": [], "refresh_token": "", "uid": "", "volume": 0.8,
    }

func load_save() -> void:
    d = fresh()
    if FileAccess.file_exists(SAVE_PATH):
        var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
        if f:
            var p = JSON.parse_string(f.get_as_text())
            if p is Dictionary:
                for k in p:
                    d[k] = p[k]
    volume = float(d.get("volume", 0.8))

func save() -> void:
    d["volume"] = volume
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(d))

func level() -> int:
    return floori(float(d.xp) / 100.0) + 1

func daily() -> Dictionary:
    var today := Time.get_date_string_from_system()
    if d.daily.get("date", "") != today:
        d.daily = {"date": today, "correct": 0, "claimed": false, "chest": false}
    return d.daily

func new_id() -> String:
    return Crypto.new().generate_random_bytes(8).hex_encode()

func is_verified_session() -> bool:
    return online_mode and str(d.uid) != "" and Auth.id_token != ""

# results: [{id, diff, right, secs}]; rw = Economy.quiz_rewards(...)
func add_result(subject: String, year: int, results: Array, won: bool, rw: Dictionary) -> void:
    d.xp = int(d.xp) + int(rw.xp)
    d.coins = int(d.coins) + int(rw.coins)
    if won:
        d.wins = int(d.wins) + 1
    var dl := daily()
    dl.correct = int(dl.correct) + int(rw.correct)
    Economy.weekly().correct = int(Economy.weekly().correct) + int(rw.correct)
    Economy.log_tx("quiz", int(rw.coins), subject)
    if is_verified_session():
        # Hanya keputusan DALAM TALIAN dihantar ke pelayan (yang mengira semula ganjaran).
        d.queue.append({"id": new_id(), "owner": d.uid, "subject": subject, "year": year, "total": results.size(),
            "c": rw.c, "t": snappedf(float(rw.secs), 0.1), "win": won})
    else:
        # Keputusan luar talian: disimpan berasingan, tidak dihantar, tidak masuk kedudukan sah.
        d.off_xp = int(d.off_xp) + int(rw.xp)
        d.off_quizzes = int(d.off_quizzes) + 1
    save()
    Sync.sync_now()

func add_coins(n: int, kind: String, note := "") -> void:
    d.coins = int(d.coins) + n
    if n != 0:
        Economy.log_tx(kind, n, note)

func spend(n: int, note: String) -> bool:
    if int(d.coins) < n:
        return false
    d.coins = int(d.coins) - n
    Economy.log_tx("spend", -n, note)
    return true

func set_volume(v: float) -> void:
    volume = clampf(v, 0.0, 1.0)
    if _music:
        _music.volume_db = linear_to_db(maxf(volume * 0.35, 0.0001))
        _music.stream_paused = volume < 0.02
    save()

func tone(freqs: Array, dur := 0.12) -> void:
    if volume < 0.02:
        return
    var rate := 22050
    var data := PackedByteArray()
    var n := int(rate * dur)
    for f in freqs:
        for i in n:
            var v := int(sin(TAU * float(f) * float(i) / float(rate)) * 9000.0 * (1.0 - float(i) / float(n)))
            data.append(v & 0xFF)
            data.append((v >> 8) & 0xFF)
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = rate
    w.data = data
    var p := AudioStreamPlayer.new()
    p.stream = w
    p.volume_db = linear_to_db(volume)
    add_child(p)
    p.play()
    p.finished.connect(p.queue_free)

func _start_music() -> void:
    var notes := [262, 330, 392, 330, 294, 349, 440, 349, 262, 392, 523, 392, 330, 294, 262, 0]
    var rate := 22050
    var n := int(rate * 0.3)
    var data := PackedByteArray()
    for f in notes:
        for i in n:
            var v := 0
            if int(f) > 0:
                var env := minf(1.0, float(n - i) / 3000.0) * minf(1.0, float(i) / 300.0)
                v = int(sin(TAU * float(f) * float(i) / float(rate)) * 2500.0 * env)
            data.append(v & 0xFF)
            data.append((v >> 8) & 0xFF)
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = rate
    w.data = data
    w.loop_mode = AudioStreamWAV.LOOP_FORWARD
    w.loop_begin = 0
    w.loop_end = data.size() / 2
    _music = AudioStreamPlayer.new()
    _music.stream = w
    add_child(_music)
    _music.play()
    set_volume(volume)
