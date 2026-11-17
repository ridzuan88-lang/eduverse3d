class_name ObjectFactory
extends RefCounted
# Membina objek katalog (rumah & dunia) daripada bentuk asas asal. Setiap nod membawa meta: def, kind.
# Bentuk dikongsi (cache) dan MeshInstance3D diberi jarak penglihatan (LOD asas) untuk prestasi Android.

static var _mats := {}
static var _meshes := {}
const VIS_RANGE := 170.0

static func mat(c: Color, glow := false) -> StandardMaterial3D:
    var key := "%s_%s" % [c.to_html(), glow]
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    if glow:
        m.emission_enabled = true
        m.emission = c
        m.emission_energy_multiplier = 1.3
    _mats[key] = m
    return m

static func _mesh(kind: String, a: Vector3) -> Mesh:
    var key := kind + str(a)
    if _meshes.has(key):
        return _meshes[key]
    var m: Mesh
    match kind:
        "box":
            var b := BoxMesh.new()
            b.size = a
            m = b
        "sph":
            var s := SphereMesh.new()
            s.radius = a.x
            s.height = a.x * 2.0
            s.radial_segments = 10
            s.rings = 5
            m = s
        "cyl":
            var c := CylinderMesh.new()
            c.top_radius = a.x
            c.bottom_radius = a.y
            c.height = a.z
            c.radial_segments = 10
            m = c
        "prism":
            var p := PrismMesh.new()
            p.size = a
            m = p
    _meshes[key] = m
    return m

static func _add(parent: Node3D, kind: String, a: Vector3, c: Color, pos: Vector3, glow := false) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = _mesh(kind, a)
    mi.material_override = mat(c, glow)
    mi.position = pos
    mi.visibility_range_end = VIS_RANGE
    parent.add_child(mi)
    return mi

static func is_solid(id: String, kind: String, sz: Vector3) -> bool:
    for k in ["flower", "grass", "rug", "floor", "lake", "river", "road", "side_walk", "pool", "hill", "mountain", "bush", "plant", "rock1", "balloon", "bld_park", "pic", "window", "mg_checkpoint"]:
        if id.contains(k):
            return false
    return kind != "floor" and sz.y > 0.4

