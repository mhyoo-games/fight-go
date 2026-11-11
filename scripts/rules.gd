class_name Rules
extends RefCounted
## 화면과 떨어진 싸움 규칙. 테스트: godot --headless -s tests/run_tests.gd
##
## 키: 방향키 이동 / Z 조준(가장 가까운 상대를 봄) / X 약공격 / C 강공격 / V 점프
##   X X X 연타, Z+X·Z+C = 장신구 기술(맨손이면 조준 치기), Z+X+C = 필살기(게이지 50)
##   공중 X·C = 공중 공격, 공중 X+C = 점프 필살기(게이지 30)
## 좌표: Vector3, 앞 = (sin yaw, 0, cos yaw)

const GRAVITY := 30.0
const STEP_UP := 0.45
const FALL_Y := -12.0
const KNOCK := 0.55          ## 밀려나는 세기 (전체 조절)
const FALL_LOSS := 0.25      ## 떨어지면 잃는 피 (최대의 몇 배)
const SUPER_COST := 50
const AIR_SUPER_COST := 30

## 유형: 능력치와 필살기가 다르다
const STYLES := {
	"brawler": {"name": "주먹꾼", "about": "고루 갖춘 싸움꾼. 때릴수록 게이지가 빨리 차요. 필살기: 연속 주먹", "hp": 110, "speed": 6.0, "jump": 10.5, "power": 1.0, "def": 1.0, "aspd": 1.0, "jumps": 1, "gain": 1.35, "super": "s_rush"},
	"agent": {"name": "요원", "about": "빠르고 두 번 뛰어요. 몸은 약해요. 필살기: 번개 돌진", "hp": 90, "speed": 7.4, "jump": 11.0, "power": 0.9, "def": 0.9, "aspd": 1.25, "jumps": 2, "gain": 1.0, "super": "s_dash"},
	"psychic": {"name": "염력사", "about": "강공격이 멀리 날아가는 염력탄. 가까이 붙으면 약해요. 필살기: 염력 폭발", "hp": 85, "speed": 5.8, "jump": 10.0, "power": 1.0, "def": 0.85, "aspd": 1.0, "jumps": 1, "gain": 1.0, "super": "s_blast"},
	"titan": {"name": "장사", "about": "느리지만 세고 튼튼해요. 필살기: 땅 울리기", "hp": 140, "speed": 5.0, "jump": 9.6, "power": 1.3, "def": 1.25, "aspd": 0.85, "jumps": 1, "gain": 1.0, "super": "s_slam"},
}
const STYLE_IDS := ["brawler", "agent", "psychic", "titan"]

## 장신구: Z+X, Z+C 기술이 바뀐다
const ACCS := {
	"none": {"name": "맨손", "about": "Z+X 조준 지르기 · Z+C 조준 차기", "zx": "aim_x", "zc": "aim_c"},
	"gloves": {"name": "권투 장갑", "about": "Z+X 소나기 주먹 · Z+C 올려치기", "zx": "g_flurry", "zc": "g_upper"},
	"bat": {"name": "방망이", "about": "Z+X 휘두르기 · Z+C 홈런 (느리지만 멀리 날려요)", "zx": "b_swing", "zc": "b_homer"},
}
const ACC_IDS := ["none", "gloves", "bat"]

static var _mv := {}

static func _m(pose: String, st: float, act: float, rec: float, dmg: float, kb: float, up: float, reach := 1.0, wide := 0.95, lunge := 0.0, extra := {}) -> Dictionary:
	var d := {"pose": pose, "st": st, "act": act, "rec": rec, "dmg": dmg, "kb": kb, "up": up, "reach": reach, "wide": wide, "lunge": lunge,
		"stun": 0.35, "down": false, "rehit": 0.0, "air": false, "cost": 0, "inv": false}
	d.merge(extra, true)
	return d

