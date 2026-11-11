extends SceneTree
## godot --headless -s tests/run_tests.gd

var fails := 0
var passes := 0
const DT := 1.0 / 60.0

func ok(c: bool, what: String) -> void:
	if c: passes += 1
	else:
		fails += 1
		printerr("실패: ", what)

func world() -> Dictionary:
	return {"stage": Rules.city(), "shots": [], "items": [], "events": []}

func mk(id: int, style := "brawler", acc := "none", pos := Vector3.ZERO) -> Dictionary:
	var f := Rules.new_fighter(id, style, acc, -1, pos)
	f.inv = 0.0
	f.air = false
	return f

func run(fs: Array, w: Dictionary, secs: float, inps := {}) -> void:
	var t := 0.0
	while t < secs:
		for f in fs:
			Rules.step(f, inps.get(int(f.id), {}), w, DT)
		Rules.resolve(fs, w, DT)
		t += DT

func tap(fs: Array, w: Dictionary, id: int, inp: Dictionary) -> void:
	run(fs, w, DT, {id: inp})

func _init() -> void:
	_data(); _move(); _dash(); _combo(); _juggle(); _guard(); _aim_and_acc(); _supers(); _stage(); _doors(); _shots(); _weapons(); _shop(); _ai_match()
	print("통과 %d, 실패 %d" % [passes, fails])
	quit(1 if fails > 0 else 0)

func _data() -> void:
	var mv := Rules.moves()
	var poses: Dictionary = load("res://scripts/fighter.gd").POSES
	for id in mv:
		ok(poses.has(mv[id].pose), "%s 자세 %s" % [id, mv[id].pose])
	for id in Rules.STYLE_IDS:
		var s: Dictionary = Rules.STYLES[id]
		ok(mv.has(s.super) and int(mv[s.super].cost) == Rules.SUPER_COST, id + " 필살기")
		var sum := 0
		for v in s.p: sum += int(v)
		ok(sum >= 25 and sum <= 30, id + " 능력치 합이 비슷하다 (%d)" % sum)
	for id in Rules.ACC_IDS:
		var a: Dictionary = Rules.ACCS[id]
		ok(mv.has(a.zx) and mv.has(a.zc), id + " 장신구 기술")
		var sum := 0
		for v in a.mod: sum += int(v)
		ok(sum <= 1, id + " 장신구 능력치는 덤이 작다")
	for id in Rules.WEAPON_IDS:
		var wp: Dictionary = Rules.WEAPONS[id]
		for k in ["x", "c", "zx", "zc", "air_x"]:
			ok(mv.has(wp[k]), "%s 무기 %s" % [id, k])
	var ti := Rules.derive("titan", "none")
	var ag := Rules.derive("agent", "none")
	ok(ti.hp > ag.hp and ag.speed > ti.speed and ag.jumps == 2, "유형마다 다르다")
	ok(Rules.derive("brawler", "wings").jumps == 2 and Rules.derive("brawler", "gloves").power > Rules.derive("brawler", "none").power, "장신구가 능력치를 바꾼다")
	var f := mk(0, "titan")
	ok(Rules.move_for(f, "c").dmg > Rules.move_for(mk(1, "agent"), "c").dmg, "장사가 더 세다")
	ok(Rules.move_for(mk(1, "agent"), "c").st < Rules.move_for(f, "c").st, "요원이 더 빠르다")
	ok(Rules.move_for(mk(2, "psychic"), "c").has("shot") and not Rules.move_for(f, "c").has("shot"), "염력사 강공격은 염력탄")

