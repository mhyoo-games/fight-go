class_name Fighter
extends Node3D
## 코드로 만드는 2.5등신 격투 캐릭터 (관절마다 Node3D → 자세를 각도로 준다). 앞은 +Z, 왼쪽은 +X.

static var _mats := {}
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
			_line.albedo_color = Color(0.1, 0.07, 0.1)
			_line.cull_mode = BaseMaterial3D.CULL_FRONT
			_line.grow = true
			_line.grow_amount = 0.022
		m.next_pass = _line
	_mats[key] = m
	return m

static func sph(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r; m.height = r * 2.0; m.radial_segments = 20; m.rings = 10
	return m

static func cap(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r; m.height = h + r * 2.0; m.radial_segments = 14; m.rings = 5
	return m

static func box(v: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = v
	return m

static func cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt; m.bottom_radius = rb; m.height = h; m.radial_segments = 16
	return m

var j := {}

func _joint(parent: Node3D, pos: Vector3, key: String) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	j[key] = n
	return n

func _m(parent: Node3D, mesh: Mesh, c: Color, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO, outline := true, flat := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, outline, flat)
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func build(look: Dictionary) -> void:
	var skin := Color.html(look.get("skin", "#f6c9a0"))
	var top := Color.html(look.get("top", "#d8362f"))
	var pants := Color.html(look.get("pants", "#2f4f9a"))
	var shoes := Color.html(look.get("shoes", "#f2f2f2"))
	var gloves := Color.html(look.get("gloves", "#f6c9a0"))
	var hairc := Color.html(look.get("hair", "#2b2230"))
	var trim := Color.html(look.get("trim", "#ffffff"))
	var sleeves: bool = look.get("sleeves", true)
	var hips := _joint(self, Vector3(0, 0.56, 0), "hips")
	_m(hips, sph(0.19), pants, Vector3(0, 0.0, 0), Vector3(1.1, 0.8, 0.9))
	var torso := _joint(hips, Vector3(0, 0.03, 0), "torso")
	_m(torso, cyl(0.235, 0.17, 0.4), top, Vector3(0, 0.24, 0), Vector3(1.1, 1, 0.82))
	_m(torso, sph(0.235), top, Vector3(0, 0.43, 0), Vector3(1.1, 0.45, 0.82))
	_m(torso, cyl(0.185, 0.185, 0.07), Color.html(look.get("belt", "#2a2a2a")), Vector3(0, 0.06, 0), Vector3(1.1, 1, 0.9))
	if look.get("zip", false):
		_m(torso, box(Vector3(0.035, 0.36, 0.02)), trim, Vector3(0, 0.27, 0.195), Vector3.ONE, Vector3(-6, 0, 0), false)
	if look.get("collar", false):
		for sx in [-1.0, 1.0]:
			_m(torso, box(Vector3(0.05, 0.3, 0.03)), trim, Vector3(sx * 0.07, 0.34, 0.185), Vector3.ONE, Vector3(-8, 0, sx * 22), false)
	if look.has("scarf"):
		var sc := TorusMesh.new()
		sc.inner_radius = 0.1; sc.outer_radius = 0.2; sc.rings = 16; sc.ring_segments = 8
		_m(torso, sc, Color.html(look.scarf), Vector3(0, 0.5, 0), Vector3(1, 1.2, 1))
		_m(torso, box(Vector3(0.12, 0.34, 0.04)), Color.html(look.scarf), Vector3(-0.1, 0.4, -0.2), Vector3.ONE, Vector3(25, 0, 0))
	# 머리
	var head := _joint(torso, Vector3(0, 0.5, 0), "head")
	_m(head, sph(0.31), skin, Vector3(0, 0.3, 0), Vector3(1.0, 0.94, 0.95))
	var dark := Color(0.12, 0.09, 0.12)
	if look.get("panda", false):
		for sx in [-1.0, 1.0]:
			_m(head, sph(0.11), dark, Vector3(sx * 0.22, 0.56, 0))
			_m(head, sph(0.085), dark, Vector3(sx * 0.115, 0.31, 0.25), Vector3(1, 1.25, 0.4), Vector3(0, 0, sx * 20), false)
			_m(head, sph(0.03), Color.WHITE, Vector3(sx * 0.115, 0.32, 0.285), Vector3(1, 1, 0.5), Vector3.ZERO, false, true)
		_m(head, sph(0.04), dark, Vector3(0, 0.22, 0.29), Vector3(1.2, 0.8, 0.6), Vector3.ZERO, false)
	else:
		for sx in [-1.0, 1.0]:
			_m(head, sph(0.06), dark, Vector3(sx * 0.115, 0.3, 0.262), Vector3(0.9, 1.35, 0.4), Vector3.ZERO, false, true)
			_m(head, sph(0.022), Color.WHITE, Vector3(sx * 0.1, 0.335, 0.287), Vector3(1, 1, 0.5), Vector3.ZERO, false, true)
			_m(head, box(Vector3(0.12, 0.028, 0.02)), hairc.darkened(0.2), Vector3(sx * 0.115, 0.415, 0.268), Vector3.ONE, Vector3(0, sx * 18, sx * float(look.get("brow", -14))), false, true)
		_m(head, box(Vector3(0.08, 0.02, 0.02)), Color(0.45, 0.15, 0.15), Vector3(0, 0.17, 0.283), Vector3.ONE, Vector3.ZERO, false, true)
		for sx in [-1.0, 1.0]:
			_m(head, sph(0.06), skin, Vector3(sx * 0.3, 0.28, 0), Vector3(0.5, 1, 0.8))
	_hair(head, str(look.get("hair_style", "spiky")), hairc, look)
	# 팔
	for side in [["l", 1.0], ["r", -1.0]]:
		var sx: float = side[1]
		var k: String = side[0]
		var sh := _joint(torso, Vector3(sx * 0.3, 0.4, 0), "s" + k)
		_m(sh, sph(0.1), top if sleeves else skin)
		_m(sh, cap(0.075, 0.14), top if sleeves else skin, Vector3(0, -0.13, 0))
		var el := _joint(sh, Vector3(0, -0.26, 0), "e" + k)
		_m(el, cap(0.07, 0.12), top if sleeves and not look.get("short", false) else skin, Vector3(0, -0.11, 0))
		if sleeves and not look.get("short", false):
			_m(el, cyl(0.085, 0.085, 0.05), trim, Vector3(0, -0.19, 0))
		_m(el, sph(0.12), gloves, Vector3(0, -0.29, 0), Vector3(1, 1, 1.05))
		# 다리
		var hp := _joint(hips, Vector3(sx * 0.115, -0.04, 0), "h" + k)
		_m(hp, cap(0.095, 0.14), pants, Vector3(0, -0.12, 0))
		var kn := _joint(hp, Vector3(0, -0.25, 0), "k" + k)
		_m(kn, cap(0.085, 0.1), pants if not look.get("shorts", false) else skin, Vector3(0, -0.1, 0))
		_m(kn, sph(0.11), shoes, Vector3(0, -0.22, 0.05), Vector3(1.0, 0.75, 1.6))
		_m(kn, box(Vector3(0.2, 0.035, 0.34)), shoes.darkened(0.45), Vector3(0, -0.29, 0.05), Vector3.ONE, Vector3.ZERO, false)

func _hair(head: Node3D, style: String, c: Color, look: Dictionary) -> void:
	match style:
		"spiky":
			_m(head, sph(0.325), c, Vector3(0, 0.36, -0.05), Vector3(1.02, 0.85, 1.0))
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			for i in 11:
				var a := TAU * i / 11.0
				var cone := cyl(0.0, 0.1, 0.3)
				var tilt := 55.0 if i % 2 == 0 else 30.0
				_m(head, cone, c, Vector3(sin(a) * 0.2, 0.55 + (0.05 if i % 2 else 0.0), cos(a) * 0.2 - 0.04), Vector3.ONE, Vector3(cos(a) * tilt, 0, -sin(a) * tilt))
			_m(head, cyl(0.0, 0.11, 0.3), c, Vector3(0, 0.66, -0.02))
			for x in [-0.12, 0.0, 0.12]:
				_m(head, cyl(0.0, 0.07, 0.2), c, Vector3(x, 0.5, 0.25), Vector3.ONE, Vector3(150, 0, x * 80))
		"ponytail":
			_m(head, sph(0.33), c, Vector3(0, 0.35, -0.045), Vector3(1.03, 0.92, 1.0))
			for x in [-0.15, -0.05, 0.05, 0.15]:
				_m(head, sph(0.09), c, Vector3(x, 0.5, 0.22), Vector3(1, 1.1, 0.7))
			_m(head, sph(0.07), Color.html(look.get("tie", "#ff5a7a")), Vector3(0, 0.56, -0.3))
			_m(head, cap(0.085, 0.3), c, Vector3(0, 0.36, -0.42), Vector3.ONE, Vector3(-30, 0, 0))
			for sx in [-1.0, 1.0]:
				_m(head, cap(0.045, 0.2), c, Vector3(sx * 0.28, 0.2, 0.1))
		"mohawk":
			for i in 7:
				var a := -0.9 + i * 0.36
				_m(head, cyl(0.0, 0.08, 0.3 - absf(i - 2.5) * 0.02), c, Vector3(0, 0.3 + cos(a) * 0.36, sin(a) * -0.36 + 0.02), Vector3(0.7, 1, 1), Vector3(-rad_to_deg(a), 0, 0))
		"cap":
			var cc := Color.html(look.get("cap", "#2f9a5a"))
			_m(head, sph(0.33), cc, Vector3(0, 0.4, -0.01), Vector3(1.02, 0.7, 1.02))
			_m(head, cyl(0.2, 0.2, 0.035), cc, Vector3(0, 0.42, 0.3), Vector3(1.1, 1, 0.9), Vector3(8, 0, 0))
			_m(head, sph(0.3), c, Vector3(0, 0.27, -0.08), Vector3(1.04, 0.8, 0.95))
		"bob":
			_m(head, sph(0.34), c, Vector3(0, 0.33, -0.05), Vector3(1.05, 1.0, 1.0))
			_m(head, box(Vector3(0.5, 0.1, 0.06)), c, Vector3(0, 0.48, 0.24), Vector3.ONE, Vector3(-18, 0, 0))
			for sx in [-1.0, 1.0]:
				_m(head, cap(0.07, 0.22), c, Vector3(sx * 0.27, 0.18, 0.08))
		"hood":
			_m(head, sph(0.345), c, Vector3(0, 0.32, -0.04), Vector3(1.04, 1.02, 1.02))
	if look.has("band"):
		_m(head, cyl(0.31, 0.31, 0.07), Color.html(look.band), Vector3(0, 0.44, 0), Vector3(1.0, 1, 0.96), Vector3(-6, 0, 0))
		for i in 2:
			_m(head, box(Vector3(0.07, 0.3, 0.02)), Color.html(look.band), Vector3(-0.06 + i * 0.12, 0.33, -0.34), Vector3.ONE, Vector3(-20 - i * 15, 0, -8 + i * 16))

const POSES := {
	"guard": {"torso": Vector3(4, -28, 0), "head": Vector3(0, 24, 0), "sl": Vector3(-55, 0, 12), "el": Vector3(-105, 0, 0), "sr": Vector3(-35, 0, -14), "er": Vector3(-120, 0, 0),
		"hl": Vector3(-28, 0, 8), "kl": Vector3(30, 0, 0), "hr": Vector3(22, 0, -10), "kr": Vector3(28, 0, 0), "y": -0.05},
	"aim": {"torso": Vector3(6, -40, 0), "head": Vector3(0, 36, 0), "sl": Vector3(-88, 0, 0), "el": Vector3(-12, 0, 0), "sr": Vector3(-30, 0, -14), "er": Vector3(-125, 0, 0),
		"hl": Vector3(-32, 0, 8), "kl": Vector3(36, 0, 0), "hr": Vector3(26, 0, -10), "kr": Vector3(30, 0, 0), "y": -0.08},
	"run_a": {"torso": Vector3(14, -10, 0), "sl": Vector3(45, 0, 8), "el": Vector3(-75, 0, 0), "sr": Vector3(-55, 0, -8), "er": Vector3(-85, 0, 0),
		"hl": Vector3(-50, 0, 0), "kl": Vector3(35, 0, 0), "hr": Vector3(32, 0, 0), "kr": Vector3(75, 0, 0), "y": -0.03},
	"jab_r": {"torso": Vector3(14, 38, 0), "head": Vector3(-8, -30, 0), "sr": Vector3(-92, 0, 0), "er": Vector3(0, 0, 0), "sl": Vector3(30, 0, 14), "el": Vector3(-125, 0, 0),
		"hl": Vector3(-42, 0, 6), "kl": Vector3(48, 0, 0), "hr": Vector3(38, 0, -6), "kr": Vector3(12, 0, 0), "y": -0.1},
	"kick": {"torso": Vector3(-24, 0, 0), "head": Vector3(18, 0, 0), "hr": Vector3(-100, 0, 0), "kr": Vector3(4, 0, 0), "hl": Vector3(22, 0, 6), "kl": Vector3(6, 0, 0),
		"sl": Vector3(-30, 0, 55), "el": Vector3(-70, 0, 0), "sr": Vector3(40, 0, -30), "er": Vector3(-50, 0, 0)},
	"upper": {"torso": Vector3(-14, 30, 0), "head": Vector3(-10, -20, 0), "sr": Vector3(-165, 0, -8), "er": Vector3(-35, 0, 0), "sl": Vector3(25, 0, 18), "el": Vector3(-110, 0, 0),
		"hl": Vector3(-15, 0, 8), "kl": Vector3(10, 0, 0), "hr": Vector3(15, 0, -8), "kr": Vector3(10, 0, 0), "y": 0.05},
	"air": {"torso": Vector3(10, 0, 0), "sl": Vector3(-140, 0, 30), "el": Vector3(-40, 0, 0), "sr": Vector3(-140, 0, -30), "er": Vector3(-40, 0, 0),
		"hl": Vector3(-60, 0, 8), "kl": Vector3(95, 0, 0), "hr": Vector3(-25, 0, -8), "kr": Vector3(70, 0, 0)},
	"airkick": {"torso": Vector3(-20, 0, 0), "head": Vector3(15, 0, 0), "hr": Vector3(-85, 0, 0), "kr": Vector3(0, 0, 0), "hl": Vector3(-40, 0, 8), "kl": Vector3(110, 0, 0),
		"sl": Vector3(-20, 0, 60), "el": Vector3(-60, 0, 0), "sr": Vector3(-20, 0, -60), "er": Vector3(-60, 0, 0)},
	"dive": {"hips": Vector3(55, 0, 0), "torso": Vector3(10, 0, 0), "head": Vector3(-40, 0, 0), "sl": Vector3(-150, 0, 10), "el": Vector3(0, 0, 0), "sr": Vector3(-150, 0, -10), "er": Vector3(0, 0, 0),
		"hl": Vector3(25, 0, 6), "kl": Vector3(25, 0, 0), "hr": Vector3(35, 0, -6), "kr": Vector3(40, 0, 0)},
	"hurt": {"torso": Vector3(-22, 18, 0), "head": Vector3(-22, 0, 10), "sl": Vector3(-50, 0, 60), "el": Vector3(-50, 0, 0), "sr": Vector3(-20, 0, -60), "er": Vector3(-40, 0, 0),
		"hl": Vector3(-25, 0, 10), "kl": Vector3(35, 0, 0), "hr": Vector3(10, 0, -10), "kr": Vector3(30, 0, 0), "y": -0.05},
	"fly": {"hips": Vector3(-60, 0, 0), "torso": Vector3(-10, 0, 0), "head": Vector3(-20, 0, 0), "sl": Vector3(-70, 0, 70), "el": Vector3(-30, 0, 0), "sr": Vector3(-70, 0, -70), "er": Vector3(-30, 0, 0),
		"hl": Vector3(-50, 0, 14), "kl": Vector3(60, 0, 0), "hr": Vector3(-20, 0, -14), "kr": Vector3(70, 0, 0), "y": 0.2},
	"down": {"hips": Vector3(-88, 0, 0), "sl": Vector3(-20, 0, 75), "el": Vector3(-20, 0, 0), "sr": Vector3(-20, 0, -75), "er": Vector3(-20, 0, 0),
		"hl": Vector3(-5, 0, 16), "kl": Vector3(10, 0, 0), "hr": Vector3(-5, 0, -16), "kr": Vector3(10, 0, 0), "y": -0.38},
	"getup": {"torso": Vector3(50, 0, 0), "head": Vector3(-30, 0, 0), "sl": Vector3(-40, 0, 20), "el": Vector3(-30, 0, 0), "sr": Vector3(-40, 0, -20), "er": Vector3(-30, 0, 0),
		"hl": Vector3(-80, 0, 10), "kl": Vector3(120, 0, 0), "hr": Vector3(-80, 0, -10), "kr": Vector3(120, 0, 0), "y": -0.3},
	"swing": {"torso": Vector3(10, 70, 0), "head": Vector3(0, -50, 0), "sr": Vector3(-85, 0, 35), "er": Vector3(-15, 0, 0), "sl": Vector3(-75, 0, -35), "el": Vector3(-55, 0, 0),
		"hl": Vector3(-30, 0, 10), "kl": Vector3(35, 0, 0), "hr": Vector3(25, 0, -10), "kr": Vector3(20, 0, 0), "y": -0.06},
	"cast": {"torso": Vector3(8, 0, 0), "sl": Vector3(-95, 0, 28), "el": Vector3(-8, 0, 0), "sr": Vector3(-95, 0, -28), "er": Vector3(-8, 0, 0),
		"hl": Vector3(-20, 0, 12), "kl": Vector3(25, 0, 0), "hr": Vector3(15, 0, -12), "kr": Vector3(20, 0, 0), "y": 0.12},
	"slam": {"torso": Vector3(45, 0, 0), "head": Vector3(-25, 0, 0), "sl": Vector3(-55, 0, 14), "el": Vector3(-5, 0, 0), "sr": Vector3(-55, 0, -14), "er": Vector3(-5, 0, 0),
		"hl": Vector3(-70, 0, 14), "kl": Vector3(95, 0, 0), "hr": Vector3(-70, 0, -14), "kr": Vector3(95, 0, 0), "y": -0.22},
	"win": {"torso": Vector3(-6, 0, 0), "head": Vector3(-12, 0, 0), "sr": Vector3(-172, 0, -12), "er": Vector3(-8, 0, 0), "sl": Vector3(-10, 0, 30), "el": Vector3(-135, 0, 0),
		"hl": Vector3(0, 0, 12), "hr": Vector3(0, 0, -12)},
}
const JOINTS := ["hips", "torso", "head", "sl", "el", "sr", "er", "hl", "kl", "hr", "kr"]

var _goal := {}
var _goal_y := 0.0
var clock := 0.0
var flash := 0.0

## 좌우를 바꾼 자세
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

## 자세 정하기 (부드럽게 넘어감). snap이면 바로
func pose(name: String, flip := false, snap := false) -> void:
	var p: Dictionary = POSES[name]
	if flip:
		p = mirror(p)
	_goal = p
	_goal_y = float(p.get("y", 0.0))
	if snap:
		_blend(1.0)

func _blend(k: float) -> void:
	for key in JOINTS:
		var n: Node3D = j[key]
		var want: Vector3 = _goal.get(key, Vector3.ZERO)
		n.rotation_degrees = n.rotation_degrees.lerp(want, k)
	var hips: Node3D = j.hips
	hips.position.y = lerpf(hips.position.y, 0.56 + _goal_y, k)

func _process(dt: float) -> void:
	if not _goal.is_empty():
		_blend(1.0 - exp(-22.0 * dt))

## 장신구 붙이기
func equip(acc: String) -> void:
	match acc:
		"gloves":
			for k in ["el", "er"]:
				_m(j[k], sph(0.17), Color("e0312f"), Vector3(0, -0.3, 0.02), Vector3(1, 1.05, 1.1))
				_m(j[k], cyl(0.1, 0.1, 0.08), Color.WHITE, Vector3(0, -0.17, 0))
		"bat":
			_m(j.er, cyl(0.075, 0.04, 0.95), Color("c9a064"), Vector3(0, -0.3, 0.42), Vector3.ONE, Vector3(90, 0, 0))
			_m(j.er, sph(0.06), Color("8a5a30"), Vector3(0, -0.3, -0.06))

## 규칙 쪽 상태를 그림으로 (f = Rules의 선수)
func sync(f: Dictionary, dt: float) -> void:
	clock += dt
	position = f.pos
	rotation.y = f.yaw
	var name := "guard"
	var flip := false
	match str(f.state):
		"free":
			if f.air: name = "air"
			elif f.moving:
				name = "run_a"
				flip = fmod(clock * 3.2, 1.0) > 0.5
			elif f.aim: name = "aim"
		"atk":
			var m: Dictionary = f.m
			name = str(m.pose)
			if name == "rush":
				name = "jab_r"
				flip = fmod(float(f.t) * 9.0, 1.0) > 0.5
			elif name == "jab_l":
				name = "jab_r"; flip = true
			if float(f.t) < float(m.st) * 0.6 and not (name in ["dive", "airkick"]):
				name = "guard" if not f.air else "air"
		"hurt": name = "hurt"
		"down": name = "fly" if f.air else "down"
		"dead": name = "down"
		"getup": name = "getup"
	pose(name, flip)
	visible = str(f.state) != "out" and (float(f.inv) <= 0.0 or str(f.state) in ["down", "dead"] or fmod(clock * 12.0, 1.0) > 0.35)
