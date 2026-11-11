class_name Fighter
extends Node3D
## 코드로 만드는 격투 캐릭터: 각진 몸통·팔다리(관절마다 Node3D), 얼굴(눈·눈썹·코·입), 머리 모양, 옷.
## 앞은 +Z, 왼쪽은 +X. 자세는 관절 각도(도)이고, 걷기·달리기는 계산으로 만든다(끊기지 않게).

static var _mats := {}
static var _meshes := {}
static var _line: StandardMaterial3D

static func mat(c: Color, outline := true, flat := false) -> StandardMaterial3D:
	var key := "%s%s%s" % [c.to_html(), outline, flat]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if flat:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if outline:
		if _line == null:
			_line = StandardMaterial3D.new()
			_line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_line.albedo_color = Color(0.09, 0.06, 0.1)
			_line.cull_mode = BaseMaterial3D.CULL_FRONT
			_line.grow = true
			_line.grow_amount = 0.016
		m.next_pass = _line
	_mats[key] = m
	return m

static func sph(r: float, seg := 14) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r; m.height = r * 2.0; m.radial_segments = seg; m.rings = seg / 2
	return m

static func box(v: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = v
	return m

static func cyl(rt: float, rb: float, h: float, seg := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt; m.bottom_radius = rb; m.height = h; m.radial_segments = seg; m.rings = 1
	return m

## 각진 덩어리: 아래(bw×bd)와 위(tw×td) 크기가 다른 상자. 면마다 따로 빛을 받는다
static func taper(bw: float, bd: float, tw: float, td: float, h: float) -> ArrayMesh:
	var key := "t%.3f,%.3f,%.3f,%.3f,%.3f" % [bw, bd, tw, td, h]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var b := [Vector3(-bw, -h, -bd) * 0.5, Vector3(bw, -h, -bd) * 0.5, Vector3(bw, -h, bd) * 0.5, Vector3(-bw, -h, bd) * 0.5]
	var t := [Vector3(-tw, h, -td) * 0.5, Vector3(tw, h, -td) * 0.5, Vector3(tw, h, td) * 0.5, Vector3(-tw, h, td) * 0.5]
	var quads := [[b[0], b[1], b[2], b[3]], [t[0], t[1], t[2], t[3]]]
	for i in 4:
		quads.append([b[i], b[(i + 1) % 4], t[(i + 1) % 4], t[i]])
	for q in quads:
		var n: Vector3 = ((q[1] as Vector3) - q[0]).cross((q[2] as Vector3) - q[0])
		var mid: Vector3 = ((q[0] as Vector3) + q[1] + q[2] + q[3]) * 0.25
		# 바깥을 보는 면이 시계 방향이 되게
		var order := [0, 1, 2, 0, 2, 3] if n.dot(mid) < 0.0 else [0, 2, 1, 0, 3, 2]
		for k in order:
			st.add_vertex(q[k])
	st.generate_normals()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh

const HIP := 0.70
## 유형별 생김새
const LOOKS := {
	"brawler": {"scale": 1.0, "bulk": 1.0, "hair_style": "spiky", "hair": "#b0522a", "eye": "#7a4a2a", "brow": -16, "top": "#d8362f", "inner": "#f4f0e6", "jacket": true,
		"pants": "#34508f", "shoes": "#f2f2f2", "sole": "#c8382f", "gloves": "#2a2632", "trim": "#ffd23a", "band": "#f4f0e6", "belt": "#5a3a22", "guard": "guard"},
	"agent": {"scale": 1.0, "bulk": 0.88, "hair_style": "slick", "hair": "#c9ccd6", "eye": "#3a78c8", "brow": -6, "top": "#23252e", "inner": "#f4f4f8", "jacket": true, "tie": "#c8323a",
		"pants": "#23252e", "shoes": "#141418", "sole": "#141418", "gloves": "#f4f4f8", "trim": "#8a8f9c", "shades": true, "belt": "#141418", "long": true, "guard": "guard_agent"},
	"psychic": {"scale": 0.95, "bulk": 0.82, "hair_style": "twin", "hair": "#f07ab0", "eye": "#8a5ae8", "brow": -2, "top": "#6a50d8", "inner": "#fff3c8", "coat": true,
		"pants": "#2a2440", "shoes": "#f4f0ff", "sole": "#ffd23a", "gloves": "#fff3c8", "trim": "#ffd23a", "gem": "#5af0e0", "belt": "#ffd23a", "girl": true, "guard": "guard_psychic"},
	"titan": {"scale": 1.17, "bulk": 1.42, "hair_style": "flat", "hair": "#e8b82a", "eye": "#2a2a2a", "brow": -24, "skin": "#c98a5e", "top": "#c98a5e", "bare": true, "strap": "#7a2a2a",
		"pants": "#30303a", "shoes": "#b02a2a", "sole": "#f2f2f2", "gloves": "#7a2a2a", "trim": "#f2c230", "beard": true, "scar": true, "belt": "#f2c230", "shorts": true, "guard": "guard_titan"},
}
const TINTS := ["#d8362f", "#3a8ae0", "#3aa85a", "#e0a020", "#9a5ad8", "#e0609a", "#30b0b0"]

static func look_for(style: String, tint := -1) -> Dictionary:
	var l: Dictionary = (LOOKS[style] as Dictionary).duplicate()
	if tint >= 0:
		var c: String = TINTS[tint % TINTS.size()]
		if l.get("bare", false): l.pants = c
		else: l.top = c
	return l

var j := {}
var body: Node3D
var hand_r: Node3D
var hand_l: Node3D
var rocket: Node3D
var look := {}
var style := "brawler"
var _held := ""
var _held_node: Node3D

func _joint(parent: Node3D, pos: Vector3, key: String) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	j[key] = n
	return n

func _m(parent: Node3D, mesh: Mesh, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, outline := true, flat := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, outline, flat)
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func build(style_id: String, tint := -1) -> void:
	style = style_id
	look = look_for(style_id, tint)
	scale = Vector3.ONE * float(look.scale)
	var skin := Color.html(look.get("skin", "#f7cfa8"))
	var top := Color.html(look.top)
	var inner := Color.html(look.get("inner", "#ffffff"))
	var pants := Color.html(look.pants)
	var shoes := Color.html(look.shoes)
	var sole := Color.html(look.sole)
	var gloves := Color.html(look.gloves)
	var trim := Color.html(look.trim)
	var beltc := Color.html(look.belt)
	var B: float = look.bulk
	var bare: bool = look.get("bare", false)
	body = Node3D.new()
	body.position.y = HIP
	add_child(body)
	var hips := _joint(body, Vector3.ZERO, "hips")
	_m(hips, taper(0.25 * B, 0.17, 0.27 * B, 0.18, 0.15), pants, Vector3(0, -0.02, 0))
	_m(hips, box(Vector3(0.275 * B, 0.05, 0.19)), beltc, Vector3(0, 0.06, 0))
	_m(hips, box(Vector3(0.07, 0.065, 0.03)), trim, Vector3(0, 0.06, 0.095), Vector3.ZERO, Vector3.ONE, false)
	var torso := _joint(hips, Vector3(0, 0.07, 0), "torso")
	var cw := 0.4 * B
	var body_c := skin if bare else (inner if look.get("jacket", false) else top)
	_m(torso, taper(0.25 * B, 0.16, cw, 0.23, 0.3), body_c, Vector3(0, 0.15, 0))
	_m(torso, taper(cw, 0.23, 0.17, 0.14, 0.07), body_c, Vector3(0, 0.335, 0))
	_m(torso, cyl(0.055, 0.065, 0.1), skin, Vector3(0, 0.4, 0))
	if bare:
		# 가슴·배 선, 어깨끈
		_m(torso, box(Vector3(cw * 0.78, 0.012, 0.01)), skin.darkened(0.3), Vector3(0, 0.2, 0.108), Vector3(-8, 0, 0), Vector3.ONE, false, true)
		_m(torso, box(Vector3(0.012, 0.13, 0.01)), skin.darkened(0.3), Vector3(0, 0.27, 0.112), Vector3(-8, 0, 0), Vector3.ONE, false, true)
		for i in 2:
			_m(torso, box(Vector3(0.16, 0.01, 0.01)), skin.darkened(0.25), Vector3(0, 0.11 - i * 0.055, 0.092), Vector3.ZERO, Vector3.ONE, false, true)
		_m(torso, box(Vector3(0.09, 0.5, 0.26)), Color.html(look.strap), Vector3(0.02, 0.17, 0), Vector3(0, 0, 38))
		_m(torso, sph(0.05, 8), trim, Vector3(-0.1, 0.27, 0.12), Vector3.ZERO, Vector3(1, 1, 0.5))
	if look.get("jacket", false):
		# 앞이 열린 윗옷: 양옆 자락 + 등 + 깃
		for sx in [-1.0, 1.0]:
			_m(torso, taper(0.11 * B, 0.2, 0.15 * B, 0.27, 0.32), top, Vector3(sx * (cw * 0.5 - 0.06 * B), 0.16, 0.0), Vector3(0, 0, sx * -12))
			_m(torso, box(Vector3(0.045, 0.2, 0.03)), top.lightened(0.18) if not look.has("tie") else top.darkened(0.25), Vector3(sx * 0.075 * B, 0.27, 0.118), Vector3(-10, 0, sx * 20))
		_m(torso, taper(0.27 * B, 0.06, cw + 0.02, 0.07, 0.32), top, Vector3(0, 0.16, -0.1))
		_m(torso, taper(cw + 0.02, 0.25, 0.2, 0.16, 0.075), top, Vector3(0, 0.34, -0.005))
		if look.has("tie"):
			_m(torso, taper(0.03, 0.012, 0.05, 0.012, 0.2), Color.html(look.tie), Vector3(0, 0.2, 0.118), Vector3(-9, 0, 0), Vector3.ONE, false)
	if look.get("coat", false):
		# 긴 옷자락 + 큰 깃 + 가운데 줄
		_m(torso, box(Vector3(0.03, 0.3, 0.01)), trim, Vector3(0, 0.16, 0.105), Vector3(-8, 0, 0), Vector3.ONE, false)
		_m(torso, taper(0.3, 0.26, 0.22, 0.2, 0.08), trim, Vector3(0, 0.37, 0))
		for i in 5:
			var a := -0.9 + i * 0.45 + PI
			_m(hips, taper(0.17, 0.03, 0.13, 0.03, 0.3), top if i % 2 == 0 else top.darkened(0.15), Vector3(sin(a) * 0.15, -0.14, cos(a) * 0.11), Vector3(-14, rad_to_deg(a), 0))
		for sx in [-1.0, 1.0]:
			_m(hips, taper(0.13, 0.03, 0.1, 0.03, 0.26), top, Vector3(sx * 0.13, -0.12, 0.09), Vector3(12, 0, sx * 10))
	if look.get("girl", false):
		_m(torso, taper(0.24, 0.1, 0.28, 0.06, 0.1), body_c, Vector3(0, 0.23, 0.09))
	_head(torso, skin)
	for side in [["l", 1.0], ["r", -1.0]]:
		var sx: float = side[1]
		var k: String = side[0]
		var A := 0.82 + 0.3 * (B - 0.82)
		var sleeve := skin if bare else top
		var sh := _joint(torso, Vector3(sx * (cw * 0.5 + 0.035), 0.3, 0), "s" + k)
		_m(sh, sph(0.085 * A, 8), sleeve, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1))
		_m(sh, cyl(0.075 * A, 0.06 * A, 0.24, 7), sleeve, Vector3(0, -0.12, 0))
		if look.get("jacket", false) and not look.get("long", false):
			_m(sh, cyl(0.09 * A, 0.085 * A, 0.05, 7), trim, Vector3(0, -0.2, 0))
		var el := _joint(sh, Vector3(0, -0.25, 0), "e" + k)
		var long_sleeve: bool = look.get("long", false) or look.get("coat", false)
		_m(el, cyl(0.058 * A, 0.066 * A, 0.22, 7), sleeve if long_sleeve else skin, Vector3(0, -0.11, 0))
		_m(el, cyl(0.075 * A, 0.07 * A, 0.07, 7), trim if not look.get("long", false) else inner, Vector3(0, -0.2, 0))
		_m(el, box(Vector3(0.105, 0.11, 0.115) * A), gloves, Vector3(0, -0.285, 0.005))
		_m(el, box(Vector3(0.04, 0.05, 0.05) * A), gloves, Vector3(sx * -0.055 * A, -0.27, 0.035))
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.285, 0)
		el.add_child(hand)
		if k == "r": hand_r = hand
		else: hand_l = hand
		# 다리
		var hp := _joint(hips, Vector3(sx * 0.075 * B, -0.06, 0), "h" + k)
		var L := 0.85 + 0.35 * (B - 0.82)
		_m(hp, cyl(0.092 * L, 0.072 * L, 0.3, 7), pants, Vector3(0, -0.15, 0))
		var kn := _joint(hp, Vector3(0, -0.32, 0), "k" + k)
		var shorts: bool = look.get("shorts", false)
		_m(kn, cyl(0.07 * L, 0.06 * L if shorts or look.get("girl", false) else 0.082 * L, 0.26, 7), skin if shorts else pants, Vector3(0, -0.13, 0))
		if shorts or look.get("girl", false):
			_m(kn, cyl(0.075 * L, 0.07 * L, 0.16, 7), shoes, Vector3(0, -0.21, 0))
			_m(kn, cyl(0.08 * L, 0.08 * L, 0.03, 7), trim, Vector3(0, -0.13, 0))
		_m(kn, taper(0.125 * L, 0.27, 0.105 * L, 0.17, 0.085), shoes, Vector3(0, -0.325, 0.045))
		_m(kn, box(Vector3(0.135 * L, 0.03, 0.29)), sole, Vector3(0, -0.365, 0.045), Vector3.ZERO, Vector3.ONE, false)
	# 타고 나는 로켓 (평소엔 숨김)
	rocket = Node3D.new()
	rocket.position = Vector3(0, -0.12, 0.1)
	rocket.visible = false
	hips.add_child(rocket)
	_m(rocket, cyl(0.13, 0.13, 1.1, 10), Color("5a7a4a"), Vector3.ZERO, Vector3(90, 0, 0))
	_m(rocket, cyl(0.0, 0.13, 0.3, 10), Color("c8382f"), Vector3(0, 0, 0.7), Vector3(90, 0, 0))
	for i in 4:
		_m(rocket, box(Vector3(0.02, 0.2, 0.22)), Color("c8382f"), Vector3(sin(i * PI / 2) * 0.16, cos(i * PI / 2) * 0.16, -0.45), Vector3(0, 0, -i * 90.0))
	_m(rocket, cyl(0.16, 0.0, 0.7, 8), Color(1.0, 0.75, 0.2), Vector3(0, 0, -0.9), Vector3(90, 0, 0), Vector3.ONE, false, true)
	pose_now(str(look.guard))