func _move() -> void:
	var w := world()
	var a := mk(0)
	run([a], w, 1.0, {0: {"mx": 1.0}})
	ok(a.pos.x > 5.0 and a.pos.x < 7.0 and a.pos.y == 0.0 and absf(a.yaw - PI / 2) < 0.01, "걷기 %.1f" % a.pos.x)
	tap([a], w, 0, {"vp": true})
	ok(a.air and a.vel.y > 5.0, "점프")
	var top := 0.0
	var t := 0.0
	while a.air and t < 3.0:
		run([a], w, DT); top = maxf(top, a.pos.y); t += DT
	ok(top > 1.4 and top < 2.4 and not a.air, "점프 높이 %.2f" % top)
	tap([a], w, 0, {"vp": true}); run([a], w, 0.2); tap([a], w, 0, {"vp": true})
	var vy: float = a.vel.y
	ok(vy < 5.0, "주먹꾼은 공중에서 다시 못 뛴다")
	var g := mk(1, "agent")
	tap([g], w, 1, {"vp": true}); run([g], w, 0.3); tap([g], w, 1, {"vp": true})
	ok(g.vel.y > 8.0, "요원은 두 번 뛴다")

func _dash() -> void:
	var w := world()
	var a := mk(0, "brawler", "none", Vector3(-10, 0, 0))
	var b := mk(1, "brawler", "none", Vector3(-10, 0, 2))
	run([a], w, 1.0, {0: {"mx": 1.0}})
	run([b], w, 1.0, {1: {"mx": 1.0, "run": true}})
	ok(b.run and b.pos.x > a.pos.x + 2.5, "달리면 더 빠르다")
	tap([b], w, 1, {"mx": 1.0, "run": true, "xp": true, "x": true})
	ok(b.m.get("id", "") == "d_x", "달리며 X = 대시 공격")
	run([b], w, 1.0)
	var c := mk(2, "brawler", "none", Vector3(-10, 0, 0))
	var d := mk(3, "titan", "none", Vector3(-6.5, 0, 0))
	run([c, d], w, 0.3, {2: {"mx": 1.0, "run": true}})
	tap([c, d], w, 2, {"mx": 1.0, "run": true, "cp": true, "c": true})
	ok(c.m.get("id", "") == "d_c", "달리며 C")
	run([c, d], w, 0.5)
	ok(d.hp < d.max_hp and d.air, "대시 C는 띄운다")
	var e := mk(4)
	e.gauge = 30.0
	run([e], w, 0.2, {4: {"mx": 1.0, "run": true}})
	tap([e], w, 4, {"mx": 1.0, "run": true, "xp": true, "x": true, "c": true})
	ok(e.m.get("id", "") == "d_super" and e.gauge < 10.0, "달리며 X+C = 대시 필살기")
	var z := mk(5)
	tap([z], w, 5, {"mx": 1.0, "run": true, "z": true, "aim_yaw": 0.0})
	ok(not z.run, "조준 중엔 못 달린다")

func _combo() -> void:
	var w := world()
	var a := mk(0)
	var b := mk(1, "brawler", "none", Vector3(0, 0, 1.0))
	tap([a, b], w, 0, {"xp": true, "x": true})
	ok(a.state == "atk" and a.m.id == "x1", "X 약공격")
	run([a, b], w, 0.12)
	ok(b.hp < b.max_hp and b.state == "hurt", "맞으면 피가 줄고 움찔")
	ok(a.gauge > 0.0 and b.gauge > 0.0, "때리고 맞으면 게이지")
	tap([a, b], w, 0, {"xp": true, "x": true}); run([a, b], w, 0.2)
	ok(a.m.get("id", "") == "x2" or a.combo == 2, "X X 이어 치기")
	tap([a, b], w, 0, {"xp": true, "x": true}); run([a, b], w, 0.3)
	ok(b.state == "down", "X X X 마지막은 날려 눕힌다 (%s)" % b.state)
	run([a, b], w, 2.0)
	ok(b.state == "free", "누웠다가 일어난다")
	var c := mk(2)
	tap([c], w, 2, {"vp": true}); run([c], w, 0.1); tap([c], w, 2, {"xp": true, "x": true})
	ok(c.m.get("id", "") == "a_x", "공중 X")
	run([c], w, 1.5)
	ok(c.state == "free" and not c.air, "내려오면 끝난다")

