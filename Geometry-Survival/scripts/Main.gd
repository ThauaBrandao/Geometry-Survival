extends Node2D
## Orquestrador de telas e da apresentação.
## Camadas (de trás para frente):
##   SpaceBackground (cenário com parallax) → World (telas; recebe o tremor)
##   → HUD (layer 10) → Overlays (layer 30: pausa, config., ajuda, diálogos,
##   fim de setor, resultado) → ScreenTransition (layer 100: fenda).
## As REGRAS continuam no GameManager; aqui só há fluxo e efeitos.

var bg: SpaceBackground
var world: Node2D
var menu: Control
var sector_map: Control
var shape_encounter: Control
var result_screen: Control
var hud: CanvasLayer
var overlays: CanvasLayer
var pause_menu: OverlayScreen
var settings_screen: OverlayScreen
var howto: OverlayScreen
var dialog: OverlayScreen
var sector_clear: OverlayScreen
var trans: ScreenTransition

var screen := ""
var busy := false
var _shake := 0.0
var _shake_dur := 0.0
var _shake_t := 0.0
var _overlay_stack: Array[OverlayScreen] = []


func _ready() -> void:
	get_tree().root.theme = UiKit.theme()
	bg = SpaceBackground.new()
	add_child(bg)
	world = Node2D.new()
	add_child(world)
	menu = load("res://scripts/screens/MenuScreen.gd").new()
	world.add_child(menu)
	sector_map = load("res://scenes/SectorMap.tscn").instantiate()
	world.add_child(sector_map)
	shape_encounter = load("res://scenes/ShapeEncounter.tscn").instantiate()
	world.add_child(shape_encounter)

	hud = load("res://scenes/HUD.tscn").instantiate()
	add_child(hud)

	overlays = CanvasLayer.new()
	overlays.layer = 30
	overlays.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlays)
	result_screen = load("res://scenes/ResultScreen.tscn").instantiate()
	result_screen.visible = false
	overlays.add_child(result_screen)
	sector_clear = load("res://scripts/screens/SectorClear.gd").new()
	overlays.add_child(sector_clear)
	pause_menu = load("res://scripts/screens/PauseMenu.gd").new()
	overlays.add_child(pause_menu)
	howto = load("res://scripts/screens/HowToPlay.gd").new()
	overlays.add_child(howto)
	settings_screen = load("res://scripts/screens/SettingsScreen.gd").new()
	overlays.add_child(settings_screen)
	dialog = load("res://scripts/screens/ConfirmDialog.gd").new()
	overlays.add_child(dialog)

	trans = ScreenTransition.new()
	add_child(trans)

	# processamento durante a pausa: o encontro congela; o resto continua
	shape_encounter.process_mode = Node.PROCESS_MODE_PAUSABLE
	for n in [bg, menu, sector_map, hud]:
		n.process_mode = Node.PROCESS_MODE_ALWAYS

	_connect()
	_show_only(menu)
	screen = "menu"
	hud.set_mode("hidden", false)
	AudioManager.play_music("menu")
	menu.show_title()


func _connect() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	menu.play_pressed.connect(_on_menu_play)
	menu.continue_pressed.connect(_on_menu_continue)
	menu.settings_pressed.connect(func(): _push_overlay(settings_screen))
	menu.howto_pressed.connect(func(): _push_overlay(howto))
	menu.quit_pressed.connect(func(): get_tree().quit())
	sector_map.sector_chosen.connect(enter_sector)
	sector_map.back_pressed.connect(func(): if not busy: go_menu())
	shape_encounter.request_shake.connect(shake)
	hud.pause_pressed.connect(open_pause)
	pause_menu.resume_pressed.connect(close_pause)
	pause_menu.howto_pressed.connect(func(): _push_overlay(howto))
	pause_menu.settings_pressed.connect(func(): _push_overlay(settings_screen))
	pause_menu.map_pressed.connect(_on_pause_map)
	pause_menu.menu_pressed.connect(_on_pause_menu)
	settings_screen.back_requested.connect(_pop_overlay)
	howto.back_requested.connect(_pop_overlay)
	result_screen.restart_pressed.connect(_on_restart)
	result_screen.menu_pressed.connect(func(): go_menu())


