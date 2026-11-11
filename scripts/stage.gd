class_name RooftopStage
extends Node3D
## 해 질 녘 옥상 무대 (코드로 만듦): 가운데 큰 옥상, 옆 옥상 두 층, 옥탑방·계단·난간·빨랫줄·물탱크, 둘레 건물들

var rng := RandomNumberGenerator.new()
var _lit := []
var _dim := []

static func m(c: Color, rough := 0.9) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = rough
	return s

func b(size: Vector3, pos: Vector3, c: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = m(c)
	add_child(mi)
	return mi

func build() -> void:
	rng.seed = 12
	_env()
	# 가운데 싸움터 옥상
	_roof(Vector3(0, 0, 0), Vector2(15.6, 8), Color("d8a65c"), Color("b9793a"), Color("a88492"))
	# 왼쪽 낮은 옥상, 오른쪽 높은 옥상
	_roof(Vector3(-11.8, -1.6, -1.0), Vector2(8, 7), Color("cfa06a"), Color("a86f3e"), Color("8f7f9a"))
	_roof(Vector3(11.3, 1.4, -1.5), Vector2(7, 7), Color("d4a35f"), Color("b0763a"), Color("b08a7a"))
	_stairs(Vector3(5.4, 0, 1.6), 1.4, 1.0)
	_stairs(Vector3(-10.2, -1.6, 1.8), 1.6, 1.0)
	# 옥탑방 (가운데 뒤쪽)
	_hut(Vector3(-4.5, 0, -2.4), Vector3(3.2, 2.3, 2.6), Color("c98f7a"))
	_hut(Vector3(12.1, 1.4, -3.4), Vector3(2.6, 2.1, 2.2), Color("b7a08a"))
	# 난간 (뒤쪽)
	_rail(Vector3(-0.5, 0, -3.85), 6.0)
	_rail(Vector3(5.0, 0, -3.85), 4.5)
	# 소품
	_tank(Vector3(-14.0, -1.6, -3.2))
	_ac(Vector3(-3.0, 2.5, -3.2)); _ac(Vector3(-5.6, 2.5, -3.2))
	_laundry(Vector3(-15.3, -1.6, -4.2), Vector3(-9.0, -1.6, -4.2))
	_plant(Vector3(-7.3, 0, -3.6)); _plant(Vector3(14.3, 1.4, 1.5)); _plant(Vector3(7.3, 0, -3.6))
	_antenna(Vector3(12.9, 3.75, -3.9))
	# 둘레 건물
	var cols := [Color("8d7f95"), Color("a38a8f"), Color("c49a86"), Color("7f8aa0"), Color("b58f6a"), Color("9a8478")]
	for i in 26:
		var x := rng.randf_range(-38, 38)
		var z := rng.randf_range(-42, -9)
		var w := rng.randf_range(6, 11)
		var d := rng.randf_range(6, 10)
		var top := rng.randf_range(-7, 13) + (-z - 9) * 0.25
		_building(Vector3(x, top, z), Vector3(w, 40, d), cols[i % cols.size()])
	for sx in [-1.0, 1.0]:
		for i in 4:
			_building(Vector3(sx * rng.randf_range(24, 34), rng.randf_range(-4, 9), rng.randf_range(-6, 6)), Vector3(8, 40, 8), cols[(i + 2) % cols.size()])
	_flush(_lit, Color(1.0, 0.86, 0.5), true)
	_flush(_dim, Color(0.2, 0.2, 0.3), false)
	# 저 아래 거리
	b(Vector3(200, 1, 200), Vector3(0, -34, 0), Color("4a4458"))

func _env() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("5a4f9a")
	sm.sky_horizon_color = Color("ffb36b")
	sm.ground_horizon_color = Color("ff9a5a")
	sm.ground_bottom_color = Color("5a4060")
	sm.sky_curve = 0.08
	sky.sky_material = sm
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b79ad6")
	e.ambient_light_energy = 0.6
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("ffb07a")
	e.fog_density = 0.006
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 128, 0)
	sun.light_color = Color(1.0, 0.82, 0.6)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

## 옥상 하나: 바닥 + 테두리 + 아래 건물 몸통 (pos = 바닥 가운데, 높이는 pos.y)
func _roof(pos: Vector3, size: Vector2, floor_c: Color, rim_c: Color, wall_c: Color) -> void:
	b(Vector3(size.x, 0.4, size.y), pos + Vector3(0, -0.2, 0), floor_c)
	b(Vector3(size.x + 0.6, 0.5, size.y + 0.6), pos + Vector3(0, -0.4, 0), rim_c)
	# 바닥 무늬 (네모 타일 줄)
	var x := -size.x * 0.5 + 2.5
	while x < size.x * 0.5:
		b(Vector3(0.05, 0.01, size.y - 0.4), pos + Vector3(x, 0.005, 0), floor_c.darkened(0.12))
		x += 2.5
	_building(pos + Vector3(0, -0.65, 0), Vector3(size.x - 0.4, 40, size.y - 0.4), wall_c)