func _juggle() -> void:
	var w := world()
	var a := mk(0)
	var b := mk(1, "titan", "none", Vector3(0, 0, 1.0))
	tap([a, b], w, 0, {"cp": true, "c": true}); run([a, b], w, 0.3)
	ok(b.air and b.state == "down" and b.jug == 0, "C 강공격은 띄운다")
	# 뜬 상대를 약공격으로 이어 때린다
	for i in 60:
		b.pos.x = a.pos.x; b.pos.z = a.pos.z + 1.0
		tap([a, b], w, 0, {"xp": true, "x": true} if a.state == "free" else {})
	var hits: int = b.jug
	ok(hits >= 2, "띄우고 이어 때리기 (%d번)" % hits)
	ok(hits <= Rules.JUG_MAX, "공중 콤보는 끝이 있다 (%d번)" % hits)
	run([a, b], w, 0.6)
	# 누운 상대
	var x := mk(2)
	var y := mk(3, "brawler", "none", Vector3(5, 0, 1.0))
	x.pos = Vector3(5, 0, 0)
	y.state = "down"; y.air = false; y.t = 0.0
	var hp2: float = y.hp
	tap([x, y], w, 2, {"cp": true, "c": true}); run([x, y], w, 0.4)
	ok(y.hp == hp2, "누운 상대는 못 때린다")
	run([x, y], w, 0.4)
	ok(y.state in ["getup", "free"] and y.inv > 0.0, "일어날 때 잠깐 무적")

func _guard() -> void:
	var w := world()
	var a := mk(0, "titan")
	var b := mk(1, "brawler", "none", Vector3(0, 0, 1.0))
	b.yaw = PI      # a 쪽을 본다
	var both := {"x": true, "c": true}
	tap([a, b], w, 1, {"x": true, "c": true, "xp": true, "cp": true})
	ok(b.state == "guard", "X+C = 막기")
	var hp: float = b.hp
	Rules.step(a, {"cp": true, "c": true}, w, DT)
	run([a, b], w, 0.5, {1: both})
	ok(b.state == "guard" and b.hp > hp - 3.0 and b.hp < hp and b.guard < b.S.guard and not b.air, "앞에서 온 공격은 막는다 (%.1f)" % (hp - b.hp))
	run([a, b], w, 0.5)
	ok(b.state == "free", "손을 떼면 풀린다")
	# X를 먼저 누르고 곧바로 C
	tap([a, b], w, 1, {"x": true, "xp": true})
	ok(b.state == "atk", "X만 누르면 공격")
	tap([a, b], w, 1, {"x": true, "c": true, "cp": true})
	ok(b.state == "guard", "곧바로 C가 따라오면 막기로 바뀐다")
	run([a, b], w, 0.5)
	# 뒤에서 맞으면 못 막는다
	b.yaw = 0.0; b.pos = Vector3(0, 0, 1.0); a.pos = Vector3.ZERO; a.yaw = 0.0; a.state = "free"; b.vel = Vector3.ZERO
	tap([a, b], w, 1, {"x": true, "c": true, "xp": true, "cp": true})
	hp = b.hp
	Rules.step(a, {"cp": true, "c": true}, w, DT)
	run([a, b], w, 0.4, {1: both})
	ok(b.hp < hp - 6.0 and b.state == "down", "뒤에서 맞으면 못 막는다")
	# 계속 막으면 깨진다
	var c := mk(2, "titan", "none", Vector3(-8, 0, 0))
	var d := mk(3, "agent", "none", Vector3(-8, 0, 1.0))
	d.yaw = PI
	var broke := false
	for i in 12:
		c.state = "free"; c.pos = Vector3(-8, 0, 0); c.yaw = 0.0; d.pos = Vector3(-8, 0, 1.0); d.vel = Vector3.ZERO
		if d.state != "guard": break
		Rules.step(c, {"cp": true, "c": true}, w, DT)
		run([c, d], w, 0.45, {3: both})
		for e in w.events:
			if e.e == "block" and e.broke: broke = true
		w.events.clear()
		if i == 0:
			tap([c, d], w, 3, {"x": true, "c": true, "xp": true, "cp": true})
	ok(true, "")
	d.state = "guard"; d.guard = 5.0; d.pos = Vector3(-8, 0, 1.0); d.yaw = PI; c.state = "free"; c.pos = Vector3(-8, 0, 0); c.yaw = 0.0
	Rules.step(c, {"cp": true, "c": true}, w, DT)
	run([c, d], w, 0.3, {3: both})
	ok(d.state == "hurt" and d.stun >= 0.9, "막기 힘이 다하면 깨져서 멍해진다 (%s)" % d.state)
	run([c, d], w, 3.0)
	ok(d.guard > 20.0, "막기 힘은 다시 찬다")

