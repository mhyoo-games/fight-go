extends Control
## 싸움 화면 위: 남은 시간, 선수별 체력·게이지, 가운데 글

var m: Match
var font: Font
var bold: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/fonts/Galmuri11.ttf")
	bold = load("res://assets/fonts/Galmuri11-Bold.ttf")

func _process(_dt: float) -> void:
	queue_redraw()

func _txt(s: String, pos: Vector2, size: int, c := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(bold, pos, s, align, width, size, maxi(4, size / 5), Color(0.08, 0.05, 0.12, 0.95))
	draw_string(bold, pos, s, align, width, size, c)

func _bar(r: Rect2, v: float, c: Color) -> void:
	draw_rect(r.grow(3), Color(0.08, 0.05, 0.12, 0.9))
	draw_rect(r, Color(0.25, 0.22, 0.3))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), c)

func _draw() -> void:
	if m == null:
		return
	var W := size.x
	var H := size.y
	var u := clampf(minf(W / 1280.0, H / 720.0), 0.5, 1.6)
	_txt("%d" % int(ceil(maxf(m.time_left, 0.0))), Vector2(0, 62 * u), int(52 * u), Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER, W)
	var n: int = m.fs.size()
	var bw := 250.0 * u
	var gap := (W - bw * n) / (n + 1)
	for i in n:
		var f: Dictionary = m.fs[i]
		var x := gap + i * (bw + gap)
		var y := H - 86 * u
		var alive := Rules.alive(f)
		var st: Dictionary = Rules.STYLES[f.style]
		draw_rect(Rect2(x - 10 * u, y - 34 * u, bw + 20 * u, 108 * u), Color(0.08, 0.05, 0.14, 0.62))
		_txt("%s  %s" % [m.names[i], st.name], Vector2(x, y - 6 * u), int(22 * u), (Color(1, 0.9, 0.3) if i == m.human and not m.demo else Color.WHITE) if alive else Color(0.6, 0.6, 0.6))
		var hp := float(f.hp) / float(f.max_hp)
		_bar(Rect2(x, y + 6 * u, bw, 20 * u), hp, Color(0.35, 0.85, 0.4).lerp(Color(0.95, 0.3, 0.25), 1.0 - hp))
		var g := float(f.gauge) / 100.0
		_bar(Rect2(x, y + 36 * u, bw, 12 * u), g, Color(1.0, 0.8, 0.2) if float(f.gauge) >= Rules.SUPER_COST else Color(0.4, 0.7, 1.0))
		draw_rect(Rect2(x + bw * 0.5 - 1, y + 34 * u, 2, 16 * u), Color(1, 1, 1, 0.7))
		var gd := float(f.guard) / float(f.S.guard)
		if gd < 0.99 and alive:
			_bar(Rect2(x, y + 52 * u, bw * 0.5, 5 * u), gd, Color(0.7, 0.9, 1.0))
		if not alive:
			_txt("탈락", Vector2(x, y + 28 * u), int(26 * u), Color(1, 0.4, 0.4), HORIZONTAL_ALIGNMENT_CENTER, bw)
		else:
			var held := str(f.held)
			var line: String = Rules.ACCS[f.acc].name
			if held != "":
				line = "%s ×%d" % [Rules.WEAPONS[held].name, maxi(0, int(f.uses))]
			_txt(line, Vector2(x, y + 68 * u), int(15 * u), Color(1.0, 0.85, 0.4) if held != "" else Color(0.85, 0.9, 1.0))
	if m.combo_t > 0.0 and m.combo_n >= 2:
		_txt("%d 콤보!" % m.combo_n, Vector2(40 * u, H * 0.3), int((40 + mini(m.combo_n, 8) * 3) * u), Color(1.0, 0.6, 0.2, clampf(m.combo_t / 0.3, 0.0, 1.0)))
	if not m.demo and m.intro <= 0.0:
		var me: Dictionary = m.fs[m.human]
		if str(me.held) == "" and Rules.alive(me):
			for it in m.w.items:
				if (it.pos as Vector3).distance_to(me.pos) < 1.2:
					_txt("X 또는 C: %s 줍기" % (Rules.WEAPONS[it.kind].name if it.kind != "food" else "도시락"), Vector2(0, H * 0.62), int(24 * u), Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER, W)
		for d in m.w.stage.doors:
			if (d.at as Vector3).distance_to(me.pos) < 1.0 and Rules.alive(me):
				_txt("↑ 문으로 들어가기", Vector2(0, H * 0.66), int(24 * u), Color(0.7, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
	if m.intro > 0.0:
		_txt("준비!", Vector2(0, H * 0.4), int(90 * u), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, W)
	elif m.msg_t > 0.0:
		_txt(m.msg, Vector2(0, H * 0.36), int(64 * u), Color(1, 0.92, 0.4, clampf(m.msg_t / 0.3, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, W)
