extends OverlayScreen
## Transição de fim de setor: "SETOR X SELADO", estrelas por fenda selada
## (aparecem uma a uma), pontos obtidos no setor e aviso do próximo setor.

signal continued

var title_l: Label
var sub_l: Label
var stats_l: Label
var next_l: Label
var stars: Control
var btn: FxButton
var _stars_lit := 0
var _stars_total := 3
var _star_pop: Array[float] = [0.0, 0.0, 0.0]
var _sector := 0


func _ready() -> void:
	build_frame(Vector2(560, 400), Color(1, 0.79, 0.29, 0.55))
	close_on_cancel = false
	var cap := UiKit.caption("FENDAS DO SETOR", Palette.INK_DIM, 12)
	cap.size = Vector2(560, 16)
	cap.position = Vector2(0, 30)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cap)
	title_l = UiKit.label("", 34, Color.WHITE, UiKit.spaced(UiKit.display_bold(), 5), HORIZONTAL_ALIGNMENT_CENTER)
	title_l.size = Vector2(560, 46)
	title_l.position = Vector2(0, 52)
	content.add_child(title_l)
	sub_l = UiKit.label("", 16, Palette.INK_DIM, UiKit.body(), HORIZONTAL_ALIGNMENT_CENTER)
	sub_l.size = Vector2(560, 24)
	sub_l.position = Vector2(0, 100)
	content.add_child(sub_l)
	stars = Control.new()
	stars.position = Vector2(130, 136)
	stars.size = Vector2(300, 90)
	stars.draw.connect(_draw_stars)
	content.add_child(stars)
	stats_l = UiKit.label("", 18, Palette.INK, UiKit.body_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	stats_l.size = Vector2(560, 26)
	stats_l.position = Vector2(0, 236)
	content.add_child(stats_l)
	next_l = UiKit.label("", 15, Palette.GOLD, UiKit.spaced(UiKit.body_bold(), 2), HORIZONTAL_ALIGNMENT_CENTER)
	next_l.size = Vector2(560, 22)
	next_l.position = Vector2(0, 272)
	content.add_child(next_l)
	btn = FxButton.make("CONTINUAR", "play", true, Vector2(240, 50))
	btn.accent = Palette.GOLD
	btn.position = Vector2(160, 318)
	btn.pressed.connect(_on_continue)
	content.add_child(btn)
	btn._apply_style()


func present(sector: int, is_final: bool) -> void:
	_sector = sector
	var s := Palette.sector(sector)
	var st := GameManager.stats_for_sector(sector)
	title_l.text = "%s SELADO" % s.key
	UiKit.glow(title_l, s.main, 14)
	sub_l.text = s.title
	stats_l.text = "+%d pontos  ·  %d de %d fendas seladas" % [GameManager.sector_score_gained(), st.x, st.y]
	if is_final:
		next_l.text = "O ARQUIPÉLAGO ESTÁ QUASE RESTAURADO…"
	else:
		next_l.text = "%s LIBERADO" % Palette.sector(sector + 1).name.to_upper()
	_stars_total = 3
	_stars_lit = 0
	_star_pop = [0.0, 0.0, 0.0]
	btn.modulate.a = 0.0
	open()
	AudioManager.play("unlock")
	for i in st.x:
		await get_tree().create_timer(0.35).timeout
		_stars_lit = i + 1
		_star_pop[i] = 1.0
		AudioManager.play("star", 1.0 + i * 0.12)
		Fx.burst(stars, Vector2(50 + i * 100, 45), Palette.GOLD, 26, 200.0, 0.7)
	await get_tree().create_timer(0.3).timeout
	create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
	btn.grab_focus()
	await continued


func _on_continue() -> void:
	close()
	emit_signal("continued")


func _process(delta: float) -> void:
	for i in 3:
		_star_pop[i] = move_toward(_star_pop[i], 0.0, delta * 2.5)
	if visible:
		stars.queue_redraw()


func _draw_stars() -> void:
	for i in 3:
		var c := Vector2(50 + i * 100, 45)
		var s := 58.0 * (1.0 + 0.35 * _star_pop[i])
		if i < _stars_lit:
			Icons.soft_light(stars, c, 50.0, Color(1, 0.79, 0.29, 0.3), 5)
			Icons.draw(stars, "star", c, s, Palette.GOLD)
		else:
			Icons.draw(stars, "star_empty", c, 58.0, Color(1, 1, 1, 0.2), 2.0)
