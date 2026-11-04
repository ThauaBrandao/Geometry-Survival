extends Control
## Seleção de fases: o ARQUIPÉLAGO DIMENSIONAL (GDD §10).
## Três ilhas flutuantes (Alpha, Beta, Gamma) com volume, sombra, emblema
## holográfico e estado (bloqueada, disponível, concluída com estrelas),
## ligadas por trilhas de energia. Uma mini Axi-01 marca o próximo destino.
## Mouse ou teclado (←/→ e Enter).

signal sector_chosen(sector: int)
signal back_pressed

const POS := [Vector2(240, 330), Vector2(576, 262), Vector2(912, 330)]

var buttons: Array[Button] = []
var title: Label
var subtitle: Label
var info: Panel
var info_title: Label
var info_sub: Label
var info_status: Label
var info_hint: Label
var btn_back: FxButton
var marker: Axi01
var paths_layer: Control
var _path_progress: Array[float] = [0.0, 0.0]
var _selected := 0
var _t := 0.0
var _unlock_fx: Array[float] = [0.0, 0.0, 0.0]


func _ready() -> void:
	size = Vector2(1152, 648)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = UiKit.label("ARQUIPÉLAGO DIMENSIONAL", 30, Color.WHITE, UiKit.spaced(UiKit.display_bold(), 6), HORIZONTAL_ALIGNMENT_CENTER)
	title.size = Vector2(1152, 40)
	title.position = Vector2(0, 80)
	UiKit.glow(title, Palette.VIOLET, 12)
	add_child(title)
	subtitle = UiKit.label("Escolha um setor e sele as fendas da Entropia", 16, Palette.INK_DIM, UiKit.body(), HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.size = Vector2(1152, 24)
	subtitle.position = Vector2(0, 122)
	add_child(subtitle)

	paths_layer = Control.new()
	paths_layer.size = size
	paths_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paths_layer.draw.connect(_draw_paths)
	add_child(paths_layer)

	for i in 3:
		var b := Button.new()
		b.flat = true
		b.size = Vector2(230, 230)
		b.position = POS[i] - Vector2(115, 125)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, empty)
		var idx := i
		b.pressed.connect(func(): _choose(idx))
		b.mouse_entered.connect(func(): _select(idx, true))
		b.focus_entered.connect(func(): _select(idx, false))
		b.draw.connect(_draw_island.bind(b, i))
		add_child(b)
		buttons.append(b)

	marker = Axi01.new()
	marker.show_platform = false
	marker.scale = Vector2(0.42, 0.42)
	add_child(marker)

	info = Panel.new()
	info.position = Vector2(326, 500)
	info.size = Vector2(500, 112)
	info.add_theme_stylebox_override("panel", UiKit.glass(Palette.PANEL, Palette.EDGE, 16))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	info_title = UiKit.label("", 20, Color.WHITE, UiKit.spaced(UiKit.display_bold(), 3))
	info_title.position = Vector2(22, 14)
	info.add_child(info_title)
	info_sub = UiKit.label("", 15, Palette.INK_DIM, UiKit.body())
	info_sub.position = Vector2(22, 44)
	info.add_child(info_sub)
	info_status = UiKit.label("", 14, Palette.INK, UiKit.body_bold())
	info_status.position = Vector2(22, 72)
	info.add_child(info_status)
	info_hint = UiKit.label("", 13, Palette.CYAN, UiKit.spaced(UiKit.body_bold(), 2), HORIZONTAL_ALIGNMENT_RIGHT)
	info_hint.position = Vector2(250, 76)
	info_hint.size = Vector2(230, 20)
	info.add_child(info_hint)

	btn_back = FxButton.make("MENU", "back", false, Vector2(130, 44))
	btn_back.position = Vector2(24, 584)
	btn_back.sfx_press = "ui_back"
	btn_back.pressed.connect(func(): emit_signal("back_pressed"))
	add_child(btn_back)
	refresh()


## Atualiza estados; chamada ao entrar no mapa.
func refresh() -> void:
	for i in 3:
		buttons[i].disabled = not GameManager.is_sector_available(i)
	for i in 2:
		_path_progress[i] = 1.0 if GameManager.is_sector_unlocked(i + 1) else 0.0
	var nxt := _next_available()
	_selected = maxi(nxt, 0)
	_place_marker(false)
	_update_info()
	for b in buttons:
		b.queue_redraw()


func focus_default() -> void:
	var nxt := _next_available()
	if nxt >= 0:
		buttons[nxt].grab_focus()


func _next_available() -> int:
	for i in 3:
		if GameManager.is_sector_available(i):
			return i
	return -1