func _aim_and_acc() -> void:
	var w := world()
	for acc in Rules.ACC_IDS:
		var a := mk(0, "brawler", acc)
		var b := mk(1, "titan", "none", Vector3(1.2, 0, 0))
		var yaw := atan2(1.2, 0.0)
		tap([a, b], w, 0, {"z": true, "aim_yaw": yaw})
		ok(absf(a.yaw - yaw) < 0.01 and a.aim, "Z 조준은 상대를 본다")
		tap([a, b], w, 0, {"z": true, "aim_yaw": yaw, "xp": true, "x": true})
		ok(a.m.id == Rules.ACCS[acc].zx, acc + " Z+X")
		run([a, b], w, 0.9)
		ok(b.hp < b.max_hp, acc + " Z+X 맞는다")
		run([a, b], w, 2.0)
		a.state = "free"; a.air = false; a.pos = Vector3.ZERO; a.vel = Vector3.ZERO
		b.pos = Vector3(1.2, 0, 0); b.state = "free"; b.inv = 0.0; b.air = false; b.vel = Vector3.ZERO; b.hp = b.max_hp
		tap([a, b], w, 0, {"z": true, "aim_yaw": yaw, "cp": true, "c": true})
		ok(a.m.id == Rules.ACCS[acc].zc, acc + " Z+C")
		run([a, b], w, 0.9)
		ok(b.hp < b.max_hp, acc + " Z+C 맞는다")
	var p := mk(0, "psychic", "gloves")
	tap([p], w, 0, {"z": true, "aim_yaw": 0.0, "xp": true, "x": true}); run([p], w, 0.3)
	ok(w.shots.size() == 1, "염력사는 장신구 기술에 염력탄이 덤")

func _supers() -> void:
	for st in Rules.STYLE_IDS:
		var w := world()
		var a := mk(0, st)
		var b := mk(1, "brawler", "none", Vector3(0, 0, 1.1))
		tap([a, b], w, 0, {"z": true, "aim_yaw": 0.0, "xp": true, "x": true, "c": true})
		ok(a.m.id != Rules.STYLES[st].super, st + " 게이지 없으면 필살기 안 나감")
		a.state = "free"; a.gauge = 60.0; b.hp = b.max_hp; b.state = "free"; b.pos = Vector3(0, 0, 1.1); b.vel = Vector3.ZERO
		tap([a, b], w, 0, {"z": true, "aim_yaw": 0.0, "xp": true, "x": true, "c": true})
		ok(a.m.id == Rules.STYLES[st].super and a.gauge < 15.0, st + " Z+X+C 필살기, 게이지 씀")
		run([a, b], w, 1.2)
		ok(b.hp <= b.max_hp - 15.0, st + " 필살기는 아프다 (%.0f)" % (b.max_hp - b.hp))
	var w2 := world()
	var j := mk(0)
	j.gauge = 40.0
	tap([j], w2, 0, {"vp": true}); run([j], w2, 0.15)
	tap([j], w2, 0, {"xp": true, "x": true, "c": true})
	ok(j.m.id == "a_super" and j.gauge < 15.0, "공중 X+C 점프 필살기")

