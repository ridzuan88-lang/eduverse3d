extends RefCounted
# Ujian runtime dunia (dipanggil oleh smoke_test.gd). Melaksanakan ciri baharu dalam World sebenar tanpa kepala.

func run(t) -> void:
    Game.d = Game.fresh()
    Game.d.name = "Tester"
    Game.online_mode = false
    var w = load("res://scripts/world/World.gd").new()
    t.add_child(w)
    await t.get_tree().create_timer(0.6).timeout
    t.ok(w.extras != null and w.player != null, "dunia dibina")
    t.ok(w.extras.town.nodes.size() >= 9, "bangku awam dibina: %d" % w.extras.town.nodes.size())
    # ---- duduk di bangku
    var sp: Array = w.extras.town.spots()
    t.ok(sp.size() >= 9, "bangku boleh diduduki")
    w.player.position = Vector3(0, 2, -4)
    var res: Dictionary = sp[0].layer.interact(sp[0])
    t.ok(res.has("sit"), "interaksi bangku memberi kedudukan duduk")
    w.player.sit_on(res.sit, float(res.yaw), false)
    await t.get_tree().create_timer(0.3).timeout
    t.ok(w.player.sitting and w.player.anim_state == Avatar.A_SIT, "pemain duduk (anim %d)" % w.player.anim_state)
    t.ok(w._find_near().kind == "stand", "butang Berdiri tersedia semasa duduk")
    var y_before: float = w.player.position.y
    w.player.stand_up()
    await t.get_tree().create_timer(0.2).timeout
    t.ok(not w.player.sitting and w.player.position.y > y_before - 0.2, "berdiri semula")
    # ---- emote
    w.player.play_emote(Avatar.A_DANCE)
    await t.get_tree().create_timer(0.3).timeout
    t.ok(w.player.anim_state == Avatar.A_DANCE, "emote menari aktif")
    w.player.emote = 0
    # ---- rumah: editor
    w.extras.house.load_items([])
    Game.d.coins = 500
    w.extras.start_house_editor()
    await t.get_tree().create_timer(0.3).timeout
    var ed = w.extras.editor
    t.ok(ed != null and w.editing, "editor rumah dibuka")
    ed.place_def = w.extras.cat.house_items[0]   # katil
    ed.cur = Vector3(0, 0, 0)
    ed._place()
    t.ok(w.extras.house.items.size() == 1, "objek diletak")
    ed.cur = Vector3(11.8, 0, 0)    # katil 2m lebar: melepasi sempadan 12
    ed._place()
    t.ok(w.extras.house.items.size() == 1, "objek di luar tanah ditolak")
    var pool: Dictionary = {}
    for d in w.extras.cat.house_items:
        if str(d.id) == "pool1":
            pool = d
    ed.place_def = pool
    ed.cur = Vector3(0, 0, -6)
    ed._place()
    t.ok(w.extras.house.items.size() == 1, "kolam di luar zon ditolak")
    ed.cur = Vector3(0, 0, 8)
    ed._place()
    t.ok(w.extras.house.items.size() == 2, "kolam dalam zon diterima")
    ed._undo()
    t.ok(w.extras.house.items.size() == 1, "buat asal")
    ed._redo()
    t.ok(w.extras.house.items.size() == 2, "buat semula")
    # pintu & lampu
    for id in ["door1", "lamp1", "chair1", "bed1"]:
        for d in w.extras.cat.house_items:
            if str(d.id) == id:
                ed.place_def = d
                ed.cur = Vector3(-6 + float(id.length()), 0, -8)
                ed._place()
    t.ok(w.extras.house.items.size() >= 5, "perabot pelbagai diletak: %d" % w.extras.house.items.size())
    # pilih, putar, skala, padam
    ed.cur = Vector3(0, 0, 8)
    ed._select()
    t.ok(ed.sel >= 0, "pilih objek")
    ed._scale(1.0)
    ed._rotate()
    ed._delete()
    t.ok(w.extras.house.items.size() >= 4 and ed.sel == -1, "padam objek terpilih")
    ed.place_def = {}
    # simpan & keluar
    ed._save()
    t.ok(Game.d.house.items.size() == w.extras.house.items.size(), "rumah disimpan setempat")
    ed._exit()
    await t.get_tree().create_timer(0.2).timeout
    t.ok(w.extras.editor == null and not w.editing, "editor ditutup")
    # interaksi dalam rumah
    var kinds := {}
    for s in w.extras.house.spots():
        kinds[str(s.node.get_meta("kind"))] = s
    t.ok(kinds.has("door") and kinds.has("light") and kinds.has("seat") and kinds.has("bed"), "spot interaktif: " + str(kinds.keys()))
    if kinds.has("door"):
        var s0: Dictionary = kinds.door
        w.extras.house.interact(s0)
        t.ok(int(s0.node.get_meta("state")) == 1 and int(w.extras.house.items[s0.idx].o) == 1, "pintu dibuka & keadaan direkod")
    if kinds.has("light"):
        var s1: Dictionary = kinds.light
        w.extras.house.interact(s1)
        t.ok((s1.node.get_node("L") as OmniLight3D).visible, "lampu dihidupkan")
    if kinds.has("bed"):
        var rb: Dictionary = w.extras.house.interact(kinds.bed)
        w.player.sit_on(rb.sit, float(rb.yaw), bool(rb.lie))
        await t.get_tree().create_timer(0.3).timeout
        t.ok(w.player.anim_state == Avatar.A_LIE, "baring di katil")
        w.player.stand_up()
    # muat semula dari rumah tersimpan
    w.extras.house.load_items(Game.d.house.items)
    t.ok(w.extras.house.nodes.size() == Game.d.house.items.size(), "rumah dimuat semula dari simpanan")
    # ---- panel-panel
    for name in ["chat", "emote", "board", "lb", "class", "profile", "menu", "house", "portal", "admin"]:
        if w.panel != null:
            w._close_panel()
        match name:
            "chat": w.extras.open_chat()
            "emote": w.extras.open_emotes()
            "board": Panels.board(w, w._open_panel("t", 780))
            "lb": Panels.leaderboard(w, w._open_panel("t", 780))
            "class": Panels.class_panel(w, w._open_panel("t", 780))
            "profile": Panels.profile(w, w._open_panel("t", 780))
            "menu": w.open_menu()
            "house": w.extras.open_house_panel()
            "portal": w.extras.open_portal()
            "admin": Panels.admin(w, w._open_panel("t", 780))
        await t.get_tree().create_timer(0.1).timeout
        t.ok(w.panel != null, "panel dibuka: " + name)
    w._close_panel()
    # papan notis luar talian: ada cache?
    # ---- cuaca/masa
    for e in [{"time": 3.0, "weather": "rain"}, {"time": 12.0, "weather": "cloudy"}, {"time": 18.5, "weather": "clear"}]:
        w.extras.apply_env(e)
        await t.get_tree().create_timer(0.05).timeout
    t.ok(not w.env_res.fog_enabled, "cuaca cerah menutup kabus")
    # ---- Mod Pembangun ditolak tanpa peranan / luar talian
    w.role = "player"
    w.dev.start()
    t.ok(w.extras.editor == null, "Mod Pembangun tidak boleh dibuka oleh pemain biasa")
    w.role = "world_dev"
    w.dev.start()
    t.ok(w.extras.editor == null, "Mod Pembangun perlu dalam talian (luar talian ditolak)")
    # ---- mini-game sasaran
    w.extras.start_target("time")
    await t.get_tree().create_timer(1.6).timeout
    var ta = w.extras.minigame
    t.ok(ta != null and ta.targets.size() > 0, "sasaran muncul: %d" % ta.targets.size())
    ta._shoot()
    # tembak terus ke sasaran pertama
    var tg: Node3D = ta.targets[0].n
    w.player.cam.global_position = tg.global_position + Vector3(0, 0, 6)
    w.player.cam.look_at(tg.global_position)
    ta._cd = 0.0
    ta._shoot()
    await t.get_tree().create_timer(0.5).timeout
    ta._end(false)
    await t.get_tree().create_timer(0.2).timeout
    t.ok(w.extras.minigame == null, "arena sasaran tamat")
    w._close_panel()
    # ---- lumba (semua litar)
    for tr in RaceGame.TRACKS.keys():
        Game.d.coins = 500
        w.extras.start_race(str(tr), 4)
        await t.get_tree().create_timer(0.4).timeout
        var rg = w.extras.minigame
        t.ok(rg != null and rg.racers.size() == 4 and w.player.riding != null, "lumba bermula: " + str(tr))
        rg.t_count = 0.5   # langkau kira detik
        await t.get_tree().create_timer(2.0).timeout
        t.ok(rg.state == "race", "kira detik 3-2-1 tamat -> lumba")
        var moved: bool = false
        for r in rg.racers:
            if r.ai and (r.v.position - (rg.CENTER + rg.wps[0])).length() > 3.0:
                moved = true
        t.ok(moved, "Robot AI bergerak di " + str(tr))
        rg._end(true)
        await t.get_tree().create_timer(0.2).timeout
        t.ok(w.extras.minigame == null and w.player.riding == null, "lumba ditamatkan & pemain turun")
        w._close_panel()
    w.queue_free()
