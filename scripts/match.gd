class_name Match
extends Node3D
## 싸움 한 판: 선수(규칙) + 그림 + 컴퓨터 + 무기 + 카메라 + 효과

signal done(result: Dictionary)

const TIME := 180.0
const CPU_NAMES := ["철수", "바람", "번개", "도토리", "호두", "고양", "별똥", "참새"]
const TAP := 0.28          # 같은 방향을 이 시간 안에 두 번 누르면 달리기
const FX_COL := {"fire": Color(1.0, 0.5, 0.1), "bolt": Color(1.0, 0.95, 0.3), "ice": Color(0.6, 0.9, 1.0), "psy": Color(0.75, 0.5, 1.0), "quake": Color(0.9, 0.75, 0.5), "boom": Color(1.0, 0.6, 0.2)}

var w := {}
var fs: Array = []
var views: Array = []
var shadows: Array = []
var names: Array = []
var human := 0
var time_left := TIME
var intro := 2.2
var over := -1.0
var win_id := -2
var cam: Camera3D
var cam_c := Vector3.ZERO
var cam_d := 13.0
var rng := RandomNumberGenerator.new()
var prev := {}
var tap_dir := ""
var tap_t := -9.0
var running := false
var clock := 0.0
var ai_hold: Array = []
var shot_nodes := {}
var item_nodes := {}
var item_t := 4.0
var msg := ""
var msg_t := 0.0
var shake := 0.0
var hitstop := 0.0
var combo_n := 0
var combo_t := 0.0
var demo := false
var focus := 0
var _helper: Fighter

func setup(style: String, acc: String, cpus := 3) -> void:
	rng.randomize()
	w = {"stage": Rules.city(), "shots": [], "items": [], "events": []}
	var starts: Array = w.stage.starts
	var pool := CPU_NAMES.duplicate()
	_helper = Fighter.new()
	for i in cpus + 1:
		var st: String = style if i == 0 else Rules.STYLE_IDS[rng.randi() % Rules.STYLE_IDS.size()]
		var ac: String = acc if i == 0 else Rules.ACC_IDS[rng.randi() % Rules.ACC_IDS.size()]
		var f := Rules.new_fighter(i, st, ac, -1, (starts[i % starts.size()] as Vector3) + Vector3(0, 0.1, 0))
		f.yaw = atan2(-f.pos.x, -f.pos.z + 0.01)
		fs.append(f)
		var v := Fighter.new()
		add_child(v)
		v.build(st, -1 if i == 0 else i + rng.randi() % 3)
		v.equip(ac)
		v.rotation.y = f.yaw
		views.append(v)
		var nm: String = "나" if i == 0 and not demo else pool.pop_at(rng.randi() % pool.size())
		names.append(nm)
		ai_hold.append({"inp": {}, "t": 0.0})
		var tag := Label3D.new()
		tag.text = nm
		tag.font_size = 40
		tag.pixel_size = 0.007
		tag.outline_size = 12
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = Color(1.0, 0.9, 0.3) if i == 0 and not demo else Color.WHITE
		tag.position.y = 2.0
		v.add_child(tag)
		# 발밑 그림자 (공중에 떠도 어디쯤인지 보이게)
		var sh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.42; cm.bottom_radius = 0.42; cm.height = 0.02; cm.radial_segments = 16
		sh.mesh = cm
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(0.05, 0.02, 0.1, 0.45)
		sh.material_override = sm
		add_child(sh)
		shadows.append(sh)
	for i in 6:
		_spawn_item()
	cam = Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.current = true
	cam_c = fs[0].pos
	_camera(1.0)
	Sound.music("rush")

func _exit_tree() -> void:
	if _helper:
		_helper.free()

func _spawn_item() -> void:
	var pts: Array = w.stage.items
	for tries in 8:
		var p: Vector3 = pts[rng.randi() % pts.size()]
		var free := true
		for it in w.items:
			if (it.pos as Vector3).distance_to(p) < 1.5: free = false
		if free:
			var kind: String = ["bat", "bat", "rifle", "rifle", "bazooka"][rng.randi() % 5]
			w.items.append({"kind": kind, "uses": int(Rules.WEAPONS[kind].uses), "pos": p})
			return

func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)

