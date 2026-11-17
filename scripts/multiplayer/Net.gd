extends Node
# Klien WebSocket: sambung ke pelayan permainan, hantar kedudukan, terima pemain lain, sambung semula automatik.

signal chat_received(id: String, name: String, text: String, scope: String)
signal chat_rejected(why: String)
signal report_ok

var my_u := ""
var radius := 30.0
var chat_log: Array = []     # {id, u, n, m, s} 30 terakhir
var muted: Dictionary = {}   # u -> true (senyap sesi ini)

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

func send_state(pos: Vector3, rot: float, anim: int, veh := 0) -> void:
    _send({"t": "s", "x": snappedf(pos.x, 0.01), "y": snappedf(pos.y, 0.01), "z": snappedf(pos.z, 0.01),
        "r": snappedf(rot, 0.01), "a": anim, "v": veh})

func send_quick(i: int, scope := "n") -> void:
    _send({"t": "q", "i": i, "s": scope})

func send_chat(text: String, scope := "n") -> void:
    _send({"t": "c", "text": text, "s": scope})

func send_cfg_text(on: bool) -> void:
    _send({"t": "cfg", "ft": on})

func report(id: String, why: String) -> void:
    _send({"t": "rep", "id": id, "why": why})

func block(u: String) -> void:
    if u != "" and not Game.d.blocked.has(u):
        Game.d.blocked.append(u)
        Game.save()
        if Game.d.blocked.size() > 50:
            Game.d.blocked.pop_front()

func unblock(u: String) -> void:
    Game.d.blocked.erase(u)
    Game.save()

func is_ready() -> bool:
    return ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and _joined

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
                    "avatar": Game.d.avatar, "room": room, "ft": bool(Game.d.chat_text), "blocks": Game.d.blocked}))
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
            my_u = str(m.get("u", ""))
            radius = float(m.get("radius", 30.0))
        "c":
            var u := str(m.get("u", ""))
            if Game.d.blocked.has(u) or muted.has(u):
                return
            var e := {"id": str(m.id), "u": u, "n": str(m.n), "m": str(m.m), "s": str(m.get("s", "n"))}
            chat_log.append(e)
            if chat_log.size() > 30:
                chat_log.pop_front()
            chat_received.emit(e.id, e.n, e.m, e.s)
        "cr":
            chat_rejected.emit(str(m.get("why", "")))
        "repok":
            report_ok.emit()
        "p":
            var fresh := {}
            for p in m.get("list", []):
                if str(p.id) != my_id:
                    fresh[str(p.id)] = {"n": p.n, "u": str(p.get("u", "")), "lv": int(p.get("lv", 1)), "cl": str(p.get("cl", "")), "av": p.av, "x": p.x, "y": p.y, "z": p.z, "r": p.r, "a": int(p.a), "v": int(p.get("v", 0))}
            remote = fresh
        "err":
            var why := str(m.get("m", ""))
            status = "ralat: " + why
            if why == "auth":
                Auth.refresh(func(_ok: bool): pass)
            if why == "full":
                _wanted = false