func _head(torso: Node3D, skin: Color) -> void:
	var head := _joint(torso, Vector3(0, 0.43, 0), "head")
	var hairc := Color.html(look.hair)
	var dark := Color(0.1, 0.07, 0.11)
	var girl: bool = look.get("girl", false)
	var wide := 1.08 if look.get("beard", false) else 1.0
	_m(head, sph(0.235, 12), skin, Vector3(0, 0.25, -0.005), Vector3.ZERO, Vector3(0.93 * wide, 0.98, 0.92))
	# 턱: 아래로 좁아지는 각진 덩어리
	_m(head, taper(0.16 * wide if not girl else 0.1, 0.15, 0.36 * wide, 0.33, 0.17), skin, Vector3(0, 0.105, 0.012), Vector3(-6, 0, 0))
	for sx in [-1.0, 1.0]:
		_m(head, taper(0.03, 0.06, 0.04, 0.09, 0.1), skin, Vector3(sx * 0.215 * wide, 0.22, -0.01), Vector3(0, 0, sx * -10))
	# 코·입
	_m(head, taper(0.035, 0.05, 0.012, 0.012, 0.07), skin.darkened(0.06), Vector3(0, 0.19, 0.212), Vector3(-18, 0, 0), Vector3.ONE, false)
	_m(head, box(Vector3(0.075 if not girl else 0.045, 0.014, 0.01)), Color(0.5, 0.18, 0.18), Vector3(0, 0.115, 0.185), Vector3(-8, 0, 0), Vector3.ONE, false, true)
	if look.get("shades", false):
		for sx in [-1.0, 1.0]:
			_m(head, taper(0.1, 0.02, 0.125, 0.02, 0.075), dark, Vector3(sx * 0.085, 0.245, 0.2), Vector3(0, sx * 14, 0), Vector3.ONE, false)
			_m(head, box(Vector3(0.03, 0.012, 0.01)), Color(0.7, 0.85, 1.0), Vector3(sx * 0.1, 0.262, 0.213), Vector3(0, sx * 14, 30), Vector3.ONE, false, true)
			_m(head, box(Vector3(0.02, 0.02, 0.2)), dark, Vector3(sx * 0.2, 0.25, 0.1), Vector3.ZERO, Vector3.ONE, false)
		_m(head, box(Vector3(0.06, 0.018, 0.02)), dark, Vector3(0, 0.265, 0.212), Vector3.ZERO, Vector3.ONE, false)
	else:
		var eh := 0.085 if girl else (0.045 if look.get("beard", false) else 0.066)
		var eyec := Color.html(look.eye)
		for sx in [-1.0, 1.0]:
			var e := Node3D.new()
			e.position = Vector3(sx * 0.088, 0.24, 0.198)
			e.rotation_degrees = Vector3(-4, sx * 16, 0)
			head.add_child(e)
			_m(e, box(Vector3(0.085, eh, 0.008)), Color(0.98, 0.98, 1.0), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false, true)
			_m(e, box(Vector3(0.05, eh * 0.92, 0.01)), eyec, Vector3(sx * -0.008, -0.002, 0.002), Vector3.ZERO, Vector3.ONE, false, true)
			_m(e, box(Vector3(0.026, eh * 0.55, 0.012)), dark, Vector3(sx * -0.008, -0.004, 0.003), Vector3.ZERO, Vector3.ONE, false, true)
			_m(e, box(Vector3(0.018, 0.018, 0.014)), Color.WHITE, Vector3(sx * -0.022, eh * 0.24, 0.004), Vector3.ZERO, Vector3.ONE, false, true)
			# 윗눈꺼풀(굵은 선)과 눈썹
			_m(e, box(Vector3(0.1, 0.02, 0.014)), dark, Vector3(0, eh * 0.5 + 0.004, 0.003), Vector3(0, 0, sx * float(look.brow) * 0.35), Vector3.ONE, false, true)
			if girl:
				_m(e, box(Vector3(0.03, 0.014, 0.012)), dark, Vector3(sx * 0.055, eh * 0.5 + 0.012, 0.002), Vector3(0, 0, sx * 35), Vector3.ONE, false, true)
			_m(e, box(Vector3(0.1, 0.03 if not girl else 0.016, 0.014)), hairc.darkened(0.35), Vector3(0, eh * 0.5 + (0.045 if not look.get("beard", false) else 0.03), 0.008), Vector3(0, 0, sx * float(look.brow)), Vector3.ONE, false, true)
		if girl:
			for sx in [-1.0, 1.0]:
				_m(head, box(Vector3(0.05, 0.022, 0.008)), Color(1.0, 0.6, 0.6), Vector3(sx * 0.13, 0.165, 0.178), Vector3(0, sx * 30, 0), Vector3.ONE, false, true)
	if look.get("scar", false):
		_m(head, box(Vector3(0.016, 0.13, 0.008)), Color(0.55, 0.25, 0.2), Vector3(0.12, 0.25, 0.192), Vector3(0, 18, 14), Vector3.ONE, false, true)
	if look.get("beard", false):
		_m(head, taper(0.19, 0.17, 0.39, 0.3, 0.13), hairc.darkened(0.25), Vector3(0, 0.075, 0.022), Vector3(-6, 0, 0))
		_m(head, box(Vector3(0.09, 0.014, 0.01)), Color(0.4, 0.15, 0.15), Vector3(0, 0.115, 0.2), Vector3.ZERO, Vector3.ONE, false, true)
	if look.has("gem"):
		_m(head, taper(0.0, 0.0, 0.05, 0.02, 0.035), Color.html(look.gem), Vector3(0, 0.345, 0.2), Vector3(-20, 0, 0), Vector3.ONE, true, true)
		_m(head, taper(0.05, 0.02, 0.0, 0.0, 0.035), Color.html(look.gem), Vector3(0, 0.38, 0.19), Vector3(-20, 0, 0), Vector3.ONE, true, true)
	_hair(head, hairc)

