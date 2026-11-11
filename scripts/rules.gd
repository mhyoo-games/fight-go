class_name Rules
extends RefCounted
## 화면과 떨어진 싸움 규칙. 테스트: godot --headless -s tests/run_tests.gd
##
## 키: 방향키 걷기, 같은 방향 두 번 = 달리기 / Z 조준 / X 약 / C 강 / V 점프
##   X X X 연타 · Z+X, Z+C 장신구 기술(무기를 들면 무기 기술) · Z+X+C 필살기(게이지 50)
##   달리면서 X·C = 대시 공격, 달리면서 X+C = 대시 필살기(게이지 25)
##   X+C 같이 누르고 있기 = 막기 (앞에서 오는 공격만. 많이 막으면 깨진다. 뒤에서 맞으면 그냥 맞는다)
##   공중 X·C, 공중 X+C = 점프 필살기(게이지 30) · 떨어진 무기 옆에서 X나 C = 줍기
## 누운 상대는 못 때린다. 공중에 뜬 상대는 이어 때릴 수 있다(JUG_MAX번까지).

const GRAVITY := 30.0
const STEP_UP := 0.55
const FALL_Y := -14.0
const KNOCK := 0.55
const FALL_LOSS := 0.25
const SUPER_COST := 50
const AIR_SUPER_COST := 30
const DASH_SUPER_COST := 25
const RUN_MULT := 1.65
const JUG_MAX := 5
const JUG_SCALE := 0.85
const BLOCK_CHIP := 0.12        # 막으면 이만큼만 아프다
const BLOCK_REGEN := 14.0       # 막기 힘이 1초에 돌아오는 양
const BREAK_STUN := 1.0         # 막기가 깨지면 이만큼 멍해진다
const GUARD_CANCEL := 0.07      # X와 C를 거의 같이 누르면 공격 대신 막기

## 유형: 다섯 능력치(1~10) STR 힘 · TEC 조준 거리 · SPD 빠르기 · JMP 점프 · DEF 맷집
const STYLES := {
	"brawler": {"name": "주먹꾼", "about": "고루 갖춘 싸움꾼. 때릴수록 게이지가 빨리 차요. 필살기: 연속 주먹", "p": [6, 5, 6, 5, 6], "aspd": 1.0, "jumps": 1, "gain": 1.35, "super": "s_rush"},
	"agent": {"name": "요원", "about": "빠르고 두 번 뛰어요. 몸은 약해요. 필살기: 번개 돌진", "p": [4, 7, 8, 7, 3], "aspd": 1.25, "jumps": 2, "gain": 1.0, "super": "s_dash"},
	"psychic": {"name": "염력사", "about": "강공격이 멀리 날아가는 염력탄. 가까이 붙으면 약해요. 필살기: 염력 폭발", "p": [5, 9, 5, 6, 3], "aspd": 1.0, "jumps": 1, "gain": 1.0, "super": "s_blast"},
	"titan": {"name": "장사", "about": "느리지만 세고 튼튼해요. 필살기: 땅 울리기", "p": [8, 3, 3, 4, 8], "aspd": 0.8, "jumps": 1, "gain": 0.85, "super": "s_slam"},
}
const STYLE_IDS := ["brawler", "agent", "psychic", "titan"]
const PARAMS := ["STR", "TEC", "SPD", "JMP", "DEF"]

## 장신구: 상점에서 사서 하나를 낀다. Z+X·Z+C 기술과 능력치가 바뀐다 (mod = 능력치 더하기)
const ACCS := {
	"none": {"name": "맨손", "price": 0, "about": "Z+X 조준 지르기 · Z+C 조준 차기", "zx": "aim_x", "zc": "aim_c", "mod": [0, 0, 0, 0, 0]},
	"gloves": {"name": "권투 장갑", "price": 300, "about": "Z+X 소나기 주먹 · Z+C 올려치기 (띄우기)", "zx": "g_flurry", "zc": "g_upper", "mod": [1, 0, 0, 0, 0]},
	"flame": {"name": "불꽃 팔찌", "price": 900, "about": "Z+X 불주먹 돌진 · Z+C 불기둥 (높이 띄움)", "zx": "f_dash", "zc": "f_pillar", "mod": [1, 0, 0, 0, -1]},
	"claws": {"name": "늑대 발톱", "price": 900, "about": "Z+X 세 번 할퀴기 · Z+C 뛰어 베기", "zx": "c_slash", "zc": "c_leap", "mod": [0, 0, 1, 0, -1]},
	"boots": {"name": "번개 장화", "price": 1400, "about": "Z+X 번개 날아차기 · Z+C 내려찍기 충격파", "zx": "b_kick", "zc": "b_stomp", "mod": [-1, 0, 1, 1, 0]},
	"wand": {"name": "얼음 지팡이", "price": 1400, "about": "Z+X 얼음 조각 쏘기 · Z+C 얼음 터뜨리기 (잠깐 얼림)", "zx": "i_shard", "zc": "i_burst", "mod": [-1, 2, 0, 0, 0]},
	"wings": {"name": "바람 날개", "price": 2000, "about": "한 번 더 뛸 수 있어요. Z+X 돌풍 · Z+C 솟구치기", "zx": "w_gust", "zc": "w_rise", "mod": [0, 0, 0, 2, -1], "jumps": 1},
}
const ACC_IDS := ["none", "gloves", "flame", "claws", "boots", "wand", "wings"]