static func build(def: Dictionary, state := 0) -> Node3D:
    var root := Node3D.new()
    var id := str(def.id)
    var kind := str(def.kind)
    var sz := Vector3(float(def.size[0]), float(def.size[1]), float(def.size[2]))
    var col := Color(str(def.color))
    root.set_meta("def", def)
    root.set_meta("kind", kind)
    root.set_meta("state", state)
    if id.contains("tree"):
        _add(root, "cyl", Vector3(0.22, 0.3, sz.y * 0.5), Color("6d4c41"), Vector3(0, sz.y * 0.25, 0))
        if id == "nat_tree2":
            for k in 5:
                var a := float(k) * TAU / 5.0
                _add(root, "box", Vector3(0.3, 0.1, 1.6), col, Vector3(cos(a) * 0.6, sz.y * 0.55, sin(a) * 0.6)).rotation.y = -a
        else:
            _add(root, "sph", Vector3(sz.x * 0.5, 0, 0), col, Vector3(0, sz.y * 0.7, 0))
    elif id.contains("roof"):
        _add(root, "prism", sz, col, Vector3(0, sz.y / 2.0, 0))
    elif id.contains("pool"):
        _add(root, "box", Vector3(sz.x + 0.5, 0.2, sz.z + 0.5), Color("e0e0e0"), Vector3(0, 0.1, 0))
        _add(root, "box", Vector3(sz.x, 0.25, sz.z), col, Vector3(0, 0.14, 0), true)
    elif kind == "light":
        _add(root, "cyl", Vector3(0.05, 0.06, maxf(sz.y - 0.3, 0.2)), Color("424242"), Vector3(0, (sz.y - 0.3) / 2.0, 0))
        var bulb := _add(root, "sph", Vector3(0.18, 0, 0), col, Vector3(0, sz.y - 0.2, 0), state == 1 or id.contains("street") or id.contains("traffic"))
        bulb.name = "Bulb"
        var ol := OmniLight3D.new()
        ol.name = "L"
        ol.omni_range = 9.0
        ol.light_energy = 1.6
        ol.position = Vector3(0, sz.y - 0.2, 0)
        ol.visible = state == 1 or id.contains("street") or id.contains("traffic")
        root.add_child(ol)
        root.set_meta("lit", ol.visible)
    elif kind == "door":
        var hinge := Node3D.new()
        hinge.name = "Hinge"
        hinge.position = Vector3(-sz.x / 2.0, 0, 0)
        root.add_child(hinge)
        _add(hinge, "box", sz, col, Vector3(sz.x / 2.0, sz.y / 2.0, 0))
        _add(hinge, "sph", Vector3(0.07, 0, 0), Color("ffd54f"), Vector3(sz.x * 0.85, sz.y * 0.5, sz.z))
        hinge.rotation.y = -PI / 2.0 if state == 1 else 0.0
    elif kind == "bed":
        _add(root, "box", Vector3(sz.x, 0.35, sz.z), Color("6d4c41"), Vector3(0, 0.175, 0))
        _add(root, "box", Vector3(sz.x - 0.2, 0.25, sz.z - 0.2), col, Vector3(0, 0.47, 0))
        _add(root, "box", Vector3(sz.x * 0.7, 0.18, 0.6), Color.WHITE, Vector3(0, 0.66, -sz.z / 2.0 + 0.45))
        _add(root, "box", Vector3(sz.x, 0.9, 0.15), Color("5d4037"), Vector3(0, 0.45, -sz.z / 2.0))
    elif kind == "seat":
        _add(root, "box", Vector3(sz.x, 0.2, sz.z), col, Vector3(0, 0.4, 0))
        _add(root, "box", Vector3(sz.x, sz.y - 0.5, 0.15), col.darkened(0.15), Vector3(0, 0.5 + (sz.y - 0.5) / 2.0, -sz.z / 2.0 + 0.08))
        if id.contains("sofa"):
            for sx in [-1.0, 1.0]:
                _add(root, "box", Vector3(0.25, 0.4, sz.z), col.darkened(0.25), Vector3(sx * (sz.x / 2.0 - 0.12), 0.55, 0))
        for sx in [-1.0, 1.0]:
            for sz2 in [-1.0, 1.0]:
                _add(root, "box", Vector3(0.1, 0.35, 0.1), Color("4e342e"), Vector3(sx * (sz.x / 2.0 - 0.1), 0.17, sz2 * (sz.z / 2.0 - 0.1)))
    elif id.contains("flower"):
        _add(root, "cyl", Vector3(0.03, 0.03, 0.35), Color("388e3c"), Vector3(0, 0.17, 0))
        _add(root, "sph", Vector3(0.17, 0, 0), col, Vector3(0, 0.4, 0))
    elif id.contains("bush") or id.contains("plant"):
        _add(root, "sph", Vector3(sz.x * 0.5, 0, 0), col, Vector3(0, sz.y * 0.4, 0))
    elif id.contains("hill"):
        _add(root, "sph", Vector3(sz.x / 2.0, 0, 0), col, Vector3(0, 0, 0)).scale = Vector3(1, sz.y / sz.x, sz.z / sz.x)
    elif id.contains("mountain"):
        _add(root, "cyl", Vector3(0.0, sz.x / 2.0, sz.y), col, Vector3(0, sz.y / 2.0, 0))
        _add(root, "cyl", Vector3(0.0, sz.x * 0.12, sz.y * 0.25), Color.WHITE, Vector3(0, sz.y * 0.88, 0))
    elif id.contains("lake") or id.contains("river"):
        _add(root, "box", sz, col, Vector3(0, 0.05, 0), true)
    elif id.contains("round"):
        _add(root, "cyl", Vector3(sz.x / 2.0, sz.x / 2.0, 0.1), col, Vector3(0, 0.05, 0))
        _add(root, "cyl", Vector3(sz.x / 5.0, sz.x / 5.0, 0.3), Color("66bb6a"), Vector3(0, 0.15, 0))
    elif id.contains("road") or id.contains("side_walk"):
        _add(root, "box", sz, col, Vector3(0, 0.05, 0))
        if id == "road_straight":
            for z in [-6.0, 0.0, 6.0]:
                _add(root, "box", Vector3(0.3, 0.02, 2.0), Color.WHITE, Vector3(0, 0.11, z))
    elif id.begins_with("bld_") and id != "bld_park" and id != "bld_playground":
        _add(root, "box", sz, col, Vector3(0, sz.y / 2.0, 0))
        _add(root, "box", Vector3(sz.x + 0.8, 0.6, sz.z + 0.8), col.darkened(0.35), Vector3(0, sz.y + 0.3, 0))
        _add(root, "box", Vector3(1.4, 2.2, 0.15), Color("5d4037"), Vector3(0, 1.1, sz.z / 2.0 + 0.05))
    elif id == "bld_playground":
        _add(root, "box", Vector3(sz.x, 0.2, sz.z), Color("ffcc80"), Vector3(0, 0.1, 0))
        _add(root, "box", Vector3(0.2, 2.0, 3.0), Color("e53935"), Vector3(-2, 1.0, 0))
        _add(root, "box", Vector3(3.0, 0.2, 0.8), Color("1e88e5"), Vector3(2, 1.0, 0))
    elif id.contains("sign"):
        _add(root, "cyl", Vector3(0.06, 0.06, sz.y), Color("757575"), Vector3(0, sz.y / 2.0, 0))
        _add(root, "cyl", Vector3(0.5, 0.5, 0.06), col, Vector3(0, sz.y, 0.05)).rotation.x = PI / 2.0
    elif id.contains("mg_target"):
        _add(root, "cyl", Vector3(0.6, 0.6, 0.15), col, Vector3(0, 1.2, 0)).rotation.x = PI / 2.0
        _add(root, "cyl", Vector3(0.3, 0.3, 0.17), Color.WHITE, Vector3(0, 1.2, 0)).rotation.x = PI / 2.0
    elif id.contains("balloon"):
        _add(root, "sph", Vector3(0.4, 0, 0), col, Vector3(0, 1.0, 0))
        _add(root, "cyl", Vector3(0.01, 0.01, 1.0), Color("bdbdbd"), Vector3(0, 0.5, 0))
    elif id.contains("flag"):
        _add(root, "cyl", Vector3(0.05, 0.05, sz.y), Color("757575"), Vector3(0, sz.y / 2.0, 0))
        _add(root, "box", Vector3(0.05, 0.8, 1.2), col, Vector3(0, sz.y - 0.5, 0.6))
    elif id.contains("globe"):
        _add(root, "cyl", Vector3(0.1, 0.4, 0.5), Color("424242"), Vector3(0, 0.25, 0))
        _add(root, "sph", Vector3(0.55, 0, 0), col, Vector3(0, 1.1, 0))
    else:
        _add(root, "box", sz, col, Vector3(0, sz.y / 2.0, 0))
    if is_solid(id, kind, sz):
        var sb := StaticBody3D.new()
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = Vector3(sz.x, sz.y, sz.z) if kind != "door" else Vector3(sz.x, sz.y, 0.2)
        cs.shape = bs
        cs.position = Vector3(0, sz.y / 2.0, 0) if kind != "door" else Vector3(0, sz.y / 2.0, 0)
        if kind == "door":
            sb.name = "Body"
            cs.position = Vector3(0, sz.y / 2.0, 0)
        sb.add_child(cs)
        root.add_child(sb)
        if kind == "door":
            sb.visible = state != 1
            sb.process_mode = Node.PROCESS_MODE_INHERIT
            cs.disabled = state == 1
    return root

# Ubah keadaan objek interaktif (pintu/lampu). Pulangkan keadaan baharu.
static func toggle(n: Node3D) -> int:
    var kind := str(n.get_meta("kind"))
    var st := 1 - int(n.get_meta("state", 0))
    n.set_meta("state", st)
    if kind == "door":
        var h: Node3D = n.get_node("Hinge")
        var tw := n.create_tween() if n.is_inside_tree() else null
        if tw:
            tw.tween_property(h, "rotation:y", -PI / 2.0 if st == 1 else 0.0, 0.25)
        else:
            h.rotation.y = -PI / 2.0 if st == 1 else 0.0
        var b := n.get_node_or_null("Body")
        if b:
            (b.get_child(0) as CollisionShape3D).set_deferred("disabled", st == 1)
    elif kind == "light":
        var l: OmniLight3D = n.get_node("L")
        l.visible = st == 1
        var bulb: MeshInstance3D = n.get_node("Bulb")
        var d: Dictionary = n.get_meta("def")
        bulb.material_override = mat(Color(str(d.color)), st == 1)
    return st