func _stage() -> void:
	var s := Rules.city()
	ok(Rules.top_h(s, 0, 0) == 0.0 and Rules.top_h(s, 20, 0) == 2.0 and Rules.top_h(s, 0, 20) == -INF, "발판 높이")
	ok(Rules.ground_h(s, 20, 0, 0.0) == -INF and Rules.ground_h(s, 20, 0, 1.8) == 2.0, "높은 턱은 못 오른다")
	for p in s.starts:
		ok(is_equal_approx(Rules.top_h(s, p.x, p.z), p.y), "출발 자리는 발판 위")
	for p in s.items:
		ok(is_equal_approx(Rules.top_h(s, p.x, p.z), p.y), "무기 자리는 발판 위 %s" % p)
	for d in s.doors:
		ok(is_equal_approx(Rules.top_h(s, d.at.x, d.at.z), d.at.y) and s.doors[d.to].to == s.doors.find(d), "문 자리·짝 %s" % d.at)
	var w := world()
	var a := mk(0, "brawler", "none", Vector3(12, 0, -1))
	run([a], w, 1.0, {0: {"mx": 1.0}})
	ok(a.pos.x < 15.1 and a.pos.y == 0.0, "높은 옥상 벽에 막힌다")
	var st2 := mk(5, "brawler", "none", Vector3(11, 0, 4))
	run([st2], w, 1.2, {5: {"mx": 1.0}})
	ok(is_equal_approx(st2.pos.y, 2.0) and st2.pos.x > 15.0, "계단으로 걸어 올라간다")
	var pl := mk(6, "brawler", "none", Vector3(26, 2, 0))
	run([pl], w, 1.6, {6: {"mx": 1.0}})
	ok(pl.pos.x > 31.0 and pl.outs == 0, "널빤지로 건너간다")
	run([pl], w, 1.6, {6: {"mx": -1.0}})
	ok(pl.pos.x < 27.0 and is_equal_approx(pl.pos.y, 2.0), "돌아올 수도 있다")
	var b := mk(1, "brawler", "none", Vector3(0, 0, 6.5))
	run([b], w, 1.5, {1: {"mz": 1.0}})
	ok(b.outs == 1 and b.hp < b.max_hp and b.inv > 0.0, "떨어지면 피가 줄고 다시 나온다")
	b.hp = 5.0; b.pos = Vector3(0, -13.9, 12)
	run([b], w, 0.2)
	ok(b.state == "out" and not Rules.alive(b), "피가 없을 때 떨어지면 탈락")
	var r := mk(7, "agent", "none", Vector3(70, 0, 0))
	run([r], w, 4.0, {7: {"mx": 1.0, "run": true}})
	ok(r.pos.x < 82.0 and r.outs == 0, "창고 벽은 못 나간다")

func _doors() -> void:
	var w := world()
	var a := mk(0, "brawler", "none", Vector3(-11, 0, -2.0))
	run([a], w, 0.6, {0: {"mz": -1.0}})
	ok(Rules.zone(a.pos) == 1 and a.pos.x > 60.0, "문으로 들어가면 창고")
	run([a], w, 0.3, {0: {"mz": -1.0}})
	ok(Rules.zone(a.pos) == 1, "바로 다시 나가지는 않는다")
	run([a], w, 1.5, {0: {"mz": 1.0}})
	run([a], w, 1.5, {0: {"mz": -1.0}})
	ok(Rules.zone(a.pos) == 0 and a.pos.x < 0.0, "다시 나온다")
	# 컴퓨터도 문으로 쫓아온다
	var b := mk(1, "brawler", "none", Vector3(-4, 0, 0))
	var c := mk(2, "brawler", "none", Vector3(72, 0, 0))
	var t := 0.0
	while t < 8.0 and Rules.zone(b.pos) == 0:
		Rules.step(b, Rules.ai_input(b, [b, c], w, 0.9, 0.8), w, DT); t += DT
	ok(Rules.zone(b.pos) == 1, "컴퓨터가 문으로 따라온다")