## 줍는 무기: uses = 쓸 수 있는 횟수(총알)
const WEAPONS := {
	"bat": {"name": "방망이", "uses": 12, "x": "wb_x", "c": "wb_c", "zx": "w_throw", "zc": "wb_zc", "air_x": "a_x"},
	"rifle": {"name": "소총", "uses": 8, "x": "wr_x", "c": "w_butt", "zx": "wr_zx", "zc": "w_throw", "air_x": "wr_x"},
	"bazooka": {"name": "바주카", "uses": 3, "x": "wz_x", "c": "w_butt", "zx": "wz_x", "zc": "w_throw", "air_x": "wz_ride"},
}
const WEAPON_IDS := ["bat", "rifle", "bazooka"]

static var _mv := {}

static func _m(pose: String, st: float, act: float, rec: float, dmg: float, kb: float, up: float, reach := 1.0, wide := 0.95, lunge := 0.0, extra := {}) -> Dictionary:
	var d := {"pose": pose, "st": st, "act": act, "rec": rec, "dmg": dmg, "kb": kb, "up": up, "reach": reach, "wide": wide, "lunge": lunge,
		"stun": 0.38, "down": false, "rehit": 0.0, "air": false, "cost": 0, "inv": false, "use": 0}
	d.merge(extra, true)
	return d

## 기술 표: st 준비, act 맞는 시간, rec 빈틈, dmg 피해, kb 밀기, up 띄우기, reach 앞 거리, wide 반지름, lunge 나가는 빠르기
## 덤: rehit 연타 간격, shot 날아가는 것, dash 상대를 지나감, fly 공중에서도 나감, use 무기 횟수 씀, vy 위아래 속도
static func moves() -> Dictionary:
	if _mv.is_empty():
		var S := SUPER_COST
		_mv = {
			"x1": _m("jab_r", 0.07, 0.08, 0.15, 4, 1.2, 0, 1.05, 0.95, 2.5),
			"x2": _m("jab_l", 0.07, 0.08, 0.15, 4, 1.2, 0, 1.05, 0.95, 2.5),
			"x3": _m("kick", 0.1, 0.1, 0.26, 7, 7, 4.5, 1.15, 1.0, 3.0, {"down": true}),
			"c": _m("upper", 0.18, 0.1, 0.24, 10, 2.0, 10.0, 1.05, 1.0, 2.0, {"down": true}),
			"a_x": _m("airkick", 0.05, 0.3, 0.1, 6, 5, 2, 0.9, 1.0, 0.0, {"air": true}),
			"a_c": _m("dive", 0.1, 0.4, 0.15, 10, 5, -6, 0.7, 1.1, 0.0, {"air": true, "down": true, "vy": -13.0}),
			"a_super": _m("dive", 0.12, 0.6, 0.2, 17, 9, 8, 0.3, 1.9, 0.0, {"air": true, "down": true, "vy": -20.0, "cost": AIR_SUPER_COST, "inv": true}),
			"d_x": _m("slide", 0.06, 0.25, 0.24, 7, 4, 5.5, 0.6, 1.0, 11.0, {"down": true}),
			"d_c": _m("knee", 0.1, 0.2, 0.24, 10, 2.5, 10, 0.7, 1.0, 9.0, {"down": true}),
			"d_super": _m("charge", 0.1, 0.35, 0.3, 16, 12, 7, 0.6, 1.3, 15.0, {"down": true, "cost": DASH_SUPER_COST, "inv": true}),
			"aim_x": _m("jab_r", 0.1, 0.1, 0.22, 8, 8, 2, 1.1, 0.95, 5.0, {"down": true}),
			"aim_c": _m("kick", 0.28, 0.12, 0.3, 14, 11, 5, 1.2, 1.05, 6.0, {"down": true}),
			"g_flurry": _m("rush", 0.1, 0.48, 0.2, 3, 0.8, 0, 1.0, 1.0, 2.5, {"rehit": 0.09, "stun": 0.25}),
			"g_upper": _m("upper", 0.14, 0.1, 0.32, 14, 2, 13.5, 1.0, 1.0, 3.0, {"down": true}),
			"f_dash": _m("jab_r", 0.14, 0.22, 0.28, 12, 8, 5, 0.3, 1.2, 14.0, {"down": true, "dash": true, "fx": "fire"}),
			"f_pillar": _m("cast", 0.26, 0.2, 0.34, 13, 1, 14, 1.7, 1.3, 0.0, {"down": true, "fx": "fire"}),
			"c_slash": _m("rush", 0.08, 0.36, 0.2, 5, 1.2, 0, 1.1, 1.1, 4.0, {"rehit": 0.12, "stun": 0.3}),
			"c_leap": _m("dive", 0.1, 0.3, 0.3, 13, 7, 6, 0.8, 1.2, 9.0, {"down": true, "hop": 7.0}),
			"b_kick": _m("airkick", 0.12, 0.25, 0.3, 11, 9, 5, 0.6, 1.1, 16.0, {"down": true, "fx": "bolt"}),
			"b_stomp": _m("slam", 0.3, 0.14, 0.36, 12, 5, 10, 0.0, 2.6, 0.0, {"down": true, "fx": "bolt"}),
			"i_shard": _m("cast", 0.2, 0.08, 0.3, 0, 0, 0, 0.0, 0.0, 0.0, {"shot": {"speed": 17.0, "dmg": 9.0, "kb": 6.0, "up": 2.0, "kind": "ice"}}),
			"i_burst": _m("slam", 0.28, 0.14, 0.36, 12, 0.5, 0, 0.0, 2.4, 0.0, {"stun": 1.1, "fx": "ice"}),
			"w_gust": _m("cast", 0.16, 0.08, 0.3, 0, 0, 0, 0.0, 0.0, 0.0, {"shot": {"speed": 13.0, "dmg": 6.0, "kb": 15.0, "up": 4.0, "kind": "wind", "big": 1.5}}),
			"w_rise": _m("upper", 0.1, 0.3, 0.3, 10, 1.5, 13, 0.4, 1.3, 2.0, {"down": true, "hop": 11.0}),
			"s_rush": _m("rush", 0.1, 0.6, 0.2, 5, 1.0, 0.5, 1.0, 1.2, 4.5, {"rehit": 0.1, "cost": S, "inv": true, "stun": 0.3}),
			"s_dash": _m("jab_r", 0.14, 0.3, 0.25, 25, 6, 8, 0.0, 1.6, 22.0, {"down": true, "cost": S, "inv": true, "dash": true, "fx": "bolt"}),
			"s_blast": _m("cast", 0.32, 0.15, 0.35, 21, 13, 8, 0.0, 3.3, 0.0, {"down": true, "cost": S, "inv": true, "fx": "psy"}),
			"s_slam": _m("slam", 0.4, 0.15, 0.45, 20, 10, 11, 0.0, 3.0, 0.0, {"down": true, "cost": S, "inv": true, "fx": "quake"}),
			# 줍는 무기
			"wb_x": _m("swing", 0.12, 0.1, 0.22, 9, 7, 3, 1.4, 1.4, 2.0, {"use": 1}),
			"wb_c": _m("slam", 0.24, 0.12, 0.3, 14, 4, 10, 1.3, 1.3, 2.0, {"down": true, "use": 1}),
			"wb_zc": _m("swing", 0.34, 0.12, 0.36, 20, 20, 9, 1.5, 1.5, 3.0, {"down": true, "use": 2}),
			"w_butt": _m("jab_r", 0.14, 0.1, 0.26, 8, 6, 3, 1.2, 1.0, 2.0, {"down": true}),
			"w_throw": _m("swing", 0.16, 0.08, 0.3, 0, 0, 0, 0.0, 0.0, 0.0, {"throw": true, "shot": {"speed": 15.0, "dmg": 11.0, "kb": 9.0, "up": 4.0, "kind": "thrown"}}),
			"wr_x": _m("shoot", 0.1, 0.06, 0.22, 0, 0, 0, 0.0, 0.0, 0.0, {"use": 1, "shot": {"speed": 30.0, "dmg": 7.0, "kb": 4.0, "up": 1.0, "kind": "bullet"}}),
			"wr_zx": _m("shoot", 0.3, 0.06, 0.34, 0, 0, 0, 0.0, 0.0, 0.0, {"use": 2, "shot": {"speed": 34.0, "dmg": 15.0, "kb": 11.0, "up": 4.0, "kind": "bullet", "big": 1.2}}),
			"wz_x": _m("shoot", 0.3, 0.08, 0.5, 0, 0, 0, 0.0, 0.0, 0.0, {"use": 1, "shot": {"speed": 16.0, "dmg": 18.0, "kb": 12.0, "up": 9.0, "kind": "rocket", "boom": 2.6}}),
			"wz_ride": _m("ride", 0.1, 0.7, 0.3, 14, 10, 9, 0.5, 1.5, 15.0, {"use": 1, "air": true, "fly": true, "vy": 1.5, "down": true, "dash": true, "fx": "boom"}),
		}
	return _mv