## 건물: top = 지붕 가운데 위치, size.y = 아래로 길이
func _building(top: Vector3, size: Vector3, c: Color) -> void:
	b(size, top + Vector3(0, -size.y * 0.5, 0), c)
	b(Vector3(size.x + 0.4, 0.4, size.z + 0.4), top + Vector3(0, 0.0, 0), c.darkened(0.25))
	if rng.randf() < 0.5:
		b(Vector3(2.0, 1.6, 2.0), top + Vector3(rng.randf_range(-1.5, 1.5), 0.9, rng.randf_range(-1.5, 1.5)), c.lightened(0.1))
	var rows := 12
	# 앞면(+z)
	var cols := int(size.x / 1.5)
	for r in rows:
		for k in cols:
			var p := top + Vector3((k - (cols - 1) * 0.5) * 1.5, -1.6 - r * 1.9, size.z * 0.5 + 0.03)
			(_lit if rng.randf() < 0.3 else _dim).append(Transform3D(Basis(), p))
	# 옆면
	var cz := int(size.z / 1.5)
	for sx in [-1.0, 1.0]:
		for r in rows:
			for k in cz:
				var p2 := top + Vector3(sx * (size.x * 0.5 + 0.03), -1.6 - r * 1.9, (k - (cz - 1) * 0.5) * 1.5)
				(_lit if rng.randf() < 0.3 else _dim).append(Transform3D(Basis(Vector3.UP, PI / 2), p2))

func _flush(xf: Array, c: Color, glow: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 1.1, 0.06)
	var mat := m(c, 0.3)
	if glow:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 1.4
	bm.material = mat
	mm.mesh = bm
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

func _hut(pos: Vector3, size: Vector3, c: Color) -> void:
	b(size, pos + Vector3(0, size.y * 0.5, 0), c)
	b(Vector3(size.x + 0.5, 0.25, size.z + 0.5), pos + Vector3(0, size.y + 0.12, 0), Color("d8a65c"))
	b(Vector3(0.9, 1.6, 0.08), pos + Vector3(-size.x * 0.2, 0.8, size.z * 0.5 + 0.03), Color("5a3a2e"))
	b(Vector3(0.08, 0.08, 0.1), pos + Vector3(-size.x * 0.2 + 0.3, 0.8, size.z * 0.5 + 0.08), Color("e8c84a"))
	var w := b(Vector3(0.8, 0.7, 0.08), pos + Vector3(size.x * 0.22, 1.3, size.z * 0.5 + 0.03), Color("ffe08a"))
	(w.material_override as StandardMaterial3D).emission_enabled = true
	(w.material_override as StandardMaterial3D).emission = Color("ffd070")

## 계단: pos = 아래 시작점, h = 올라가는 높이 (오른쪽 +x로 올라감, dir -1이면 왼쪽)
func _stairs(pos: Vector3, h: float, dir: float, width := 1.4) -> void:
	var n := 4
	for i in n - 1:
		var sh := (i + 1) * h / n
		b(Vector3(0.8, sh, width), pos + Vector3(dir * (i * 0.8 + 0.4), sh * 0.5, 0), Color("b98a6a") if i % 2 == 0 else Color("a87a5c"))

func _rail(pos: Vector3, length: float) -> void:
	b(Vector3(length, 0.07, 0.07), pos + Vector3(0, 0.9, 0), Color("5a5560"))
	b(Vector3(length, 0.05, 0.05), pos + Vector3(0, 0.5, 0), Color("5a5560"))
	var x := -length * 0.5
	while x <= length * 0.5 + 0.01:
		b(Vector3(0.07, 0.9, 0.07), pos + Vector3(x, 0.45, 0), Color("5a5560"))
		x += 1.0

func _tank(pos: Vector3) -> void:
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			b(Vector3(0.1, 1.0, 0.1), pos + Vector3(sx, 0.5, sz), Color("6a6470"))
	var t := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.85; cm.bottom_radius = 0.85; cm.height = 1.3
	t.mesh = cm
	t.position = pos + Vector3(0, 1.65, 0)
	t.material_override = m(Color("4f86c6"), 0.5)
	add_child(t)
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.2; lm.bottom_radius = 0.9; lm.height = 0.3
	lid.mesh = lm
	lid.position = pos + Vector3(0, 2.45, 0)
	lid.material_override = m(Color("3f6fa8"))
	add_child(lid)

func _ac(pos: Vector3) -> void:
	b(Vector3(0.9, 0.7, 0.5), pos + Vector3(0, 0.35, 0), Color("d8d8dc"))
	b(Vector3(0.5, 0.5, 0.04), pos + Vector3(-0.12, 0.35, 0.26), Color("3a3a44"))

func _plant(pos: Vector3) -> void:
	b(Vector3(0.5, 0.4, 0.5), pos + Vector3(0, 0.2, 0), Color("b5562e"))
	for i in 4:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.28; sm.height = 0.56
		s.mesh = sm
		s.position = pos + Vector3(rng.randf_range(-0.15, 0.15), 0.6 + i * 0.12, rng.randf_range(-0.15, 0.15))
		s.material_override = m(Color("4f9a48") if i % 2 == 0 else Color("6ab45a"))
		add_child(s)

func _antenna(pos: Vector3) -> void:
	b(Vector3(0.06, 2.6, 0.06), pos + Vector3(0, 1.3, 0), Color("4a4650"))
	for i in 4:
		b(Vector3(1.0 - i * 0.18, 0.04, 0.04), pos + Vector3(0, 1.6 + i * 0.3, 0), Color("4a4650"))

func _laundry(a: Vector3, c: Vector3) -> void:
	for p in [a, c]:
		b(Vector3(0.08, 2.0, 0.08), p + Vector3(0, 1.0, 0), Color("5a5560"))
	b(Vector3(a.distance_to(c), 0.025, 0.025), (a + c) * 0.5 + Vector3(0, 1.9, 0), Color("eeeeee"))
	var cols := [Color("f2f2f2"), Color("e85a5a"), Color("6aa8e8"), Color("f2d24a"), Color("f2f2f2"), Color("7ac87a")]
	for i in cols.size():
		var t := (i + 0.7) / (cols.size() + 0.4)
		b(Vector3(0.55, 0.7 if i % 2 == 0 else 0.5, 0.03), a.lerp(c, t) + Vector3(0, 1.9 - (0.35 if i % 2 == 0 else 0.25), 0), cols[i])