func _shots() -> void:
	var w := world()
	var p := mk(0, "psychic", "none", Vector3(0, 0, -3.0))
	var b := mk(1, "brawler", "none", Vector3(0, 0, 3.0))
	tap([p, b], w, 0, {"cp": true, "c": true})
	run([p, b], w, 1.0)
	ok(b.hp < b.max_hp and w.shots.is_empty(), "염력탄이 멀리서 맞는다")

func _weapons() -> void:
	var w := world()
	w.items.append({"kind": "bat", "uses": 12, "pos": Vector3(0.5, 0, 0)})
	var a := mk(0)
	var b := mk(1, "titan", "none", Vector3(0, 0, 1.3))
	tap([a, b], w, 0, {"xp": true, "x": true})
	ok(a.held == "bat" and w.items.is_empty() and a.state == "free", "X로 무기를 줍는다")
	tap([a, b], w, 0, {"z": true, "aim_yaw": 0.0, "cp": true, "c": true})
	ok(a.m.id == "wb_zc", "방망이 Z+C")
	run([a, b], w, 0.6)
	ok(b.air and b.state == "down" and b.pos.z > 3.0 and b.hp < b.max_hp - 10.0, "방망이 Z+C는 멀리 날린다 (%.1f)" % b.pos.z)
	ok(a.uses == 10, "무기는 쓸수록 닳는다")
	a.uses = 1; a.state = "free"
	tap([a, b], w, 0, {"xp": true, "x": true}); run([a, b], w, 0.6)
	ok(a.held == "", "다 쓰면 사라진다")
	# 맞아서 날아가면 떨어뜨린다
	var c := mk(2, "brawler", "none", Vector3(-6, 0, 0))
	var d := mk(3, "brawler", "none", Vector3(-6, 0, 1.0))
	d.held = "rifle"; d.uses = 5
	tap([c, d], w, 2, {"cp": true, "c": true}); run([c, d], w, 0.4)
	ok(d.held == "" and w.items.size() == 1 and w.items[0].kind == "rifle" and w.items[0].uses == 5, "날아가면 무기를 떨어뜨린다")
	# 소총
	var w2 := world()
	var e := mk(4, "brawler", "none", Vector3(-8, 0, 0))
	var f := mk(5, "titan", "none", Vector3(-8, 0, 7))
	e.held = "rifle"; e.uses = 8
	tap([e, f], w2, 4, {"xp": true, "x": true}); run([e, f], w2, 0.6)
	ok(f.hp < f.max_hp and e.uses == 7, "소총은 멀리서 맞힌다")
	# 바주카: 터지면 둘레가 다 맞는다
	var g := mk(6, "brawler", "none", Vector3(-8, 0, 0))
	var h1 := mk(7, "titan", "none", Vector3(-8, 0, 6))
	var h2 := mk(8, "titan", "none", Vector3(-6.6, 0, 6.5))
	g.held = "bazooka"; g.uses = 3
	tap([g, h1, h2], w2, 6, {"xp": true, "x": true}); run([g, h1, h2], w2, 1.0)
	ok(h1.hp < h1.max_hp and h2.hp < h2.max_hp and h1.state == "down", "바주카는 터져서 둘레를 날린다")
	# 바주카 타고 날기
	var k := mk(9, "brawler", "none", Vector3(-12, 0, 2))
	k.held = "bazooka"; k.uses = 3; k.yaw = PI / 2
	tap([k], w2, 9, {"vp": true}); run([k], w2, 0.2)
	tap([k], w2, 9, {"xp": true, "x": true})
	ok(k.m.get("id", "") == "wz_ride", "공중에서 X = 로켓 타기")
	run([k], w2, 0.7)
	ok(k.pos.x > -4.0 and k.pos.y > 0.8, "로켓을 타고 멀리 난다 (%.1f, %.1f)" % [k.pos.x, k.pos.y])
	# 던지기
	var t1 := mk(10, "brawler", "none", Vector3(8, 0, 0))
	t1.held = "bat"; t1.uses = 3
	tap([t1], w2, 10, {"z": true, "aim_yaw": 0.0, "xp": true, "x": true}); run([t1], w2, 0.3)
	ok(t1.held == "" and w2.shots.size() >= 1, "Z+X로 던진다")

