extends Node3D
## 대기실(유형·능력치·장신구) ↔ 상점 ↔ 싸움 ↔ 결과
## 개발용: -- --shot=title|shop|lineup|poses|fightN|roomN|super|strip_<walk|run|combo|strong|super>|result --out=/tmp/x.png

const SAVE := "user://fightgo_save.json"

var stage: RooftopStage
var ui: CanvasLayer
var menu: Control
var game: Match
var preview: Fighter
var extras: Array = []
var cam: Camera3D
var save := {}
var font: Font
var bold: Font
var last := {}
var screen := "title"
var look_acc := ""

func _ready() -> void:
	font = load("res://assets/fonts/Galmuri11.ttf")
	bold = load("res://assets/fonts/Galmuri11-Bold.ttf")
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 20
	get_tree().root.theme = th
	save = Rules.parse_save(FileAccess.get_file_as_string(SAVE) if FileAccess.file_exists(SAVE) else "")
	stage = RooftopStage.new()
	add_child(stage)
	stage.build()
	ui = CanvasLayer.new()
	add_child(ui)
	cam = Camera3D.new()
	cam.fov = 34
	add_child(cam)
	title()
	var shot := ""
	var out := "/tmp/fight.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot = a.substr(7)
		if a.begins_with("--out="): out = a.substr(6)
	if shot != "":
		_dev(shot, out)

func _store() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))

func _dev(shot: String, out: String) -> void:
	save = Rules.default_save()
	await get_tree().create_timer(0.6).timeout
	if shot == "shop":
		save.coins = 1500; save.owned = ["none", "gloves", "flame"]; save.acc = "flame"
		shop()
	elif shot == "lineup" or shot == "poses":
		_clear()
		var accs := ["flame", "claws", "wand", "gloves", "boots", "wings"]
		var poses := ["jab_r", "kick", "upper", "swing", "block", "cast", "slide", "knee", "shoot", "down"]
		var n := 4 if shot == "lineup" else poses.size()
		for i in n:
			var f := Fighter.new()
			add_child(f)
			f.build(Rules.STYLE_IDS[i % 4])
			f.position = Vector3((i - (n - 1) * 0.5) * (1.5 if shot == "lineup" else 1.25), 0, 2.0)
			if shot == "lineup":
				f.equip(accs[i])
				f.rotation.y = 0.35 - i * 0.22
			else:
				f.rotation.y = 0.9
				f.pose_now(poses[i])
				if poses[i] in ["swing", "slam"]: f.hold("bat")
				if poses[i] == "shoot": f.hold("rifle" if i % 2 == 0 else "bazooka")
			extras.append(f)
		cam.current = true
		cam.fov = 30
		cam.position = Vector3(0, 1.5, 9.0 if shot == "lineup" else 15.0)
		cam.look_at(Vector3(0, 0.95, 2.0), Vector3.UP)
	elif shot.begins_with("fight") or shot.begins_with("room"):
		fight(true)
		if shot.begins_with("room"):
			for i in game.fs.size():
				game.fs[i].pos = Vector3(66 + i * 3.5, 0.1, (i % 2) * 2.0 - 1.0)
		await get_tree().create_timer(float(shot.substr(5 if shot.begins_with("fight") else 4)) if shot.length() > 5 else 6.0).timeout
	elif shot == "super":
		# 필살기 모으기(0.5초) → 나가는 순간(1.25초)을 찍는다
		fight(true)
		game.intro = 0.0
		await get_tree().create_timer(0.3).timeout
		var me: Dictionary = game.fs[0]
		for i in game.fs.size():
			game.fs[i].pos = Vector3(-4.0 + i * 2.2, 0.0, 1.0)
			game.fs[i].vel = Vector3.ZERO
		me.gauge = 100.0
		me.yaw = PI / 2
		me.state = "free"
		Rules._start(me, str(me.S.super), game.w)
		await get_tree().create_timer(0.55).timeout
		get_viewport().get_texture().get_image().save_png(out + "_a.png")
		await get_tree().create_timer(0.55).timeout
		get_viewport().get_texture().get_image().save_png(out + "_b.png")
		get_tree().quit()
		return
	elif shot.begins_with("strip"):
		# 동작 확인: 한 선수가 정해진 입력으로 움직이는 것을 여러 장 찍는다 (out은 파일 앞부분)
		await _strip(shot.substr(6), out)
		get_tree().quit()
		return
	elif shot == "result":
		last = {"winner": 0, "name": "나", "me": true, "hp": 42.0, "outs": 1, "coins": 310, "kos": 2}
		title()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()

