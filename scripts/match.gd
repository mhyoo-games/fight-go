class_name Match
extends Node3D
## 싸움 한 판: 선수(규칙) + 그림 + 컴퓨터 + 카메라 + 효과

signal done(result: Dictionary)

const TIME := 120.0
const CPU_NAMES := ["철수", "바람", "번개", "도토리", "호두", "고양", "별똥", "참새"]
const LOOKS := {
	"brawler": {"hair_style": "spiky", "hair": "#2b2a3a", "top": "#d8362f", "pants": "#30407a", "shoes": "#f2f2f2", "zip": true, "trim": "#ffffff", "band": "#f2f2f2"},
	"agent": {"hair_style": "bob", "hair": "#26304a", "top": "#2a2c36", "pants": "#2a2c36", "shoes": "#1a1a1e", "gloves": "#f2f2f2", "collar": true, "trim": "#e8e8ee", "scarf": "#c8323a", "brow": -4},
	"psychic": {"hair_style": "ponytail", "hair": "#e86aa8", "top": "#6a5ad8", "pants": "#2a2440", "shoes": "#f2f2f2", "gloves": "#ffe45a", "zip": true, "trim": "#ffe45a", "tie": "#ffe45a", "brow": -4},
	"titan": {"hair_style": "mohawk", "hair": "#f2c230", "skin": "#c98a5e", "top": "#c98a5e", "sleeves": false, "pants": "#2a2a30", "shorts": true, "shoes": "#e03a3a", "gloves": "#c98a5e", "belt": "#f2c230"},
}
const SCALES := {"brawler": 1.0, "agent": 0.96, "psychic": 0.94, "titan": 1.18}
const TINTS := ["#d8362f", "#3a8ae0", "#3aa85a", "#e0a020", "#9a5ad8", "#e0609a"]

var w := {}
var fs: Array = []
var views: Array = []
var names: Array = []
var human := 0
var time_left := TIME
var intro := 2.2
var over := -1.0
var win_id := -2
var cam: Camera3D
var cam_c := Vector3(0, 0, 0)
var cam_d := 13.0
var rng := RandomNumberGenerator.new()
var prev := {}
var ai_hold: Array = []
var shot_nodes := {}
var msg := ""
var msg_t := 0.0
var shake := 0.0
var demo := false

static func look_for(style: String, tint := -1) -> Dictionary:
	var l: Dictionary = (LOOKS[style] as Dictionary).duplicate()
	if tint >= 0:
		l.top = TINTS[tint % TINTS.size()]
		if style == "titan":
			l.pants = TINTS[tint % TINTS.size()]
			l.top = l.skin
	return l

func setup(style: String, acc: String, cpus := 3) -> void:
	rng.randomize()
	w = {"stage": Rules.rooftop(), "shots": [], "events": []}
	var starts: Array = w.stage.starts
	var pool := CPU_NAMES.duplicate()
	for i in cpus + 1:
		var st: String = style if i == 0 else Rules.STYLE_IDS[rng.randi() % Rules.STYLE_IDS.size()]
		var ac: String = acc if i == 0 else Rules.ACC_IDS[rng.randi() % Rules.ACC_IDS.size()]
		var f := Rules.new_fighter(i, st, ac, -1, (starts[i % starts.size()] as Vector3) + Vector3(0, 0.1, 0))
		f.yaw = atan2(-f.pos.x, -f.pos.z + 0.01)
		fs.append(f)
		var v := Fighter.new()
		add_child(v)
		v.build(look_for(st, -1 if i == 0 else i))
		v.equip(ac)
		v.scale = Vector3.ONE * float(SCALES[st])
		v.pose("guard", false, true)
		views.append(v)
		var nm: String = "나" if i == 0 and not demo else pool.pop_at(rng.randi() % pool.size())
		names.append(nm)
		ai_hold.append({"inp": {}, "t": 0.0})
		var tag := Label3D.new()
		tag.text = nm
		tag.font_size = 40
		tag.pixel_size = 0.008
		tag.outline_size = 12
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = Color(1.0, 0.9, 0.3) if i == 0 and not demo else Color.WHITE
		tag.position.y = 1.95
		v.add_child(tag)
	cam = Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.current = true
	_camera(1.0)
	Sound.music("rush")

func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)

func _human_input(f: Dictionary) -> Dictionary:
	var now := {"x": _key(KEY_X), "c": _key(KEY_C), "v": _key(KEY_V), "z": _key(KEY_Z)}
	var inp := {
		"mx": (1.0 if _key(KEY_RIGHT) else 0.0) - (1.0 if _key(KEY_LEFT) else 0.0),
		"mz": (1.0 if _key(KEY_DOWN) else 0.0) - (1.0 if _key(KEY_UP) else 0.0),
		"z": now.z, "x": now.x, "c": now.c,
		"xp": now.x and not prev.get("x", false), "cp": now.c and not prev.get("c", false), "vp": now.v and not prev.get("v", false),
	}
	prev = now
	var tg := Rules.nearest(f, fs)
	if not tg.is_empty():
		var d: Vector3 = (tg.pos as Vector3) - (f.pos as Vector3)
		inp.aim_yaw = atan2(d.x, d.z)
	return inp

