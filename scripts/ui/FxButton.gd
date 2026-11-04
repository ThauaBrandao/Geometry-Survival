class_name FxButton
extends Button
## Botão com microinterações: cresce ao passar o mouse/foco, "pop" ao clicar,
## som de hover/seleção e ícone vetorial opcional à esquerda.

var icon_name: String = ""
var primary: bool = false
var accent: Color = Palette.CYAN
var sfx_press: String = "ui_select"
var _hover_t: Tween


static func make(txt: String, ic: String = "", is_primary: bool = false, min_size: Vector2 = Vector2(240, 52)) -> FxButton:
	var b := FxButton.new()
	b.text = txt
	b.icon_name = ic
	b.primary = is_primary
	b.custom_minimum_size = min_size
	return b


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_style()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))
	pressed.connect(_on_pressed)
	resized.connect(func(): pivot_offset = size / 2.0)
	pivot_offset = size / 2.0


func _apply_style() -> void:
	var th := UiKit.theme()
	var pad := 50 if icon_name != "" else 24
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = th.get_stylebox(st, "Button").duplicate()
		sb.content_margin_left = pad
		if primary and st != "disabled":
			sb.bg_color = accent.darkened(0.45 if st == "normal" else 0.25)
			sb.border_color = accent
			sb.set_border_width_all(2)
			sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
			sb.shadow_offset = Vector2.ZERO
			sb.shadow_size = 14 if st != "normal" else 8
		add_theme_stylebox_override(st, sb)
	add_theme_font_override("font", UiKit.spaced(UiKit.display_bold(), 1))
	add_theme_font_size_override("font_size", 16)


func _on_hover(on: bool) -> void:
	if disabled:
		return
	if on:
		AudioManager.play("ui_hover")
	if _hover_t:
		_hover_t.kill()
	_hover_t = create_tween()
	_hover_t.tween_property(self, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_pressed() -> void:
	AudioManager.play(sfx_press)
	Fx.pop(self, 0.06, 0.25)


func _draw() -> void:
	if icon_name == "":
		return
	var col := Palette.INK_FAINT if disabled else (Color.WHITE if primary else accent)
	Icons.draw(self, icon_name, Vector2(27, size.y / 2.0), 18.0, col, 2.0)