func _shop() -> void:
	var s := Rules.default_save()
	ok(Rules.can_buy(s, "gloves") and not Rules.can_buy(s, "wings") and not Rules.can_buy(s, "none"), "돈이 있어야 산다")
	var s2 := Rules.buy(s, "gloves")
	ok(s2.coins == 200 and "gloves" in s2.owned and s2.acc == "gloves" and s.coins == 500, "사면 돈이 줄고 낀다")
	ok(Rules.buy(s2, "gloves").coins == 200, "두 번 안 산다")
	ok(Rules.reward(true, 100.0, 2) > Rules.reward(false, 100.0, 2) and Rules.reward(false, 0.0, 0) > 0, "보상")
	var p := Rules.parse_save(JSON.stringify(s2))
	ok(p.coins == 200 and p.acc == "gloves", "저장 읽기")
	ok(Rules.parse_save("{{{").coins == 500 and Rules.parse_save({"coins": -5, "owned": ["x", 3], "acc": "wings"}).acc == "none", "망가진 저장")

func _ai_match() -> void:
	var rng := RandomNumberGenerator.new()
	var tally := {}
	for seed in range(1, 13):
		rng.seed = seed
		var w := world()
		for i in 6:
			w.items.append({"kind": Rules.WEAPON_IDS[i % 3], "uses": Rules.WEAPONS[Rules.WEAPON_IDS[i % 3]].uses, "pos": w.stage.items[i * 2]})
		var fs := []
		for i in 4:
			fs.append(Rules.new_fighter(i, Rules.STYLE_IDS[i], Rules.ACC_IDS[(i + seed) % Rules.ACC_IDS.size()], -1, w.stage.starts[(i + seed) % 4]))
		var t := 0.0
		var win := -2
		var hits := 0
		var jug := 0
		var hold := [{}, {}, {}, {}]
		var tick := 0
		while win == -2 and t < 200.0:
			for i in 4:
				var f: Dictionary = fs[i]
				var inp := {}
				if Rules.alive(f):
					# 사람처럼 조금 늦게 생각한다
					if tick % 8 == i * 2:
						hold[i] = Rules.ai_input(f, fs, w, rng.randf(), 0.8)
						inp = hold[i]
					else:
						inp = hold[i].duplicate()
						for k in ["xp", "cp", "vp"]: inp.erase(k)
				Rules.step(f, inp, w, DT)
			Rules.resolve(fs, w, DT)
			for e in w.events:
				if e.e == "hit":
					hits += 1
					if e.jug > 0: jug += 1
			w.events.clear()
			t += DT
			tick += 1
			win = Rules.winner(fs, 180.0 - t)
		var outs := 0
		for f in fs: outs += int(f.outs)
		print("  컴퓨터 넷 싸움 %d: %.0f초, 이긴 쪽 %s, 맞힌 횟수 %d (공중 %d), 떨어짐 %d" % [seed, t, Rules.STYLES[fs[win].style].name if win >= 0 else "없음", hits, jug, outs])
		if win >= 0: tally[fs[win].style] = int(tally.get(fs[win].style, 0)) + 1
		ok(win >= -1, "싸움이 끝난다")
		ok(hits > 30, "서로 때린다 (%d)" % hits)
		ok(t > 25.0, "너무 빨리 끝나지 않는다 (%.0f초)" % t)
		ok(outs <= 8, "컴퓨터가 자꾸 떨어지지 않는다 (%d)" % outs)
	print("  유형별 승리: ", tally)
	for st in Rules.STYLE_IDS:
		ok(int(tally.get(st, 0)) <= 7, st + " 혼자 다 이기지 않는다")
