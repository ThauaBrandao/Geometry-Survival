extends Control
## Telas de Vitória e Derrota (GDD §12).
## Vitória: arquipélago restaurado, fogos de artifício, Axi-01 comemorando,
## contagem da pontuação, desempenho por setor e selo de NOVO RECORDE.
## Derrota: a Entropia avança (fenda vermelha gigante), mensagem encorajadora,
## resolução da última fenda e opção de tentar novamente.

signal restart_pressed
signal menu_pressed

var scene: Node2D
var axi: Axi01
var rift: Rift
var title_l: Label
var sub_l: Label
var card: Panel
var score_l: Label
var record_l: Label
var badge: Label
var rows: Control
var note_l: Label
var btn_restart: FxButton
var btn_menu: FxButton
var victory := false
var shown_score: float = 0.0
var _fireworks := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	size = Vector2(1152, 648)
	scene = Node2D.new()
	add_child(scene)
	rift = Rift.new()
	rift.position = Vector2(300, 300)
	rift.scale = Vector2(1.3, 1.3)
	scene.add_child(rift)
	axi = Axi01.new()
	axi.position = Vector2(300, 360)
	axi.scale = Vector2(1.4, 1.4)
	scene.add_child(axi)

	title_l = UiKit.label("", 40, Color.WHITE, UiKit.spaced(UiKit.display_bold(), 5), HORIZONTAL_ALIGNMENT_CENTER)
	title_l.size = Vector2(1152, 56)
	title_l.position = Vector2(0, 40)
	UiKit.outline(title_l, Color(0, 0, 0, 0.8), 8)
	add_child(title_l)
	sub_l = UiKit.label("", 17, Palette.INK, UiKit.body(), HORIZONTAL_ALIGNMENT_CENTER)
	sub_l.size = Vector2(1152, 26)
	sub_l.position = Vector2(0, 98)
	add_child(sub_l)

	card = Panel.new()
	card.position = Vector2(600, 150)
	card.size = Vector2(500, 430)
	card.add_theme_stylebox_override("panel", UiKit.glass(Palette.PANEL, Palette.EDGE, 18))
	add_child(card)
	var cap := UiKit.caption("PONTUAÇÃO FINAL", Palette.INK_DIM, 12)
	cap.position = Vector2(30, 24)
	card.add_child(cap)
	score_l = UiKit.label("0", 56, Color.WHITE, UiKit.numbers())
	score_l.position = Vector2(28, 40)
	UiKit.glow(score_l, Palette.GOLD, 10)
	card.add_child(score_l)
	record_l = UiKit.label("", 14, Palette.GOLD, UiKit.spaced(UiKit.body_bold(), 2))
	record_l.position = Vector2(32, 108)
	card.add_child(record_l)
	badge = UiKit.label("NOVO RECORDE!", 14, Palette.BG_DEEP, UiKit.spaced(UiKit.display_bold(), 2), HORIZONTAL_ALIGNMENT_CENTER)
	badge.add_theme_stylebox_override("normal", UiKit.pill(Palette.GOLD, Color(0, 0, 0, 0), 10))
	badge.position = Vector2(300, 60)
	badge.rotation = deg_to_rad(-6)
	card.add_child(badge)
	rows = Control.new()
	rows.position = Vector2(30, 140)
	rows.size = Vector2(440, 150)
	rows.draw.connect(_draw_rows)
	card.add_child(rows)
	note_l = UiKit.label("", 14, Palette.INK_DIM, UiKit.body())
	note_l.position = Vector2(30, 290)
	note_l.size = Vector2(440, 60)
	note_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(note_l)
	btn_restart = FxButton.make("JOGAR NOVAMENTE", "play", true, Vector2(276, 50))
	btn_restart.position = Vector2(30, 356)
	btn_restart.pressed.connect(func(): emit_signal("restart_pressed"))
	card.add_child(btn_restart)
	btn_menu = FxButton.make("MENU", "home", false, Vector2(158, 50))
	btn_menu.position = Vector2(318, 356)
	btn_menu.pressed.connect(func(): emit_signal("menu_pressed"))
	card.add_child(btn_menu)