## 기술 표: st 준비, act 맞는 시간, rec 뒤 빈틈, dmg 피해, kb 밀어내기, up 띄우기, reach 앞 거리, wide 맞는 반지름, lunge 앞으로 나가는 빠르기
static func moves() -> Dictionary:
	if _mv.is_empty():
		_mv = {
			"x1": _m("jab_r", 0.07, 0.08, 0.16, 4, 1.5, 0, 1.0, 0.95, 2.5),
			"x2": _m("jab_l", 0.07, 0.08, 0.16, 4, 1.5, 0, 1.0, 0.95, 2.5),
			"x3": _m("kick", 0.1, 0.1, 0.26, 7, 7, 4.5, 1.1, 1.0, 3.0, {"down": true}),
			"c": _m("upper", 0.2, 0.1, 0.3, 11, 4, 9, 1.0, 1.0, 2.0, {"down": true}),
			"a_x": _m("airkick", 0.05, 0.3, 0.1, 6, 6, 2, 0.9, 1.0, 0.0, {"air": true}),
			"a_c": _m("dive", 0.1, 0.4, 0.15, 10, 5, -6, 0.7, 1.1, 0.0, {"air": true, "down": true, "vy": -13.0}),
			"a_super": _m("dive", 0.12, 0.6, 0.2, 17, 9, 8, 0.3, 1.9, 0.0, {"air": true, "down": true, "vy": -20.0, "cost": AIR_SUPER_COST, "inv": true}),
			"aim_x": _m("jab_r", 0.1, 0.1, 0.22, 8, 8, 2, 1.1, 0.95, 5.0, {"down": true}),
			"aim_c": _m("kick", 0.28, 0.12, 0.3, 14, 11, 5, 1.2, 1.05, 6.0, {"down": true}),
			"g_flurry": _m("rush", 0.1, 0.48, 0.2, 3, 0.8, 0, 1.0, 1.0, 2.5, {"rehit": 0.09, "stun": 0.25}),
			"g_upper": _m("upper", 0.14, 0.1, 0.32, 15, 3, 13, 1.0, 1.0, 3.0, {"down": true}),
			"b_swing": _m("swing", 0.16, 0.1, 0.3, 12, 12, 3, 1.3, 1.5, 2.0, {"down": true}),
			"b_homer": _m("swing", 0.38, 0.12, 0.36, 21, 18, 9, 1.4, 1.5, 2.0, {"down": true}),
			"s_rush": _m("rush", 0.1, 0.6, 0.25, 4, 1.0, 0.5, 1.0, 1.2, 4.5, {"rehit": 0.1, "cost": SUPER_COST, "inv": true, "stun": 0.3}),
			"s_dash": _m("jab_r", 0.14, 0.3, 0.25, 22, 6, 8, 0.0, 1.4, 22.0, {"down": true, "cost": SUPER_COST, "inv": true, "dash": true}),
			"s_blast": _m("cast", 0.32, 0.15, 0.35, 22, 13, 8, 0.0, 3.6, 0.0, {"down": true, "cost": SUPER_COST, "inv": true}),
			"s_slam": _m("slam", 0.4, 0.15, 0.4, 27, 10, 12, 0.0, 4.2, 0.0, {"down": true, "cost": SUPER_COST, "inv": true}),
		}
	return _mv

## 이 선수가 쓰는 기술 (유형에 따라 빠르기·세기·덤이 달라진다)
static func move_for(f: Dictionary, id: String) -> Dictionary:
	var m: Dictionary = (moves()[id] as Dictionary).duplicate()
	var st: Dictionary = STYLES[f.style]
	m.id = id
	m.st = float(m.st) / float(st.aspd)
	m.rec = float(m.rec) / float(st.aspd)
	m.dmg = float(m.dmg) * float(st.power)
	if f.style == "psychic":
		# 염력사: 강공격과 장신구 Z+X에 염력탄이 덤으로 나간다
		if id == "c":
			m.shot = {"speed": 15.0, "dmg": 8.0, "kb": 7.0, "up": 3.0}
		elif id == ACCS[f.acc].zx:
			m.shot = {"speed": 13.0, "dmg": 5.0, "kb": 4.0, "up": 2.0}
	if f.style == "titan" and id == ACCS[f.acc].zc:
		m.wide = float(m.wide) + 0.3     # 장사: 장신구 강타가 더 넓다
	return m