## 능력치(1~10)를 실제 값으로. 장신구의 mod를 더한다
static func derive(style: String, acc: String) -> Dictionary:
	var s: Dictionary = STYLES[style]
	var a: Dictionary = ACCS[acc]
	var p := []
	for i in 5:
		p.append(clampi(int(s.p[i]) + int(a.mod[i]), 1, 10))
	return {"p": p, "power": 0.84 + 0.03 * p[0], "aim": 3.5 + 0.9 * p[1], "speed": 4.3 + 0.3 * p[2], "jump": 8.8 + 0.28 * p[3], "def": 0.88 + 0.02 * p[4],
		"hp": 200.0 + 1.0 * p[4], "guard": 26.0 + 4.0 * p[4], "aspd": float(s.aspd), "jumps": int(s.jumps) + int(a.get("jumps", 0)), "gain": float(s.gain), "super": str(s.super)}

static func move_for(f: Dictionary, id: String) -> Dictionary:
	var m: Dictionary = (moves()[id] as Dictionary).duplicate(true)
	var S: Dictionary = f.S
	m.id = id
	m.st = float(m.st) / float(S.aspd)
	m.rec = float(m.rec) / float(S.aspd)
	m.dmg = float(m.dmg) * float(S.power)
	var acc_move: bool = id == str(ACCS[f.acc].zx) or id == str(ACCS[f.acc].zc)
	if f.style == "psychic":
		# 염력사: 강공격과 장신구 Z+X에 염력탄이 덤
		if id == "c":
			m.shot = {"speed": 15.0, "dmg": 8.0, "kb": 7.0, "up": 3.0, "kind": "psy"}
		elif id == str(ACCS[f.acc].zx) and not m.has("shot"):
			m.shot = {"speed": 13.0, "dmg": 5.0, "kb": 4.0, "up": 2.0, "kind": "psy"}
	if f.style == "titan" and acc_move and float(m.wide) > 0.0:
		m.wide = float(m.wide) + 0.3
	return m

static func new_fighter(id: int, style: String, acc: String, team: int, pos: Vector3) -> Dictionary:
	var S := derive(style, acc)
	return {"id": id, "style": style, "acc": acc, "S": S, "team": team, "pos": pos, "vel": Vector3.ZERO, "yaw": 0.0,
		"hp": float(S.hp), "max_hp": float(S.hp), "gauge": 0.0, "state": "free", "t": 0.0, "m": {}, "hit": [], "rehit_t": 0.0,
		"combo": 0, "combo_t": 0.0, "buf": false, "air": true, "jumps": int(S.jumps) - 1, "inv": 1.0, "stun": 0.0, "moving": false, "run": false,
		"shot_done": false, "outs": 0, "aim": false, "jug": 0, "held": "", "uses": 0, "door_cd": 0.0, "dealt": 0.0, "kos": 0, "hits": 0, "guard": float(S.guard), "blocks": 0}

