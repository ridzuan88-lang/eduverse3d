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
    var g := int(av.get("gender", 0))
    var pants := Color("37474f") if g == 0 else Color("6a1b9a")
    part(body, box(Vector3(0.7, 0.8, 0.4)), shirt, Vector3(0, 1.1, 0))
    part(body, sph(0.32), skin, Vector3(0, 1.85, 0))
    part(body, sph(0.05), Color.BLACK, Vector3(-0.12, 1.9, 0.28))
    part(body, sph(0.05), Color.BLACK, Vector3(0.12, 1.9, 0.28))
    part(body, box(Vector3(0.62, 0.18, 0.62)), hair, Vector3(0, 2.08, 0))
    if g == 1:
        part(body, box(Vector3(0.62, 0.7, 0.2)), hair, Vector3(0, 1.8, -0.28))
    for s in [-1, 1]:
        var side := "L" if s < 0 else "R"
        var leg := Node3D.new()
        leg.name = "Leg" + side
        leg.position = Vector3(0.18 * s, 0.7, 0)
        body.add_child(leg)
        part(leg, box(Vector3(0.28, 0.7, 0.3)), pants, Vector3(0, -0.35, 0))
        part(leg, box(Vector3(0.3, 0.15, 0.4)), Color("212121"), Vector3(0, -0.65, 0.05))
        var arm := Node3D.new()
        arm.name = "Arm" + side
        arm.position = Vector3(0.48 * s, 1.45, 0)
        body.add_child(arm)
        part(arm, box(Vector3(0.2, 0.7, 0.2)), skin, Vector3(0, -0.35, 0))
        part(arm, box(Vector3(0.22, 0.25, 0.22)), shirt, Vector3(0, -0.1, 0))
    match _idx(av, "hat", HATS.size()):
        1:
            part(body, cyl(0.3, 0.3, 0.14), Color("d32f2f"), Vector3(0, 2.2, 0))
            part(body, box(Vector3(0.5, 0.04, 0.35)), Color("b71c1c"), Vector3(0, 2.14, 0.3))
        2:
            part(body, cyl(0.25, 0.25, 0.45), Color("212121"), Vector3(0, 2.4, 0))
            part(body, cyl(0.42, 0.42, 0.04), Color("212121"), Vector3(0, 2.18, 0))
        3:
            part(body, cyl(0.32, 0.26, 0.24), Color("ffc107"), Vector3(0, 2.28, 0))
    match _idx(av, "pack", PACKS.size()):
        1:
            part(body, box(Vector3(0.5, 0.6, 0.22)), Color("1976d2"), Vector3(0, 1.15, -0.31))
        2:
            part(body, box(Vector3(0.5, 0.6, 0.22)), Color("d32f2f"), Vector3(0, 1.15, -0.31))
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

static func animate(root: Node3D, t: float, state: int) -> void:
    var body := root.get_node_or_null("Body")
    if body == null:
        return
    var sp := 0.0
    var amp := 0.0
    if state == 1:
        sp = 8.0
        amp = 0.6
    elif state >= 2:
        sp = 13.0
        amp = 0.9
    var s := sin(t * sp) * amp
    body.get_node("LegL").rotation.x = s
    body.get_node("LegR").rotation.x = -s
    body.get_node("ArmL").rotation.x = -s
    body.get_node("ArmR").rotation.x = s
