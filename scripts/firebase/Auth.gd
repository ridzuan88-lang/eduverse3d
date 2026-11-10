extends Node
# Firebase Authentication melalui REST (Identity Toolkit). Tiada kunci dicipta - isi firebase_config.cfg.

signal result(ok: bool, msg: String)

var api_key := ""
var server_url := ""
var http_url := ""
var id_token := ""
var uid := ""
var refresh_token := ""
var configured := false

func _ready() -> void:
    var cf := ConfigFile.new()
    if cf.load("res://firebase_config.cfg") == OK:
        api_key = str(cf.get_value("firebase", "api_key", ""))
        server_url = str(cf.get_value("server", "ws_url", ""))
        http_url = str(cf.get_value("server", "http_url", ""))
           configured = api_key != "" and not api_key.begins_with("YOUR_")

func _post(url: String, body: String, ctype: String, cb: Callable) -> void:
    var r := HTTPRequest.new()
    add_child(r)
    r.request_completed.connect(func(res: int, code: int, _h: PackedStringArray, bytes: PackedByteArray):
        r.queue_free()
        var j = JSON.parse_string(bytes.get_string_from_utf8())
        cb.call(res == HTTPRequest.RESULT_SUCCESS and code == 200, j if j is Dictionary else {}))
    var err := r.request(url, ["Content-Type: " + ctype], HTTPClient.METHOD_POST, body)
    if err != OK:
        r.queue_free()
        cb.call(false, {})

func _err(j: Dictionary) -> String:
    var m := ""
    if j.has("error") and j.error is Dictionary:
        m = str(j.error.get("message", ""))
    if m.begins_with("EMAIL_EXISTS"): return "E-mel sudah didaftarkan."
    if m.begins_with("INVALID_LOGIN") or m.begins_with("INVALID_PASSWORD") or m.begins_with("EMAIL_NOT_FOUND"): return "E-mel atau kata laluan salah."
    if m.begins_with("WEAK_PASSWORD"): return "Kata laluan terlalu lemah."
    if m.begins_with("TOO_MANY"): return "Terlalu banyak cubaan. Cuba sebentar lagi."
    return "Gagal. Periksa sambungan internet dan konfigurasi Firebase."

func _store(j: Dictionary) -> void:
    id_token = str(j.get("idToken", j.get("id_token", "")))
    refresh_token = str(j.get("refreshToken", j.get("refresh_token", "")))
    uid = str(j.get("localId", j.get("user_id", "")))
    Game.d.refresh_token = refresh_token
    Game.save()

func _auth(ep: String, email: String, pw: String) -> void:
    if not configured:
        result.emit(false, "Firebase belum dikonfigurasi (lihat FIREBASE_SETUP.md).")
        return
    var url := "https://identitytoolkit.googleapis.com/v1/%s?key=%s" % [ep, api_key]
    _post(url, JSON.stringify({"email": email, "password": pw, "returnSecureToken": true}), "application/json",
        func(ok: bool, j: Dictionary):
            if ok:
                _store(j)
                result.emit(true, "Berjaya!")
            else:
                result.emit(false, _err(j)))

func login(email: String, pw: String) -> void:
    _auth("accounts:signInWithPassword", email, pw)

func register(email: String, pw: String) -> void:
    _auth("accounts:signUp", email, pw)

func reset(email: String) -> void:
    if not configured:
        result.emit(false, "Firebase belum dikonfigurasi.")
        return
    var url := "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=" + api_key
    _post(url, JSON.stringify({"requestType": "PASSWORD_RESET", "email": email}), "application/json",
        func(ok: bool, j: Dictionary):
            result.emit(ok, "E-mel set semula dihantar." if ok else _err(j)))

func resume() -> void:
    refresh(func(ok: bool):
        result.emit(ok, "Sesi disambung." if ok else "Sesi tamat. Sila log masuk semula."))

func refresh(cb: Callable) -> void:
    var rt := refresh_token if refresh_token != "" else str(Game.d.refresh_token)
    if not configured or rt == "":
        cb.call(false)
        return
    var url := "https://securetoken.googleapis.com/v1/token?key=" + api_key
    _post(url, "grant_type=refresh_token&refresh_token=" + rt.uri_encode(), "application/x-www-form-urlencoded",
        func(ok: bool, j: Dictionary):
            if ok:
                _store(j)
            cb.call(ok))

func logout() -> void:
    id_token = ""
    uid = ""
    refresh_token = ""
    Game.d.refresh_token = ""
    Game.save()
