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
	return {"stage": Rules.rooftop(), "shots": [], "events": []}

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
	_data(); _move(); _combo(); _aim_and_acc(); _supers(); _stage(); _shots(); _ai_match()
	print("통과 %d, 실패 %d" % [passes, fails])
	quit(1 if fails > 0 else 0)

func _data() -> void:
	var mv := Rules.moves()
	for id in Rules.STYLE_IDS:
		var s: Dictionary = Rules.STYLES[id]
		ok(mv.has(s.super) and int(mv[s.super].cost) == Rules.SUPER_COST, id + " 필살기")
		ok(s.hp >= 80 and s.speed > 4.0 and s.jump > 9.0, id + " 능력치")
	for id in Rules.ACC_IDS:
		ok(mv.has(Rules.ACCS[id].zx) and mv.has(Rules.ACCS[id].zc), id + " 장신구 기술")
	ok(Rules.STYLES.titan.hp > Rules.STYLES.agent.hp and Rules.STYLES.agent.speed > Rules.STYLES.titan.speed, "유형마다 다르다")
	var f := mk(0, "titan")
	ok(Rules.move_for(f, "c").dmg > Rules.move_for(mk(1, "agent"), "c").dmg, "장사가 더 세다")
	ok(Rules.move_for(mk(1, "agent"), "c").st < Rules.move_for(f, "c").st, "요원이 더 빠르다")
	ok(Rules.move_for(mk(2, "psychic"), "c").has("shot") and not Rules.move_for(f, "c").has("shot"), "염력사 강공격은 염력탄")

func _move() -> void:
	var w := world()
	var a := mk(0)
	run([a], w, 1.0, {0: {"mx": 1.0}})
	ok(a.pos.x > 5.0 and a.pos.y == 0.0 and absf(a.yaw - PI / 2) < 0.01, "걷기")
	tap([a], w, 0, {"vp": true})
	ok(a.air and a.vel.y > 5.0, "점프")
	var top := 0.0
	var t := 0.0
	while a.air and t < 3.0:
		run([a], w, DT); top = maxf(top, a.pos.y); t += DT
	ok(top > 1.5 and top < 2.4 and not a.air, "점프 높이 %.2f" % top)
	tap([a], w, 0, {"vp": true}); run([a], w, 0.2); tap([a], w, 0, {"vp": true})
	var vy: float = a.vel.y
	ok(vy < 5.0, "주먹꾼은 공중에서 다시 못 뛴다")
	var g := mk(1, "agent")
	tap([g], w, 1, {"vp": true}); run([g], w, 0.3); tap([g], w, 1, {"vp": true})
	ok(g.vel.y > 8.0, "요원은 두 번 뛴다")

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
	b.pos = a.pos + Rules.fwd(a.yaw) * 1.0; b.inv = 0.0
	var hp: float = b.hp
	tap([a, b], w, 0, {"cp": true, "c": true}); run([a, b], w, 0.35)
	ok(b.hp < hp - 8.0 and b.air and b.state == "down", "C 강공격은 띄운다")
	# 공중 공격
	var c := mk(2)
	tap([c], w, 2, {"vp": true}); run([c], w, 0.1); tap([c], w, 2, {"xp": true, "x": true})
	ok(c.m.get("id", "") == "a_x", "공중 X")
	run([c], w, 1.5)
	ok(c.state == "free" and not c.air, "내려오면 끝난다")

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
		a.state = "free"; a.pos = Vector3.ZERO; b.pos = Vector3(1.2, 0, 0); b.state = "free"; b.inv = 0.0; b.air = false; b.vel = Vector3.ZERO
		tap([a, b], w, 0, {"z": true, "aim_yaw": yaw, "cp": true, "c": true})
		ok(a.m.id == Rules.ACCS[acc].zc, acc + " Z+C")
	var p := mk(0, "psychic", "bat")
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
	var s := Rules.rooftop()
	ok(Rules.top_h(s, 0, 0) == 0.0 and Rules.top_h(s, 12, 0) == 1.4 and Rules.top_h(s, 0, 20) == -INF, "발판 높이")
	ok(Rules.ground_h(s, 12, 0, 0.0) == -INF and Rules.ground_h(s, 12, 0, 1.2) == 1.4, "높은 턱은 못 오른다")
	for p in s.starts:
		ok(is_equal_approx(Rules.top_h(s, p.x, p.z), p.y), "출발 자리는 발판 위")
	var w := world()
	var a := mk(0, "brawler", "none", Vector3(6.5, 0, -1))
	run([a], w, 1.0, {0: {"mx": 1.0}})
	ok(a.pos.x < 7.9 and a.pos.y == 0.0, "높은 옥상 벽에 막힌다")
	var st2 := mk(5, "brawler", "none", Vector3(4.5, 0, 1.6))
	run([st2], w, 1.2, {5: {"mx": 1.0}})
	ok(is_equal_approx(st2.pos.y, 1.4) and st2.pos.x > 8.0, "계단으로 걸어 올라간다")
	var b := mk(1, "brawler", "none", Vector3(0, 0, 3.5))
	run([b], w, 1.2, {1: {"mz": 1.0}})
	ok(b.outs == 1 and b.hp < b.max_hp and b.inv > 0.0, "떨어지면 피가 줄고 다시 나온다")
	b.hp = 5.0; b.pos = Vector3(0, -11.9, 9)
	run([b], w, 0.2)
	ok(b.state == "out" and not Rules.alive(b), "피가 없을 때 떨어지면 탈락")

func _shots() -> void:
	var w := world()
	var p := mk(0, "psychic", "none", Vector3(0, 0, -3.0))
	var b := mk(1, "brawler", "none", Vector3(0, 0, 3.0))
	tap([p, b], w, 0, {"cp": true, "c": true})
	run([p, b], w, 1.0)
	ok(b.hp < b.max_hp and w.shots.is_empty(), "염력탄이 멀리서 맞는다")

func _ai_match() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in [1, 2, 3]:
		rng.seed = seed
		var w := world()
		var fs := []
		for i in 4:
			fs.append(Rules.new_fighter(i, Rules.STYLE_IDS[i], Rules.ACC_IDS[i % 3], -1, w.stage.starts[i]))
		var t := 0.0
		var win := -2
		var hits := 0
		while win == -2 and t < 150.0:
			for f in fs:
				Rules.step(f, Rules.ai_input(f, fs, w.stage, rng.randf(), 0.8) if Rules.alive(f) else {}, w, DT)
			Rules.resolve(fs, w, DT)
			for e in w.events:
				if e.e == "hit": hits += 1
			w.events.clear()
			t += DT
			win = Rules.winner(fs, 120.0 - t)
		var outs := 0
		for f in fs: outs += int(f.outs)
		print("  컴퓨터 넷 싸움 %d: %.0f초, 이긴 쪽 %s, 맞힌 횟수 %d, 떨어짐 %d" % [seed, t, Rules.STYLES[fs[win].style].name if win >= 0 else "없음", hits, outs])
		ok(win >= -1, "싸움이 끝난다")
		ok(hits > 30, "서로 때린다 (%d)" % hits)
		ok(outs <= 8, "컴퓨터가 자꾸 떨어지지 않는다 (%d)" % outs)
