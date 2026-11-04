extends Control
## Tela inicial + Menu principal.
## Fase "title": o logotipo se monta no centro e pede "pressione qualquer tecla".
## Fase "menu": o logotipo desliza para a esquerda, as opções entram em
## cascata e à direita surge a cena de Axi-01 diante de uma fenda distante.

signal play_pressed
signal continue_pressed
signal settings_pressed
signal howto_pressed
signal quit_pressed

var logo: Logo
var press_label: Label
var options_box: VBoxContainer
var options: Array[MenuOption] = []
var opt_continue: MenuOption
var scene_root: Node2D
var axi: Axi01
var rift: Rift
var footer: Label
var hint: Label
var phase := "title"
var _t := 0.0


func _ready() -> void:
	size = Vector2(1152, 648)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# cena à direita (em profundidade)
	scene_root = Node2D.new()
	add_child(scene_root)
	rift = Rift.new()
	rift.position = Vector2(960, 236)
	rift.scale = Vector2(0.75, 0.75)
	rift.set_theme_color(Palette.VIOLET)
	scene_root.add_child(rift)
	axi = Axi01.new()
	axi.position = Vector2(790, 404)
	axi.scale = Vector2(1.3, 1.3)
	scene_root.add_child(axi)
	scene_root.modulate.a = 0.0

	logo = Logo.new()
	logo.position = Vector2(266, 150)
	logo.pivot_offset = Vector2(310, 0)
	add_child(logo)
	press_label = UiKit.label("PRESSIONE QUALQUER TECLA", 16, Palette.INK, UiKit.spaced(UiKit.display_bold(), 6), HORIZONTAL_ALIGNMENT_CENTER)
	press_label.size = Vector2(1152, 24)
	press_label.position = Vector2(0, 500)
	add_child(press_label)

	options_box = VBoxContainer.new()
	options_box.position = Vector2(70, 234)
	options_box.add_theme_constant_override("separation", 6)
	add_child(options_box)
	var defs := [
		["JOGAR", "Iniciar uma nova missão", "play", "play_pressed"],
		["CONTINUAR", "Retomar a partida salva", "continue", "continue_pressed"],
		["CONFIGURAÇÕES", "Áudio, vídeo e acessibilidade", "gear", "settings_pressed"],
		["COMO JOGAR", "Aprenda a selar as fendas", "help", "howto_pressed"],
		["SAIR", "Encerrar o jogo", "exit", "quit_pressed"],
	]
	var i := 1
	for d in defs:
		if d[0] == "SAIR" and OS.has_feature("web"):
			continue
		var o := MenuOption.make(i, d[0], d[1], d[2])
		var sig: String = d[3]
		o.pressed.connect(func(): emit_signal(sig))
		options_box.add_child(o)
		options.append(o)
		if d[0] == "CONTINUAR":
			opt_continue = o
		i += 1
	options_box.visible = false
	refresh()

	footer = UiKit.label("v1.4  ·  Engenharia de Software — Católica SC  ·  feito em Godot 4", 12, Palette.INK_FAINT, UiKit.body())
	footer.position = Vector2(70, 614)
	add_child(footer)
	hint = UiKit.label("↑ ↓  NAVEGAR     ENTER  SELECIONAR", 11, Palette.INK_FAINT, UiKit.spaced(UiKit.body_bold(), 2), HORIZONTAL_ALIGNMENT_RIGHT)
	hint.position = Vector2(700, 614)
	hint.size = Vector2(420, 16)
	add_child(hint)
	hint.visible = false


## Tela de título com animação de montagem do logotipo.
func show_title() -> void:
	phase = "title"
	options_box.visible = false
	hint.visible = false
	scene_root.modulate.a = 0.0
	logo.position = Vector2(266, 150)
	logo.scale = Vector2.ONE
	press_label.visible = true
	press_label.modulate.a = 0.0
	logo.play_intro()
	create_tween().tween_property(press_label, "modulate:a", 1.0, 0.6).set_delay(1.6)


## Vai direto ao menu (ao voltar de uma partida).
func show_menu(animate: bool = true) -> void:
	phase = "menu"
	press_label.visible = false
	logo.build = 1.0
	refresh()
	var tw := create_tween().set_parallel(true)
	var d := 0.6 if animate else 0.0
	tw.tween_property(logo, "position", Vector2(-18, 16), d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(logo, "scale", Vector2(0.72, 0.72), d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(scene_root, "modulate:a", 1.0, d + 0.2)
	options_box.visible = true
	hint.visible = true
	var k := 0
	for o in options:
		o.intro = 0.0
		o.modulate.a = 0.0
		var ot := create_tween()
		ot.tween_interval((0.25 + k * 0.07) if animate else 0.0)
		ot.tween_property(o, "modulate:a", 1.0, 0.01)
		ot.tween_property(o, "intro", 1.0, 0.4 if animate else 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		k += 1
	rift.open(55)
	axi.idle()
	await get_tree().create_timer(0.3 if animate else 0.0).timeout
	focus_first()


func refresh() -> void:
	if opt_continue:
		opt_continue.disabled = not SaveGame.has_save()
		opt_continue.subtitle = "Retomar a partida salva" if SaveGame.has_save() else "Nenhuma partida salva"
		opt_continue.focus_mode = Control.FOCUS_NONE if opt_continue.disabled else Control.FOCUS_ALL
		opt_continue.queue_redraw()


func focus_first() -> void:
	if not is_visible_in_tree():
		return
	if opt_continue and not opt_continue.disabled:
		opt_continue.grab_focus()
	elif options.size() > 0:
		options[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or phase != "title":
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		if logo.build < 0.5:
			return
		get_viewport().set_input_as_handled()
		AudioManager.play("ui_select")
		show_menu(true)


func _process(delta: float) -> void:
	_t += delta
	if press_label.visible and phase == "title" and press_label.modulate.a > 0.9:
		press_label.self_modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 3.0))