func _spike(head: Node3D, c: Color, pos: Vector3, rot: Vector3, r: float, h: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees = rot
	head.add_child(holder)
	_m(holder, cyl(0.0, r, h, 4), c, Vector3(0, h * 0.5, 0), Vector3(0, 45, 0))

func _hair(head: Node3D, c: Color) -> void:
	var c2 := c.darkened(0.18)
	match str(look.hair_style):
		"spiky":
			_m(head, sph(0.245, 10), c, Vector3(0, 0.3, -0.04), Vector3.ZERO, Vector3(0.98, 0.86, 0.98))
			# 위·뒤로 뻗은 굵은 가시들
			var spikes := [[0, 0.5, -0.02, -8, 0, 0.11, 0.3], [0.12, 0.47, 0.0, -5, -28, 0.1, 0.27], [-0.12, 0.47, 0.0, -5, 28, 0.1, 0.27],
				[0.19, 0.38, -0.05, -15, -62, 0.09, 0.24], [-0.19, 0.38, -0.05, -15, 62, 0.09, 0.24], [0, 0.44, -0.15, -55, 0, 0.11, 0.3],
				[0.13, 0.36, -0.16, -70, -30, 0.1, 0.26], [-0.13, 0.36, -0.16, -70, 30, 0.1, 0.26], [0, 0.26, -0.2, -105, 0, 0.1, 0.24]]
			for s in spikes:
				_spike(head, c if s[3] > -60 else c2, Vector3(s[0], s[1], s[2]), Vector3(s[3], 0, s[4]), s[5], s[6])
			# 앞머리 (이마로 내려오는 가시)
			for s in [[-0.11, 0.42, 0.17, 150, 18, 0.06, 0.17], [0.0, 0.44, 0.19, 145, 0, 0.07, 0.15], [0.11, 0.42, 0.17, 150, -18, 0.06, 0.2]]:
				_spike(head, c, Vector3(s[0], s[1], s[2]), Vector3(s[3], 0, s[4]), s[5], s[6])
		"slick":
			_m(head, sph(0.245, 10), c, Vector3(0, 0.3, -0.035), Vector3.ZERO, Vector3(0.97, 0.84, 1.0))
			# 뒤로 넘긴 머리: 앞에서 뒤로 층층이
			for i in 4:
				_m(head, taper(0.3 - i * 0.03, 0.14, 0.2 - i * 0.02, 0.06, 0.07), c if i % 2 == 0 else c2, Vector3(0.02, 0.45 - i * 0.012, 0.1 - i * 0.1), Vector3(-25 - i * 14, 0, 0))
			_spike(head, c, Vector3(-0.1, 0.43, 0.17), Vector3(120, 0, 50), 0.05, 0.16)
			for sx in [-1.0, 1.0]:
				_m(head, box(Vector3(0.03, 0.12, 0.1)), c2, Vector3(sx * 0.215, 0.27, 0.06))
		"twin":
			_m(head, sph(0.25, 10), c, Vector3(0, 0.29, -0.04), Vector3.ZERO, Vector3(0.98, 0.9, 1.0))
			# 앞머리: 가지런한 덩어리 + 옆머리
			for i in 5:
				var x := -0.14 + i * 0.07
				_m(head, taper(0.05, 0.03, 0.075, 0.07, 0.13), c if i % 2 == 0 else c2, Vector3(x, 0.365, 0.185 - absf(x) * 0.25), Vector3(-12, -x * 120, x * 60))
			for sx in [-1.0, 1.0]:
				_m(head, taper(0.03, 0.03, 0.06, 0.07, 0.26), c, Vector3(sx * 0.2, 0.2, 0.1), Vector3(0, 0, sx * 4))
				# 양 갈래: 방울 + 아래로 가늘어지는 머리채
				_m(head, sph(0.05, 8), Color.html(look.trim), Vector3(sx * 0.24, 0.42, -0.06))
				var tail := Node3D.new()
				tail.position = Vector3(sx * 0.27, 0.4, -0.08)
				tail.rotation_degrees = Vector3(18, 0, sx * 22)
				head.add_child(tail)
				j["tail" + ("l" if sx > 0 else "r")] = tail
				_m(tail, taper(0.07, 0.07, 0.12, 0.11, 0.22), c, Vector3(0, -0.12, 0))
				_m(tail, taper(0.02, 0.02, 0.07, 0.07, 0.26), c2, Vector3(0, -0.36, 0))
		"flat":
			# 짧게 깎은 머리 + 각진 윗머리
			_m(head, sph(0.24, 10), c2, Vector3(0, 0.275, -0.03), Vector3.ZERO, Vector3(1.03, 0.82, 0.98))
			_m(head, taper(0.3, 0.3, 0.26, 0.27, 0.09), c, Vector3(0, 0.475, -0.01))
			_m(head, taper(0.3, 0.05, 0.3, 0.02, 0.05), c, Vector3(0, 0.415, 0.155), Vector3(-14, 0, 0))
	if look.has("band"):
		var bc := Color.html(look.band)
		_m(head, cyl(0.232, 0.228, 0.055, 12), bc, Vector3(0, 0.345, -0.012), Vector3(-5, 0, 0), Vector3(0.95, 1, 0.93))
		for i in 2:
			var t := Node3D.new()
			t.position = Vector3(-0.03 + i * 0.06, 0.35, -0.22)
			t.rotation_degrees = Vector3(-35 - i * 20, 0, -8 + i * 16)
			head.add_child(t)
			j["band%d" % i] = t
			_m(t, box(Vector3(0.05, 0.3, 0.012)), bc, Vector3(0, -0.15, 0))

# ─────────── 자세 ───────────

const _G_LEGS := {"hl": Vector3(-30, 0, 6), "kl": Vector3(34, 0, 0), "hr": Vector3(20, 0, -8), "kr": Vector3(30, 0, 0)}
const POSES := {
	"guard": {"torso": Vector3(6, -30, 0), "head": Vector3(0, 26, 0), "sl": Vector3(-50, 0, 10), "el": Vector3(-110, 0, 0), "sr": Vector3(-30, 0, -12), "er": Vector3(-125, 0, 0),
		"hl": Vector3(-30, 0, 6), "kl": Vector3(34, 0, 0), "hr": Vector3(20, 0, -8), "kr": Vector3(30, 0, 0), "y": -0.05},
	"guard_agent": {"torso": Vector3(2, -38, 0), "head": Vector3(0, 34, 0), "sl": Vector3(-62, 0, 4), "el": Vector3(-50, 0, 0), "sr": Vector3(12, 0, -10), "er": Vector3(-95, 0, 0),
		"hl": Vector3(-24, 0, 4), "kl": Vector3(24, 0, 0), "hr": Vector3(14, 0, -6), "kr": Vector3(18, 0, 0), "y": -0.03},
	"guard_psychic": {"torso": Vector3(2, -18, 0), "head": Vector3(-4, 16, 0), "sl": Vector3(-40, 0, 38), "el": Vector3(-70, 0, 0), "sr": Vector3(-25, 0, -42), "er": Vector3(-80, 0, 0),
		"hl": Vector3(-14, 0, 5), "kl": Vector3(16, 0, 0), "hr": Vector3(8, 0, -5), "kr": Vector3(14, 0, 0), "y": -0.01},
	"guard_titan": {"torso": Vector3(14, -14, 0), "head": Vector3(-8, 12, 0), "sl": Vector3(-45, 0, 40), "el": Vector3(-75, 0, 0), "sr": Vector3(-40, 0, -40), "er": Vector3(-80, 0, 0),
		"hl": Vector3(-34, 0, 20), "kl": Vector3(44, 0, 0), "hr": Vector3(-10, 0, -22), "kr": Vector3(40, 0, 0), "y": -0.07},
	"aim": {"torso": Vector3(6, -52, 0), "head": Vector3(0, 48, 0), "sl": Vector3(-86, 0, -6), "el": Vector3(-8, 0, 0), "sr": Vector3(-20, 0, -14), "er": Vector3(-130, 0, 0),
		"hl": Vector3(-36, 0, 8), "kl": Vector3(42, 0, 0), "hr": Vector3(26, 0, -10), "kr": Vector3(34, 0, 0), "y": -0.09},
	"jab_r_w": {"torso": Vector3(4, -48, 0), "head": Vector3(0, 42, 0), "sr": Vector3(-15, 0, -16), "er": Vector3(-140, 0, 0), "sl": Vector3(-55, 0, 10), "el": Vector3(-100, 0, 0),
		"hl": Vector3(-32, 0, 6), "kl": Vector3(40, 0, 0), "hr": Vector3(22, 0, -8), "kr": Vector3(34, 0, 0), "y": -0.07},
	"jab_r": {"torso": Vector3(12, 44, 0), "head": Vector3(-6, -36, 0), "sr": Vector3(-92, 0, 4), "er": Vector3(0, 0, 0), "sl": Vector3(22, 0, 14), "el": Vector3(-130, 0, 0),
		"hl": Vector3(-42, 0, 6), "kl": Vector3(48, 0, 0), "hr": Vector3(36, 0, -6), "kr": Vector3(14, 0, 0), "y": -0.1},
	"jab_l": {}, "rush": {},
	"kick_w": {"torso": Vector3(-6, -30, 0), "head": Vector3(4, 26, 0), "hr": Vector3(-98, 0, 0), "kr": Vector3(125, 0, 0), "hl": Vector3(8, 0, 6), "kl": Vector3(10, 0, 0),
		"sl": Vector3(-50, 0, 20), "el": Vector3(-100, 0, 0), "sr": Vector3(-20, 0, -30), "er": Vector3(-100, 0, 0)},
	"kick": {"torso": Vector3(-28, -24, 0), "head": Vector3(20, 20, 0), "hr": Vector3(-108, 0, 0), "kr": Vector3(2, 0, 0), "hl": Vector3(20, 0, 6), "kl": Vector3(8, 0, 0),
		"sl": Vector3(-30, 0, 52), "el": Vector3(-70, 0, 0), "sr": Vector3(38, 0, -30), "er": Vector3(-45, 0, 0), "y": 0.0},
	"upper_w": {"torso": Vector3(32, -38, 0), "head": Vector3(-22, 32, 0), "sr": Vector3(28, 0, -10), "er": Vector3(-75, 0, 0), "sl": Vector3(-50, 0, 10), "el": Vector3(-110, 0, 0),
		"hl": Vector3(-58, 0, 8), "kl": Vector3(84, 0, 0), "hr": Vector3(-22, 0, -8), "kr": Vector3(84, 0, 0), "y": -0.2},
	"upper": {"torso": Vector3(-18, 34, 0), "head": Vector3(-14, -26, 0), "sr": Vector3(-170, 0, -6), "er": Vector3(-28, 0, 0), "sl": Vector3(26, 0, 18), "el": Vector3(-110, 0, 0),
		"hl": Vector3(-12, 0, 8), "kl": Vector3(8, 0, 0), "hr": Vector3(16, 0, -8), "kr": Vector3(12, 0, 0), "y": 0.07},
	"slide": {"hips": Vector3(-52, 0, 0), "torso": Vector3(22, 0, 0), "head": Vector3(26, 0, 0), "hl": Vector3(-42, 0, 4), "kl": Vector3(0, 0, 0), "hr": Vector3(12, 0, -6), "kr": Vector3(78, 0, 0),
		"sl": Vector3(30, 0, 30), "el": Vector3(-20, 0, 0), "sr": Vector3(42, 0, -30), "er": Vector3(-30, 0, 0), "y": -0.44},
	"knee": {"hips": Vector3(16, 0, 0), "torso": Vector3(10, 22, 0), "head": Vector3(-20, -18, 0), "hr": Vector3(-112, 0, 0), "kr": Vector3(128, 0, 0), "hl": Vector3(26, 0, 4), "kl": Vector3(16, 0, 0),
		"sl": Vector3(-40, 0, 30), "el": Vector3(-90, 0, 0), "sr": Vector3(-60, 0, -20), "er": Vector3(-100, 0, 0), "y": 0.14},
	"charge": {"hips": Vector3(34, 0, 0), "torso": Vector3(14, 56, 0), "head": Vector3(-30, -46, 0), "sr": Vector3(-20, 0, -5), "er": Vector3(-130, 0, 0), "sl": Vector3(42, 0, 20), "el": Vector3(-60, 0, 0),
		"hl": Vector3(-58, 0, 0), "kl": Vector3(62, 0, 0), "hr": Vector3(40, 0, 0), "kr": Vector3(20, 0, 0), "y": -0.1},
	"cast_w": {"torso": Vector3(0, -55, 0), "head": Vector3(0, 48, 0), "sl": Vector3(-12, 0, -8), "el": Vector3(-100, 0, 0), "sr": Vector3(22, 0, -6), "er": Vector3(-112, 0, 0),
		"hl": Vector3(-34, 0, 10), "kl": Vector3(42, 0, 0), "hr": Vector3(26, 0, -10), "kr": Vector3(30, 0, 0), "y": -0.08},
	"cast": {"torso": Vector3(12, 0, 0), "head": Vector3(-8, 0, 0), "sl": Vector3(-88, 0, -12), "el": Vector3(-6, 0, 0), "sr": Vector3(-88, 0, 12), "er": Vector3(-6, 0, 0),
		"hl": Vector3(-38, 0, 10), "kl": Vector3(42, 0, 0), "hr": Vector3(30, 0, -10), "kr": Vector3(22, 0, 0), "y": -0.07},
	"slam_w": {"torso": Vector3(-22, 0, 0), "head": Vector3(-10, 0, 0), "sl": Vector3(-172, 0, 10), "el": Vector3(-20, 0, 0), "sr": Vector3(-172, 0, -10), "er": Vector3(-20, 0, 0),
		"hl": Vector3(-5, 0, 10), "kl": Vector3(6, 0, 0), "hr": Vector3(-5, 0, -10), "kr": Vector3(6, 0, 0), "y": 0.08},
	"slam": {"torso": Vector3(56, 0, 0), "head": Vector3(-36, 0, 0), "sl": Vector3(-48, 0, 10), "el": Vector3(-5, 0, 0), "sr": Vector3(-48, 0, -10), "er": Vector3(-5, 0, 0),
		"hl": Vector3(-76, 0, 14), "kl": Vector3(100, 0, 0), "hr": Vector3(-76, 0, -14), "kr": Vector3(100, 0, 0), "y": -0.27},
	"swing_w": {"torso": Vector3(4, -80, 0), "head": Vector3(0, 70, 0), "sr": Vector3(-58, 0, -52), "er": Vector3(-62, 0, 0), "sl": Vector3(-82, 0, -48), "el": Vector3(-72, 0, 0),
		"hl": Vector3(-30, 0, 10), "kl": Vector3(38, 0, 0), "hr": Vector3(24, 0, -10), "kr": Vector3(32, 0, 0), "y": -0.07},
	"swing": {"torso": Vector3(10, 78, 0), "head": Vector3(0, -62, 0), "sr": Vector3(-86, 0, 30), "er": Vector3(-8, 0, 0), "sl": Vector3(-80, 0, 20), "el": Vector3(-50, 0, 0),
		"hl": Vector3(-38, 0, 10), "kl": Vector3(44, 0, 0), "hr": Vector3(32, 0, -10), "kr": Vector3(18, 0, 0), "y": -0.08},
	"shoot": {"torso": Vector3(4, -22, 0), "head": Vector3(0, 20, 0), "sr": Vector3(-88, 0, 16), "er": Vector3(-4, 0, 0), "sl": Vector3(-74, 0, -36), "el": Vector3(-52, 0, 0),
		"hl": Vector3(-30, 0, 6), "kl": Vector3(34, 0, 0), "hr": Vector3(20, 0, -8), "kr": Vector3(30, 0, 0), "y": -0.05},
	"ride": {"hips": Vector3(8, 0, 0), "torso": Vector3(28, 0, 0), "head": Vector3(-30, 0, 0), "hl": Vector3(-62, 0, 34), "kl": Vector3(84, 0, 0), "hr": Vector3(-62, 0, -34), "kr": Vector3(84, 0, 0),
		"sl": Vector3(-52, 0, -14), "el": Vector3(-28, 0, 0), "sr": Vector3(-52, 0, 14), "er": Vector3(-28, 0, 0), "y": 0.0},
	"air_up": {"torso": Vector3(8, 0, 0), "sl": Vector3(-150, 0, 26), "el": Vector3(-34, 0, 0), "sr": Vector3(-150, 0, -26), "er": Vector3(-34, 0, 0),
		"hl": Vector3(-58, 0, 6), "kl": Vector3(96, 0, 0), "hr": Vector3(-18, 0, -6), "kr": Vector3(64, 0, 0)},
	"air_down": {"torso": Vector3(-6, 0, 0), "head": Vector3(10, 0, 0), "sl": Vector3(-78, 0, 62), "el": Vector3(-24, 0, 0), "sr": Vector3(-78, 0, -62), "er": Vector3(-24, 0, 0),
		"hl": Vector3(-28, 0, 10), "kl": Vector3(44, 0, 0), "hr": Vector3(6, 0, -10), "kr": Vector3(34, 0, 0)},
	"airkick": {"hips": Vector3(-14, 0, 0), "torso": Vector3(-12, -20, 0), "head": Vector3(20, 18, 0), "hr": Vector3(-78, 0, 0), "kr": Vector3(0, 0, 0), "hl": Vector3(-44, 0, 8), "kl": Vector3(118, 0, 0),
		"sl": Vector3(-20, 0, 62), "el": Vector3(-60, 0, 0), "sr": Vector3(-20, 0, -62), "er": Vector3(-60, 0, 0)},
	"dive_w": {"hips": Vector3(20, 0, 0), "torso": Vector3(30, 0, 0), "head": Vector3(-10, 0, 0), "sl": Vector3(-170, 0, 12), "el": Vector3(-40, 0, 0), "sr": Vector3(-170, 0, -12), "er": Vector3(-40, 0, 0),
		"hl": Vector3(-95, 0, 8), "kl": Vector3(125, 0, 0), "hr": Vector3(-95, 0, -8), "kr": Vector3(125, 0, 0)},
	"dive": {"hips": Vector3(58, 0, 0), "torso": Vector3(10, 0, 0), "head": Vector3(-42, 0, 0), "sl": Vector3(-154, 0, 10), "el": Vector3(0, 0, 0), "sr": Vector3(-154, 0, -10), "er": Vector3(0, 0, 0),
		"hl": Vector3(26, 0, 6), "kl": Vector3(24, 0, 0), "hr": Vector3(36, 0, -6), "kr": Vector3(42, 0, 0)},
	"hurt": {"torso": Vector3(-24, 20, 0), "head": Vector3(-24, 0, 12), "sl": Vector3(-50, 0, 62), "el": Vector3(-50, 0, 0), "sr": Vector3(-20, 0, -62), "er": Vector3(-40, 0, 0),
		"hl": Vector3(-26, 0, 10), "kl": Vector3(38, 0, 0), "hr": Vector3(10, 0, -10), "kr": Vector3(32, 0, 0), "y": -0.06},
	"fly": {"torso": Vector3(-14, 0, 0), "head": Vector3(-22, 0, 0), "sl": Vector3(-80, 0, 72), "el": Vector3(-30, 0, 0), "sr": Vector3(-80, 0, -72), "er": Vector3(-30, 0, 0),
		"hl": Vector3(-56, 0, 16), "kl": Vector3(64, 0, 0), "hr": Vector3(-24, 0, -16), "kr": Vector3(78, 0, 0)},
	"down": {"hips": Vector3(-88, 0, 0), "head": Vector3(10, 0, 14), "sl": Vector3(-20, 0, 76), "el": Vector3(-24, 0, 0), "sr": Vector3(-12, 0, -64), "er": Vector3(-40, 0, 0),
		"hl": Vector3(-4, 0, 18), "kl": Vector3(26, 0, 0), "hr": Vector3(-10, 0, -14), "kr": Vector3(8, 0, 0), "y": -0.56},
	"getup": {"torso": Vector3(52, 0, 0), "head": Vector3(-32, 0, 0), "sl": Vector3(-40, 0, 20), "el": Vector3(-30, 0, 0), "sr": Vector3(-40, 0, -20), "er": Vector3(-30, 0, 0),
		"hl": Vector3(-84, 0, 10), "kl": Vector3(126, 0, 0), "hr": Vector3(-84, 0, -10), "kr": Vector3(126, 0, 0), "y": -0.34},
	"win": {"torso": Vector3(-8, 0, 0), "head": Vector3(-14, 0, 0), "sr": Vector3(-174, 0, -12), "er": Vector3(-8, 0, 0), "sl": Vector3(-10, 0, 30), "el": Vector3(-135, 0, 0),
		"hl": Vector3(0, 0, 12), "hr": Vector3(0, 0, -12)},
}
const JOINTS := ["hips", "torso", "head", "sl", "el", "sr", "er", "hl", "kl", "hr", "kr"]
## 무기를 들었을 때 팔 모양 (서 있거나 걸을 때)
const CARRY := {
	"bat": {"sr": Vector3(-28, 0, -14), "er": Vector3(-100, 0, 0)},
	"rifle": {"sr": Vector3(-42, 0, 10), "er": Vector3(-62, 0, 0), "sl": Vector3(-58, 0, -30), "el": Vector3(-60, 0, 0)},
	"bazooka": {"sr": Vector3(-96, 0, -4), "er": Vector3(-96, 0, 0), "sl": Vector3(-70, 0, -30), "el": Vector3(-60, 0, 0)},
}

var _goal := {}
var _rate := 16.0
var clock := 0.0
var phase := 0.0
var run_amt := 0.0
var spin := 0.0
var win := false

static func mirror(p: Dictionary) -> Dictionary:
	var out := {}
	for key in p:
		if key == "y":
			out.y = p.y
			continue
		var k2: String = key
		if key.length() == 2 and key[1] in ["l", "r"]:
			k2 = key[0] + ("r" if key[1] == "l" else "l")
		var v: Vector3 = p[key]
		out[k2] = Vector3(v.x, -v.y, -v.z)
	return out

## 걷기(0)~달리기(1): 한 바퀴(phase 0~TAU)가 두 걸음
func _loco(ph: float, amt: float) -> Dictionary:
	var s := sin(ph)
	var c := cos(ph)
	var A := lerpf(30.0, 54.0, amt)
	var K := lerpf(40.0, 92.0, amt)
	var kb := lerpf(12.0, 22.0, amt)
	var arm := lerpf(26.0, 58.0, amt)
	var elb := lerpf(-35.0, -92.0, amt)
	return {"torso": Vector3(lerpf(5.0, 20.0, amt), -s * lerpf(7.0, 14.0, amt), 0), "head": Vector3(lerpf(-2.0, -12.0, amt), s * 6.0, 0),
		"hips": Vector3(0, s * 5.0, 0),
		"hl": Vector3(-A * s - 8.0 * amt, 0, 3), "hr": Vector3(A * s - 8.0 * amt, 0, -3),
		"kl": Vector3(kb + K * maxf(0.0, c), 0, 0), "kr": Vector3(kb + K * maxf(0.0, -c), 0, 0),
		"sl": Vector3(arm * s, 0, 8), "sr": Vector3(-arm * s, 0, -8), "el": Vector3(elb - 12.0 * s, 0, 0), "er": Vector3(elb + 12.0 * s, 0, 0),
		"y": lerpf(-0.02, -0.05, amt) + absf(c) * lerpf(0.025, 0.06, amt)}

func pose_now(name: String) -> void:
	_goal = POSES[name]
	_blend(1.0)

func _blend(k: float) -> void:
	for key in JOINTS:
		var n: Node3D = j[key]
		var want: Vector3 = _goal.get(key, Vector3.ZERO)
		n.rotation_degrees = n.rotation_degrees.lerp(want, k)
	var hips: Node3D = j.hips
	hips.position.y = lerpf(hips.position.y, float(_goal.get("y", 0.0)), k)

## 서 있는 자세에 숨쉬기를 얹는다
func _idle() -> Dictionary:
	var p: Dictionary = (POSES[look.guard] as Dictionary).duplicate()
	var b := sin(clock * 3.2)
	p.torso = (p.torso as Vector3) + Vector3(b * 1.6, 0, 0)
	p.sl = (p.sl as Vector3) + Vector3(b * 3.0, 0, 0)
	p.sr = (p.sr as Vector3) + Vector3(-b * 3.0, 0, 0)
	p.y = float(p.get("y", 0.0)) + b * 0.008 + (sin(clock * 2.0) * 0.03 + 0.04 if style == "psychic" else 0.0)
	return p

## 미리 보기 화면 등: 규칙 없이 서 있기
func idle_tick(dt: float) -> void:
	clock += dt
	_goal = _idle()
	_blend(1.0 - exp(-14.0 * dt))
	_sway(dt, 0.0)

func _sway(dt: float, speed: float) -> void:
	# 머리띠 끈·갈래 머리가 움직임에 따라 뒤로 날린다
	var back := clampf(speed * 6.0, 0.0, 55.0) + sin(clock * 5.0) * 6.0
	for i in 2:
		if j.has("band%d" % i):
			(j["band%d" % i] as Node3D).rotation_degrees.x = lerpf((j["band%d" % i] as Node3D).rotation_degrees.x, -35.0 - i * 20.0 - back, 1.0 - exp(-10.0 * dt))
	for k in ["taill", "tailr"]:
		if j.has(k):
			(j[k] as Node3D).rotation_degrees.x = lerpf((j[k] as Node3D).rotation_degrees.x, 18.0 - back * 1.2, 1.0 - exp(-8.0 * dt))

## 규칙 쪽 상태를 그림으로 (f = Rules의 선수)
func sync(f: Dictionary, dt: float) -> void:
	clock += dt
	position = f.pos
	rotation.y = lerp_angle(rotation.y, float(f.yaw), 1.0 - exp(-26.0 * dt))
	var v: Vector3 = f.vel
	var hs := Vector2(v.x, v.z).length()
	var p: Dictionary = {}
	_rate = 16.0
	var tumbling := false
	var riding := false
	var held := str(f.held)
	var carry := false
	match str(f.state):
		"free":
			carry = true
			run_amt = lerpf(run_amt, 1.0 if f.run else 0.0, 1.0 - exp(-10.0 * dt))
			if win and not f.air:
				p = POSES.win
				carry = false
			elif f.air:
				p = POSES.air_up if v.y > 1.5 else POSES.air_down
				_rate = 11.0
			elif f.moving:
				phase = fmod(phase + dt * TAU * lerpf(2.0, 2.7, run_amt), TAU)
				p = _loco(phase, run_amt * (0.0 if f.aim else 1.0))
				_rate = 28.0
				if f.aim:
					for k in ["torso", "head", "sl", "el", "sr", "er"]:
						p[k] = POSES.aim[k]
			elif f.aim:
				p = POSES.aim
			else:
				p = _idle()
				_rate = 13.0
		"atk":
			var m: Dictionary = f.m
			var name := str(m.pose)
			var t: float = f.t
			var st: float = m.st
			var flip := name == "jab_l"
			if flip: name = "jab_r"
			if name == "rush":
				name = "jab_r"
				flip = fmod(t * 8.0, 1.0) > 0.5
				p = POSES.jab_r if t >= st else POSES.jab_r_w
				_rate = 46.0
			elif t < st:
				p = POSES.get(name + "_w", POSES.air_up if f.air else POSES[look.guard])
				_rate = clampf(4.5 / maxf(st, 0.02), 16.0, 60.0)
			elif t < st + float(m.act) + float(m.rec) * 0.45:
				p = POSES[name]
				_rate = 50.0
			else:
				p = POSES.air_down if f.air else POSES[look.guard]
				_rate = 10.0
				carry = true
			if flip:
				p = mirror(p)
			riding = name == "ride" and t >= st
		"hurt":
			p = POSES.hurt if int(f.id + f.hits) % 2 == 0 else mirror(POSES.hurt)
			p = POSES.hurt
			_rate = 36.0
		"down", "dead":
			if f.air:
				p = POSES.fly
				tumbling = true
				_rate = 24.0
			else:
				p = POSES.down
				_rate = 26.0
		"getup":
			p = POSES.getup
			_rate = 15.0
	if carry and CARRY.has(held):
		p = p.duplicate()
		p.merge(CARRY[held], true)
	_goal = p
	_blend(1.0 - exp(-_rate * dt))
	# 날아갈 때 뒤로 빙글 돈다
	if tumbling:
		spin -= dt * (5.0 + hs * 0.5)
		body.rotation.x = spin
	else:
		spin = 0.0
		body.rotation.x = lerp_angle(body.rotation.x, 0.0, 1.0 - exp(-30.0 * dt))
	rocket.visible = riding
	_sway(dt, hs)
	hold(held)
	visible = str(f.state) != "out" and (float(f.inv) <= 0.0 or str(f.state) in ["down", "dead"] or fmod(clock * 12.0, 1.0) > 0.35)

# ─────────── 장신구·무기 ───────────

## 장신구 붙이기 (상점에서 산 것)
func equip(acc: String) -> void:
	match acc:
		"gloves":
			for k in ["el", "er"]:
				_m(j[k], sph(0.105, 10), Color("e0312f"), Vector3(0, -0.3, 0.01), Vector3.ZERO, Vector3(1, 1.15, 1.1))
				_m(j[k], sph(0.045, 8), Color("e0312f"), Vector3(0.07 if k == "er" else -0.07, -0.27, 0.04))
				_m(j[k], cyl(0.08, 0.075, 0.07, 10), Color.WHITE, Vector3(0, -0.19, 0))
		"flame":
			for k in ["el", "er"]:
				_m(j[k], cyl(0.085, 0.085, 0.08, 8), Color("ffb020"), Vector3(0, -0.17, 0))
				_m(j[k], cyl(0.09, 0.09, 0.025, 8), Color("c8382f"), Vector3(0, -0.17, 0))
				for i in 5:
					var a := TAU * i / 5.0
					_m(j[k], cyl(0.0, 0.04, 0.17 + (i % 2) * 0.06, 4), Color(1.0, 0.45 + (i % 2) * 0.3, 0.1), Vector3(sin(a) * 0.085, -0.09, cos(a) * 0.085), Vector3(cos(a) * 16, 0, -sin(a) * 16), Vector3.ONE, false, true)
		"claws":
			for k in ["el", "er"]:
				_m(j[k], box(Vector3(0.13, 0.07, 0.13)), Color("5a4a3a"), Vector3(0, -0.24, 0))
				for i in 3:
					var h := Node3D.new()
					h.position = Vector3(-0.04 + i * 0.04, -0.3, 0.05)
					h.rotation_degrees = Vector3(-150, 0, 0)
					(j[k] as Node3D).add_child(h)
					_m(h, taper(0.022, 0.035, 0.0, 0.006, 0.26), Color("e8eef4"), Vector3(0, 0.13, 0))
		"boots":
			for k in ["kl", "kr"]:
				_m(j[k], cyl(0.085, 0.095, 0.2, 7), Color("ffd23a"), Vector3(0, -0.2, 0))
				_m(j[k], taper(0.14, 0.29, 0.12, 0.19, 0.095), Color("ffd23a"), Vector3(0, -0.32, 0.045))
				_m(j[k], taper(0.02, 0.05, 0.02, 0.16, 0.14), Color("5ad0ff"), Vector3(0, -0.16, -0.12), Vector3(20, 0, 0), Vector3.ONE, true, true)
		"wand":
			var h := Node3D.new()
			h.rotation_degrees = Vector3(100, 0, 0)
			hand_l.add_child(h)
			_m(h, cyl(0.018, 0.022, 0.85, 6), Color("7a5a3a"), Vector3(0, 0.15, 0))
			_m(h, taper(0.0, 0.0, 0.11, 0.11, 0.1), Color("8ae0ff"), Vector3(0, 0.6, 0), Vector3(0, 45, 0), Vector3.ONE, true, true)
			_m(h, taper(0.11, 0.11, 0.0, 0.0, 0.16), Color("c8f4ff"), Vector3(0, 0.73, 0), Vector3(0, 45, 0), Vector3.ONE, true, true)
			_m(h, cyl(0.04, 0.03, 0.04, 6), Color("ffd23a"), Vector3(0, 0.56, 0))
		"wings":
			for sx in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = Vector3(sx * 0.07, 0.26, -0.13)
				w.rotation_degrees = Vector3(0, sx * -35, sx * -18)
				(j.torso as Node3D).add_child(w)
				for i in 4:
					_m(w, taper(0.03, 0.02, 0.1, 0.03, 0.34 - i * 0.05), Color("f4f8ff") if i % 2 == 0 else Color("bfe0ff"), Vector3(sx * (0.08 + i * 0.085), 0.06 - i * 0.05, 0), Vector3(0, 0, sx * (-62 - i * 9)))

static func weapon_mesh(kind: String, into: Node3D, helper: Fighter) -> void:
	match kind:
		"bat":
			helper._m(into, cyl(0.055, 0.03, 0.8, 8), Color("d8b070"), Vector3(0, 0.33, 0))
			helper._m(into, sph(0.055, 8), Color("d8b070"), Vector3(0, 0.73, 0))
			helper._m(into, cyl(0.04, 0.04, 0.03, 8), Color("8a5a30"), Vector3(0, -0.08, 0))
			helper._m(into, cyl(0.033, 0.033, 0.16, 8), Color("3a3a44"), Vector3(0, 0.01, 0), Vector3.ZERO, Vector3.ONE, false)
		"rifle":
			helper._m(into, box(Vector3(0.05, 0.62, 0.07)), Color("4a4e58"), Vector3(0, 0.22, 0))
			helper._m(into, cyl(0.016, 0.016, 0.3, 6), Color("2a2c34"), Vector3(0, 0.66, 0.01))
			helper._m(into, taper(0.05, 0.14, 0.05, 0.08, 0.26), Color("8a5a30"), Vector3(0, -0.2, -0.03))
			helper._m(into, box(Vector3(0.04, 0.1, 0.14)), Color("2a2c34"), Vector3(0, 0.12, -0.09), Vector3(15, 0, 0))
			helper._m(into, cyl(0.022, 0.022, 0.18, 6), Color("2a2c34"), Vector3(0, 0.3, 0.06))
		"bazooka":
			helper._m(into, cyl(0.085, 0.085, 1.1, 10), Color("5a7a4a"), Vector3(0, 0.1, 0.12))
			helper._m(into, cyl(0.11, 0.085, 0.14, 10), Color("3a5030"), Vector3(0, 0.68, 0.12))
			helper._m(into, cyl(0.1, 0.12, 0.12, 10), Color("3a5030"), Vector3(0, -0.48, 0.12))
			helper._m(into, box(Vector3(0.04, 0.06, 0.14)), Color("2a2c34"), Vector3(0, 0.0, 0.03))
			helper._m(into, box(Vector3(0.03, 0.1, 0.03)), Color("2a2c34"), Vector3(0, 0.3, 0.22))

## 손에 든 무기 바꾸기
func hold(kind: String) -> void:
	if kind == _held:
		return
	_held = kind
	if _held_node:
		_held_node.queue_free()
		_held_node = null
	if kind == "":
		return
	_held_node = Node3D.new()
	# 방망이는 주먹에서 비스듬히 위로, 총은 팔뚝 방향으로
	_held_node.rotation_degrees = Vector3(125, 0, 0) if kind == "bat" else Vector3(0, 0, 180)
	hand_r.add_child(_held_node)
	weapon_mesh(kind, _held_node, self)
