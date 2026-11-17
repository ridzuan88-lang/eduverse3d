class_name Safety
extends RefCounted
# Penapis sembang sebelah klien (cermin server/lib/safety.js). Pelayan tetap menapis semula - klien hanya memberi maklum balas pantas.
# Penapis kata kunci TIDAK sempurna: kekalkan fungsi lapor + semakan moderator.

static var _cfg: Dictionary = {}

static func cfg() -> Dictionary:
    if _cfg.is_empty():
        var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/safety.json"))
        _cfg = j if j is Dictionary else {}
    return _cfg

static func normalize(s: String) -> String:
    var t := s.to_lower()
    for pair in [["àáâãäå", "a"], ["èéêë", "e"], ["ìíîï", "i"], ["òóôõö", "o"], ["ùúûü", "u"], ["ç", "c"], ["ñ", "n"]]:
        for ch in str(pair[0]):
            t = t.replace(ch, str(pair[1]))
    for pair in [["@", "a"], ["4", "a"], ["3", "e"], ["1", "i"], ["!", "i"], ["|", "i"], ["0", "o"], ["$", "s"], ["5", "s"], ["7", "t"]]:
        t = t.replace(pair[0], pair[1])
    var rx := RegEx.new()
    rx.compile("[^a-z\\s]")
    t = rx.sub(t, " ", true)
    rx.compile("(.)\\1{2,}")
    t = rx.sub(t, "$1$1", true)
    rx.compile("\\s+")
    t = rx.sub(t, " ", true).strip_edges()
    return t

static func _squash(s: String) -> String:
    var t := normalize(s).replace(" ", "")
    var rx := RegEx.new()
    rx.compile("(.)\\1+")
    return rx.sub(t, "$1", true)

static func _join_singles(norm: String) -> String:
    var out: Array = []
    var run := ""
    for tok in norm.split(" "):
        if tok.length() == 1:
            run += tok
            continue
        if run != "":
            out.append(run)
            run = ""
        out.append(tok)
    if run != "":
        out.append(run)
    return " ".join(out)

static func _has_word(norm: String, word: String) -> bool:
    var w := normalize(word)
    if w.contains(" "):
        return norm.contains(w)
    var rx := RegEx.new()
    rx.compile("(^|\\s)" + w + "(s|es|lah|nya)?(\\s|$)")
    return rx.search(norm) != null

static func check(text: String) -> Dictionary:
    var c := cfg()
    var t := text.strip_edges()
    var rx := RegEx.new()
    rx.compile("\\s+")
    t = rx.sub(t, " ", true)
    if t == "":
        return {"ok": false, "reason": "empty"}
    if t.length() > int(c.max_len):
        return {"ok": false, "reason": "long"}
    rx.compile("[^\\s@]+\\s*(@|\\(at\\)|\\[at\\])\\s*[^\\s@]+")
    if rx.search(t) != null and t.contains("."):
        return {"ok": false, "reason": "personal"}
    rx.compile("(?i)(https?://|www\\.|\\.com\\b|\\.my\\b|\\.net\\b|\\.org\\b|bit\\.ly)")
    if rx.search(t) != null:
        return {"ok": false, "reason": "personal"}
    var digits := t
    for ch in [" ", "(", ")", ".", "-", "+", "_"]:
        digits = digits.replace(ch, "")
    rx.compile("\\d{7,}")
    if rx.search(digits) != null:
        return {"ok": false, "reason": "personal"}
    var dc := 0
    for ch in t:
        if ch >= "0" and ch <= "9":
            dc += 1
    if dc >= 8:
        return {"ok": false, "reason": "personal"}
    var norm := normalize(t)
    var nums := "(kosong|satu|dua|tiga|empat|lima|enam|tujuh|lapan|sembilan|zero|one|two|three|four|five|six|seven|eight|nine)"
    rx.compile("\\b" + nums + "(\\s+" + nums + "){5,}")
    if rx.search(norm) != null:
        return {"ok": false, "reason": "personal"}
    for cue in c.personal_info_cues:
        if norm.contains(normalize(str(cue))):
            return {"ok": false, "reason": "personal"}
    for ph in c.threat_phrases:
        if norm.contains(normalize(str(ph))):
            return {"ok": false, "reason": "threat"}
    var sq := _squash(t)
    var joined := _join_singles(norm)
    for w in c.blocked_words:
        if _has_word(norm, str(w)) or _has_word(joined, str(w)):
            return {"ok": false, "reason": "bad"}
        var ws := _squash(str(w))
        if ws.length() >= 5 and sq.contains(ws):
            return {"ok": false, "reason": "bad"}
    return {"ok": true, "text": t}

static func why_text(reason: String) -> String:
    match reason:
        "personal": return "Jangan kongsi maklumat peribadi (nombor telefon, e-mel, alamat, pautan)."
        "bad": return "Mesej mengandungi perkataan yang tidak sesuai."
        "threat": return "Mesej bersifat ugutan tidak dibenarkan."
        "long": return "Mesej terlalu panjang."
        "empty": return "Tulis sesuatu dahulu."
        "rate": return "Terlalu laju. Tunggu sebentar."
        "locked": return "Sembang dikunci seketika kerana terlalu banyak mesej tidak sesuai."
        "text_off": return "Sembang teks dimatikan. Guna ayat pantas atau minta ibu bapa membukanya."
    return "Mesej tidak dapat dihantar."