static func fwd(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))

# ─────────── 무대 ───────────

static func _p(x0: float, x1: float, z0: float, z1: float, h: float, kind := "roof", base := -40.0) -> Dictionary:
	return {"x0": x0, "x1": x1, "z0": z0, "z1": z1, "h": h, "kind": kind, "base": base}

## 옥상 마을: 큰 옥상(A), 왼쪽 낮은 옥상(B), 오른쪽 높은 옥상(C), 건너편 옥상(D, 널빤지 다리), 문으로 들어가는 창고(R)
## kind: roof 옥상(아래 건물) · step 계단 · box 상자·옥탑(막힘) · plank 널빤지 · room 실내 바닥 · wall 안 보이는 벽
static func city() -> Dictionary:
	var pl := [
		_p(-15, 15, -7, 7, 0.0), _p(-29, -15, -6, 6, -2.0), _p(15, 27, -7, 5, 2.0), _p(31, 41, -5, 5, 1.6),
		_p(27, 31, -0.8, 0.8, 1.8, "plank", 1.65),
		_p(-16, -15, 3, 5, -0.5, "step", -2.0), _p(-17, -16, 3, 5, -1.0, "step", -2.0), _p(-18, -17, 3, 5, -1.5, "step", -2.0),
		_p(14, 15, 3, 5, 1.5, "step", 0.0), _p(13, 14, 3, 5, 1.0, "step", 0.0), _p(12, 13, 3, 5, 0.5, "step", 0.0),
		_p(-13, -9, -6.6, -3.6, 2.6, "hut", 0.0), _p(21, 25, -6.6, -3.6, 4.6, "hut", 2.0),
		_p(4, 6, -5.5, -3.5, 1.0, "box", 0.0), _p(5, 6, -5.5, -4.5, 2.0, "box", 1.0), _p(-24, -22, -4, -2, -1.0, "box", -2.0), _p(34, 36, 2, 4, 2.6, "box", 1.6),
		# 창고 (멀리 떨어진 실내)
		_p(60, 82, -6, 6, 0.0, "room", -1.0),
		_p(59, 60, -7, 7, 5.0, "wall", 0.0), _p(82, 83, -7, 7, 5.0, "wall", 0.0), _p(59, 83, -7, -6, 5.0, "wall", 0.0), _p(59, 83, 6, 7, 5.0, "wall", 0.0),
		_p(66, 68, -5.6, -3.6, 1.0, "box", 0.0), _p(67, 68, -5.6, -4.6, 2.0, "box", 1.0), _p(72, 76, 1.5, 3.0, 1.2, "box", 0.0), _p(78.5, 80.5, 3, 5, 1.0, "box", 0.0),
	]
	return {"plats": pl, "spawn": Vector3(0, 7, 0),
		"starts": [Vector3(-5, 0, 2), Vector3(5, 0, 2), Vector3(-1, 0, -3), Vector3(9, 0, -1), Vector3(-21, -2, 0), Vector3(20, 2, 0)],
		# 문: at = 문 앞 자리(여기서 ↑로 들어감), 짝끼리 오간다
		"doors": [{"at": Vector3(-11, 0, -3.1), "to": 1}, {"at": Vector3(63, 0, -5.4), "to": 0}, {"at": Vector3(23, 2, -3.1), "to": 3}, {"at": Vector3(79, 0, -5.4), "to": 2}],
		"items": [Vector3(0, 0, -5), Vector3(-8, 0, 4), Vector3(10, 0, -5), Vector3(-25, -2, 3), Vector3(-20, -2, -4), Vector3(18, 2, -4), Vector3(24, 2, 2), Vector3(37, 1.6, -2),
			Vector3(63, 0, 2), Vector3(70, 0, -2), Vector3(77, 0, -3), Vector3(71, 0, 4.5)],
		# 컴퓨터가 높은 곳에 오를 때 쓰는 길: 아래 → 위
		"ramps": [{"a": Vector3(-19, -2, 4), "b": Vector3(-14, 0, 4)}, {"a": Vector3(11, 0, 4), "b": Vector3(16, 2, 4)}]}

static func zone(pos: Vector3) -> int:
	return 1 if pos.x > 50.0 else 0

static func top_h(stage: Dictionary, x: float, z: float) -> float:
	var best := -INF
	for p in stage.plats:
		if x >= p.x0 and x <= p.x1 and z >= p.z0 and z <= p.z1:
			best = maxf(best, float(p.h))
	return best

static func ground_h(stage: Dictionary, x: float, z: float, y: float) -> float:
	var best := -INF
	for p in stage.plats:
		if x >= p.x0 and x <= p.x1 and z >= p.z0 and z <= p.z1 and float(p.h) <= y + STEP_UP:
			best = maxf(best, float(p.h))
	return best

# ─────────── 한 프레임 ───────────

