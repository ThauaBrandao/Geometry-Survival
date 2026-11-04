class_name ToggleSwitch
extends Button
## Interruptor animado (liga/desliga) para a tela de configurações.

var knob: float = 0.0:
	set(v):
		knob = v
		queue_redraw()


func _ready() -> void:
	toggle_mode = true
	flat = true
	custom_minimum_size = Vector2(64, 32)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(st, empty)
	knob = 1.0 if button_pressed else 0.0
	toggled.connect(func(on):
		AudioManager.play("ui_select" if on else "ui_back")
		create_tween().tween_property(self, "knob", 1.0 if on else 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	knob = 1.0 if on else 0.0


func _draw() -> void:
	var r := Rect2(Vector2(0, (size.y - 28) / 2.0), Vector2(56, 28))
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.bg_color = Color(0.08, 0.12, 0.22).lerp(Palette.CYAN.darkened(0.35), knob)
	sb.border_color = Palette.CYAN if has_focus() else Color(1, 1, 1, 0.15)
	sb.set_border_width_all(2 if has_focus() else 1)
	draw_style_box(sb, r)
	var c := r.position + Vector2(14 + 28 * knob, 14)
	draw_circle(c, 10, Color.WHITE)
