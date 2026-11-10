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
        "avatar": {"gender": 0, "skin": 0, "shirt": 0, "hair": 0, "hat": 0, "pack": 0, "pet": 0},
        "owned": ["hat0", "pack0", "pet0"],
        "xp": 0, "coins": 20, "wins": 0, "last_login": "",
        "daily": {"date": "", "correct": 0, "claimed": false, "chest": false},
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

func add_result(subject: String, year: int, correct: int, total: int, xp: int, coins: int, won: bool) -> void:
    d.xp = int(d.xp) + xp
    d.coins = int(d.coins) + coins
    if won:
        d.wins = int(d.wins) + 1
    var dl := daily()
    dl.correct = int(dl.correct) + correct
    d.queue.append({"id": new_id(), "owner": d.uid, "subject": subject, "year": year,
        "correct": correct, "total": total, "xp": xp, "ts": int(Time.get_unix_time_from_system())})
    save()
    Sync.sync_now()

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
