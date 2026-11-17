extends Node
# Klien HTTP ke pelayan EduVerse: token Firebase, auto-refresh pada 401, cache luar talian untuk GET.
# cb(ok: bool, data: Dictionary, code: int). Jika GET gagal dan ada cache, data["_cached"] = true.

var dev_code := ""   # kod pengesahan Pembangun (pilihan, hanya dalam ingatan sesi - TIDAK disimpan)

func can_go_online() -> bool:
    return Game.online_mode and Auth.id_token != "" and Auth.configured and Auth.server_ok()

func _cache_path(key: String) -> String:
    return "user://cache_%s.json" % key.validate_filename()

func cached(key: String) -> Dictionary:
    var p := _cache_path(key)
    if FileAccess.file_exists(p):
        var j = JSON.parse_string(FileAccess.get_file_as_string(p))
        if j is Dictionary:
            return j
    return {}

func _save_cache(key: String, data: Dictionary) -> void:
    var f := FileAccess.open(_cache_path(key), FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data))

func get_json(path: String, cb: Callable, cache_key := "") -> void:
    _request(HTTPClient.METHOD_GET, path, {}, cb, cache_key, true)

func post_json(path: String, body: Dictionary, cb: Callable) -> void:
    _request(HTTPClient.METHOD_POST, path, body, cb, "", true)

func _fallback(cache_key: String, cb: Callable, code: int) -> void:
    if cache_key != "":
        var c := cached(cache_key)
        if not c.is_empty():
            c["_cached"] = true
            cb.call(true, c, code)
            return
    cb.call(false, {}, code)

func _request(method: int, path: String, body: Dictionary, cb: Callable, cache_key: String, retry: bool) -> void:
    if not can_go_online():
        _fallback(cache_key, cb, 0)
        return
    var r := HTTPRequest.new()
    r.timeout = 15.0
    add_child(r)
    var headers := PackedStringArray(["Authorization: Bearer " + Auth.id_token, "Content-Type: application/json"])
    if dev_code != "":
        headers.append("X-Dev-Code: " + dev_code)
    r.request_completed.connect(func(res: int, code: int, _h: PackedStringArray, bytes: PackedByteArray):
        r.queue_free()
        if code == 401 and retry:
            Auth.refresh(func(ok: bool):
                if ok:
                    _request(method, path, body, cb, cache_key, false)
                else:
                    _fallback(cache_key, cb, code))
            return
        var j = JSON.parse_string(bytes.get_string_from_utf8())
        var d: Dictionary = j if j is Dictionary else {}
        if res == HTTPRequest.RESULT_SUCCESS and code == 200:
            if cache_key != "":
                _save_cache(cache_key, d)
            cb.call(true, d, code)
        elif res != HTTPRequest.RESULT_SUCCESS:
            _fallback(cache_key, cb, 0)   # tiada rangkaian -> guna cache jika ada
        else:
            cb.call(false, d, code))
    var err := r.request(Auth.http_url + path, headers, method, JSON.stringify(body) if method == HTTPClient.METHOD_POST else "")
    if err != OK:
        r.queue_free()
        _fallback(cache_key, cb, 0)