## inp = {mx, mz, run (달리기 중), z, x, c (누르고 있음), xp, cp, vp (이번에 누름), aim_yaw, face}
## w = {stage, shots: [], items: [], events: []}
static func step(f: Dictionary, inp: Dictionary, w: Dictionary, dt: float) -> void:
	var S: Dictionary = f.S
	var stage: Dictionary = w.stage
	f.inv = maxf(0.0, float(f.inv) - dt)
	f.combo_t = maxf(0.0, float(f.combo_t) - dt)
	f.door_cd = maxf(0.0, float(f.door_cd) - dt)
	var vel: Vector3 = f.vel
	f.moving = false
	f.aim = false
	var holding: bool = inp.get("x", false) and inp.get("c", false) and not inp.get("z", false)
	if str(f.state) != "guard":
		f.guard = minf(float(S.guard), float(f.guard) + BLOCK_REGEN * dt)
	# X를 누른 바로 뒤에 C가 따라 눌리면(또는 반대로) 공격을 접고 막는다
	if str(f.state) == "atk" and holding and not f.air and float(f.t) < GUARD_CANCEL and str(f.m.id) in ["x1", "c", "wb_x", "wb_c", "wr_x", "wz_x", "w_butt"]:
		if int(f.m.use) > 0:
			f.uses = int(f.uses) + int(f.m.use)
			f.held_gone = false
		f.state = "guard"
		f.t = 0.0
	match str(f.state):
		"guard":
			f.t = float(f.t) + dt
			vel.x *= exp(-14.0 * dt)
			vel.z *= exp(-14.0 * dt)
			if inp.has("aim_yaw") and inp.get("face", false):
				f.yaw = float(inp.aim_yaw)
			if (not holding and float(f.t) > 0.12) or f.air:
				f.state = "free"
		"free":
			var mv := Vector2(float(inp.get("mx", 0.0)), float(inp.get("mz", 0.0))).limit_length(1.0)
			var aim: bool = inp.get("z", false) and inp.has("aim_yaw")
			f.aim = aim
			f.moving = mv.length() > 0.1
			f.run = f.moving and not aim and inp.get("run", false) and (not f.air or f.run)
			var spd: float = float(S.speed) * (0.55 if aim else (RUN_MULT if f.run else 1.0))
			vel.x = mv.x * spd
			vel.z = mv.y * spd
			if aim:
				f.yaw = float(inp.aim_yaw)
			elif f.moving:
				f.yaw = atan2(mv.x, mv.y)
			# 문: 문 앞에서 ↑
			if not f.air and float(f.door_cd) <= 0.0 and mv.y < -0.5:
				var doors: Array = stage.get("doors", [])
				for d in doors:
					if (d.at as Vector3).distance_to(f.pos) < 1.0:
						var o: Dictionary = doors[int(d.to)]
						f.pos = (o.at as Vector3) + Vector3(0, 0.05, 0.5)
						f.door_cd = 1.2
						f.yaw = 0.0
						vel = Vector3.ZERO
						w.events.append({"e": "door", "id": f.id})
						break
			if inp.get("vp", false) and (not f.air or int(f.jumps) > 0):
				if f.air:
					f.jumps = int(f.jumps) - 1
				vel.y = float(S.jump)
				f.air = true
				w.events.append({"e": "jump", "id": f.id})
			var xp: bool = inp.get("xp", false)
			var cp: bool = inp.get("cp", false)
			var both: bool = (xp and inp.get("c", false)) or (cp and inp.get("x", false))
			var id := ""
			var wp: Dictionary = WEAPONS.get(str(f.held), {})
			if holding and not f.air and not f.run:
				f.state = "guard"
				f.t = 0.0
				vel.x = 0.0
				vel.z = 0.0
			elif (xp or cp) and not f.air and wp.is_empty() and _pickup(f, w):
				pass
			elif f.air:
				if both and float(f.gauge) >= AIR_SUPER_COST: id = "a_super"
				elif xp: id = str(wp.get("air_x", "a_x"))
				elif cp: id = "a_c"
			elif inp.get("z", false):
				if both and float(f.gauge) >= SUPER_COST: id = str(S.super)
				elif xp: id = str(wp.get("zx", ACCS[f.acc].zx))
				elif cp: id = str(wp.get("zc", ACCS[f.acc].zc))
			elif f.run:
				if both and float(f.gauge) >= DASH_SUPER_COST: id = "d_super"
				elif xp: id = "d_x"
				elif cp: id = "d_c"
			elif xp:
				if not wp.is_empty(): id = str(wp.x)
				else: id = ["x1", "x2", "x3"][int(f.combo) % 3] if float(f.combo_t) > 0.0 else "x1"
			elif cp:
				id = str(wp.get("c", "c"))
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
				if not m.air or m.get("fly", false):
					var d2 := fwd(f.yaw) * (float(m.lunge) if not m.get("dash", false) or t >= float(m.st) else 0.0)
					vel.x = d2.x
					vel.z = d2.z
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
				var kind := str(s.get("kind", "psy"))
				if m.get("throw", false):
					kind = str(f.held)
					f.held = ""
				w.shots.append({"pos": (f.pos as Vector3) + fwd(f.yaw) * 0.9 + Vector3(0, 1.0, 0), "vel": fwd(f.yaw) * float(s.speed), "dmg": float(s.dmg) * float(S.power),
					"kb": float(s.kb), "up": float(s.up), "owner": f.id, "team": f.team, "life": 1.6, "kind": kind, "boom": float(s.get("boom", 0.0)), "big": float(s.get("big", 1.0))})
				w.events.append({"e": "shot", "id": f.id, "kind": kind})
			if str(m.id) in ["x1", "x2"] and inp.get("xp", false) and t >= float(m.st):
				f.buf = true
			var total: float = float(m.st) + float(m.act) + float(m.rec)
			if f.buf and t >= float(m.st) + float(m.act) + float(m.rec) * 0.35:
				_start(f, "x2" if str(m.id) == "x1" else "x3", w)
			elif t >= total or (m.air and not f.air and t > float(m.st) and not m.get("fly", false)):
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
				elif float(f.t) > 0.65:
					f.state = "getup"
					f.t = 0.0
					f.inv = 0.9
					f.jug = 0
		"getup":
			f.t = float(f.t) + dt
			vel.x = 0.0
			vel.z = 0.0
			if float(f.t) > 0.3:
				f.state = "free"
		"dead":
			vel.x *= exp(-6.0 * dt)
			vel.z *= exp(-6.0 * dt)
	if str(f.state) != "free":
		f.run = false
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
			w.events.append({"e": "land", "id": f.id, "hard": str(f.state) == "down"})
		f.jumps = int(S.jumps) - 1
	elif pos.y > g + 0.05:
		if not f.air:
			f.jumps = int(S.jumps) - 1
		f.air = true
	f.pos = pos
	f.vel = vel
	# ── 떨어짐
	if pos.y < FALL_Y and str(f.state) != "out":
		f.outs = int(f.outs) + 1
		f.hp = float(f.hp) - float(f.max_hp) * FALL_LOSS
		f.held = ""
		w.events.append({"e": "fall", "id": f.id})
		if float(f.hp) <= 0.0:
			f.hp = 0.0
			f.state = "out"
		else:
			f.pos = stage.spawn
			f.state = "free"
			f.inv = 2.0
			f.air = true
			f.jug = 0
		f.vel = Vector3.ZERO
	if str(f.state) == "out":
		f.pos = Vector3(0, -60, 0)
		f.vel = Vector3.ZERO