static func new_fighter(id: int, style: String, acc: String, team: int, pos: Vector3) -> Dictionary:
	var st: Dictionary = STYLES[style]
	return {"id": id, "style": style, "acc": acc, "team": team, "pos": pos, "vel": Vector3.ZERO, "yaw": 0.0,
		"hp": float(st.hp), "max_hp": float(st.hp), "gauge": 0.0, "state": "free", "t": 0.0, "m": {}, "hit": [], "rehit_t": 0.0,
		"combo": 0, "combo_t": 0.0, "buf": false, "air": true, "jumps": int(st.jumps) - 1, "inv": 1.0, "stun": 0.0, "moving": false, "shot_done": false, "outs": 0, "aim": false}

static func fwd(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))

# ─────────── 무대 ───────────

## 옥상 무대: 발판 {x0, x1, z0, z1, h}
static func rooftop() -> Dictionary:
	return {"spawn": Vector3(0, 6, 0), "starts": [Vector3(-4, 0, 1.5), Vector3(4, 0, 1.5), Vector3(-1.5, 0, -1), Vector3(2, 0, 2.5), Vector3(-12, -1.6, 0), Vector3(11.5, 1.4, -0.5)],
		"plats": [
			{"x0": -7.8, "x1": 7.8, "z0": -4.0, "z1": 4.0, "h": 0.0},
			{"x0": -15.8, "x1": -7.8, "z0": -4.5, "z1": 2.5, "h": -1.6},
			{"x0": 7.8, "x1": 14.8, "z0": -5.0, "z1": 2.0, "h": 1.4},
			{"x0": -6.35, "x1": -2.65, "z0": -3.95, "z1": -0.85, "h": 2.5},
			{"x0": 10.55, "x1": 13.65, "z0": -4.75, "z1": -2.05, "h": 3.75},
			{"x0": 5.4, "x1": 6.2, "z0": 0.9, "z1": 2.3, "h": 0.35}, {"x0": 6.2, "x1": 7.0, "z0": 0.9, "z1": 2.3, "h": 0.7}, {"x0": 7.0, "x1": 7.8, "z0": 0.9, "z1": 2.3, "h": 1.05},
			{"x0": -10.2, "x1": -9.4, "z0": 1.1, "z1": 2.5, "h": -1.2}, {"x0": -9.4, "x1": -8.6, "z0": 1.1, "z1": 2.5, "h": -0.8}, {"x0": -8.6, "x1": -7.8, "z0": 1.1, "z1": 2.5, "h": -0.4},
		]}

## 그 자리에서 가장 높은 발판 높이 (없으면 -INF)
static func top_h(stage: Dictionary, x: float, z: float) -> float:
	var best := -INF
	for p in stage.plats:
		if x >= p.x0 and x <= p.x1 and z >= p.z0 and z <= p.z1:
			best = maxf(best, float(p.h))
	return best

## 발 높이 y 에서 설 수 있는 땅 (y보다 조금 높은 턱까지)
static func ground_h(stage: Dictionary, x: float, z: float, y: float) -> float:
	var best := -INF
	for p in stage.plats:
		if x >= p.x0 and x <= p.x1 and z >= p.z0 and z <= p.z1 and float(p.h) <= y + STEP_UP:
			best = maxf(best, float(p.h))
	return best

# ─────────── 한 프레임 ───────────