func _strip(what: String, out: String) -> void:
	_clear()
	var w := {"stage": Rules.city(), "shots": [], "items": [], "events": []}
	var st := "titan" if what == "super" else "brawler"
	var a := Rules.new_fighter(0, st, "none", -1, Vector3(-3, 0, 2))
	var b := Rules.new_fighter(1, "agent", "none", -1, Vector3(3, 0, 2))
	a.inv = 0.0; b.inv = 0.0; a.air = false; b.air = false
	a.yaw = PI / 2; b.yaw = -PI / 2
	if what == "super": a.gauge = 100.0
	var va := Fighter.new(); add_child(va); va.build(st)
	var vb := Fighter.new(); add_child(vb); vb.build("agent")
	extras.append(va); extras.append(vb)
	var aura: Node3D = null
	cam.current = true
	cam.fov = 40
	var dt := 1.0 / 60.0
	var frame := 0
	var shots := 0
	var every := 6
	while shots < 16:
		var ia := {}
		var tt := frame * dt
		match what:
			"walk": ia = {"mx": 1.0}
			"run": ia = {"mx": 1.0, "run": true}
			"combo":
				if frame % 22 == 2: ia = {"xp": true, "x": true}
				b.pos = a.pos + Vector3(1.0, 0, 0)
			"strong":
				if frame == 2: ia = {"cp": true, "c": true}
				b.pos = Vector3(a.pos.x + 1.0, b.pos.y, a.pos.z) if tt < 0.3 else b.pos
			"super":
				if frame == 2: ia = {"z": true, "x": true, "c": true, "xp": true, "aim_yaw": PI / 2}
				b.pos = a.pos + Vector3(2.0, 0, 0) if tt < 0.5 else b.pos
		Rules.step(a, ia, w, dt)
		Rules.step(b, {}, w, dt)
		Rules.resolve([a, b], w, dt)
		w.events.clear()
		va.sync(a, dt)
		vb.sync(b, dt)
		var c: Vector3 = (a.pos as Vector3) if what in ["walk", "run"] else Vector3(0, 0, 2)
		cam.position = c + Vector3(0.0, 1.6, 6.5)
		cam.look_at(c + Vector3(0, 0.9, 0), Vector3.UP)
		frame += 1
		await get_tree().process_frame
		if frame % every == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s%02d.png" % [out, shots])
			shots += 1

func _clear() -> void:
	for c in ui.get_children():
		c.queue_free()
	if game:
		game.queue_free()
		game = null
	if preview:
		preview.queue_free()
		preview = null
	for e in extras:
		e.queue_free()
	extras.clear()

func _process(dt: float) -> void:
	if preview:
		preview.idle_tick(dt)
		preview.rotation.y = -0.45 + sin(Time.get_ticks_msec() * 0.0006) * 0.5

func _btn(text: String, cb: Callable, on := false, w := 150, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 46)
	b.disabled = not enabled
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 21)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.86, 0.35) if on else (Color(1, 1, 1, 0.95) if st != "hover" else Color(1.0, 0.95, 0.75))
		if st == "disabled": sb.bg_color = Color(0.7, 0.68, 0.72, 0.9)
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(4)
		sb.border_color = Color(0.25, 0.14, 0.3) if st != "focus" else Color(0.9, 0.3, 0.3)
		sb.content_margin_left = 14; sb.content_margin_right = 14
		b.add_theme_stylebox_override(st, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(0.2, 0.1, 0.25))
	b.pressed.connect(func():
		Sound.play("click")
		cb.call())
	return b

