extends Node
# Memuat bank soalan JSON: res://data/questions/<subjek>_d<tahun>.json

const SUBJECTS := {"bm": "Bahasa Melayu", "en": "Bahasa Inggeris", "math": "Matematik",
    "sci": "Sains", "jawi": "Jawi", "arab": "Bahasa Arab", "mix": "Campuran"}
const DIFF := ["", "easy", "medium", "hard"]
var _cache := {}

func subject_name(code: String) -> String:
    return SUBJECTS.get(code, code)

func bank(subject: String, year: int) -> Array:
    var key := "%s_d%d" % [subject, year]
    if _cache.has(key):
        return _cache[key]
    var out: Array = []
    var path := "res://data/questions/%s.json" % key
    if FileAccess.file_exists(path):
        var p = JSON.parse_string(FileAccess.get_file_as_string(path))
        if p is Array:
            out = p
    _cache[key] = out
    return out

func pick(subject: String, year: int, diff: int, n: int) -> Array:
    var all: Array = []
    if subject == "mix":
        for s in ["bm", "en", "math", "sci", "jawi", "arab"]:
            all.append_array(bank(s, year))
    else:
        all = bank(subject, year).duplicate()
    var pool: Array = all
    if diff > 0:
        var f := all.filter(func(q): return q.difficulty == DIFF[diff])
        if f.size() >= n:
            pool = f
    pool = pool.duplicate()
    pool.shuffle()
    return pool.slice(0, n)