## inp = {mx, mz (-1..1), z, x, c (누르고 있음), xp, cp, vp (이번에 누름), aim_yaw (조준할 방향, 없으면 안 줌)}
## w = {stage, shots: [], events: []}
static func step(f: Dictionary, inp: Dictionary, w: Dictionary, dt: float) -> void:
	var st: Dictionary = STYLES[f.style]
	var stage: Dictionary = w.stage
	f.inv = maxf(0.0, float(f.inv) - dt)
	f.combo_t = maxf(0.0, float(f.combo_t) - dt)
	var vel: Vector3 = f.vel
	f.moving = false
	f.aim = false
	match str(f.state):
		"free":
			var mv := Vector2(float(inp.get("mx", 0.0)), float(inp.get("mz", 0.0))).limit_length(1.0)
			var aim: bool = inp.get("z", false) and inp.has("aim_yaw")
			f.aim = aim
			var spd: float = float(st.speed) * (0.55 if aim else 1.0)
			vel.x = mv.x * spd
			vel.z = mv.y * spd
			f.moving = mv.length() > 0.1
			if aim:
				f.yaw = float(inp.aim_yaw)
			elif f.moving:
				f.yaw = atan2(mv.x, mv.y)
			if inp.get("vp", false) and (not f.air or int(f.jumps) > 0):
				if f.air:
					f.jumps = int(f.jumps) - 1
				vel.y = float(st.jump)
				f.air = true
				w.events.append({"e": "jump", "id": f.id})
			var xp: bool = inp.get("xp", false)
			var cp: bool = inp.get("cp", false)
			var both: bool = (xp and inp.get("c", false)) or (cp and inp.get("x", false))
			var id := ""
			if f.air:
				if both and float(f.gauge) >= AIR_SUPER_COST: id = "a_super"
				elif xp: id = "a_x"
				elif cp: id = "a_c"
			elif inp.get("z", false):
				if both and float(f.gauge) >= SUPER_COST: id = str(st.super)
				elif xp: id = str(ACCS[f.acc].zx)
				elif cp: id = str(ACCS[f.acc].zc)
			elif xp:
				id = ["x1", "x2", "x3"][int(f.combo) % 3] if float(f.combo_t) > 0.0 else "x1"
			elif cp:
				id = "c"
			if id != "":
				if inp.get("face", false) and inp.has("aim_yaw"):
					f.yaw = float(inp.aim_yaw)
				f.vel = vel
				_start(f, id, w)
				vel = f.vel
		"atk":
			var m: Dictionary = f.m
			f.t = float(f.t) + dt
			var t: float = f.t
			if t < float(m.st) + float(m.act):
				if not m.air:
					var d := fwd(f.yaw) * (float(m.lunge) if not m.get("dash", false) or t >= float(m.st) else 0.0)
					vel.x = d.x
					vel.z = d.z
				if m.has("vy") and t >= float(m.st):
					vel.y = float(m.vy)
			elif not f.air:
				vel.x *= exp(-12.0 * dt)
				vel.z *= exp(-12.0 * dt)
			if float(m.rehit) > 0.0:
				f.rehit_t = float(f.rehit_t) - dt
				if float(f.rehit_t) <= 0.0:
					f.hit = []
					f.rehit_t = float(m.rehit)
			if m.has("shot") and not f.shot_done and t >= float(m.st):
				f.shot_done = true
				var s: Dictionary = m.shot
				w.shots.append({"pos": (f.pos as Vector3) + fwd(f.yaw) * 0.8 + Vector3(0, 0.9, 0), "vel": fwd(f.yaw) * float(s.speed), "dmg": float(s.dmg) * float(st.power),
					"kb": float(s.kb), "up": float(s.up), "owner": f.id, "team": f.team, "life": 1.3})
				w.events.append({"e": "shot", "id": f.id})
			if str(m.id) in ["x1", "x2"] and inp.get("xp", false) and t >= float(m.st):
				f.buf = true
			var total: float = float(m.st) + float(m.act) + float(m.rec)
			if f.buf and t >= float(m.st) + float(m.act) + float(m.rec) * 0.35:
				_start(f, "x2" if str(m.id) == "x1" else "x3", w)
			elif t >= total or (m.air and not f.air and t > float(m.st)):
				if str(m.id) in ["x1", "x2"]:
					f.combo = 1 if str(m.id) == "x1" else 2
					f.combo_t = 0.4
				f.state = "free"
				f.t = 0.0
		"hurt":
			f.t = float(f.t) + dt
			vel.x *= exp(-8.0 * dt)
			vel.z *= exp(-8.0 * dt)
			if float(f.t) >= float(f.stun):
				f.state = "free"
		"down":
			if f.air:
				vel.x *= exp(-1.2 * dt)
				vel.z *= exp(-1.2 * dt)
			else:
				f.t = float(f.t) + dt
				vel.x *= exp(-6.0 * dt)
				vel.z *= exp(-6.0 * dt)
				if float(f.hp) <= 0.0:
					f.state = "dead"
				elif float(f.t) > 0.7:
					f.state = "getup"
					f.t = 0.0
					f.inv = 0.9
		"getup":
			f.t = float(f.t) + dt
			vel.x = 0.0
			vel.z = 0.0
			if float(f.t) > 0.3:
				f.state = "free"
		"dead":
			vel.x *= exp(-6.0 * dt)
			vel.z *= exp(-6.0 * dt)
	# ── 움직임·땅
	var pos: Vector3 = f.pos
	var prev := pos
	pos.x += vel.x * dt
	if top_h(stage, pos.x, pos.z) > pos.y + STEP_UP:
		pos.x = prev.x
	pos.z += vel.z * dt
	if top_h(stage, pos.x, pos.z) > pos.y + STEP_UP:
		pos.z = prev.z
	vel.y -= GRAVITY * dt
	pos.y += vel.y * dt
	var g := ground_h(stage, pos.x, pos.z, prev.y)
	if pos.y <= g and vel.y <= 0.0:
		pos.y = g
		vel.y = 0.0
		if f.air:
			f.air = false
			w.events.append({"e": "land", "id": f.id})
		f.jumps = int(st.jumps) - 1
	elif pos.y > g + 0.05:
		if not f.air:
			f.jumps = int(st.jumps) - 1
		f.air = true
	f.pos = pos
	f.vel = vel
	# ── 떨어짐
	if pos.y < FALL_Y and str(f.state) != "out":
		f.outs = int(f.outs) + 1
		f.hp = float(f.hp) - float(f.max_hp) * FALL_LOSS
		w.events.append({"e": "fall", "id": f.id})
		if float(f.hp) <= 0.0:
			f.hp = 0.0
			f.state = "out"
			f.vel = Vector3.ZERO
		else:
			f.pos = stage.spawn
			f.vel = Vector3.ZERO
			f.state = "free"
			f.inv = 2.0
			f.air = true
	if str(f.state) == "out":
		f.pos = Vector3(0, -50, 0)
		f.vel = Vector3.ZERO

