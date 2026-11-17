class_name PlotLayer
extends Node3D
# Lapisan objek: memaparkan senarai item (rumah pemain ATAU dunia pembangun), menguruskan interaksi objek (pintu, lampu, tempat duduk, katil).
# Item: {id, x, y, z, r (0-3 x 90 darjah) ATAU ry (darjah), s (skala), o (keadaan 0/1)}. Koordinat relatif kepada `origin` lapisan.

var catalog_by_id := {}
var items: Array = []
var nodes: Array = []

func set_catalog(list: Array) -> void:
    catalog_by_id.clear()
    for d in list:
        catalog_by_id[str(d.id)] = d

static func item_yaw(it: Dictionary) -> float:
    if it.has("ry"):
        return deg_to_rad(float(it.ry))
    return float(int(it.get("r", 0))) * PI / 2.0

func load_items(arr: Array) -> void:
    items = arr.duplicate(true)
    rebuild()

func rebuild() -> void:
    for n in nodes:
        if is_instance_valid(n):
            n.queue_free()
    nodes.clear()
    for it in items:
        var n := make_node(it)
        if n:
            nodes.append(n)
            add_child(n)

func make_node(it: Dictionary) -> Node3D:
    var def: Dictionary = catalog_by_id.get(str(it.id), {})
    if def.is_empty():
        return null
    var n := ObjectFactory.build(def, int(it.get("o", 0)))
    n.position = Vector3(float(it.x), float(it.get("y", 0.0)), float(it.z))
    n.rotation.y = item_yaw(it)
    n.scale = Vector3.ONE * float(it.get("s", 1.0))
    return n

func spots() -> Array:
    var out: Array = []
    for i in nodes.size():
        var n: Node3D = nodes[i]
        if not is_instance_valid(n):
            continue
        var k := str(n.get_meta("kind"))
        var title := ""
        match k:
            "door": title = "Buka/Tutup pintu"
            "light": title = "Suis lampu"
            "seat": title = "Duduk"
            "bed": title = "Baring di katil"
        if title != "":
            out.append({"pos": n.global_position, "kind": "obj", "title": title, "node": n, "idx": i, "layer": self})
    return out

# Dipanggil oleh World apabila pemain tekan AMBIL pada objek. Pulangkan Dictionary {sit: Vector3, yaw, lie} jika perlu duduk.
func interact(spot: Dictionary) -> Dictionary:
    var n: Node3D = spot.node
    var k := str(n.get_meta("kind"))
    if k == "door" or k == "light":
        var st := ObjectFactory.toggle(n)
        if int(spot.idx) < items.size():
            items[int(spot.idx)].o = st
        return {}
    var yaw := n.rotation.y
    var sc := n.scale.y
    if k == "seat":
        return {"sit": n.global_position + Vector3(0, 0.5 * sc, 0), "yaw": yaw, "lie": false}
    if k == "bed":
        var def: Dictionary = n.get_meta("def")
        var len := float(def.size[2]) * sc
        return {"sit": n.global_position + Vector3(0, 0.62 * sc, 0) + Vector3(0, 0, len / 2.0 - 0.35).rotated(Vector3.UP, yaw), "yaw": yaw, "lie": true}
    return {}
