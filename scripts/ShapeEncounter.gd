extends Control
## Tela de Encontro (GDD §4, §12). A cada onda:
##   faixa "ONDA n/3" → a FENDA se abre → a Forma Caótica é construída →
##   Geo analisa o risco → o jogador calcula e confirma →
##   Axi-01 dispara o feixe → fenda SELADA (acerto) ou fenda que
##   RESISTE / SE EXPANDE (erro), com resolução passo a passo.
## Regras continuam no GameManager; esta tela só apresenta.

signal ready_for_input
signal result_shown
signal request_shake(strength: float, dur: float)

const RIFT_POS := Vector2(640, 252)

var stage: Node2D
var axi: Axi01
var rift: Rift
var shape_display: Node2D
var geo: GeoDrone
var banner: Label
var banner_sub: Label
var console: Panel
var geo_label: Label
var solution_box: Panel
var solution_label: Label
var formula_hint: Label
var answer_input: LineEdit
var btn_confirm: FxButton
var btn_next: FxButton
var gauge: RiskGauge
var risk_value: Label
var risk_note: Label
var feedback_label: Label   # = banner (compatibilidade)

var accepting := false
var busy := false
var _type_tw: Tween


func _ready() -> void:
	size = Vector2(1152, 648)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = Node2D.new()
	add_child(stage)
	rift = Rift.new()
	rift.position = RIFT_POS
	stage.add_child(rift)
	axi = Axi01.new()
	axi.position = Vector2(205, 318)
	stage.add_child(axi)
	shape_display = load("res://scripts/ShapeDisplay.gd").new()
	shape_display.position = RIFT_POS
	stage.add_child(shape_display)

	banner = UiKit.label("", 40, Color.WHITE, UiKit.spaced(UiKit.display_bold(), 4), HORIZONTAL_ALIGNMENT_CENTER)
	banner.size = Vector2(1152, 56)
	banner.position = Vector2(0, 76)
	banner.pivot_offset = banner.size / 2.0
	UiKit.outline(banner, Color(0, 0, 0, 0.9), 10)
	add_child(banner)
	banner_sub = UiKit.label("", 17, Palette.INK, UiKit.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	banner_sub.size = Vector2(1152, 26)
	banner_sub.position = Vector2(0, 128)
	UiKit.outline(banner_sub, Color(0, 0, 0, 0.9), 6)
	add_child(banner_sub)
	feedback_label = banner

	_build_console()
	_hide_banner(true)
	GameManager.encounter_result.connect(on_result)


func _build_console() -> void:
	console = Panel.new()
	console.position = Vector2(16, 450)
	console.size = Vector2(1120, 186)
	console.add_theme_stylebox_override("panel", UiKit.glass(Color(0.03, 0.05, 0.12, 0.86), Color(1, 1, 1, 0.08), 16))
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(console)
	# divisórias
	for x in [456.0, 800.0]:
		var d := ColorRect.new()
		d.color = Color(1, 1, 1, 0.06)
		d.size = Vector2(1, 150)
		d.position = Vector2(x, 18)
		console.add_child(d)

	# --- Geo
	geo = GeoDrone.new()
	geo.position = Vector2(46, 44)
	console.add_child(geo)
	var gcap := UiKit.caption("GEO  ·  IA ANALÍTICA", Palette.CYAN, 11)
	gcap.position = Vector2(84, 14)
	console.add_child(gcap)
	geo_label = UiKit.label("", 15, Palette.INK, UiKit.body())
	geo_label.position = Vector2(84, 32)
	geo_label.size = Vector2(360, 60)
	geo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	console.add_child(geo_label)
	solution_box = Panel.new()
	solution_box.position = Vector2(16, 96)
	solution_box.size = Vector2(428, 76)
	solution_box.add_theme_stylebox_override("panel", UiKit.glass(Color(0.1, 0.08, 0.02, 0.55), Color(1, 0.79, 0.29, 0.45), 10))
	console.add_child(solution_box)
	var scap := UiKit.caption("RESOLUÇÃO", Palette.GOLD, 10)
	scap.position = Vector2(12, 7)
	solution_box.add_child(scap)
	solution_label = UiKit.label("", 15, Color(1, 0.95, 0.8), UiKit.body_bold())
	solution_label.position = Vector2(12, 24)
	solution_label.size = Vector2(404, 48)
	solution_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	solution_box.add_child(solution_label)

	# --- resposta
	formula_hint = UiKit.label("", 15, Palette.GOLD, UiKit.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	formula_hint.position = Vector2(472, 12)
	formula_hint.size = Vector2(312, 30)
	formula_hint.add_theme_stylebox_override("normal", UiKit.pill(Color(1, 0.79, 0.29, 0.08), Color(1, 0.79, 0.29, 0.35), 8))
	formula_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	console.add_child(formula_hint)
	var acap := UiKit.caption("ÁREA", Palette.INK_DIM, 11)
	acap.position = Vector2(474, 70)
	console.add_child(acap)
	answer_input = LineEdit.new()
	answer_input.position = Vector2(522, 54)
	answer_input.size = Vector2(196, 52)
	answer_input.placeholder_text = "0,0"
	answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer_input.max_length = 12
	answer_input.text_submitted.connect(_on_text_submitted)
	answer_input.text_changed.connect(func(_t): AudioManager.play("type", randf_range(0.9, 1.15), -4.0))
	console.add_child(answer_input)
	var ucap := UiKit.label("u²", 22, Palette.INK_DIM, UiKit.body_bold())
	ucap.position = Vector2(730, 64)
	console.add_child(ucap)
	btn_confirm = FxButton.make("SELAR FENDA  ·  ENTER", "", true, Vector2(312, 50))
	btn_confirm.position = Vector2(472, 120)
	btn_confirm.sfx_press = "charge"
	btn_confirm.pressed.connect(_on_confirm_pressed)
	console.add_child(btn_confirm)
	btn_next = FxButton.make("PRÓXIMA ONDA  →", "", true, Vector2(312, 50))
	btn_next.accent = Palette.GOLD
	btn_next.position = Vector2(472, 120)
	btn_next.pressed.connect(_on_next_pressed)
	console.add_child(btn_next)
	btn_next._apply_style()
	btn_next.visible = false

	# --- risco
	var rcap := UiKit.caption("RISCO DE COLAPSO", Palette.INK_DIM, 11)
	rcap.position = Vector2(816, 14)
	rcap.size = Vector2(290, 16)
	rcap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	console.add_child(rcap)
	gauge = RiskGauge.new()
	gauge.position = Vector2(866, 32)
	gauge.size = Vector2(190, 104)
	console.add_child(gauge)
	risk_value = UiKit.label("0%", 28, Color.WHITE, UiKit.numbers(), HORIZONTAL_ALIGNMENT_CENTER)
	risk_value.position = Vector2(816, 96)
	risk_value.size = Vector2(290, 34)
	console.add_child(risk_value)
	risk_note = UiKit.label("", 13, Palette.INK_DIM, UiKit.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	risk_note.position = Vector2(816, 142)
	risk_note.size = Vector2(290, 36)
	risk_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	console.add_child(risk_note)
	_set_accepting(false)


# ================================================================ setor
func prepare_sector() -> void:
	var s := Palette.sector(GameManager.current_sector)
	rift.set_theme_color(s.main)
	shape_display.set_colors(s.main, s.accent)
	shape_display.modulate.a = 0.0
	rift.openness = 0.0
	axi.idle()
	_hide_banner(true)
	solution_box.visible = false
	btn_next.visible = false
	btn_confirm.visible = true
	geo_label.text = ""
	formula_hint.text = ""
	risk_value.text = "—"
	risk_note.text = ""
	gauge.set_risk(0, false)


func finish_sector() -> void:
	_set_accepting(false)
	shape_display.play_vanish(0.3)
	rift.close()
	axi.idle()
	await get_tree().create_timer(0.45, false).timeout


# ================================================================ onda
## Sequência de entrada de uma onda. first=true para a primeira do setor.
func begin_wave(first: bool) -> void:
	busy = true
	_set_accepting(false)
	btn_next.visible = false
	btn_confirm.visible = true
	solution_box.visible = false
	_hide_banner()
	axi.idle()
	if not first:
		shape_display.play_vanish(0.25)
		if rift.openness > 0.05:
			AudioManager.play("rift_close")
			rift.close()
		await get_tree().create_timer(0.45, false).timeout
	# faixa da onda
	var sector := GameManager.current_sector
	var wave := GameManager.current_wave
	var sub := ""
	if sector == GameManager.Sector.GAMMA and wave == GameRules.WAVES_PER_SECTOR:
		sub = "FENDA DO LÍDER ALEATÓRIO"
	elif sector == GameManager.Sector.BETA and wave == GameRules.WAVES_PER_SECTOR:
		sub = "Atenção: agora Geo informa o diâmetro"
	await _wave_banner("ONDA %d/%d" % [wave, GameRules.WAVES_PER_SECTOR], sub)
	# fenda se abre
	var rp := GameManager.risk_percent
	AudioManager.play("rift_open")
	rift.open(rp)
	await get_tree().create_timer(0.4, false).timeout
	# forma é construída
	shape_display.setup(GameManager.current_shape_type, GameManager.current_shape_params, GameManager.current_size_units)
	shape_display.play_appear(0.8)
	# painel do Geo e risco
	var hint := GameManager.current_formula_hint
	if GameManager.current_shape_type in [GameManager.ShapeType.CIRCLE, GameManager.ShapeType.COMPOSITE_RECT_SEMI]:
		hint += "   ·   π ≈ 3,14"
	formula_hint.text = hint
	gauge.set_risk(rp)
	_count_risk(rp)
	var high := GameRules.is_high_risk(rp)
	if high:
		risk_note.text = "ALTO  ·  acerto vale %d pts\nerro custa 1 vida" % GameRules.points_for(true, true)
		risk_note.add_theme_color_override("font_color", Palette.DANGER)
		geo.set_mood(Palette.DANGER, true)
		_say("Fenda instável! Confira o cálculo com calma antes de selar.")
	else:
		risk_note.text = "ESTÁVEL  ·  acerto vale %d pts\num erro aqui não custa vidas" % GameRules.points_for(true, false)
		risk_note.add_theme_color_override("font_color", Palette.SUCCESS)
		geo.set_mood(Palette.CYAN, false)
		_say("Fenda estável detectada. Calcule a área para selá-la.")
	await shape_display.appeared
	answer_input.text = ""
	_set_accepting(true)
	busy = false
	emit_signal("ready_for_input")


func _count_risk(rp: int) -> void:
	var tw := create_tween()
	tw.tween_method(func(v): risk_value.text = "%d%%" % int(v), 0.0, float(rp), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	risk_value.add_theme_color_override("font_color", Palette.risk_color(rp))


func _wave_banner(text: String, sub: String) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", Color.WHITE)
	UiKit.glow(banner, Palette.sector(GameManager.current_sector).main, 14)
	banner_sub.text = sub
	banner_sub.add_theme_color_override("font_color", Palette.GOLD if sub != "" else Palette.INK)
	banner.visible = true
	banner_sub.visible = sub != ""
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	banner.scale = Vector2(1.4, 1.4)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner_sub, "modulate:a", 1.0, 0.3).set_delay(0.15)
	AudioManager.play("stamp", 1.2, -8.0)
	await get_tree().create_timer(0.8 if sub == "" else 1.2, false).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(banner, "modulate:a", 0.0, 0.25)
	out.tween_property(banner_sub, "modulate:a", 0.0, 0.25)
	await out.finished


func _hide_banner(instant: bool = false) -> void:
	if instant:
		banner.modulate.a = 0.0
		banner_sub.modulate.a = 0.0
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(banner, "modulate:a", 0.0, 0.2)
	tw.tween_property(banner_sub, "modulate:a", 0.0, 0.2)


func _show_banner(text: String, sub: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	UiKit.glow(banner, color, 16)
	banner_sub.text = sub
	banner_sub.add_theme_color_override("font_color", Palette.INK)
	banner.visible = true
	banner_sub.visible = sub != ""
	banner.scale = Vector2(0.6, 0.6)
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.15)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner_sub, "modulate:a", 1.0, 0.3).set_delay(0.2)


## Geo "digita" a mensagem (efeito máquina de escrever).
func _say(text: String) -> void:
	geo_label.text = text
	geo_label.visible_ratio = 0.0
	if _type_tw:
		_type_tw.kill()
	_type_tw = create_tween()
	_type_tw.tween_property(geo_label, "visible_ratio", 1.0, clampf(text.length() * 0.018, 0.25, 1.2))


func _set_accepting(on: bool) -> void:
	accepting = on
	answer_input.editable = on
	btn_confirm.disabled = not on
	if on and is_inside_tree() and is_visible_in_tree():
		answer_input.call_deferred("grab_focus")


# ================================================================ entrada
func _on_text_submitted(_t: String) -> void:
	if btn_next.visible:
		_on_next_pressed()
	else:
		_on_confirm_pressed()


func _on_confirm_pressed() -> void:
	if GameManager.wave_resolved or not accepting:
		return
	var parsed := AnswerValidator.parse(answer_input.text)
	if not parsed.ok:
		_say(AnswerValidator.error_message(parsed.error).trim_prefix("Geo: "))
		geo.set_mood(Palette.WARN, false)
		AudioManager.play("soft_error")
		Fx.shake_control(answer_input, 8.0, 0.3)
		answer_input.call_deferred("grab_focus")
		return
	_set_accepting(false)
	busy = true
	GameManager.submit_answer(parsed.value)


## Resultado já decidido pelo GameManager → sequência visual.
func on_result(success: bool, risk_was_high: bool) -> void:
	var expected := "Área esperada: %s u²" % GameRules.fmt(GameManager.correct_area)
	solution_label.text = GameManager.current_solution
	# 1) Axi dispara o feixe
	AudioManager.play("charge")
	axi.cast_at(stage.to_global(RIFT_POS))
	await get_tree().create_timer(0.3, false).timeout
	if success:
		var pts := GameRules.points_for(true, risk_was_high)
		shape_display.play_shatter()
		rift.seal()
		AudioManager.play("seal")
		await get_tree().create_timer(0.3, false).timeout
		AudioManager.play("correct")
		axi.success()
		_show_banner("FENDA SELADA!", expected, Palette.SUCCESS)
		Fx.float_text(self, RIFT_POS + Vector2(0, -20), "+%d" % pts, Palette.GOLD, 44)
		if risk_was_high:
			Fx.float_text(self, RIFT_POS + Vector2(0, 30), "BÔNUS DE RISCO", Palette.DANGER, 18, 60.0, 1.3)
		Fx.burst(self, Vector2(88, 40), Palette.GOLD, 24, 160.0, 0.6)
		if GameManager.streak >= 2:
			_say("Cálculo confirmado. %d fendas seladas em sequência — excelente precisão, Axi-01!" % GameManager.streak)
		else:
			_say("Cálculo confirmado. Excelente precisão, Axi-01.")
		geo.set_mood(Palette.SUCCESS, false)
		solution_box.visible = true
		solution_label.text = GameManager.current_solution
	elif risk_was_high:
		shape_display.play_glitch(true)
		rift.expand()
		AudioManager.play("rift_expand")
		AudioManager.play("life_lost")
		emit_signal("request_shake", 14.0, 0.5)
		axi.hurt(true)
		_show_banner("A FENDA SE EXPANDIU", "Axi-01 perdeu 1 vida  ·  " + expected, Palette.DANGER)
		Fx.burst(self, RIFT_POS, Palette.DANGER, 50, 380.0, 0.9)
		_say("Vamos revisar juntos: veja a resolução abaixo e tente de novo na próxima fenda.")
		geo.set_mood(Palette.DANGER, true)
		solution_box.visible = true
	else:
		shape_display.play_glitch(false)
		rift.resist()
		AudioManager.play("wrong")
		emit_signal("request_shake", 5.0, 0.3)
		axi.hurt(false)
		_show_banner("A FENDA RESISTIU", "Sem perda de vida  ·  " + expected, Palette.WARN)
		_say("Quase! Esta fenda era estável, então nada foi perdido. Veja como resolver:")
		geo.set_mood(Palette.WARN, false)
		solution_box.visible = true
	Fx.pop(solution_box, 0.05, 0.3)
	await get_tree().create_timer(0.5, false).timeout
	var lives_after := GameManager.lives
	if lives_after > 0:
		var last := GameManager.current_wave >= GameRules.WAVES_PER_SECTOR
		btn_next.text = "CONCLUIR SETOR  →" if last else "PRÓXIMA ONDA  →"
		btn_confirm.visible = false
		btn_next.visible = true
		btn_next.modulate.a = 0.0
		create_tween().tween_property(btn_next, "modulate:a", 1.0, 0.25)
		answer_input.editable = true
		answer_input.call_deferred("grab_focus")
	busy = false
	emit_signal("result_shown")


func _on_next_pressed() -> void:
	if not btn_next.visible or busy:
		return
	btn_next.visible = false
	answer_input.editable = false
	GameManager.advance_wave()