## 가까운 무기 줍기
static func _pickup(f: Dictionary, w: Dictionary) -> bool:
	var items: Array = w.get("items", [])
	for i in items.size():
		var it: Dictionary = items[i]
		if (it.pos as Vector3).distance_to(f.pos) < 1.2:
			f.held = str(it.kind)
			f.uses = int(it.uses)
			items.remove_at(i)
			w.events.append({"e": "pickup", "id": f.id})
			return true
	return false

static func _start(f: Dictionary, id: String, w: Dictionary) -> void:
	var m := move_for(f, id)
	f.gauge = float(f.gauge) - float(m.cost)
	if int(m.use) > 0:
		f.uses = int(f.uses) - int(m.use)
	f.state = "atk"
	f.m = m
	f.t = 0.0
	f.hit = []
	f.rehit_t = float(m.rehit)
	f.buf = false
	f.shot_done = false
	f.combo_t = 0.0
	f.run = false
	if m.has("hop"):
		f.vel.y = float(m.hop)
		f.air = true
	w.events.append({"e": "swing", "id": f.id, "super": int(m.cost) > 0, "fx": str(m.get("fx", ""))})
	if str(f.held) != "" and int(f.uses) <= 0 and not m.get("throw", false):
		f.held_gone = true

static func alive(f: Dictionary) -> bool:
	return not (str(f.state) in ["dead", "out"])

static func _can_hit(a_team: int, a_id: int, b: Dictionary) -> bool:
	if int(b.id) == a_id or (a_team >= 0 and a_team == int(b.team)):
		return false
	if not alive(b) or float(b.inv) > 0.0 or str(b.state) == "getup":
		return false
	if str(b.state) == "down" and (not b.air or int(b.jug) >= JUG_MAX):
		return false      # 누운 상대·너무 많이 맞은 공중 상대는 못 때린다
	if str(b.state) == "atk" and b.m.get("inv", false):
		return false
	return true

static func resolve(fs: Array, w: Dictionary, dt: float) -> void:
	for a in fs:
		# 다 쓴 무기는 기술이 끝나면 사라진다
		if a.get("held_gone", false) and str(a.state) != "atk":
			a.held = ""
			a.held_gone = false
		if str(a.state) != "atk":
			continue
		var m: Dictionary = a.m
		var t: float = a.t
		if t < float(m.st) or t >= float(m.st) + float(m.act) or float(m.wide) <= 0.0:
			continue
		var c: Vector3 = (a.pos as Vector3) + fwd(a.yaw) * float(m.reach)
		for b in fs:
			if not _can_hit(int(a.team), int(a.id), b) or int(b.id) in (a.hit as Array):
				continue
			var d: Vector3 = (b.pos as Vector3) - c
			if Vector2(d.x, d.z).length() > float(m.wide) or d.y > 2.0 or d.y < -1.3:
				continue
			(a.hit as Array).append(int(b.id))
			var dir := fwd(a.yaw)
			if float(m.reach) == 0.0 and not m.get("dash", false):
				var r: Vector3 = (b.pos as Vector3) - (a.pos as Vector3)
				r.y = 0
				dir = r.normalized() if r.length() > 0.05 else dir
			_hurt(b, a, float(m.dmg), dir, float(m.kb), float(m.up), float(m.stun), bool(m.down), w)
	# 몸끼리 겹치지 않게
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
	# 날아가는 것
	var keep := []
	for s in w.shots:
		s.pos = (s.pos as Vector3) + (s.vel as Vector3) * dt
		s.life = float(s.life) - dt
		var sp: Vector3 = s.pos
		var gone: bool = float(s.life) <= 0.0 or top_h(w.stage, sp.x, sp.z) > sp.y
		var owner: Dictionary = {}
		for o in fs:
			if int(o.id) == int(s.owner):
				owner = o
		for b in fs:
			if gone or not _can_hit(int(s.team), int(s.owner), b):
				continue
			var d3: Vector3 = (b.pos as Vector3) + Vector3(0, 0.9, 0) - sp
			if d3.length() < 0.95 * float(s.big):
				if float(s.boom) <= 0.0:
					_hurt(b, owner, float(s.dmg), (s.vel as Vector3).normalized(), float(s.kb), float(s.up), 0.38, false, w)
				gone = true
		if gone and float(s.boom) > 0.0:
			w.events.append({"e": "boom", "pos": sp, "r": float(s.boom)})
			for b in fs:
				if _can_hit(int(s.team), int(s.owner), b):
					var r2: Vector3 = (b.pos as Vector3) + Vector3(0, 0.9, 0) - sp
					if r2.length() < float(s.boom):
						r2.y = 0
						_hurt(b, owner, float(s.dmg), r2.normalized() if r2.length() > 0.05 else Vector3(1, 0, 0), float(s.kb), float(s.up), 0.38, true, w)
		if not gone:
			keep.append(s)
		elif str(s.kind) in WEAPON_IDS:
			pass   # 던진 무기는 부서진다
	w.shots = keep