# ================================================================ helpers
func _show_only(node: Control) -> void:
	for n in [menu, sector_map, shape_encounter]:
		n.visible = n == node


func shake(strength: float, dur: float) -> void:
	if not Settings.screen_shake or Settings.reduced_motion:
		return
	_shake = maxf(_shake, strength)
	_shake_dur = dur
	_shake_t = dur


func _process(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= delta
		var k := _shake_t / maxf(_shake_dur, 0.01)
		world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * k
		if _shake_t <= 0.0:
			_shake = 0.0
			world.position = Vector2.ZERO


func _push_overlay(o: OverlayScreen) -> void:
	if not _overlay_stack.is_empty():
		_overlay_stack.back().visible = false
	_overlay_stack.append(o)
	o.open()


func _pop_overlay() -> void:
	if _overlay_stack.is_empty():
		return
	var o: OverlayScreen = _overlay_stack.pop_back()
	o.close()
	if not _overlay_stack.is_empty():
		var prev: OverlayScreen = _overlay_stack.back()
		prev.visible = true
		prev._on_opened()
	elif screen == "menu":
		menu.focus_first()


# ================================================================ menu
func _on_menu_play() -> void:
	if busy:
		return
	if SaveGame.has_save():
		var ok: bool = await dialog.ask("NOVA PARTIDA?", "Existe uma partida salva. Começar de novo irá substituí-la.", "NOVA PARTIDA")
		if not ok:
			menu.focus_first()
			return
	start_new_game()


func _on_menu_continue() -> void:
	if busy or not SaveGame.has_save():
		return
	if not SaveGame.load_progress():
		SaveGame.clear_progress()
		menu.refresh()
		return
	await go_map()


func start_new_game() -> void:
	SaveGame.clear_progress()
	GameManager.reset_game()
	await go_map()


func go_menu() -> void:
	if busy:
		return
	busy = true
	get_tree().paused = false
	await trans.cover(Palette.VIOLET)
	result_screen.visible = false
	_show_only(menu)
	screen = "menu"
	hud.set_mode("hidden", false)
	bg.set_palette(Palette.MENU_SKY, Palette.CYAN, false, 0.0)
	bg.set_danger(0.0, 0.0)
	AudioManager.play_music("menu")
	menu.show_menu(false)
	await trans.reveal()
	busy = false
	menu.focus_first()


# ================================================================ mapa
func go_map(play_unlock_for: int = -1) -> void:
	busy = true
	await trans.cover(Palette.VIOLET)
	result_screen.visible = false
	_show_only(sector_map)
	screen = "map"
	sector_map.refresh()
	hud.set_mode("map", false)
	bg.set_palette(Palette.MENU_SKY, Palette.VIOLET, false, 0.0)
	bg.set_danger(0.0, 0.0)
	AudioManager.play_music("menu")
	await trans.reveal()
	busy = false
	if play_unlock_for > 0:
		sector_map.play_unlock(play_unlock_for)
	sector_map.focus_default()


func enter_sector(sector: int) -> void:
	if busy or screen != "map" or not GameManager.is_sector_available(sector):
		return
	busy = true
	var col: Color = Palette.sector(sector).main
	await trans.cover(col)
	GameManager.start_encounter(sector)   # emite ENCOUNTER com screen = "map" (ignorado)
	_show_only(shape_encounter)
	screen = "encounter"
	shape_encounter.prepare_sector()
	bg.set_sector(sector, true, 0.0)
	hud.set_mode("encounter", false)
	AudioManager.play_music(["alpha", "beta", "gamma"][sector])
	await trans.show_sector_card(sector)
	await trans.reveal()
	busy = false
	shape_encounter.begin_wave(true)


# ================================================================ jogo
func _on_state_changed(state: int) -> void:
	if screen != "encounter" or _abandoning:
		return
	match state:
		GameManager.GameState.ENCOUNTER:
			shape_encounter.begin_wave(false)
		GameManager.GameState.SECTOR_MAP:
			_after_sector(false)
		GameManager.GameState.GAME_WIN:
			_after_sector(true)
		GameManager.GameState.GAME_OVER:
			_defeat()


var _abandoning := false


func _after_sector(win: bool) -> void:
	busy = true
	var sector := GameManager.current_sector
	await shape_encounter.finish_sector()
	await sector_clear.present(sector, win)
	if win:
		SaveGame.clear_progress()
		await trans.cover(Palette.GOLD, 0.7)
		_show_only(null)
		screen = "result"
		hud.set_mode("hidden", false)
		bg.set_palette([Color("0a0714"), Color("2a1a4d"), Color("7a5a1a")], Palette.GOLD, false, 0.0)
		AudioManager.play_music("victory")
		AudioManager.play("victory")
		result_screen.present(true)
		await trans.reveal(0.8)
		busy = false
	else:
		SaveGame.save_progress()
		busy = false
		await go_map(sector + 1)


func _defeat() -> void:
	busy = true
	if shape_encounter.busy:
		await shape_encounter.result_shown
	await get_tree().create_timer(1.2).timeout
	shape_encounter.axi.defeat()
	bg.set_danger(0.9, 1.0)
	AudioManager.stop_music()
	await get_tree().create_timer(1.0).timeout
	SaveGame.clear_progress()
	await trans.cover(Palette.DANGER, 0.7)
	_show_only(null)
	screen = "result"
	hud.set_mode("hidden", false)
	bg.set_palette([Color("0a0204"), Color("3a0610"), Color("5a1020")], Palette.DANGER, false, 0.0)
	bg.set_danger(0.5, 0.0)
	AudioManager.play("defeat")
	AudioManager.play_music("defeat")
	result_screen.present(false)
	await trans.reveal(0.8)
	busy = false


func _on_restart() -> void:
	if busy:
		return
	result_screen.visible = false
	await start_new_game()


# ================================================================ pausa
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and screen == "encounter" and not busy \
			and not get_tree().paused and _overlay_stack.is_empty():
		get_viewport().set_input_as_handled()
		open_pause()


func open_pause() -> void:
	if screen != "encounter" or busy or get_tree().paused:
		return
	get_tree().paused = true
	AudioManager.play("pause")
	_push_overlay(pause_menu)


func close_pause() -> void:
	_overlay_stack.clear()
	pause_menu.close()
	get_tree().paused = false
	AudioManager.play("pause", 1.2)
	if shape_encounter.accepting:
		shape_encounter.answer_input.grab_focus()
	elif shape_encounter.btn_next.visible:
		shape_encounter.answer_input.grab_focus()


func _on_pause_map() -> void:
	var ok: bool = await dialog.ask("VOLTAR AO MAPA?", "O progresso deste setor será perdido. Setores já concluídos continuam salvos.", "VOLTAR")
	if not ok:
		pause_menu.buttons[0].grab_focus()
		return
	_leave_sector()
	await go_map()


func _on_pause_menu() -> void:
	var ok: bool = await dialog.ask("MENU PRINCIPAL?", "O progresso deste setor será perdido. Setores já concluídos continuam salvos — use \"Continuar\".", "SAIR")
	if not ok:
		pause_menu.buttons[0].grab_focus()
		return
	_leave_sector()
	await go_menu()


func _leave_sector() -> void:
	_overlay_stack.clear()
	pause_menu.close()
	get_tree().paused = false
	_abandoning = true
	GameManager.abandon_sector()
	_abandoning = false
	shape_encounter.finish_sector()
	busy = false
