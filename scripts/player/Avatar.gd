class_name Avatar
extends RefCounted
# Avatar 3D asal dibina daripada bentuk asas (low-poly) - tiada aset luaran.

const SKIN := [Color("f1c27d"), Color("e0ac69"), Color("c68642"), Color("8d5524"), Color("ffdbac")]
const SHIRT := [Color("e53935"), Color("1e88e5"), Color("43a047"), Color("fdd835"), Color("8e24aa"), Color("fb8c00")]
const HAIR := [Color("2b1b0e"), Color("6d4c41"), Color("f9d71c"), Color("e53935"), Color("9e9e9e")]
const HATS := ["Tiada", "Topi", "Topi Tinggi", "Mahkota"]
const HAT_PRICE := [0, 20, 30, 60]
const PACKS := ["Tiada", "Beg Biru", "Beg Merah"]
const PACK_PRICE := [0, 25, 25]
const PETS := ["Tiada", "Kucing Oren", "Kucing Putih", "Anak Ungu"]
const PET_PRICE := [0, 50, 50, 80]
const PET_COL := [Color.WHITE, Color("ff9800"), Color("f5f5f5"), Color("9c27b0")]
const FACES := ["Senyum", "Ceria", "Tenang", "Terkejut"]
const STYLES := ["Pendek", "Panjang", "Tocang", "Sanggul", "Berdiri"]
const SHOES := ["Hitam", "Putih", "Merah", "Biru", "Hijau"]
const SHOE_COL := [Color("212121"), Color("f5f5f5"), Color("d32f2f"), Color("1565c0"), Color("2e7d32")]
const ACCS := ["Tiada", "Cermin Mata", "Skarf", "Fon Kepala"]
const ACC_PRICE := [0, 30, 25, 40]

# Kod animasi (juga dihantar ke pelayan sebagai `a`; pelayan sah 0-22)
const A_IDLE := 0
const A_WALK := 1
const A_RUN := 2
const A_SPRINT := 3
const A_JUMP := 4
const A_FALL := 5
const A_LAND := 6
const A_CARRY := 8
const A_WAVE := 10
const A_CLAP := 11
const A_LAUGH := 12
const A_DANCE := 13
const A_SIT := 14
const A_POINT := 15
const A_THUMBS := 16
const A_GREET := 17
const A_CELEBRATE := 18
const A_DRIVE := 19
const A_RIDE := 20
const A_LIE := 21
# Emote yang boleh dicetuskan pemain dari menu pantas: [kod, nama]
const EMOTES := [[10, "Lambai"], [11, "Tepuk"], [12, "Ketawa"], [13, "Menari"], [14, "Duduk"], [15, "Tunjuk"], [16, "Bagus!"], [17, "Salam"], [18, "Raikan"]]

