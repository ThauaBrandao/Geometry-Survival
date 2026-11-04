extends CanvasLayer
## HUD (GDD §12): barra de vidro no topo.
##   esquerda: pausa · pontuação animada (contagem) · recorde
##   centro:  setor atual + barra de progresso das ondas (segmentos)
##   direita: sequência de acertos · vidas (corações vetoriais que se partem)
## Modos: "hidden", "map" (sem barra de ondas) e "encounter".

signal pause_pressed

var root: Control
var bar: Panel
var draw_layer: Control
var score_label: Label
var record_label: Label
var sector_label: Label
var wave_label: Label
var streak_chip: Label
var btn_pause: FxButton
var mode := "hidden"

var shown_score: float = 0.0
var _last_tick_score := 0
var _lives_shown: int = 3
var _heart_pulse: Array[float] = [0.0, 0.0, 0.0]
var _broken: Array = []          # metades de corações caindo
var _wave_fill: Array[float] = [0.0, 0.0, 0.0]
var _wave_state: Array[int] = [0, 0, 0]   # 0 futuro, 1 atual, 2 acerto, 3 erro
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.size = Vector2(1152, 80)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	bar = Panel.new()
	bar.position = Vector2(12, 10)
	bar.size = Vector2(1128, 56)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", UiKit.glass(Color(0.03, 0.05, 0.12, 0.78), Color(1, 1, 1, 0.08), 14))
	root.add_child(bar)
	draw_layer = Control.new()
	draw_layer.size = root.size
	draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_layer.draw.connect(_draw_hud)
	root.add_child(draw_layer)

	btn_pause = FxButton.make("", "pause", false, Vector2(44, 40))
	btn_pause.position = Vector2(20, 18)
	btn_pause.tooltip_text = "Pausar (Esc)"
	btn_pause.pressed.connect(func(): emit_signal("pause_pressed"))
	root.add_child(btn_pause)

	var cap := UiKit.caption("PONTUAÇÃO", Palette.INK_DIM, 10)
	cap.position = Vector2(78, 16)
	root.add_child(cap)
	score_label = UiKit.label("0", 26, Color.WHITE, UiKit.numbers())
	score_label.position = Vector2(77, 25)
	UiKit.glow(score_label, Palette.CYAN, 6)
	root.add_child(score_label)
	record_label = UiKit.label("RECORDE 0", 11, Palette.GOLD, UiKit.spaced(UiKit.body_bold(), 2))
	record_label.position = Vector2(210, 38)
	root.add_child(record_label)

	sector_label = UiKit.label("", 13, Palette.INK, UiKit.spaced(UiKit.display_bold(), 3), HORIZONTAL_ALIGNMENT_CENTER)
	sector_label.size = Vector2(460, 20)
	sector_label.position = Vector2(346, 15)
	root.add_child(sector_label)
	wave_label = UiKit.label("", 11, Palette.INK_DIM, UiKit.spaced(UiKit.body_bold(), 2))
	wave_label.position = Vector2(724, 38)
	root.add_child(wave_label)

	streak_chip = UiKit.label("", 12, Palette.BG_DEEP, UiKit.spaced(UiKit.display_bold(), 2), HORIZONTAL_ALIGNMENT_CENTER)
	streak_chip.add_theme_stylebox_override("normal", UiKit.pill(Palette.GOLD, Color(0, 0, 0, 0), 9))
	streak_chip.position = Vector2(810, 24)
	streak_chip.visible = false
	root.add_child(streak_chip)

	var lives_cap := UiKit.caption("VIDAS", Palette.INK_DIM, 10)
	lives_cap.position = Vector2(1000, 16)
	root.add_child(lives_cap)

	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.wave_changed.connect(func(_w, _s): refresh_waves())
	GameManager.encounter_result.connect(_on_result)
	set_mode("hidden", false)


