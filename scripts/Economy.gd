extends Node
# Ekonomi syiling/XP. Semua nilai dari res://data/config/economy.json (boleh diubah pembangun).
# Pelayan mengira semula ganjaran kuiz untuk akaun dalam talian (server/lib/economy.js); nilai di sini ialah untuk paparan & mod luar talian.

var cfg: Dictionary = {}

func _ready() -> void:
    var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/economy.json"))
    cfg = j if j is Dictionary else {}

func now_my() -> int:
    return int(Time.get_unix_time_from_system()) + 8 * 3600

func day_key() -> String:
    return Time.get_date_string_from_unix_time(now_my())

func week_key() -> int:
    return int(floor(float(now_my() / 86400 + 3) / 7.0))   # minggu bermula Isnin (UTC+8)

func state() -> Dictionary:
    var s: Dictionary = Game.d.eco
    if str(s.get("date", "")) != day_key():
        s = {"date": day_key(), "quiz": 0, "pickup": 0, "mini": 0}
        Game.d.eco = s
    return s

func weekly() -> Dictionary:
    var w: Dictionary = Game.d.weekly
    if int(w.get("k", -1)) != week_key():
        w = {"k": week_key(), "correct": 0, "claimed": false}
        Game.d.weekly = w
    return w

func is_repeat(qid: String) -> bool:
    var seen: Dictionary = Game.d.seen
    if not seen.has(qid):
        return false
    var hrs := float(cfg.caps.repeat_question_cooldown_hours)
    return float(Time.get_unix_time_from_system()) - float(seen[qid]) < hrs * 3600.0

func mark_seen(qid: String) -> void:
    var seen: Dictionary = Game.d.seen
    seen[qid] = int(Time.get_unix_time_from_system())
    if seen.size() > 600:   # buang yang paling lama
        var keys := seen.keys()
        keys.sort_custom(func(a, b): return seen[a] < seen[b])
        for k in keys.slice(0, 150):
            seen.erase(k)

# results: [{id, diff: "easy|medium|hard", right: bool, secs: float}]
func quiz_rewards(results: Array, won: bool) -> Dictionary:
    var c := {"easy": 0, "medium": 0, "hard": 0}
    var xp := 0
    var coins := 0
    var correct_paid := 0
    var correct_all := 0
    var secs := 0.0
    var repeats := 0
    for r in results:
        secs += float(r.secs)
        if not bool(r.right):
            continue
        correct_all += 1
        if is_repeat(str(r.id)):
            repeats += 1   # soalan yang sama dalam 24 jam: tiada ganjaran (anti-ternak)
            continue
        var dname := str(r.diff)
        c[dname] = int(c[dname]) + 1
        correct_paid += 1
        xp += int(cfg.xp_per_correct[dname])
        coins += int(cfg.coins_per_correct[dname])
    var total := results.size()
    xp += int(cfg.quiz_complete.xp)
    coins += int(cfg.quiz_complete.coins)
    var perfect := correct_paid == total and total > 0
    if perfect:
        xp += int(cfg.perfect_quiz.xp)
        coins += int(cfg.perfect_quiz.coins)
    if won:
        xp += int(cfg.win_vs_robot.xp)
        coins += int(cfg.win_vs_robot.coins)
    if correct_paid >= ceili(float(total) / 2.0) and total > 0 and secs / float(total) < float(cfg.speed_bonus.avg_seconds_below):
        xp += int(cfg.speed_bonus.xp)
    var st := state()
    var room := maxi(int(cfg.caps.daily_quiz_coins) - int(st.quiz), 0)
    var capped := coins > room
    coins = mini(coins, room)
    st.quiz = int(st.quiz) + coins
    for r in results:
        if bool(r.right):
            mark_seen(str(r.id))
    return {"xp": xp, "coins": coins, "c": c, "perfect": perfect, "correct": correct_all, "paid": correct_paid, "repeats": repeats, "capped": capped, "secs": secs}

func pickup_coin() -> int:
    var st := state()
    var v := int(cfg.pickups.coin_value)
    if int(st.pickup) + v > int(cfg.caps.daily_pickup_coins):
        return 0
    st.pickup = int(st.pickup) + v
    return v

func minigame_coins(amount: int) -> int:
    var st := state()
    var room := maxi(int(cfg.caps.daily_minigame_coins) - int(st.mini), 0)
    var give := mini(amount, room)
    st.mini = int(st.mini) + give
    return give

func log_tx(kind: String, delta: int, note: String) -> void:
    var l: Array = Game.d.txlog
    l.append({"ts": int(Time.get_unix_time_from_system()), "k": kind, "d": delta, "n": note})
    if l.size() > 80:
        l.pop_front()