func _human_input(f: Dictionary) -> Dictionary:
	var now := {"x": _key(KEY_X), "c": _key(KEY_C), "v": _key(KEY_V), "z": _key(KEY_Z),
		"left": _key(KEY_LEFT), "right": _key(KEY_RIGHT), "up": _key(KEY_UP), "down": _key(KEY_DOWN)}
	# 같은 방향 두 번 = 달리기. 방향키를 다 떼면 멈춘다
	var any := false
	for d in ["left", "right", "up", "down"]:
		any = any or now[d]
		if now[d] and not prev.get(d, false):
			if tap_dir == d and clock - tap_t < TAP:
				running = true
			tap_dir = d
			tap_t = clock
	if not any:
		running = false
	var inp := {
		"mx": (1.0 if now.right else 0.0) - (1.0 if now.left else 0.0),
		"mz": (1.0 if now.down else 0.0) - (1.0 if now.up else 0.0),
		"run": running, "z": now.z, "x": now.x, "c": now.c,
		"xp": now.x and not prev.get("x", false), "cp": now.c and not prev.get("c", false), "vp": now.v and not prev.get("v", false),
	}
	prev = now
	# Z 조준: 조준 거리(TEC) 안의 가장 가까운 상대를 본다
	var tg := Rules.nearest(f, fs, true, float(f.S.aim))
	if not tg.is_empty():
		var d: Vector3 = (tg.pos as Vector3) - (f.pos as Vector3)
		inp.aim_yaw = atan2(d.x, d.z)
	return inp

func _physics_process(dt: float) -> void:
	clock += dt
	if intro > 0.0:
		intro -= dt
		if intro <= 0.0:
			Sound.play("go")
			say("싸워라!", 1.0)
	var frozen := intro > 0.0
	if hitstop > 0.0:
		# 맞는 순간 아주 잠깐 멈춘다 (타격감)
		hitstop -= dt
		_camera(1.0 - exp(-4.0 * dt))
		return
	for i in fs.size():
		var f: Dictionary = fs[i]
		var inp := {}
		if not frozen and Rules.alive(f) and over < 0.0:
			if i == human and not demo:
				inp = _human_input(f)
			else:
				# 컴퓨터는 조금씩 늦게 생각한다
				var h: Dictionary = ai_hold[i]
				h.t = float(h.t) - dt
				if float(h.t) <= 0.0:
					h.inp = Rules.ai_input(f, fs, w, rng.randf(), 0.7)
					h.t = rng.randf_range(0.1, 0.22)
					inp = h.inp
				else:
					inp = (h.inp as Dictionary).duplicate()
					for k in ["xp", "cp", "vp"]:
						inp.erase(k)
		Rules.step(f, inp, w, dt)
	Rules.resolve(fs, w, dt)
	_events()
	for i in fs.size():
		var f: Dictionary = fs[i]
		var v: Fighter = views[i]
		v.sync(f, dt)
		var sh: MeshInstance3D = shadows[i]
		var p: Vector3 = f.pos
		var g := Rules.ground_h(w.stage, p.x, p.z, p.y + 0.1)
		sh.visible = v.visible and g > -INF
		if sh.visible:
			sh.position = Vector3(p.x, g + 0.02, p.z)
			var k := clampf(1.0 - (p.y - g) * 0.18, 0.4, 1.0) * float(v.look.scale)
			sh.scale = Vector3(k, 1, k)
		# 불·번개 기술은 꼬리를 남긴다
		if str(f.state) == "atk" and FX_COL.has(str(f.m.get("fx", ""))) and float(f.t) >= float(f.m.st) and float(f.t) < float(f.m.st) + float(f.m.act) and Engine.get_physics_frames() % 2 == 0:
			_burst(p + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.4, 1.3), rng.randf_range(-0.3, 0.3)), 0.7, FX_COL[str(f.m.fx)])
		if f.run and not f.air and Engine.get_physics_frames() % 7 == 0:
			_burst(p + Vector3(0, 0.1, 0), 0.45, Color(0.95, 0.9, 0.8, 0.6))
	_shots()
	_items(dt)
	_camera(1.0 - exp(-4.0 * dt))
	msg_t -= dt
	combo_t -= dt
	if over < 0.0 and not frozen:
		time_left -= dt
		item_t -= dt
		if item_t <= 0.0:
			item_t = 7.0
			if w.items.size() < 7:
				_spawn_item()
		var wn := Rules.winner(fs, time_left)
		if wn != -2:
			win_id = wn
			over = 3.2
			Sound.play("finish")
			say(("%s 승리!" % names[wn]) if wn >= 0 else "무승부!", 3.2)
			if wn >= 0:
				(views[wn] as Fighter).win = true
				focus = wn
	elif over >= 0.0:
		over -= dt
		if over < 0.0:
			set_physics_process(false)
			var me: Dictionary = fs[human]
			done.emit({"winner": win_id, "name": names[win_id] if win_id >= 0 else "", "me": win_id == human, "hp": me.hp, "outs": me.outs,
				"dealt": me.dealt, "kos": me.kos, "coins": Rules.reward(win_id == human, float(me.dealt), int(me.kos))})

func say(t: String, secs: float) -> void:
	msg = t
	msg_t = secs