static func mat(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    return m

static func box(s: Vector3) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = s
    return b

static func sph(r: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 12
    s.rings = 6
    return s

static func cyl(rt: float, rb: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = rt
    c.bottom_radius = rb
    c.height = h
    c.radial_segments = 12
    return c

static func part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat(c)
    mi.position = pos
    parent.add_child(mi)
    return mi

static func _idx(av: Dictionary, key: String, size: int) -> int:
    return posmod(int(av.get(key, 0)), size)

static func build(av: Dictionary) -> Node3D:
    var root := Node3D.new()
    var body := Node3D.new()
    body.name = "Body"
    root.add_child(body)
    var skin: Color = SKIN[_idx(av, "skin", SKIN.size())]
    var shirt: Color = SHIRT[_idx(av, "shirt", SHIRT.size())]
    var hair: Color = HAIR[_idx(av, "hair", HAIR.size())]
    var shoe: Color = SHOE_COL[_idx(av, "shoes", SHOE_COL.size())]
    var g := int(av.get("gender", 0))
    var pants := Color("37474f") if g == 0 else Color("6a1b9a")
    # badan & leher
    part(body, box(Vector3(0.72, 0.82, 0.42)), shirt, Vector3(0, 1.08, 0))
    part(body, box(Vector3(0.74, 0.1, 0.44)), shirt.darkened(0.2), Vector3(0, 0.7, 0))
    part(body, cyl(0.1, 0.1, 0.12), skin, Vector3(0, 1.52, 0))
    # kepala (lebih besar: mesra kanak-kanak) dengan muka terperinci
    var head := Node3D.new()
    head.name = "Head"
    head.position = Vector3(0, 1.55, 0)
    body.add_child(head)
    part(head, sph(0.38), skin, Vector3(0, 0.38, 0))
    for s in [-1, 1]:
        part(head, sph(0.075), Color.WHITE, Vector3(0.14 * s, 0.42, 0.31))        # mata
        part(head, sph(0.042), Color("1b1b1b"), Vector3(0.14 * s, 0.42, 0.365))   # anak mata
        var brow := part(head, box(Vector3(0.14, 0.03, 0.03)), hair.darkened(0.3), Vector3(0.14 * s, 0.55, 0.33))
        brow.rotation.z = -0.12 * s if _idx(av, "face", FACES.size()) != 3 else 0.2 * s
        part(head, sph(0.06), Color("ff9e9e"), Vector3(0.24 * s, 0.28, 0.28)).scale = Vector3(1, 0.6, 0.4)  # pipi
        part(head, sph(0.07), skin.darkened(0.06), Vector3(0.39 * s, 0.38, 0.0))  # telinga
    part(head, sph(0.045), skin.darkened(0.1), Vector3(0, 0.33, 0.375))          # hidung
    match _idx(av, "face", FACES.size()):
        0:
            var m := part(head, box(Vector3(0.14, 0.025, 0.03)), Color("8d2b2b"), Vector3(0, 0.2, 0.365))
            part(head, box(Vector3(0.04, 0.025, 0.03)), Color("8d2b2b"), Vector3(-0.08, 0.215, 0.36))
            part(head, box(Vector3(0.04, 0.025, 0.03)), Color("8d2b2b"), Vector3(0.08, 0.215, 0.36))
            m.name = "Mouth"
        1:
            part(head, box(Vector3(0.2, 0.07, 0.03)), Color("7b1f1f"), Vector3(0, 0.2, 0.362))
            part(head, box(Vector3(0.17, 0.025, 0.03)), Color.WHITE, Vector3(0, 0.222, 0.372))
        2:
            part(head, box(Vector3(0.1, 0.02, 0.03)), Color("8d2b2b"), Vector3(0, 0.2, 0.365))
        3:
            part(head, sph(0.04), Color("5a1a1a"), Vector3(0, 0.2, 0.355))
    # gaya rambut
    var hs := _idx(av, "style", STYLES.size())
    if hs != 4:
        part(head, sph(0.4), hair, Vector3(0, 0.46, -0.04)).scale = Vector3(1.0, 0.78, 1.0)
    match hs:
        1:
            part(head, box(Vector3(0.78, 0.9, 0.18)), hair, Vector3(0, 0.05, -0.3))
        2:
            part(head, sph(0.14), hair, Vector3(0, 0.3, -0.45))
            part(head, cyl(0.06, 0.1, 0.5), hair, Vector3(0, 0.0, -0.5))
        3:
            part(head, sph(0.18), hair, Vector3(0, 0.88, -0.05))
        4:
            for i in 7:
                var a := float(i) * TAU / 7.0
                var sp := part(head, cyl(0.0, 0.1, 0.3), hair, Vector3(cos(a) * 0.22, 0.78, sin(a) * 0.22 - 0.03))
                sp.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
            part(head, cyl(0.0, 0.12, 0.38), hair, Vector3(0, 0.88, -0.03))
            part(head, sph(0.37), hair, Vector3(0, 0.45, -0.05)).scale = Vector3(1.0, 0.7, 1.0)
    # aksesori
    match _idx(av, "acc", ACCS.size()):
        1:
            for s in [-1, 1]:
                var lens := part(head, cyl(0.1, 0.1, 0.02), Color(0.7, 0.9, 1.0, 0.6), Vector3(0.14 * s, 0.42, 0.39))
                lens.rotation.x = PI / 2.0
            part(head, box(Vector3(0.1, 0.02, 0.02)), Color("212121"), Vector3(0, 0.43, 0.39))
        2:
            part(body, cyl(0.2, 0.22, 0.12), Color("ef5350"), Vector3(0, 1.48, 0))
            part(body, box(Vector3(0.12, 0.4, 0.06)), Color("ef5350"), Vector3(0.12, 1.25, 0.24))
        3:
            part(head, box(Vector3(0.84, 0.06, 0.1)), Color("37474f"), Vector3(0, 0.62, 0))
            for s in [-1, 1]:
                part(head, cyl(0.12, 0.12, 0.1), Color("1976d2"), Vector3(0.4 * s, 0.38, 0)).rotation.z = PI / 2.0
    # tangan & kaki (pivot di bahu/pinggul supaya mudah dianimasi)
    for s in [-1, 1]:
        var side := "L" if s < 0 else "R"
        var leg := Node3D.new()
        leg.name = "Leg" + side
        leg.position = Vector3(0.18 * s, 0.7, 0)
        body.add_child(leg)
        part(leg, box(Vector3(0.29, 0.5, 0.3)), pants, Vector3(0, -0.25, 0))
        part(leg, box(Vector3(0.25, 0.14, 0.26)), Color("f5f5f5"), Vector3(0, -0.57, 0))   # stoking
        part(leg, box(Vector3(0.3, 0.14, 0.42)), shoe, Vector3(0, -0.64, 0.05))
        var arm := Node3D.new()
        arm.name = "Arm" + side
        arm.position = Vector3(0.48 * s, 1.43, 0)
        body.add_child(arm)
        part(arm, box(Vector3(0.2, 0.62, 0.2)), skin, Vector3(0, -0.31, 0))
        part(arm, box(Vector3(0.22, 0.26, 0.22)), shirt, Vector3(0, -0.1, 0))
        part(arm, sph(0.11), skin, Vector3(0, -0.66, 0))                                    # tapak tangan
        if s == 1:
            part(arm, box(Vector3(0.05, 0.1, 0.05)), skin, Vector3(0.0, -0.74, 0.1))        # ibu jari
    match _idx(av, "hat", HATS.size()):
        1:
            part(head, cyl(0.3, 0.3, 0.14), Color("d32f2f"), Vector3(0, 0.78, 0))
            part(head, box(Vector3(0.5, 0.04, 0.35)), Color("b71c1c"), Vector3(0, 0.72, 0.3))
        2:
            part(head, cyl(0.25, 0.25, 0.45), Color("212121"), Vector3(0, 1.0, 0))
            part(head, cyl(0.42, 0.42, 0.04), Color("212121"), Vector3(0, 0.78, 0))
        3:
            part(head, cyl(0.32, 0.26, 0.24), Color("ffc107"), Vector3(0, 0.88, 0))
    match _idx(av, "pack", PACKS.size()):
        1:
            part(body, box(Vector3(0.5, 0.6, 0.22)), Color("1976d2"), Vector3(0, 1.15, -0.32))
        2:
            part(body, box(Vector3(0.5, 0.6, 0.22)), Color("d32f2f"), Vector3(0, 1.15, -0.32))
    return root

static func build_pet(idx: int) -> Node3D:
    var p := Node3D.new()
    var c: Color = PET_COL[posmod(idx, PET_COL.size())]
    part(p, sph(0.28), c, Vector3(0, 0.32, 0))
    part(p, sph(0.2), c, Vector3(0, 0.62, 0.18))
    part(p, box(Vector3(0.1, 0.16, 0.06)), c, Vector3(-0.1, 0.84, 0.18))
    part(p, box(Vector3(0.1, 0.16, 0.06)), c, Vector3(0.1, 0.84, 0.18))
    part(p, sph(0.04), Color.BLACK, Vector3(-0.07, 0.66, 0.36))
    part(p, sph(0.04), Color.BLACK, Vector3(0.07, 0.66, 0.36))
    return p

# Sasaran pose bagi satu keadaan. Kekunci: al/ar = putaran-x lengan, alz/arz = putaran-z (sisi), ll/lr = kaki, dy = naik/turun badan,
# lean = condong badan, hx/hy = kepala, twist = pusingan badan.
static func _target(state: int, t: float) -> Dictionary:
    var p := {"al": 0.0, "ar": 0.0, "alz": 0.06, "arz": -0.06, "ll": 0.0, "lr": 0.0, "dy": 0.0, "lean": 0.0, "hx": 0.0, "hy": 0.0, "twist": 0.0}
    match state:
        0:
            p.dy = sin(t * 2.0) * 0.012
            p.al = sin(t * 1.5) * 0.05
            p.ar = -sin(t * 1.5) * 0.05
        1, 2, 3:
            var sp := 8.0
            var amp := 0.6
            if state == 2:
                sp = 13.0
                amp = 0.9
            elif state == 3:
                sp = 16.0
                amp = 1.1
                p.lean = 0.22
            var s := sin(t * sp) * amp
            p.ll = s
            p.lr = -s
            p.al = -s
            p.ar = s
            p.dy = absf(sin(t * sp)) * (0.02 if state == 1 else 0.05)
        4:
            p.al = -2.5
            p.ar = -2.5
            p.ll = -0.5
            p.lr = 0.2
        5:
            p.alz = -1.2
            p.arz = 1.2
            p.ll = sin(t * 14.0) * 0.4
            p.lr = -sin(t * 14.0) * 0.4
        6:
            p.dy = -0.22
            p.al = -0.5
            p.ar = -0.5
            p.ll = -0.5
            p.lr = -0.5
        8:
            p.al = -1.3
            p.ar = -1.3
            p.alz = 0.3
            p.arz = -0.3
        10:
            p.ar = 0.0
            p.arz = 2.7 + sin(t * 11.0) * 0.28
            p.al = sin(t * 1.5) * 0.05
        11:
            var c := 0.5 + 0.5 * sin(t * 14.0)
            p.al = -1.3
            p.ar = -1.3
            p.alz = 0.55 * c
            p.arz = -0.55 * c
        12:
            p.hx = -0.3 + sin(t * 18.0) * 0.1
            p.dy = sin(t * 18.0) * 0.04
            p.al = -0.6
            p.ar = -0.6
            p.alz = 0.5
            p.arz = -0.5
            p.lean = -0.1
        13:
            var b := sin(t * 5.0)
            p.twist = b * 0.4
            p.dy = absf(b) * 0.1
            p.al = -2.4 + b * 0.6
            p.ar = -2.4 - b * 0.6
            p.ll = b * 0.4
            p.lr = -b * 0.4
        14:
            p.ll = -1.5
            p.lr = -1.5
            p.al = -0.5
            p.ar = -0.5
        15:
            p.ar = -1.57
            p.arz = -0.1
            p.hy = -0.15
        16:
            p.ar = -1.25 + sin(t * 8.0) * 0.1
            p.arz = -0.15
            p.dy = absf(sin(t * 8.0)) * 0.015
        17:
            p.ar = -1.9
            p.arz = -0.95
            p.al = 0.0
            p.lean = 0.3
            p.hx = 0.25
        18:
            var j := absf(sin(t * 9.0))
            p.al = -2.9
            p.ar = -2.9
            p.alz = -0.4
            p.arz = 0.4
            p.dy = j * 0.35
            p.ll = -j * 0.3
            p.lr = j * 0.3
        19:
            p.ll = -1.35
            p.lr = -1.35
            p.al = -1.2
            p.ar = -1.2
        20:
            p.ll = -0.9
            p.lr = -0.9
            p.al = -1.1
            p.ar = -1.1
            p.lean = 0.25
        21:
            p.lean = -PI / 2.0
            p.dy = 0.18
            p.al = 0.1
            p.ar = 0.1
    return p

# Animasi dengan peralihan lembut (lerp ke pose sasaran). dt = masa bingkai.
static func animate(root: Node3D, t: float, state: int, dt := 0.016) -> void:
    var body := root.get_node_or_null("Body")
    if body == null:
        return
    var tg := _target(state, t)
    var cur: Dictionary = root.get_meta("pose") if root.has_meta("pose") else tg.duplicate()
    var k := clampf(dt * 14.0, 0.0, 1.0)
    for key in tg:
        cur[key] = lerpf(float(cur[key]), float(tg[key]), k)
    root.set_meta("pose", cur)
    body.get_node("LegL").rotation.x = cur.ll
    body.get_node("LegR").rotation.x = cur.lr
    var al: Node3D = body.get_node("ArmL")
    var ar: Node3D = body.get_node("ArmR")
    al.rotation = Vector3(cur.al, 0.0, cur.alz)
    ar.rotation = Vector3(cur.ar, 0.0, cur.arz)
    body.position.y = cur.dy
    body.rotation.x = cur.lean
    body.rotation.y = cur.twist
    var head: Node3D = body.get_node("Head")
    head.rotation = Vector3(cur.hx, cur.hy, 0.0)
