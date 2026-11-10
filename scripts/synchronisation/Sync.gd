extends Node
# Baris gilir setempat -> pelayan (POST /sync). Pelayan mengesahkan token, menolak pendua dan skor mustahil.

var busy := false

func sync_now(retry := true) -> void:
    if busy or Auth.id_token == "" or not Auth.configured or not Auth.server_ok():
        return
    var txs: Array = []
    for t in Game.d.queue:
        var owner := str(t.get("owner", ""))
        if owner == "" or owner == Auth.uid:
            txs.append(t)
    if txs.is_empty():
        return
    busy = true
    var r := HTTPRequest.new()
    add_child(r)
    r.request_completed.connect(_done.bind(r, retry))
    var err := r.request(Auth.http_url + "/sync",
        ["Content-Type: application/json", "Authorization: Bearer " + Auth.id_token],
        HTTPClient.METHOD_POST, JSON.stringify({"name": Game.d.name, "txs": txs}))
    if err != OK:
        busy = false
        r.queue_free()

func _done(res: int, code: int, _h: PackedStringArray, body: PackedByteArray, r: HTTPRequest, retry: bool) -> void:
    r.queue_free()
    busy = false
    if code == 401 and retry:
        Auth.refresh(func(ok: bool):
            if ok:
                sync_now(false))
        return
    if res != HTTPRequest.RESULT_SUCCESS or code != 200:
        return  # kekal dalam baris gilir, cuba lagi kemudian
    var j = JSON.parse_string(body.get_string_from_utf8())
    if not (j is Dictionary):
        return
    var done: Array = []
    for k in ["accepted", "duplicate", "rejected"]:
        done.append_array(j.get(k, []))
    Game.d.queue = Game.d.queue.filter(func(t): return not done.has(t.get("id", "")))
    Game.save()
