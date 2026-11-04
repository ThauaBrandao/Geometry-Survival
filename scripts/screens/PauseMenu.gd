extends OverlayScreen
## Tela de pausa: desfoca o jogo e oferece continuar, ajuda, configurações,
## voltar ao mapa (abandona o setor) ou ao menu principal.

signal resume_pressed
signal howto_pressed
signal settings_pressed
signal map_pressed
signal menu_pressed

var info: Label
var buttons: Array[FxButton] = []


func _ready() -> void:
	build_frame(Vector2(420, 470))
	add_title("PAUSA", 26)
	info = UiKit.label("", 14, Palette.INK_DIM, UiKit.body(), HORIZONTAL_ALIGNMENT_CENTER)
	info.position = Vector2(20, 72)
	info.size = Vector2(380, 40)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	var defs := [["CONTINUAR", "play", "resume_pressed", true], ["COMO JOGAR", "help", "howto_pressed", false],
		["CONFIGURAÇÕES", "gear", "settings_pressed", false], ["VOLTAR AO MAPA", "map", "map_pressed", false],
		["MENU PRINCIPAL", "home", "menu_pressed", false]]
	var y := 124.0
	for d in defs:
		var b := FxButton.make(d[0], d[1], d[3], Vector2(300, 50))
		b.position = Vector2(60, y)
		var sig: String = d[2]
		b.pressed.connect(func(): emit_signal(sig))
		content.add_child(b)
		buttons.append(b)
		y += 64.0
	back_requested.connect(func(): emit_signal("resume_pressed"))


func _on_opened() -> void:
	var s := Palette.sector(GameManager.current_sector)
	info.text = "%s  ·  Onda %d/3  ·  %d pontos\nO jogo é salvo automaticamente no mapa." % [s.name, GameManager.current_wave, GameManager.score]
	buttons[0].call_deferred("grab_focus")