static func _start(f: Dictionary, id: String, w: Dictionary) -> void:
	var m := move_for(f, id)
	f.gauge = float(f.gauge) - float(m.cost)
	f.state = "atk"
	f.m = m
	f.t = 0.0
	f.hit = []
	f.rehit_t = float(m.rehit)
	f.buf = false
	f.shot_done = false
	f.combo_t = 0.0
	w.events.append({"e": "swing", "id": f.id, "super": int(m.cost) > 0})

static func alive(f: Dictionary) -> bool:
	return not (str(f.state) in ["dead", "out"])

static func _can_hit(a_team: int, a_id: int, b: Dictionary) -> bool:
	if int(b.id) == a_id or (a_team >= 0 and a_team == int(b.team)):
		return false
	if not alive(b) or float(b.inv) > 0.0 or str(b.state) == "getup":
		return false
	if str(b.state) == "atk" and b.m.get("inv", false):
		return false
	return true

## 맞았는지 확인하고 피해·날아가기를 준다
static func resolve(fs: Array, w: Dictionary, dt: float) -> void:
	for a in fs:
		if str(a.state) != "atk":
			continue
		var m: Dictionary = a.m
		var t: float = a.t
		if t < float(m.st) or t >= float(m.st) + float(m.act):
			continue
		var c: Vector3 = (a.pos as Vector3) + fwd(a.yaw) * float(m.reach)
		for b in fs:
			if not _can_hit(int(a.team), int(a.id), b) or int(b.id) in (a.hit as Array):
				continue
			var d: Vector3 = (b.pos as Vector3) - c
			if Vector2(d.x, d.z).length() > float(m.wide) or absf(d.y) > 1.6:
				continue
			(a.hit as Array).append(int(b.id))
			var dir := fwd(a.yaw)
			if float(m.reach) == 0.0:
				var r: Vector3 = (b.pos as Vector3) - (a.pos as Vector3)
				r.y = 0
				dir = r.normalized() if r.length() > 0.05 else dir
			_hurt(b, a, float(m.dmg), dir, float(m.kb), float(m.up), float(m.stun), bool(m.down), w)
	# 몸끼리 겹치지 않게 살짝 밀어낸다 (돌진 중에는 통과)
	for i in fs.size():
		for k in range(i + 1, fs.size()):
			var p: Dictionary = fs[i]
			var q: Dictionary = fs[k]
			if not alive(p) or not alive(q) or str(p.state) == "down" or str(q.state) == "down":
				continue
			if (str(p.state) == "atk" and p.m.get("dash", false)) or (str(q.state) == "atk" and q.m.get("dash", false)):
				continue
			var dd: Vector3 = (q.pos as Vector3) - (p.pos as Vector3)
			var hd := Vector2(dd.x, dd.z)
			var L := hd.length()
			if L < 0.75 and absf(dd.y) < 1.2:
				var n := hd / L if L > 0.01 else Vector2(1, 0)
				var push := (0.75 - L) * 0.5
				p.pos = (p.pos as Vector3) - Vector3(n.x, 0, n.y) * push
				q.pos = (q.pos as Vector3) + Vector3(n.x, 0, n.y) * push
	var keep := []
	for s in w.shots:
		s.pos = (s.pos as Vector3) + (s.vel as Vector3) * dt
		s.life = float(s.life) - dt
		var gone: bool = float(s.life) <= 0.0
		for b in fs:
			if gone or not _can_hit(int(s.team), int(s.owner), b):
				continue
			var d2: Vector3 = (b.pos as Vector3) + Vector3(0, 0.8, 0) - (s.pos as Vector3)
			if d2.length() < 0.95:
				var owner: Dictionary = {}
				for o in fs:
					if int(o.id) == int(s.owner):
						owner = o
				_hurt(b, owner, float(s.dmg), (s.vel as Vector3).normalized(), float(s.kb), float(s.up), 0.35, false, w)
				gone = true
		if not gone:
			keep.append(s)
	w.shots = keep

