class_name Fighter
extends Node3D
## 격투 캐릭터: Kenney Animated Characters(CC0) 모델의 뼈를 우리 자세(관절 각도)로 직접 움직인다. 장신구·무기는 코드로 만들어 뼈에 붙인다.
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
const MODEL := preload("res://assets/hero/characterMedium.fbx")
const HEIGHT := 1.62
## 유형별 생김새: Kenney Animated Characters(CC0)의 몸 하나에 옷(skin)만 다르다
const LOOKS := {
	"brawler": {"scale": 1.0, "wide": 1.0, "skin": "skaterMaleA", "guard": "guard"},
	"agent": {"scale": 1.0, "wide": 0.94, "skin": "criminalMaleA", "guard": "guard_agent"},
	"psychic": {"scale": 0.93, "wide": 0.92, "skin": "cyborgFemaleA", "guard": "guard_psychic"},
	"titan": {"scale": 1.2, "wide": 1.16, "skin": "skaterFemaleA", "guard": "guard_titan"},
}
const TINTS := ["#ffb0a8", "#a8c8ff", "#a8e8b0", "#ffe090", "#d0b0ff", "#ffb0d8", "#a0e8e8"]
## 내 관절 → 모델 뼈. 모델은 팔을 옆으로 뻗고 선 자세(T)라 팔은 아래로 내린 것을 기준으로 맞춘다
const BONES := {"hips": "Hips", "spine": "Spine", "chest": "Chest", "chest2": "UpperChest", "neck": "Neck", "head": "Head",
	"cl": "LeftShoulder", "sl": "LeftArm", "el": "LeftForeArm", "wl": "LeftHand", "cr": "RightShoulder", "sr": "RightArm", "er": "RightForeArm", "wr": "RightHand",
	"hl": "LeftUpLeg", "kl": "LeftLeg", "fl": "LeftFoot", "hr": "RightUpLeg", "kr": "RightLeg", "fr": "RightFoot"}
const ORDER := ["hips", "spine", "chest", "chest2", "neck", "head", "cl", "sl", "el", "wl", "cr", "sr", "er", "wr", "hl", "kl", "fl", "hr", "kr", "fr"]

var j := {}
var body: Node3D
var sk: Skeleton3D
var hand_r: Node3D
var hand_l: Node3D
var rocket: Node3D
var look := {}
var style := "brawler"
var cur := {}                 # 지금 관절 각도(도)
var cur_y := 0.0
var _bi := {}                 # 관절 → 뼈 번호
var _rest := {}               # 관절 → 쉬는 자세의 방향(뼈대 기준)
var _unit := 1.0              # 뼈대 길이 1이 화면에서 몇인지
var _hips_pos := Vector3.ZERO
var _hips_parent := Basis()
var _held := ""
var _held_node: Node3D
## 내 좌표(왼쪽 x, 위 y, 앞 z) → 뼈대 좌표(왼쪽 x, 뒤 y, 위 z)
static var CB := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
static var OFF_L := Basis(Vector3(0, 0, 1), -PI / 2)
static var OFF_R := Basis(Vector3(0, 0, 1), PI / 2)

func _m(parent: Node3D, mesh: Mesh, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, outline := true, flat := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, outline, flat)
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _off(key: String) -> Basis:
	if key in ["sl", "el", "wl"]: return OFF_L
	if key in ["sr", "er", "wr"]: return OFF_R
	return Basis()

## 뼈에 붙는 자리: 그 안에서는 예전처럼 내 좌표·내 크기로 물건을 놓을 수 있다
func _socket(key: String, name: String, stretch := 1.0, shift := Vector3.ZERO) -> Node3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = BONES[key]
	sk.add_child(ba)
	var n := Node3D.new()
	var basis: Basis = (_rest[key] as Basis).inverse() * CB * _off(key).inverse()
	n.transform = Transform3D(basis.scaled_local(Vector3.ONE * stretch / _unit), basis * shift / _unit)
	ba.add_child(n)
	j[name] = n
	return n