func _place_marker(animate: bool) -> void:
	var nxt := _next_available()
	marker.visible = nxt >= 0
	if nxt < 0:
		return
	var p: Vector2 = POS[nxt] + Vector2(-112, -70)
	if animate:
		var tw := create_tween()
		tw.tween_property(marker, "position", marker.position + Vector2(0, -30), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(marker, "position", p, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		marker.position = p


## Animação de desbloqueio: a trilha se desenha até a nova ilha.
func play_unlock(sector: int) -> void:
	if sector <= 0 or sector > 2:
		return
	_path_progress[sector - 1] = 0.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_method(func(v): _path_progress[sector - 1] = v, 0.0, 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		AudioManager.play("unlock")
		_unlock_fx[sector] = 1.0
		Fx.burst(self, POS[sector] + Vector2(0, -20), Palette.sector(sector).main, 60, 320.0, 1.0)
		Fx.shockwave(self, POS[sector] + Vector2(0, -20), Palette.sector(sector).main, 170.0, 0.7, 4.0)
		Fx.float_text(self, POS[sector] + Vector2(0, 10), "SETOR LIBERADO!", Palette.GOLD, 22, 40.0, 1.6))
	tw.tween_method(func(v): _unlock_fx[sector] = v, 1.0, 0.0, 1.2)
	marker.position = POS[sector - 1] + Vector2(-112, -70)
	_place_marker(true)


func _select(i: int, from_mouse: bool) -> void:
	if _selected != i:
		_selected = i
		if from_mouse:
			AudioManager.play("ui_hover")
	_update_info()


func _choose(i: int) -> void:
	if not GameManager.is_sector_available(i):
		AudioManager.play("soft_error")
		Fx.shake_control(buttons[i], 6.0, 0.3)
		return
	AudioManager.play("ui_select")
	emit_signal("sector_chosen", i)


func _update_info() -> void:
	var i := _selected
	var s := Palette.sector(i)
	info_title.text = s.name.to_upper()
	info_title.add_theme_color_override("font_color", s.main.lerp(Color.WHITE, 0.3))
	info_sub.text = "%s  ·  %s" % [s.title, s.content]
	var st := GameManager.stats_for_sector(i)
	if GameManager.sectors_completed[i]:
		info_status.text = "Concluído  ·  %d de %d fendas seladas" % [st.x, st.y]
		info_status.add_theme_color_override("font_color", Palette.GOLD)
		info_hint.text = ""
	elif GameManager.is_sector_unlocked(i):
		info_status.text = "Disponível  ·  3 fendas a selar"
		info_status.add_theme_color_override("font_color", Palette.SUCCESS)
		info_hint.text = "ENTER / CLIQUE PARA ENTRAR"
	else:
		info_status.text = "Bloqueado  ·  conclua o setor anterior"
		info_status.add_theme_color_override("font_color", Palette.INK_FAINT)
		info_hint.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		emit_signal("back_pressed")


func _process(delta: float) -> void:
	_t += delta * (0.3 + 0.7 * Settings.motion())
	paths_layer.queue_redraw()
	for b in buttons:
		b.queue_redraw()
	var pulse := sin(_t * 3.0) * 0.5 + 0.5
	info_hint.modulate.a = 0.55 + 0.45 * pulse


# ------------------------------------------------------------------ desenho
func _bez(a: Vector2, b: Vector2, t: float) -> Vector2:
	var ctrl := (a + b) / 2.0 + Vector2(0, 70)
	return a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)


func _draw_paths() -> void:
	for i in 2:
		var a: Vector2 = POS[i] + Vector2(0, 30)
		var b: Vector2 = POS[i + 1] + Vector2(0, 30)
		# trilha apagada
		var n := 40
		for k in n:
			if k % 2 == 1:
				continue
			paths_layer.draw_line(_bez(a, b, float(k) / n), _bez(a, b, float(k + 1) / n), Color(1, 1, 1, 0.12), 2.0)
		# trilha acesa até o progresso
		var prog := _path_progress[i]
		if prog > 0.0:
			var col: Color = Palette.sector(i + 1).main
			var pts := PackedVector2Array()
			var m := int(n * prog)
			for k in m + 1:
				pts.append(_bez(a, b, float(k) / n))
			Icons.glow_polyline(paths_layer, pts, Color(col.r, col.g, col.b, 0.85), 2.0, 1.2)
			# pulsos de energia correndo pela trilha
			if prog >= 1.0:
				for j in 3:
					var tt := fmod(_t * 0.35 + j / 3.0, 1.0)
					var p := _bez(a, b, tt)
					Icons.soft_light(paths_layer, p, 10.0, Color(1, 1, 1, 0.6), 3)


func _draw_island(b: Button, i: int) -> void:
	var s := Palette.sector(i)
	var col: Color = s.main
	var done: bool = GameManager.sectors_completed[i]
	var unlocked := GameManager.is_sector_unlocked(i)
	var sel := _selected == i
	var c := Vector2(115, 125) + Vector2(0, sin(_t * 1.4 + i * 1.7) * 7.0)
	if not unlocked:
		col = Color(0.35, 0.38, 0.48)
	var hover := 1.0 if sel and unlocked else 0.0
	# sombra projetada abaixo (profundidade)
	b.draw_set_transform(Vector2(115, 225), 0, Vector2(1.0, 0.22))
	b.draw_circle(Vector2.ZERO, 70.0 - (c.y - 125) * 0.8, Color(0, 0, 0, 0.35))
	b.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# luz do setor
	if unlocked:
		Icons.soft_light(b, c + Vector2(0, -10), 110.0 + 12.0 * hover, Color(col.r, col.g, col.b, 0.22 + 0.12 * hover), 6)
	# rocha: base facetada (lateral escura) + topo claro
	var top := PackedVector2Array()
	for k in 8:
		var a := k * TAU / 8.0 + PI / 8.0
		top.append(c + Vector2(cos(a) * 88.0, sin(a) * 26.0 + 22.0))
	var under := PackedVector2Array([top[0], top[1], top[2], top[3], c + Vector2(-40, 70), c + Vector2(-8, 104), c + Vector2(20, 80), c + Vector2(52, 60)])
	b.draw_colored_polygon(under, Color(0.05, 0.06, 0.12))
	b.draw_polyline(PackedVector2Array([top[3], c + Vector2(-40, 70), c + Vector2(-8, 104), c + Vector2(20, 80), c + Vector2(52, 60), top[0]]),
		Color(col.r, col.g, col.b, 0.25), 1.5, true)
	b.draw_colored_polygon(top, Color(0.08, 0.12, 0.22).lerp(col, 0.15))
	var tl := top.duplicate()
	tl.append(tl[0])
	Icons.glow_polyline(b, tl, Color(col.r, col.g, col.b, 0.9 if unlocked else 0.4), 2.0, 0.6 + hover)
	# anel de seleção
	if sel and unlocked and not done:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		b.draw_set_transform(c + Vector2(0, 22), 0, Vector2(1.0, 0.3))
		b.draw_arc(Vector2.ZERO, 100.0 + pulse * 8.0, 0, TAU, 48, Color(col.r, col.g, col.b, 0.8 - pulse * 0.5), 2.0, true)
		b.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# emblema holográfico flutuante
	var e := c + Vector2(0, -44)
	var rot := _t * 0.6
	var ecol := Palette.GOLD if done else col
	match i:
		0:
			var tri := PackedVector2Array()
			for k in 4:
				var a := rot - PI / 2 + k * TAU / 3.0
				tri.append(e + Vector2(cos(a), sin(a)) * 30.0)
			Icons.glow_polyline(b, tri, ecol, 2.5, 1.0)
			b.draw_rect(Rect2(e - Vector2(11, 11) + Vector2(0, 6), Vector2(22, 22)), Color(ecol.r, ecol.g, ecol.b, 0.5), false, 1.5)
		1:
			Icons.glow_circle(b, e, 28.0, ecol, 2.5, 1.0)
			b.draw_line(e, e + Vector2(cos(rot), sin(rot)) * 28.0, Color(ecol.r, ecol.g, ecol.b, 0.7), 1.5)
			b.draw_circle(e, 3.0, ecol)
		2:
			var rr := Rect2(e + Vector2(-22, -4), Vector2(44, 26))
			b.draw_rect(rr, Color(ecol.r, ecol.g, ecol.b, 0.9), false, 2.5)
			b.draw_arc(e + Vector2(0, -4), 22.0, PI, TAU, 24, ecol, 2.5, true)
	# feixe entre emblema e ilha
	b.draw_line(e + Vector2(0, 30), c + Vector2(0, 14), Color(ecol.r, ecol.g, ecol.b, 0.25), 6.0)
	# selo de estado
	if not unlocked:
		Icons.draw(b, "lock", c + Vector2(0, 20), 26.0, Color(0.75, 0.78, 0.88))
	elif done:
		var st := GameManager.stats_for_sector(i)
		for k in 3:
			Icons.draw(b, "star" if k < st.x else "star_empty", c + Vector2(-30 + k * 30, 22), 20.0, Palette.GOLD, 1.5)
	# nome
	var f := UiKit.spaced(UiKit.display_bold(), 3)
	b.draw_string_outline(f, Vector2(0, 222), s.key, HORIZONTAL_ALIGNMENT_CENTER, 230, 18, 6, Color(0, 0, 0, 0.8))
	b.draw_string(f, Vector2(0, 222), s.key, HORIZONTAL_ALIGNMENT_CENTER, 230, 18, col.lerp(Color.WHITE, 0.3 + 0.4 * hover))
	if _unlock_fx[i] > 0.01:
		Icons.soft_light(b, c, 160.0, Color(1, 1, 1, 0.5 * _unlock_fx[i]), 5)
