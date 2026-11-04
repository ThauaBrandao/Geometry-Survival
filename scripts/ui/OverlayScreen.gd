class_name OverlayScreen
extends Control
## Base das sobreposições (pausa, configurações, como jogar, diálogos):
## fundo desfocado/escurecido + painel de vidro que entra com escala e fade.
## Funciona com o jogo pausado (PROCESS_MODE_ALWAYS). Esc = voltar.

signal back_requested

var dim: ColorRect
var panel: Panel
var content: Control
var is_open := false
var close_on_cancel := true


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(1152, 648)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func build_frame(panel_size: Vector2, edge: Color = Palette.EDGE) -> void:
	dim = ColorRect.new()
	dim.size = size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/blur_dim.gdshader")
	dim.material = mat
	add_child(dim)
	panel = Panel.new()
	panel.size = panel_size
	panel.position = (size - panel_size) / 2.0
	panel.pivot_offset = panel_size / 2.0
	panel.add_theme_stylebox_override("panel", UiKit.glass(Palette.PANEL, edge, 18, 1))
	add_child(panel)
	content = Control.new()
	content.size = panel_size
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(content)
	# filete luminoso no topo do painel
	var line := ColorRect.new()
	line.color = Color(edge.r, edge.g, edge.b, 0.9)
	line.size = Vector2(panel_size.x * 0.4, 2)
	line.position = Vector2(panel_size.x * 0.3, 0)
	panel.add_child(line)


func open() -> void:
	is_open = true
	visible = true
	modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_on_opened()


func close() -> void:
	if not is_open:
		return
	is_open = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.16)
	tw.chain().tween_callback(func(): visible = false)


func _on_opened() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if is_open and close_on_cancel and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		AudioManager.play("ui_back")
		emit_signal("back_requested")


func add_title(text: String, y: float = 26.0, color: Color = Palette.INK) -> Label:
	var l := UiKit.label(text, 28, color, UiKit.spaced(UiKit.display_bold(), 4), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.glow(l, Palette.CYAN, 10)
	l.size = Vector2(panel.size.x, 40)
	l.position = Vector2(0, y)
	content.add_child(l)
	return l