static func _hurt(b: Dictionary, a: Dictionary, dmg: float, dir: Vector3, kb: float, up: float, stun: float, down: bool, w: Dictionary) -> void:
	var real := dmg / float(STYLES[b.style].def)
	b.hp = maxf(0.0, float(b.hp) - real)
	if not a.is_empty():
		a.gauge = minf(100.0, float(a.gauge) + real * 1.2 * float(STYLES[a.style].gain))
	b.gauge = minf(100.0, float(b.gauge) + real * 0.6)
	var v := dir * kb * KNOCK
	v.y = up
	b.vel = v
	if down or b.air or float(b.hp) <= 0.0 or up > 5.0:
		b.state = "down"
		if up <= 0.0 and not b.air:
			b.vel.y = 3.0
		b.air = true
	else:
		b.state = "hurt"
	b.stun = stun
	b.t = 0.0
	b.m = {}
	w.events.append({"e": "hit", "pos": (b.pos as Vector3) + Vector3(0, 0.9, 0), "big": dmg >= 10.0, "id": b.id, "ko": float(b.hp) <= 0.0})

# ─────────── 컴퓨터 ───────────

## 가장 가까운 살아 있는 상대 (없으면 빈 값)
static func nearest(f: Dictionary, fs: Array) -> Dictionary:
	var best := {}
	var bd := INF
	for o in fs:
		if int(o.id) == int(f.id) or not alive(o) or (int(f.team) >= 0 and int(f.team) == int(o.team)):
			continue
		var d: float = (o.pos as Vector3).distance_to(f.pos)
		if d < bd:
			bd = d
			best = o
	return best

