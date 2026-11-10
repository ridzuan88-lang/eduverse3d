extends Node
# Klien WebSocket: sambung ke pelayan permainan, hantar kedudukan, terima pemain lain, sambung semula automatik.

const PRESETS := ["Hai!", "Terima kasih!", "Bagus!", "Jom main!", "Hore!", "Selamat tinggal!"]

var ws: WebSocketPeer = null
var url := ""
var room := "public"
var my_id := ""
var remote := {}
var status := "luar talian"
var _joined := false
var _wanted := false
var _retry := 0.0
var _send_t := 0.0

func start(u: String, _tok: String, rm := "public") -> void:
    stop()
    if u == "" or u.contains("YOUR-"):
        status = "pelayan belum dikonfigurasi"
        return
    url = u
    room = rm
    _wanted = true
    _connect()

func stop() -> void:
    _wanted = false
    if ws:
        ws.close()
    ws = null
    remote.clear()
    my_id = ""
    status = "luar talian"

func _connect() -> void:
    ws = WebSocketPeer.new()
    _joined = false
    status = "menghubungkan" if ws.connect_to_url(url) == OK else "gagal"

func _send(o: Dictionary) -> void:
    if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and _joined:
        ws.send_text(JSON.stringify(o))

func send_state(pos: Vector3, rot: float, anim: int) -> void:
    _send({"t": "s", "x": snappedf(pos.x, 0.01), "y": snappedf(pos.y, 0.01), "z": snappedf(pos.z, 0.01),
        "r": snappedf(rot, 0.01), "a": anim})

func send_emote(i: int) -> void:
    _send({"t": "e", "i": i})

func _process(dt: float) -> void:
    if ws == null:
        if _wanted:
            _retry -= dt
            if _retry <= 0.0:
                _retry = 3.0
                _connect()
        return
    ws.poll()
    match ws.get_ready_state():
        WebSocketPeer.STATE_OPEN:
            if not _joined:
                _joined = true
                status = "dalam talian"
                ws.send_text(JSON.stringify({"t": "join", "token": Auth.id_token, "name": Game.d.name,
                    "avatar": Game.d.avatar, "room": room}))
            while ws.get_available_packet_count() > 0:
                _handle(ws.get_packet().get_string_from_utf8())
        WebSocketPeer.STATE_CLOSED:
            ws = null
            remote.clear()
            if _wanted:
                status = "terputus - menyambung semula"
                _retry = 3.0

func _handle(txt: String) -> void:
    var m = JSON.parse_string(txt)
    if not (m is Dictionary):
        return
    match str(m.get("t", "")):
        "w":
            my_id = str(m.id)
        "p":
            var fresh := {}
            for p in m.get("list", []):
                if str(p.id) != my_id:
                    fresh[str(p.id)] = {"n": p.n, "av": p.av, "x": p.x, "y": p.y, "z": p.z, "r": p.r, "a": p.a, "m": p.get("m", "")}
            remote = fresh
        "err":
            var why := str(m.get("m", ""))
            status = "ralat: " + why
            if why == "auth":
                Auth.refresh(func(_ok: bool): pass)
            if why == "full":
                _wanted = false