func _label(text: String, size: int, c := Color.WHITE, b := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", bold if b else font)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.16))
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	return l

func _row(sep := 8) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	return r

func _panel(c: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	return p

## 능력치 막대 다섯 줄 (장신구로 바뀐 칸은 색이 다르다)
func _stats(style: String, acc: String) -> Control:
	var base: Array = Rules.STYLES[style].p
	var now: Array = Rules.derive(style, acc).p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var cols := [Color("ff6a5a"), Color("ffd23a"), Color("5ad0ff"), Color("7ae07a"), Color("b08aff")]
	for i in 5:
		var r := _row(3)
		var name := _label(Rules.PARAMS[i], 18, cols[i], true)
		name.custom_minimum_size = Vector2(56, 0)
		r.add_child(name)
		for k in 10:
			var cr := ColorRect.new()
			cr.custom_minimum_size = Vector2(20, 14)
			var on: bool = k < int(now[i])
			cr.color = cols[i] if on else Color(0.1, 0.06, 0.14, 0.75)
			if on and k >= int(base[i]): cr.color = Color.WHITE
			if not on and k < int(base[i]): cr.color = Color(0.5, 0.2, 0.2)
			var mc := MarginContainer.new()
			mc.add_theme_constant_override("margin_top", 6)
			mc.add_child(cr)
			r.add_child(mc)
		v.add_child(r)
	return v

func _show_preview(style: String, acc: String, pos: Vector3) -> void:
	if preview:
		preview.queue_free()
	preview = Fighter.new()
	add_child(preview)
	preview.build(style)
	preview.equip(acc)
	preview.scale *= 1.25
	preview.position = pos

func _base(cam_x: float) -> VBoxContainer:
	_clear()
	cam.current = true
	cam.fov = 34
	cam.position = Vector3(cam_x, 2.1, 7.6)
	cam.look_at(Vector3(cam_x, 1.05, 0), Vector3.UP)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var v := VBoxContainer.new()
	v.position = Vector2(48, 24)
	v.add_theme_constant_override("separation", 9)
	menu.add_child(v)
	return v

func title() -> void:
	screen = "title"
	var v := _base(2.6)
	Sound.music("title")
	var style: String = save.style
	var acc: String = save.acc
	_show_preview(style, acc, Vector3(4.7, 0, 1.6))
	var head := _row(24)
	head.add_child(_label("파이트 고!", 70, Color(1.0, 0.86, 0.3), true))
	head.add_child(_label("\n● %d" % int(save.coins), 30, Color(1.0, 0.9, 0.4), true))
	v.add_child(head)
	if not last.is_empty():
		var r := "이겼어요!" if last.me else ("%s 승리. 다시 도전!" % last.name if int(last.winner) >= 0 else "무승부!")
		v.add_child(_label("지난 판: %s   K.O. %d번 · ● +%d" % [r, int(last.get("kos", 0)), int(last.get("coins", 0))], 22, Color(0.7, 1.0, 0.75) if last.me else Color(1.0, 0.8, 0.7), true))
	var row := _row()
	for id in Rules.STYLE_IDS:
		row.add_child(_btn(Rules.STYLES[id].name, func(): save.style = id; _store(); title(), id == style))
	v.add_child(row)
	var about := _label(str(Rules.STYLES[style].about), 18, Color(1, 0.97, 0.9))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(620, 0)
	v.add_child(about)
	var pn := _panel(Color(0.1, 0.06, 0.16, 0.6))
	var pr := _row(22)
	pr.add_child(_stats(style, acc))
	var pv := VBoxContainer.new()
	pv.add_child(_label("낀 장신구", 16, Color(0.8, 0.85, 1.0)))
	pv.add_child(_label(str(Rules.ACCS[acc].name), 26, Color(1.0, 0.9, 0.5), true))
	var ab := _label(str(Rules.ACCS[acc].about), 16, Color(1, 0.97, 0.9))
	ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ab.custom_minimum_size = Vector2(290, 0)
	pv.add_child(ab)
	pr.add_child(pv)
	pn.add_child(pr)
	v.add_child(pn)
	var row3 := _row(10)
	var go := _btn("싸우기!", func(): fight(false), false, 220)
	row3.add_child(go)
	row3.add_child(_btn("상점 · 장신구", shop, false, 200))
	row3.add_child(_btn("라이선스", _licenses, false, 130))
	v.add_child(row3)
	v.add_child(_label("방향키 걷기 · 같은 방향 두 번 달리기 · Z 조준 · X 약(연타) · C 강(띄우기) · V 점프\nX+C 막기 · Z+X · Z+C 장신구 기술 · Z+X+C 필살기 · 달리며 X/C 대시 공격 · 달리며 X+C 대시 필살기\n공중 X/C · 공중 X+C 점프 필살기 · 무기 옆에서 X/C 줍기 · 문 앞에서 ↑ 들어가기\n날아가다 땅에 닿기 직전 V 낙법 · 누운 채 X/C 기상 공격 · 누운 상대는 못 때려요", 16, Color(1, 1, 1)))
	go.call_deferred("grab_focus")

func shop() -> void:
	screen = "shop"
	var v := _base(3.4)
	if look_acc == "" or not Rules.ACCS.has(look_acc):
		look_acc = save.acc
	_show_preview(save.style, look_acc, Vector3(6.3, 0, 1.6))
	var head := _row(24)
	head.add_child(_label("상점", 54, Color(1.0, 0.86, 0.3), true))
	head.add_child(_label("\n● %d" % int(save.coins), 28, Color(1.0, 0.9, 0.4), true))
	v.add_child(head)
	v.add_child(_label("장신구를 사서 끼면 Z+X · Z+C 기술과 능력치가 바뀌어요. 싸우면 ●을 벌어요.", 17))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for id in Rules.ACC_IDS:
		var a: Dictionary = Rules.ACCS[id]
		var owned: bool = id in save.owned
		var on: bool = id == save.acc
		var card := _panel(Color(0.3, 0.2, 0.1, 0.8) if id == look_acc else Color(0.1, 0.06, 0.16, 0.66))
		card.custom_minimum_size = Vector2(372, 0)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		var top := _row(10)
		var nm := _label(str(a.name), 22, Color(1.0, 0.9, 0.5) if on else Color.WHITE, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		var mods := ""
		for i in 5:
			if int(a.mod[i]) != 0:
				mods += "%s%+d " % [Rules.PARAMS[i], int(a.mod[i])]
		top.add_child(_label(mods, 14, Color(0.7, 0.95, 1.0)))
		cv.add_child(top)
		var ab := _label(str(a.about), 14, Color(1, 0.97, 0.9))
		ab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ab.custom_minimum_size = Vector2(340, 0)
		cv.add_child(ab)
		var br := _row(8)
		br.add_child(_btn("보기", func(): look_acc = id; shop(), false, 76))
		if on:
			br.add_child(_btn("끼는 중", func(): pass, true, 120))
		elif owned:
			br.add_child(_btn("끼기", func(): save.acc = id; look_acc = id; _store(); shop(), false, 120))
		else:
			br.add_child(_btn("● %d 사기" % int(a.price), func():
				save = Rules.buy(save, id); look_acc = id; _store(); Sound.play("buy"); shop(), false, 170, Rules.can_buy(save, id)))
		for c in br.get_children():
			(c as Button).custom_minimum_size.y = 36
			(c as Button).add_theme_font_size_override("font_size", 17)
		cv.add_child(br)
		card.add_child(cv)
		grid.add_child(card)
	v.add_child(grid)
	var back := _btn("돌아가기", title, false, 180)
	v.add_child(back)
	back.call_deferred("grab_focus")

func _licenses() -> void:
	var l: Control = preload("res://scripts/licenses.gd").new()
	l.credits = [
		"파이트 고! — 유민혁 (minhyuk94)",
		"게임 엔진: Godot Engine (MIT 라이선스) — godotengine.org/license",
		"글꼴: 갈무리 Galmuri (SIL Open Font License 1.1) — github.com/quiple/galmuri",
		"캐릭터 모델·옷: Kenney Animated Characters Protagonists (CC0) — kenney.nl",
		"동작·장신구·무기·무대·효과음·곡: 코드로 새로 만듦",
	]
	l.font_size = 18
	menu.add_child(l)

func fight(demo: bool) -> void:
	_clear()
	screen = "fight"
	game = Match.new()
	game.demo = demo
	add_child(game)
	game.setup(save.style, save.acc)
	var hud: Control = preload("res://scripts/hud.gd").new()
	hud.m = game
	ui.add_child(hud)
	game.done.connect(func(r: Dictionary):
		last = r
		if not demo:
			save.coins = int(save.coins) + int(r.coins)
			save.games = int(save.games) + 1
			if r.me: save.wins = int(save.wins) + 1
			_store()
		title())

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if game:
			last = {}
			title()
		elif screen == "shop":
			title()
