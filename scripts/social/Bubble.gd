class_name Bubble
extends RefCounted
# Gelembung ucapan di atas avatar (mengikut avatar, hilang sendiri) dan papan nama.

const LIFETIME := 5.0

static func say(parent: Node3D, text: String, y := 3.5) -> void:
    var old := parent.get_node_or_null("Bubble")
    if old:
        old.free()
    var root := Node3D.new()
    root.name = "Bubble"
    root.position = Vector3(0, y, 0)
    var chars := mini(text.length(), 18)
    var lines := ceili(float(text.length()) / 18.0)
    var w := chars * 0.17 + 0.5
    var h := lines * 0.36 + 0.28
    var q := MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(w, h)
    q.mesh = qm
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(1, 1, 1, 0.92)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.no_depth_test = true
    m.render_priority = 1
    q.material_override = m
    root.add_child(q)
    var l := Label3D.new()
    l.text = text
    l.font_size = 44
    l.pixel_size = 0.006
    l.width = 18.0 * 44.0 * 0.62
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.modulate = Color("1b1b1b")
    l.outline_size = 0
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.render_priority = 2
    root.add_child(l)
    parent.add_child(root)
    if parent.is_inside_tree():
        parent.get_tree().create_timer(LIFETIME).timeout.connect(func():
            if is_instance_valid(root):
                root.queue_free())

static func nameplate(node: Node3D, name: String, level: int, cls: String, y := 2.95) -> void:
    var old := node.get_node_or_null("Plate")
    if old:
        old.free()
    var l := Label3D.new()
    l.name = "Plate"
    l.text = "%s  Lv%d" % [name, level] + (("\n[" + cls + "]") if cls != "" else "")
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.font_size = 44
    l.pixel_size = 0.01
    l.outline_size = 12
    l.position = Vector3(0, y, 0)
    node.add_child(l)