func build(style_id: String, tint := -1) -> void:
	style = style_id
	look = LOOKS[style_id]
	scale = Vector3.ONE * float(look.scale)
	body = Node3D.new()
	body.position.y = HIP
	add_child(body)
	var model: Node3D = MODEL.instantiate()
	body.add_child(model)
	sk = model.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var bb := mi.mesh.get_aabb()
	var k := HEIGHT / (bb.size.z * 100.0)
	model.scale = Vector3(k * float(look.wide), k, k * float(look.wide))
	model.position.y = -HIP
	_unit = 100.0 * k
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/hero/%s.png" % look.skin)
	m.albedo_color = Color.WHITE if tint < 0 else Color.html(TINTS[tint % TINTS.size()])
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var line := StandardMaterial3D.new()
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.albedo_color = Color(0.09, 0.06, 0.1)
	line.cull_mode = BaseMaterial3D.CULL_FRONT
	line.grow = true
	line.grow_amount = 0.02 / _unit
	m.next_pass = line
	mi.material_override = m
	for key in ORDER:
		var i := sk.find_bone(BONES[key])
		_bi[key] = i
		_rest[key] = sk.get_bone_global_rest(i).basis.orthonormalized()
	var hi: int = _bi.hips
	_hips_pos = sk.get_bone_rest(hi).origin
	_hips_parent = sk.get_bone_global_rest(sk.get_bone_parent(hi)).basis.orthonormalized()
	# 장신구·무기가 붙는 자리 (팔뚝·정강이 길이는 모델에 맞춰 늘인다)
	var fore: float = sk.get_bone_global_rest(_bi.wl).origin.distance_to(sk.get_bone_global_rest(_bi.el).origin) * _unit
	var shin: float = sk.get_bone_global_rest(_bi.fl).origin.distance_to(sk.get_bone_global_rest(_bi.kl).origin) * _unit
	_socket("el", "el", (fore + 0.05) / 0.285); _socket("er", "er", (fore + 0.05) / 0.285)
	_socket("kl", "kl", (shin + 0.07) / 0.38); _socket("kr", "kr", (shin + 0.07) / 0.38)
	_socket("chest", "torso", 1.0, Vector3(0, -0.14, 0))
	_socket("hips", "hips")
	_socket("head", "head")
	hand_l = _socket("wl", "hand_l", 1.0, Vector3(0, -0.05, 0))
	hand_r = _socket("wr", "hand_r", 1.0, Vector3(0, -0.05, 0))
	# 타고 나는 로켓 (평소엔 숨김)
	rocket = Node3D.new()
	rocket.position = Vector3(0, -0.12, 0.1)
	rocket.visible = false
	(j.hips as Node3D).add_child(rocket)
	_m(rocket, cyl(0.13, 0.13, 1.1, 10), Color("5a7a4a"), Vector3.ZERO, Vector3(90, 0, 0))
	_m(rocket, cyl(0.0, 0.13, 0.3, 10), Color("c8382f"), Vector3(0, 0, 0.7), Vector3(90, 0, 0))
	for i in 4:
		_m(rocket, box(Vector3(0.02, 0.2, 0.22)), Color("c8382f"), Vector3(sin(i * PI / 2) * 0.16, cos(i * PI / 2) * 0.16, -0.45), Vector3(0, 0, -i * 90.0))
	_m(rocket, cyl(0.16, 0.0, 0.7, 8), Color(1.0, 0.75, 0.2), Vector3(0, 0, -0.9), Vector3(90, 0, 0), Vector3.ONE, false, true)
	pose_now(str(look.guard))

static func _e(v: Vector3) -> Basis:
	return Basis.from_euler(v * (PI / 180.0))

static func _half(v: Vector3) -> Basis:
	return Basis(Quaternion.IDENTITY.slerp(_e(v).get_rotation_quaternion(), 0.5))

## 관절 각도 → 모델 뼈
func _apply() -> void:
	var z := Vector3.ZERO
	var hips := _e(cur.get("hips", z))
	var torso := hips * _e(cur.get("torso", z))
	var R := {"hips": hips, "spine": hips * _half(cur.get("torso", z)), "chest": torso, "chest2": torso,
		"neck": torso * _half(cur.get("head", z)), "head": torso * _e(cur.get("head", z)), "cl": torso, "cr": torso}
	for sd in ["l", "r"]:
		R["s" + sd] = torso * _e(cur.get("s" + sd, z))
		R["e" + sd] = (R["s" + sd] as Basis) * _e(cur.get("e" + sd, z))
		R["w" + sd] = R["e" + sd]
		R["h" + sd] = hips * _e(cur.get("h" + sd, z))
		R["k" + sd] = (R["h" + sd] as Basis) * _e(cur.get("k" + sd, z))
		R["f" + sd] = R["k" + sd]
	var gp := {}
	for key in ORDER:
		var i: int = _bi[key]
		var g: Basis = CB * (R[key] as Basis) * _off(key) * CB.inverse() * (_rest[key] as Basis)
		gp[i] = g
		var par := sk.get_bone_parent(i)
		var pg: Basis = gp[par] if gp.has(par) else sk.get_bone_global_rest(par).basis.orthonormalized()
		sk.set_bone_pose_rotation(i, (pg.inverse() * g).get_rotation_quaternion())
	sk.set_bone_pose_position(_bi.hips, _hips_pos + _hips_parent.inverse() * Vector3(0, 0, cur_y / _unit))

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
	"block": {"torso": Vector3(14, -18, 0), "head": Vector3(8, 14, 0), "sl": Vector3(-78, 0, -34), "el": Vector3(-118, 0, 0), "sr": Vector3(-70, 0, 34), "er": Vector3(-122, 0, 0),
		"hl": Vector3(-36, 0, 8), "kl": Vector3(50, 0, 0), "hr": Vector3(14, 0, -10), "kr": Vector3(44, 0, 0), "y": -0.11},
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
		var want: Vector3 = _goal.get(key, Vector3.ZERO)
		cur[key] = (cur.get(key, want) as Vector3).lerp(want, k)
	cur_y = lerpf(cur_y, float(_goal.get("y", 0.0)), k)
	_apply()

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
		"guard":
			p = POSES.block
			_rate = 34.0
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
			h.rotation_degrees = Vector3(62, 0, 0)
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