func _physics_process(dt: float) -> void:
	if intro > 0.0:
		intro -= dt
		if intro <= 0.0:
			Sound.play("go")
			say("싸워라!", 1.0)
	var frozen := intro > 0.0
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
					h.inp = Rules.ai_input(f, fs, w.stage, rng.randf(), 0.75)
					h.t = rng.randf_range(0.08, 0.2)
					inp = h.inp
				else:
					inp = (h.inp as Dictionary).duplicate()
					for k in ["xp", "cp", "vp"]:
						inp.erase(k)
		Rules.step(f, inp, w, dt)
	Rules.resolve(fs, w, dt)
	_events()
	for i in fs.size():
		(views[i] as Fighter).sync(fs[i], dt)
	_shots()
	_camera(1.0 - exp(-3.0 * dt))
	msg_t -= dt
	if over < 0.0 and not frozen:
		time_left -= dt
		var wn := Rules.winner(fs, time_left)
		if wn != -2:
			win_id = wn
			over = 3.0
			Sound.play("finish")
			say(("%s 승리!" % names[wn]) if wn >= 0 else "무승부!", 3.0)
	elif over >= 0.0:
		if win_id >= 0 and Rules.alive(fs[win_id]) and not fs[win_id].air:
			(views[win_id] as Fighter).pose("win")
		over -= dt
		if over < 0.0:
			set_physics_process(false)
			done.emit({"winner": win_id, "name": names[win_id] if win_id >= 0 else "", "me": win_id == human, "hp": fs[human].hp, "outs": fs[human].outs})

func say(t: String, secs: float) -> void:
	msg = t
	msg_t = secs

func _events() -> void:
	for e in w.events:
		match str(e.e):
			"hit":
				Sound.play("hit" if e.big else "bump", -4.0, rng.randf_range(0.9, 1.15))
				_spark(e.pos, 1.6 if e.big else 1.0)
				if e.big: shake = maxf(shake, 0.25)
				if e.ko: say("%s K.O.!" % names[int(e.id)], 1.6)
			"jump": Sound.play("jump", -10.0)
			"land": Sound.play("land", -12.0)
			"swing":
				Sound.play("whoosh", -8.0 if not e.super else 0.0, 1.3 if not e.super else 0.8)
				if e.super:
					Sound.play("dash", -2.0)
					_spark((fs[int(e.id)].pos as Vector3) + Vector3(0, 1.0, 0), 2.4, Color(0.5, 0.9, 1.0))
			"shot": Sound.play("throw", -6.0)
			"fall":
				Sound.play("fall", -4.0)
				say("%s 떨어졌다!" % names[int(e.id)], 1.4)
	w.events.clear()

func _spark(pos: Vector3, size: float, c := Color(1.0, 0.9, 0.3)) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25; sm.height = 0.5; sm.radial_segments = 8; sm.rings = 4
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size * 2.6, 0.18)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(mi.queue_free)

func _shots() -> void:
	var seen := {}
	for s in w.shots:
		var key: int = s.get_or_add("uid", rng.randi())
		seen[key] = true
		if not shot_nodes.has(key):
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.3; sm.height = 0.6
			mi.mesh = sm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.7, 0.5, 1.0)
			mi.material_override = m
			add_child(mi)
			shot_nodes[key] = mi
		(shot_nodes[key] as Node3D).position = s.pos
	for key in shot_nodes.keys():
		if not seen.has(key):
			_spark((shot_nodes[key] as Node3D).position, 1.0, Color(0.8, 0.6, 1.0))
			(shot_nodes[key] as Node3D).queue_free()
			shot_nodes.erase(key)

func _camera(k: float) -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var n := 0
	for f in fs:
		if Rules.alive(f) and (f.pos as Vector3).y > -4.0:
			var p: Vector3 = f.pos
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
			n += 1
	if n == 0:
		return
	var c := (lo + hi) * 0.5
	var spread := maxf(hi.x - lo.x, (hi.z - lo.z) * 1.8)
	cam_c = cam_c.lerp(c, k)
	cam_d = lerpf(cam_d, clampf(9.0 + spread * 0.62, 10.0, 22.0), k)
	var off := Vector3(0, 0.62, 0.78) * cam_d
	shake = maxf(0.0, shake - 0.016)
	cam.position = cam_c + off + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * shake * 0.4
	cam.look_at(cam_c + Vector3(0, 0.7, 0), Vector3.UP)