static func ai_input(f: Dictionary, fs: Array, stage: Dictionary, rnd: float, skill: float) -> Dictionary:
	var inp := {"mx": 0.0, "mz": 0.0}
	var tg := nearest(f, fs)
	var pos: Vector3 = f.pos
	var goal := Vector3(0, 0, 0)
	if not tg.is_empty():
		goal = tg.pos
	var d := goal - pos
	var flat := Vector2(d.x, d.z)
	var dist := flat.length()
	var dir := flat.normalized() if dist > 0.01 else Vector2.ZERO
	# 땅 없는 곳 위(떨어지는 중)면 가운데로
	if f.air and top_h(stage, pos.x, pos.z) == -INF:
		var home := Vector2(-pos.x, -pos.z).normalized()
		inp.mx = home.x
		inp.mz = home.y
		inp.vp = int(f.jumps) > 0 and float(f.vel.y) < 0.0
		return inp
	if dist > 1.15:
		var probe := pos + Vector3(dir.x, 0, dir.y) * 1.0
		var ahead := ground_h(stage, probe.x, probe.z, pos.y)
		if ahead == -INF and not f.air:
			# 앞이 낭떠러지거나 높은 턱: 턱이면 뛰고, 낭떠러지면 선다
			var far := pos + Vector3(dir.x, 0, dir.y) * 2.2
			if top_h(stage, probe.x, probe.z) > -INF or top_h(stage, far.x, far.z) > -INF:
				inp.vp = true
				inp.mx = dir.x
				inp.mz = dir.y
		else:
			inp.mx = dir.x
			inp.mz = dir.y
	if tg.is_empty():
		return inp
	inp.aim_yaw = atan2(d.x, d.z)
	inp.face = true
	var close := dist < 1.5 and absf(d.y) < 1.2
	if f.air:
		if dist < 1.6 and d.y < 0.5 and rnd < 0.2 * skill:
			inp.xp = true
	elif close:
		inp.z = rnd > 0.5
		if float(f.gauge) >= SUPER_COST and rnd < 0.06 * skill:
			inp.z = true; inp.x = true; inp.c = true; inp.xp = true
		elif rnd < 0.16 * skill:
			inp.xp = true
		elif rnd < 0.2 * skill:
			inp.cp = true
	elif f.style == "psychic" and dist < 9.0 and absf(d.y) < 1.0 and rnd < 0.03 * skill:
		inp.z = false
		inp.cp = true
		inp.mx = 0.0
		inp.mz = 0.0
	elif float(f.gauge) >= SUPER_COST and str(STYLES[f.style].super) in ["s_dash"] and dist < 5.0 and rnd < 0.03 * skill:
		inp.z = true; inp.x = true; inp.c = true; inp.xp = true
	return inp

## 끝났나: 살아 있는 편이 하나 이하. 이긴 선수 id (없으면 -1), 아직이면 -2
static func winner(fs: Array, time_left: float) -> int:
	var live := fs.filter(func(f): return alive(f))
	if live.size() == 1:
		return int(live[0].id)
	if live.is_empty():
		return -1
	if time_left <= 0.0:
		live.sort_custom(func(a, b): return float(a.hp) / float(a.max_hp) > float(b.hp) / float(b.max_hp))
		return int(live[0].id)
	return -2