func present(is_victory: bool) -> void:
	victory = is_victory
	shown_score = 0.0
	visible = true
	var new_record := GameManager.is_new_record()
	badge.visible = false
	if victory:
		title_l.text = "ARQUIPÉLAGO RESTAURADO"
		title_l.add_theme_color_override("font_color", Palette.GOLD)
		UiKit.glow(title_l, Palette.GOLD, 18)
		sub_l.text = "Vitória! Todas as fendas foram seladas e a Entropia recuou."
		btn_restart.text = "JOGAR NOVAMENTE"
		rift.visible = false
		axi.victory()
		var total := GameManager.attempts.size()
		note_l.text = "Precisão geral: %d%% (%d de %d fendas). A geometria é a sua arma, Arquiteta!" % [
			int(round(100.0 * GameManager.total_correct() / maxf(total, 1))), GameManager.total_correct(), total]
		_fireworks = 1.0
	else:
		title_l.text = "A ENTROPIA AVANÇOU"
		title_l.add_theme_color_override("font_color", Palette.DANGER)
		UiKit.glow(title_l, Palette.DANGER, 18)
		sub_l.text = "Fim da missão — mas cada cálculo deixa Axi-01 mais precisa."
		btn_restart.text = "TENTAR NOVAMENTE"
		rift.visible = true
		rift.set_theme_color(Palette.DANGER)
		rift.open(90)
		rift.widen = 1.4
		axi.defeat()
		note_l.text = "Última fenda — %s" % GameManager.current_solution
		_fireworks = 0.0
	record_l.text = "RECORDE  %d" % GameManager.best_score
	btn_restart._apply_style()
	# entrada animada
	card.modulate.a = 0.0
	card.position.x = 640
	title_l.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(title_l, "modulate:a", 1.0, 0.5)
	tw.tween_property(card, "modulate:a", 1.0, 0.5).set_delay(0.3)
	tw.tween_property(card, "position:x", 600.0, 0.6).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "shown_score", float(GameManager.score), 1.4).set_delay(0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if new_record:
			badge.visible = true
			badge.pivot_offset = badge.size / 2.0
			badge.scale = Vector2(2.2, 2.2)
			var bt := badge.create_tween()
			bt.tween_property(badge, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			AudioManager.play("stamp")
			Fx.burst(card, badge.position + Vector2(70, 14), Palette.GOLD, 40, 260.0, 0.8))
	btn_restart.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if not visible:
		return
	var s := int(round(shown_score))
	if score_l.text != str(s):
		score_l.text = str(s)
		if s % 20 == 0:
			AudioManager.play("tick", 1.2, -8.0)
	rows.queue_redraw()
	if victory and Settings.motion() > 0.0:
		_fireworks -= delta
		if _fireworks <= 0.0:
			_fireworks = _rng.randf_range(0.35, 0.8)
			var cols := [Palette.GOLD, Palette.CYAN, Palette.VIOLET, Palette.SUCCESS, Color("ff6b9d")]
			var p := Vector2(_rng.randf_range(80, 1080), _rng.randf_range(90, 300))
			Fx.burst(scene, p, cols[_rng.randi_range(0, cols.size() - 1)], 60, 300.0, 1.4, 120.0, 3.5)
			Fx.shockwave(scene, p, Color(1, 1, 1, 0.5), 90.0, 0.5, 2.0)


func _draw_rows() -> void:
	var f := UiKit.body_bold()
	for i in 3:
		var s := Palette.sector(i)
		var y := 10.0 + i * 44.0
		var st := GameManager.stats_for_sector(i)
		var col: Color = s.main
		rows.draw_rect(Rect2(0, y - 6, 440, 38), Color(1, 1, 1, 0.03))
		rows.draw_rect(Rect2(0, y - 6, 4, 38), col)
		rows.draw_string(UiKit.spaced(UiKit.display_bold(), 2), Vector2(16, y + 19), s.key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col.lerp(Color.WHITE, 0.3))
		rows.draw_string(UiKit.body(), Vector2(100, y + 19), s.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK_DIM)
		if st.y == 0:
			rows.draw_string(f, Vector2(300, y + 19), "não jogado", HORIZONTAL_ALIGNMENT_RIGHT, 130, 13, Palette.INK_FAINT)
		else:
			for k in 3:
				Icons.draw(rows, "star" if k < st.x else "star_empty", Vector2(356 + k * 26, y + 13), 18.0, Palette.GOLD if k < st.x else Color(1, 1, 1, 0.25), 1.5)