func _events() -> void:
	for e in w.events:
		match str(e.e):
			"hit":
				Sound.play("hit" if e.big else "bump", -4.0, rng.randf_range(0.9, 1.15))
				_burst(e.pos, 1.7 if e.big else 1.0, Color(1.0, 0.9, 0.3))
				_star(e.pos, 1.3 if e.big else 0.8)
				hitstop = maxf(hitstop, 0.085 if e.big else 0.04)
				if e.big: shake = maxf(shake, 0.28)
				if e.ko:
					say("%s K.O.!" % names[int(e.id)], 1.6)
					hitstop = 0.22
				if int(e.by) == human and not demo:
					combo_n = combo_n + 1 if combo_t > 0.0 else 1
					combo_t = 1.3
			"jump": Sound.play("jump", -10.0)
			"land":
				Sound.play("land", -12.0 if not e.hard else -4.0)
				_ring((fs[int(e.id)].pos as Vector3) + Vector3(0, 0.05, 0), 0.9 if not e.hard else 1.5, Color(0.95, 0.9, 0.8, 0.7))
			"swing":
				Sound.play("whoosh", -8.0 if not e.super else 0.0, 1.3 if not e.super else 0.8)
				var fp: Vector3 = fs[int(e.id)].pos
				if e.super:
					Sound.play("dash", -2.0)
					_burst(fp + Vector3(0, 1.0, 0), 2.6, Color(0.5, 0.9, 1.0))
					_ring(fp + Vector3(0, 0.05, 0), 2.2, Color(0.5, 0.9, 1.0))
				if str(e.fx) in ["quake", "ice", "psy"] or (str(e.fx) == "bolt" and not e.super):
					_ring(fp + Vector3(0, 0.08, 0), 3.0, FX_COL[str(e.fx)])
			"shot": Sound.play("throw" if not (str(e.kind) in ["bullet", "rocket"]) else "boost", -6.0, 1.0 if str(e.kind) != "bullet" else 1.8)
			"boom":
				Sound.play("hit", 2.0, 0.6)
				_burst(e.pos, 4.5, Color(1.0, 0.6, 0.15))
				_burst(e.pos, 3.0, Color(1.0, 0.95, 0.6))
				_ring((e.pos as Vector3) + Vector3(0, -0.6, 0), float(e.r) * 1.2, Color(1.0, 0.7, 0.3))
				shake = maxf(shake, 0.5)
			"pickup": Sound.play("item", -4.0)
			"door":
				Sound.play("slide", -4.0)
				if int(e.id) == focus:
					cam_c = fs[focus].pos
			"fall":
				Sound.play("fall", -4.0)
				say("%s 떨어졌다!" % names[int(e.id)], 1.4)
	w.events.clear()