func set_mode(m: String, animate: bool = true) -> void:
	mode = m
	var show := m != "hidden"
	sector_label.visible = true
	wave_label.visible = m == "encounter"
	btn_pause.visible = m == "encounter"
	if m == "map":
		sector_label.text = "SELEÇÃO DE SETOR"
		sector_label.add_theme_color_override("font_color", Palette.INK)
	if animate:
		var tw := create_tween()
		tw.tween_property(root, "position:y", 0.0 if show else -90.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		root.position.y = 0.0 if show else -90.0
	sync_now()


func sync_now() -> void:
	shown_score = GameManager.score
	_last_tick_score = GameManager.score
	score_label.text = str(GameManager.score)
	record_label.text = "RECORDE %d" % GameManager.best_score
	_lives_shown = GameManager.lives
	refresh_waves()


func refresh_waves() -> void:
	var s := GameManager.current_sector
	var info := Palette.sector(s)
	if mode == "encounter":
		sector_label.text = "%s  ·  %s" % [info.name.to_upper(), info.title.to_upper()]
		sector_label.add_theme_color_override("font_color", info.main.lerp(Color.WHITE, 0.35))
	var w := GameManager.current_wave
	wave_label.text = "ONDA %d/%d" % [mini(w, 3), GameRules.WAVES_PER_SECTOR]
	var list := GameManager.current_sector_attempts()
	for i in 3:
		var res = null
		for at in list:
			if int(at.wave) == i + 1:
				res = at
		if res != null:
			_wave_state[i] = 2 if res.success else 3
		elif i == w - 1:
			_wave_state[i] = 1
		else:
			_wave_state[i] = 0
		var target := 1.0 if _wave_state[i] >= 2 else (0.35 if _wave_state[i] == 1 else 0.0)
		create_tween().tween_method(func(v): _wave_fill[i] = v, _wave_fill[i], target, 0.5)


func _on_result(success: bool, _high: bool) -> void:
	refresh_waves()
	var st := GameManager.streak
	if success and st >= 2:
		streak_chip.text = "SEQUÊNCIA ×%d" % st
		streak_chip.visible = true
		streak_chip.pivot_offset = streak_chip.size / 2.0
		Fx.pop(streak_chip, 0.3, 0.4)
	elif not success:
		streak_chip.visible = false


func _on_score_changed(v: int) -> void:
	record_label.text = "RECORDE %d" % GameManager.best_score
	var tw := create_tween()
	tw.tween_property(self, "shown_score", float(v), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if v > _last_tick_score:
		Fx.pop(score_label, 0.25, 0.4)


func _on_lives_changed(v: int) -> void:
	if v < _lives_shown:
		for i in range(v, _lives_shown):
			var c := _heart_center(i)
			_broken.append({"c": c, "t": 0.0})
		_flash = 1.0
		Fx.shake_control(bar, 8.0, 0.35)
	_lives_shown = v


func _heart_center(i: int) -> Vector2:
	return Vector2(1004 + i * 36, 45)


func _process(delta: float) -> void:
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 2.0)
	var s := int(round(shown_score))
	if score_label.text != str(s):
		score_label.text = str(s)
		if s - _last_tick_score >= 10:
			AudioManager.play("tick", 1.0 + (s % 100) / 200.0, -6.0)
			_last_tick_score = s
	for b in _broken:
		b.t += delta
	_broken = _broken.filter(func(b): return b.t < 1.0)
	draw_layer.queue_redraw()


func _draw_hud() -> void:
	var ci := draw_layer
	var off := bar.position + Vector2(-12, -10) + Vector2(0, 0)
	if _flash > 0.01:
		var r := Rect2(bar.position, bar.size)
		ci.draw_rect(r.grow(2), Color(1, 0.2, 0.3, 0.25 * _flash), false, 3.0)
	# barra de ondas
	if mode == "encounter":
		var col: Color = Palette.sector(GameManager.current_sector).main
		for i in 3:
			var r := Rect2(Vector2(462 + i * 80, 40) + off - Vector2(0, 0), Vector2(72, 8))
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(4)
			sb.bg_color = Color(1, 1, 1, 0.08)
			ci.draw_style_box(sb, r)
			var fill := r
			fill.size.x = r.size.x * _wave_fill[i]
			if fill.size.x > 1.0:
				var fc := col
				if _wave_state[i] == 2:
					fc = Palette.GOLD
				elif _wave_state[i] == 3:
					fc = Palette.INK_FAINT
				elif _wave_state[i] == 1:
					fc = Color(col.r, col.g, col.b, 0.6 + 0.4 * sin(_t * 5.0))
				sb.bg_color = fc
				ci.draw_style_box(sb, fill)
	# vidas
	if mode != "hidden":
		for i in 3:
			var c := _heart_center(i)
			if i < _lives_shown:
				var beat: float = 1.0 + (0.12 * max(0.0, sin(_t * 7.0)) if _lives_shown == 1 else 0.0)
				var hc := Palette.DANGER
				Icons.soft_light(ci, c, 18.0, Color(hc.r, hc.g, hc.b, 0.25), 3)
				Icons.draw(ci, "heart", c, 22.0 * beat, hc)
			else:
				Icons.draw(ci, "heart_empty", c, 22.0, Color(1, 1, 1, 0.2), 1.5)
		for b in _broken:
			var t: float = b.t
			for side in [-1.0, 1.0]:
				var pts := Icons.heart_points(Vector2.ZERO, 22.0)
				var half := PackedVector2Array()
				for p in pts:
					if p.x * side >= -0.5:
						half.append(p)
				var xf := Transform2D(side * t * 1.5, b.c + Vector2(side * t * 26.0, t * t * 90.0))
				var tp := PackedVector2Array()
				for p in half:
					tp.append(xf * p)
				if tp.size() >= 3:
					ci.draw_colored_polygon(tp, Color(1, 0.25, 0.35, 1.0 - t))