static func _hurt(b: Dictionary, a: Dictionary, dmg: float, dir: Vector3, kb: float, up: float, stun: float, down: bool, w: Dictionary) -> void:
	# 막기: 앞에서 온 공격이면 조금만 아프고 밀리기만 한다. 막기 힘이 다하면 깨진다
	if str(b.state) == "guard" and dir.dot(fwd(b.yaw)) < -0.2:
		b.guard = float(b.guard) - dmg
		b.hp = maxf(1.0, float(b.hp) - dmg * BLOCK_CHIP / float(b.S.def))
		b.blocks = int(b.blocks) + 1
		b.vel = dir * minf(kb, 6.0) * 0.5
		if not a.is_empty():
			a.gauge = minf(100.0, float(a.gauge) + dmg * 0.4 * float(a.S.gain))
		b.gauge = minf(100.0, float(b.gauge) + dmg * 0.5)
		var broke: bool = float(b.guard) <= 0.0
		if broke:
			b.state = "hurt"
			b.stun = BREAK_STUN
			b.t = 0.0
			b.guard = float(b.S.guard) * 0.5
		w.events.append({"e": "block", "pos": (b.pos as Vector3) + fwd(b.yaw) * 0.4 + Vector3(0, 1.0, 0), "id": b.id, "broke": broke})
		return
	var juggle: bool = str(b.state) == "down" and b.air
	var real := dmg / float(b.S.def)
	if juggle:
		b.jug = int(b.jug) + 1
		real *= pow(JUG_SCALE, int(b.jug))
		up = maxf(up * 0.7, 5.0)        # 뜬 상대는 약한 공격에도 다시 살짝 뜬다
		kb *= 0.5
	b.hp = maxf(0.0, float(b.hp) - real)
	if not a.is_empty():
		a.gauge = minf(100.0, float(a.gauge) + real * 1.2 * float(a.S.gain))
		a.dealt = float(a.dealt) + real
		a.hits = int(a.hits) + 1
		if float(b.hp) <= 0.0:
			a.kos = int(a.kos) + 1
	b.gauge = minf(100.0, float(b.gauge) + real * 0.6)
	var v := dir * kb * KNOCK
	v.y = up
	b.vel = v
	if down or b.air or float(b.hp) <= 0.0 or up > 5.0:
		b.state = "down"
		if up <= 0.0 and not b.air:
			b.vel.y = 3.0
		b.air = true
		# 날아가면 든 무기를 떨어뜨린다
		if str(b.held) != "":
			if int(b.uses) > 0:
				(w.items as Array).append({"kind": b.held, "uses": b.uses, "pos": b.pos})
			b.held = ""
	else:
		b.state = "hurt"
	b.stun = stun
	b.t = 0.0
	b.m = {}
	b.run = false
	w.events.append({"e": "hit", "pos": (b.pos as Vector3) + Vector3(0, 1.0, 0), "big": dmg >= 10.0, "id": b.id, "ko": float(b.hp) <= 0.0, "jug": int(b.jug) if juggle else 0, "by": int(a.get("id", -1))})

# ─────────── 컴퓨터 ───────────

static func nearest(f: Dictionary, fs: Array, same_zone := false, max_d := INF) -> Dictionary:
	var best := {}
	var bd := max_d
	for o in fs:
		if int(o.id) == int(f.id) or not alive(o) or (int(f.team) >= 0 and int(f.team) == int(o.team)):
			continue
		if same_zone and zone(o.pos) != zone(f.pos):
			continue
		var d: float = (o.pos as Vector3).distance_to(f.pos)
		if d < bd:
			bd = d
			best = o
	return best