func _fx_node(mesh: Mesh, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi

func _fade(mi: MeshInstance3D, to_scale: Vector3, secs: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", to_scale, secs).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, secs)
	tw.chain().tween_callback(mi.queue_free)

func _burst(pos: Vector3, size: float, c: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.25; sm.height = 0.5; sm.radial_segments = 8; sm.rings = 4
	_fade(_fx_node(sm, pos, c), Vector3.ONE * size * 2.4, 0.2)

## 맞은 자리의 뾰족한 별
func _star(pos: Vector3, size: float) -> void:
	for i in 3:
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 0.07, 0.07)
		var mi := _fx_node(bm, pos, Color(1, 1, 1))
		mi.rotation = Vector3(0, rng.randf() * TAU, rng.randf() * TAU)
		mi.scale = Vector3.ONE * size * 0.3
		_fade(mi, Vector3.ONE * size, 0.14)

func _ring(pos: Vector3, r: float, c: Color) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42; tm.outer_radius = 0.5; tm.rings = 20; tm.ring_segments = 6
	var mi := _fx_node(tm, pos, c)
	mi.scale = Vector3(0.3, 0.4, 0.3)
	_fade(mi, Vector3(r * 2.0, 0.4, r * 2.0), 0.3)

func _shots() -> void:
	var seen := {}
	for s in w.shots:
		var key: int = s.get_or_add("uid", rng.randi())
		seen[key] = true
		var kind := str(s.kind)
		if not shot_nodes.has(key):
			var n := Node3D.new()
			add_child(n)
			if kind in Rules.WEAPON_IDS:
				Fighter.weapon_mesh(kind, n, _helper)
			elif kind == "rocket":
				_helper._m(n, Fighter.cyl(0.1, 0.1, 0.55, 8), Color("5a7a4a"), Vector3.ZERO, Vector3(90, 0, 0))
				_helper._m(n, Fighter.cyl(0.0, 0.1, 0.22, 8), Color("c8382f"), Vector3(0, 0, 0.38), Vector3(90, 0, 0))
				_helper._m(n, Fighter.cyl(0.12, 0.0, 0.5, 8), Color(1.0, 0.75, 0.2), Vector3(0, 0, -0.5), Vector3(90, 0, 0), Vector3.ONE, false, true)
			elif kind == "bullet":
				_helper._m(n, Fighter.box(Vector3(0.07, 0.07, 0.7)), Color(1.0, 0.95, 0.5), Vector3.ZERO, Vector3.ZERO, Vector3.ONE * float(s.big), false, true)
			elif kind == "ice":
				_helper._m(n, Fighter.taper(0.0, 0.0, 0.26, 0.26, 0.3), Color(0.7, 0.93, 1.0), Vector3(0, 0, 0.15), Vector3(-90, 0, 0), Vector3.ONE, true, true)
				_helper._m(n, Fighter.taper(0.26, 0.26, 0.0, 0.0, 0.5), Color(0.85, 0.97, 1.0), Vector3(0, 0, -0.25), Vector3(-90, 0, 0), Vector3.ONE, true, true)
			elif kind == "wind":
				for i in 3:
					var tm := TorusMesh.new()
					tm.inner_radius = 0.3 + i * 0.12; tm.outer_radius = 0.38 + i * 0.12
					_helper._m(n, tm, Color(0.9, 1.0, 1.0), Vector3(0, 0, -i * 0.3), Vector3(90, 0, 0), Vector3.ONE, false, true)
			else:
				_helper._m(n, Fighter.sph(0.3, 10), Color(0.75, 0.5, 1.0), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false, true)
				_helper._m(n, Fighter.sph(0.18, 8), Color(1, 0.9, 1.0), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false, true)
			var v: Vector3 = s.vel
			n.rotation.y = atan2(v.x, v.z)
			shot_nodes[key] = n
		var node: Node3D = shot_nodes[key]
		node.position = s.pos
		if kind in Rules.WEAPON_IDS:
			node.rotate_x(0.35)
		elif kind in ["rocket", "psy", "ice"] and Engine.get_physics_frames() % 2 == 0:
			_burst(s.pos, 0.5, FX_COL.boom if kind == "rocket" else (FX_COL.ice if kind == "ice" else FX_COL.psy))
	for key in shot_nodes.keys():
		if not seen.has(key):
			_burst((shot_nodes[key] as Node3D).position, 1.0, Color(1.0, 0.9, 0.7))
			(shot_nodes[key] as Node3D).queue_free()
			shot_nodes.erase(key)

## 바닥에 떨어진 무기: 살짝 떠서 돈다
func _items(dt: float) -> void:
	var seen := {}
	for it in w.items:
		var key: int = it.get_or_add("uid", rng.randi())
		seen[key] = true
		if not item_nodes.has(key):
			var n := Node3D.new()
			add_child(n)
			var tilt := Node3D.new()
			tilt.rotation_degrees = Vector3(0, 0, 62)
			tilt.position.y = 0.55
			n.add_child(tilt)
			Fighter.weapon_mesh(str(it.kind), tilt, _helper)
			var tm := TorusMesh.new()
			tm.inner_radius = 0.5; tm.outer_radius = 0.58; tm.rings = 20; tm.ring_segments = 5
			_helper._m(n, tm, Color(1.0, 0.9, 0.3), Vector3(0, 0.04, 0), Vector3.ZERO, Vector3.ONE, false, true)
			item_nodes[key] = n
		var node: Node3D = item_nodes[key]
		node.position = it.pos
		node.rotation.y += dt * 1.8
	for key in item_nodes.keys():
		if not seen.has(key):
			(item_nodes[key] as Node3D).queue_free()
			item_nodes.erase(key)

func _camera(k: float) -> void:
	# 보는 사람(나)을 따라가고, 가까운 상대가 화면에 들어오게 물러난다
	if not Rules.alive(fs[focus]):
		for f in fs:
			if Rules.alive(f):
				focus = int(f.id)
				break
	var me: Dictionary = fs[focus]
	var mp: Vector3 = me.pos
	if mp.y < -5.0:
		return
	var lo := mp
	var hi := mp
	for f in fs:
		var p: Vector3 = f.pos
		if int(f.id) != focus and Rules.alive(f) and p.y > -4.0 and Rules.zone(p) == Rules.zone(mp) and p.distance_to(mp) < (30.0 if demo else 13.0):
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var c := ((lo + hi) * 0.5).lerp(mp, 0.0 if demo else 0.45)
	var spread := maxf(hi.x - lo.x, (hi.z - lo.z) * 1.8)
	if cam_c.distance_to(c) > 28.0:
		k = 1.0
	cam_c = cam_c.lerp(c, k)
	cam_d = lerpf(cam_d, clampf(9.5 + spread * 0.6, 10.5, 24.0 if demo else 17.0), k)
	var off := Vector3(0, 0.6, 0.8) * cam_d
	shake = maxf(0.0, shake - 0.02)
	cam.position = cam_c + off + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * shake * 0.4
	cam.look_at(cam_c + Vector3(0, 0.8, 0), Vector3.UP)
