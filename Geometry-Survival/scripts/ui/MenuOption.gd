class_name MenuOption
extends Button
## Opção do menu principal: faixa em paralelogramo com número, ícone,
## título e descrição. No hover/foco a faixa se preenche da esquerda para a
## direita, o texto desliza e surge uma seta; toca som e brilha.

var index: int = 1
var title: String = ""
var subtitle: String = ""
var icon_name: String = "play"
var hl: float = 0.0:
	set(v):
		hl = v
		queue_redraw()
var intro: float = 1.0:
	set(v):
		intro = v
		queue_redraw()
var _tw: Tween
var _t := 0.0


static func make(i: int, t: String, sub: String, ic: String) -> MenuOption:
	var m := MenuOption.new()
	m.index = i
	m.title = t
	m.subtitle = sub
	m.icon_name = ic
	m.custom_minimum_size = Vector2(430, 64)
	return m


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, empty)
	mouse_entered.connect(func(): grab_focus())
	focus_entered.connect(_set_hl.bind(true))
	focus_exited.connect(_set_hl.bind(false))
	pressed.connect(func():
		AudioManager.play("ui_select")
		Fx.pop(self, 0.04, 0.25))


func _set_hl(on: bool) -> void:
	if on and not disabled:
		AudioManager.play("ui_hover")
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "hl", 1.0 if on else 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if hl > 0.01:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var dim := 0.35 if disabled else 1.0
	var slant := 16.0
	var off := (1.0 - intro) * -60.0
	var a := intro * dim
	# faixa base
	var base := PackedVector2Array([Vector2(slant + off, 0), Vector2(w + off, 0), Vector2(w - slant + off, h), Vector2(off, h)])
	draw_colored_polygon(base, Color(0.04, 0.07, 0.16, 0.55 * a))
	# preenchimento do hover
	if hl > 0.01:
		var fw := (w - slant) * hl
		var fill := PackedVector2Array([Vector2(slant + off, 0), Vector2(slant + fw + off, 0), Vector2(fw + off, h), Vector2(off, h)])
		draw_colored_polygon(fill, Color(0.1, 0.55, 0.7, 0.35 * a))
		draw_line(Vector2(slant + off, 0), Vector2(slant + fw + off, 0), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.9 * a * hl), 2.0)
		draw_line(Vector2(off, h), Vector2(fw + off, h), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.5 * a * hl), 1.0)
	# barra lateral
	var bar := PackedVector2Array([Vector2(slant * 0.6 + off, 0), Vector2(slant * 0.6 + 5 + off, 0), Vector2(5 + off, h), Vector2(off, h)])
	draw_colored_polygon(bar, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, (0.35 + 0.65 * hl) * a))
	var shift := hl * 14.0 + off
	# número
	var small := UiKit.spaced(UiKit.display(), 1)
	draw_string(small, Vector2(30 + shift, h / 2.0 + 5), "%02d" % index, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(Palette.INK_DIM.r, Palette.INK_DIM.g, Palette.INK_DIM.b, a))
	# ícone em losango
	var ic := Vector2(84 + shift, h / 2.0)
	var dia := PackedVector2Array([ic + Vector2(0, -18), ic + Vector2(18, 0), ic + Vector2(0, 18), ic + Vector2(-18, 0)])
	draw_colored_polygon(dia, Color(0.05, 0.1, 0.2, 0.9 * a))
	var dl := dia.duplicate()
	dl.append(dl[0])
	draw_polyline(dl, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, (0.5 + 0.5 * hl) * a), 1.5, true)
	Icons.draw(self, icon_name, ic, 15.0, Color(1, 1, 1, a), 2.0)
	# título e descrição
	var tf := UiKit.spaced(UiKit.display_bold(), 2)
	draw_string(tf, Vector2(118 + shift, h / 2.0 + 1), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 21,
		Color(1, 1, 1, a).lerp(Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, a), hl * 0.3))
	draw_string(UiKit.body(), Vector2(119 + shift, h / 2.0 + 20), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(Palette.INK_DIM.r, Palette.INK_DIM.g, Palette.INK_DIM.b, a))
	# seta
	if hl > 0.01:
		var ax := w - 40 + off + sin(_t * 6.0) * 3.0
		draw_polyline(PackedVector2Array([Vector2(ax - 6, h / 2 - 8), Vector2(ax + 2, h / 2), Vector2(ax - 6, h / 2 + 8)]),
			Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, hl * a), 2.5, true)