static func ai_input(f: Dictionary, fs: Array, w: Dictionary, rnd: float, skill: float) -> Dictionary:
	var stage: Dictionary = w.stage
	var inp := {"mx": 0.0, "mz": 0.0}
	var pos: Vector3 = f.pos
	var tg := nearest(f, fs, true)
	var goal := pos
	var chase := not tg.is_empty()
	if chase:
		goal = tg.pos
		# 높은 곳의 상대: 계단으로
		if goal.y - pos.y > 1.0:
			var bestr := INF
			for r in stage.get("ramps", []):
				var a: Vector3 = r.a
				if absf(a.y - pos.y) < 0.6 and (r.b as Vector3).y <= goal.y + 0.6 and a.distance_to(pos) < bestr:
					bestr = a.distance_to(pos)
					goal = r.b if a.distance_to(pos) < 1.2 or (pos.y > a.y + 0.1) else a
			chase = false
	else:
		# 같은 곳에 상대가 없으면 문으로
		var any := nearest(f, fs)
		if not any.is_empty():
			var bd := INF
			for d in stage.get("doors", []):
				var at: Vector3 = d.at
				if zone(at) == zone(pos) and absf(at.y - pos.y) < 0.6 and at.distance_to(pos) < bd:
					bd = at.distance_to(pos)
					goal = at
			if bd < 0.9:
				inp.mz = -1.0
				return inp
	# 무기가 가까이 있으면 줍는다
	if str(f.held) == "" and not f.air:
		for it in w.get("items", []):
			var ip: Vector3 = it.pos
			if ip.distance_to(pos) < 6.0 and absf(ip.y - pos.y) < 0.6 and (tg.is_empty() or ip.distance_to(pos) < (tg.pos as Vector3).distance_to(pos)):
				goal = ip
				chase = false
				if ip.distance_to(pos) < 1.0:
					inp.xp = true
					return inp
	var d := goal - pos
	var flat := Vector2(d.x, d.z)
	var dist := flat.length()
	var dir := flat.normalized() if dist > 0.01 else Vector2.ZERO
	if f.air and top_h(stage, pos.x, pos.z) == -INF:
		var home := Vector2(-pos.x + (71.0 if zone(pos) == 1 else 0.0), -pos.z).normalized()
		inp.mx = home.x
		inp.mz = home.y
		inp.vp = int(f.jumps) > 0 and float(f.vel.y) < 0.0
		return inp
	if dist > (1.15 if chase else 0.3):
		var probe := pos + Vector3(dir.x, 0, dir.y) * 1.0
		if ground_h(stage, probe.x, probe.z, pos.y) == -INF and not f.air:
			var far := pos + Vector3(dir.x, 0, dir.y) * 2.2
			var th := top_h(stage, probe.x, probe.z)
			if (th > -INF and th - pos.y < 1.5) or (th == -INF and top_h(stage, far.x, far.z) > -INF):
				inp.vp = true
				inp.mx = dir.x
				inp.mz = dir.y
			else:
				# 막힌 벽·낭떠러지: 옆으로 비켜 간다
				inp.mx = -dir.y
				inp.mz = dir.x
		else:
			inp.mx = dir.x
			inp.mz = dir.y
			inp.run = dist > 6.0
	if tg.is_empty() or not chase:
		return inp
	inp.aim_yaw = atan2(d.x, d.z)
	inp.face = true
	var floating: bool = str(tg.state) == "down" and tg.air
	var close := dist < 1.6 and (absf(d.y) < 1.2 or (floating and d.y < 2.0 and d.y > 0.0))
	var held := str(f.held)
	var lying: bool = str(tg.state) == "down" and not tg.air
	if lying:
		# 누운 상대는 못 때린다: 조금 물러나 기다린다
		if dist < 2.0:
			inp.mx = -dir.x * 0.6
			inp.mz = -dir.y * 0.6
		return inp
	if f.air:
		if dist < 1.6 and d.y < 0.5 and rnd < 0.2 * skill:
			inp.xp = true
	elif held in ["rifle", "bazooka"] and dist > 3.0 and dist < 16.0 and absf(d.y) < 1.0:
		if rnd < 0.07 * skill:
			inp.xp = true
			inp.mx = 0.0
			inp.mz = 0.0
	elif f.run and dist < 2.6 and rnd < 0.3 * skill:
		if float(f.gauge) >= DASH_SUPER_COST and rnd < 0.08: inp.xp = true; inp.c = true
		elif rnd < 0.2: inp.xp = true
		else: inp.cp = true
	elif close and str(tg.state) == "atk" and float(tg.t) < float(tg.m.st) and float(f.guard) > 8.0 and fwd(tg.yaw).dot(Vector3(d.x, 0, d.z)) < 0.0 and rnd < 0.4 * skill:
		# 상대가 치려고 하면 막는다
		inp.x = true
		inp.c = true
		inp.mx = 0.0
		inp.mz = 0.0
	elif close:
		inp.z = rnd > 0.55
		# 뜬 상대는 이어 때린다
		if floating:
			inp.z = false
			if rnd < 0.75 * skill: inp.xp = true
		elif float(f.gauge) >= SUPER_COST and rnd < 0.06 * skill:
			inp.z = true; inp.x = true; inp.c = true; inp.xp = true
		elif rnd < 0.16 * skill:
			inp.xp = true
		elif rnd < 0.21 * skill:
			inp.cp = true
	elif (f.style == "psychic" or str(f.acc) in ["wand", "wings"]) and dist < 10.0 and absf(d.y) < 1.0 and rnd < 0.03 * skill:
		inp.mx = 0.0
		inp.mz = 0.0
		if f.style == "psychic": inp.cp = true
		else: inp.z = true; inp.xp = true
	elif float(f.gauge) >= SUPER_COST and str(f.S.super) == "s_dash" and dist < 5.0 and rnd < 0.03 * skill:
		inp.z = true; inp.x = true; inp.c = true; inp.xp = true
	return inp

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

# ─────────── 돈·상점·저장 ───────────

## 한 판 보상
static func reward(win: bool, dealt: float, kos: int) -> int:
	return 40 + int(dealt * 0.8) + kos * 40 + (120 if win else 0)

static func default_save() -> Dictionary:
	return {"v": 1, "coins": 500, "owned": ["none"], "acc": "none", "style": "brawler", "wins": 0, "games": 0}

static func can_buy(save: Dictionary, acc: String) -> bool:
	return ACCS.has(acc) and not (acc in save.owned) and int(save.coins) >= int(ACCS[acc].price)

static func buy(save: Dictionary, acc: String) -> Dictionary:
	if not can_buy(save, acc):
		return save
	var s := save.duplicate(true)
	s.coins = int(s.coins) - int(ACCS[acc].price)
	s.owned.append(acc)
	s.acc = acc
	return s

static func parse_save(raw: Variant) -> Dictionary:
	var s := default_save()
	if typeof(raw) == TYPE_STRING:
		var j := JSON.new()
		raw = j.data if j.parse(raw) == OK else null
	if typeof(raw) != TYPE_DICTIONARY:
		return s
	for key in ["coins", "wins", "games"]:
		if typeof(raw.get(key)) in [TYPE_INT, TYPE_FLOAT]:
			s[key] = maxi(0, int(raw[key]))
	if typeof(raw.get("owned")) == TYPE_ARRAY:
		for id in raw.owned:
			if ACCS.has(id) and not (id in s.owned):
				s.owned.append(id)
	if raw.get("acc") in s.owned:
		s.acc = raw.acc
	if raw.get("style") in STYLE_IDS:
		s.style = raw.style
	return s
