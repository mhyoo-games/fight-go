extends Node3D
## 처음 화면(유형·장신구 고르기) ↔ 싸움 ↔ 결과
## 개발용: -- --shot=title|fight|result --out=/tmp/x.png  (fight는 컴퓨터끼리 싸우는 장면)

var stage: RooftopStage
var ui: CanvasLayer
var menu: Control
var game: Match
var preview: Fighter
var cam: Camera3D
var style := "brawler"
var acc := "none"
var font: Font
var bold: Font
var last := {}

func _ready() -> void:
	font = load("res://assets/fonts/Galmuri11.ttf")
	bold = load("res://assets/fonts/Galmuri11-Bold.ttf")
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 20
	get_tree().root.theme = th
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

func _dev(shot: String, out: String) -> void:
	await get_tree().create_timer(0.6).timeout
	if shot == "title2":
		style = "psychic"; acc = "bat"; title()
	if shot.begins_with("fight"):
		fight(true)
		await get_tree().create_timer(float(shot.substr(5)) if shot.length() > 5 else 6.0).timeout
	elif shot == "result":
		last = {"winner": 0, "name": "나", "me": true, "hp": 42.0, "outs": 1}
		title()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()

func _clear() -> void:
	for c in ui.get_children():
		c.queue_free()
	if game:
		game.queue_free()
		game = null
	if preview:
		preview.queue_free()
		preview = null

func _btn(text: String, cb: Callable, on := false, w := 150) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 48)
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.86, 0.35) if on else (Color(1, 1, 1, 0.95) if st != "hover" else Color(1.0, 0.95, 0.75))
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(4)
		sb.border_color = Color(0.25, 0.14, 0.3) if st != "focus" else Color(0.9, 0.3, 0.3)
		sb.content_margin_left = 14; sb.content_margin_right = 14
		b.add_theme_stylebox_override(st, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
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

func title() -> void:
	_clear()
	Sound.music("title")
	cam.current = true
	cam.position = Vector3(2.6, 2.2, 7.2)
	cam.look_at(Vector3(2.6, 1.0, 0), Vector3.UP)
	preview = Fighter.new()
	add_child(preview)
	preview.build(Match.look_for(style))
	preview.equip(acc)
	preview.scale = Vector3.ONE * float(Match.SCALES[style]) * 1.25
	preview.position = Vector3(4.6, 0, 1.6)
	preview.rotation.y = -0.45
	preview.pose("aim" if acc != "none" else "guard", false, true)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var v := VBoxContainer.new()
	v.position = Vector2(56, 30)
	v.add_theme_constant_override("separation", 10)
	menu.add_child(v)
	v.add_child(_label("파이트 고!", 76, Color(1.0, 0.86, 0.3), true))
	if not last.is_empty():
		var r := "이겼어요! 남은 체력 %d" % int(last.hp) if last.me else ("%s 승리. 다시 도전!" % last.name if int(last.winner) >= 0 else "무승부!")
		v.add_child(_label("지난 판: " + r, 24, Color(0.7, 1.0, 0.75) if last.me else Color(1.0, 0.75, 0.7), true))
	v.add_child(_label("유형", 22, Color.WHITE, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for id in Rules.STYLE_IDS:
		row.add_child(_btn(Rules.STYLES[id].name, func(): style = id; title(), id == style))
	v.add_child(row)
	var st: Dictionary = Rules.STYLES[style]
	var about := _label(str(st.about), 18, Color(1, 0.97, 0.9))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(640, 0)
	v.add_child(about)
	v.add_child(_label("체력 %d · 빠르기 %.1f · 힘 %.0f%% · 맷집 %.0f%% · 점프 %d번" % [int(st.hp), float(st.speed), float(st.power) * 100, float(st.def) * 100, int(st.jumps)], 17, Color(0.85, 0.9, 1.0)))
	v.add_child(_label("장신구", 22, Color.WHITE, true))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	for id in Rules.ACC_IDS:
		row2.add_child(_btn(Rules.ACCS[id].name, func(): acc = id; title(), id == acc))
	v.add_child(row2)
	v.add_child(_label(str(Rules.ACCS[acc].about), 18, Color(1, 0.97, 0.9)))
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	var go := _btn("싸우기! (컴퓨터 3명과)", func(): fight(false), false, 330)
	row3.add_child(go)
	row3.add_child(_btn("라이선스", _licenses, false, 130))
	v.add_child(row3)
	var help := _label("방향키 이동 · Z 조준 · X 약공격(연타) · C 강공격 · V 점프\nZ+X · Z+C 장신구 기술 · Z+X+C 필살기(게이지 절반) · 공중 X/C · 공중 X+C 점프 필살기\n옥상 밖으로 떨어지면 체력이 크게 줄어요", 17, Color(1, 1, 1))
	v.add_child(help)
	go.call_deferred("grab_focus")

func _licenses() -> void:
	var l: Control = preload("res://scripts/licenses.gd").new()
	l.credits = [
		"파이트 고! — 유민혁 (minhyuk94)",
		"게임 엔진: Godot Engine (MIT 라이선스) — godotengine.org/license",
		"글꼴: 갈무리 Galmuri (SIL Open Font License 1.1) — github.com/quiple/galmuri",
		"캐릭터·무대·효과음·곡: 코드로 새로 만듦",
	]
	l.font_size = 18
	menu.add_child(l)

func fight(demo: bool) -> void:
	_clear()
	game = Match.new()
	game.demo = demo
	add_child(game)
	game.setup(style, acc)
	var hud: Control = preload("res://scripts/hud.gd").new()
	hud.m = game
	ui.add_child(hud)
	game.done.connect(func(r: Dictionary):
		last = r
		title())

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and game:
		last = {}
		title()
