class_name UiKit
extends RefCounted
## Tipografia, tema global e fábricas de componentes de interface.
## Fontes: Orbitron (títulos/números) e Exo 2 (texto) — ambas SIL OFL 1.1,
## licenças em assets/fonts. Nenhum sprite externo (Pilar 5 do GDD).

static var _display: FontVariation
static var _display_bold: FontVariation
static var _body: FontVariation
static var _body_bold: FontVariation
static var _theme: Theme


static func _weighted(path: String, weight: int, fallback: Array[Font]) -> FontVariation:
	var file: FontFile = load(path)
	if file != null:
		file.fallbacks = fallback
	var fv := FontVariation.new()
	fv.base_font = file if file != null else ThemeDB.fallback_font
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv


static func _ensure_fonts() -> void:
	if _body != null:
		return
	var base_fallback: Array[Font] = [ThemeDB.fallback_font]
	_body = _weighted("res://assets/fonts/Exo2-Variable.ttf", 500, base_fallback)
	_body_bold = _weighted("res://assets/fonts/Exo2-Variable.ttf", 750, base_fallback)
	# Orbitron não tem π, ², ≈ … → cai para Exo 2 e depois para a fonte padrão.
	var disp_fallback: Array[Font] = [_body_bold, ThemeDB.fallback_font]
	_display = _weighted("res://assets/fonts/Orbitron-Variable.ttf", 600, disp_fallback)
	_display_bold = _weighted("res://assets/fonts/Orbitron-Variable.ttf", 850, disp_fallback)


static func display() -> Font:
	_ensure_fonts()
	return _display


static func display_bold() -> Font:
	_ensure_fonts()
	return _display_bold


## Números grandes (pontuação, risco, resposta): Exo 2 extra-negrito —
## o zero do Orbitron é cortado e parece um ícone "proibido".
static var _numbers: FontVariation
static func numbers() -> Font:
	_ensure_fonts()
	if _numbers == null:
		_numbers = _weighted("res://assets/fonts/Exo2-Variable.ttf", 820, [ThemeDB.fallback_font] as Array[Font])
	return _numbers


static func body() -> Font:
	_ensure_fonts()
	return _body


static func body_bold() -> Font:
	_ensure_fonts()
	return _body_bold


# ------------------------------------------------------------------ estilos
static func glass(bg: Color = Palette.PANEL, edge: Color = Palette.EDGE, radius: int = 14,
		border: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	s.anti_aliasing = true
	return s


static func pill(bg: Color, edge: Color = Color(0, 0, 0, 0), radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1 if edge.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func _circle_texture(radius: int, color: Color, ring: Color) -> ImageTexture:
	var d := radius * 2 + 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d / 2.0, d / 2.0)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(radius - dist + 0.5, 0.0, 1.0)
			if a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col := color if dist < radius - 2.5 else ring
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)


## Tema global aplicado à janela: botões, campos, sliders e textos.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_ensure_fonts()
	var t := Theme.new()
	t.default_font = _body
	t.default_font_size = 18

	t.set_color("font_color", "Label", Palette.INK)

	# Button
	var bn := glass(Color(0.06, 0.1, 0.22, 0.85), Color(0.15, 0.9, 1.0, 0.35), 10)
	bn.shadow_size = 6
	bn.content_margin_left = 22
	bn.content_margin_right = 22
	bn.content_margin_top = 10
	bn.content_margin_bottom = 10
	var bh := bn.duplicate()
	bh.bg_color = Color(0.08, 0.2, 0.32, 0.95)
	bh.border_color = Palette.CYAN
	bh.set_border_width_all(2)
	bh.shadow_color = Color(0.15, 0.9, 1.0, 0.25)
	var bp := bh.duplicate()
	bp.bg_color = Color(0.1, 0.35, 0.45, 1.0)
	var bd := bn.duplicate()
	bd.bg_color = Color(0.05, 0.06, 0.1, 0.6)
	bd.border_color = Color(1, 1, 1, 0.08)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("focus", "Button", bh)
	t.set_stylebox("disabled", "Button", bd)
	t.set_font("font", "Button", _body_bold)
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Button", Palette.INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Palette.INK_FAINT)

	# LineEdit
	var le := glass(Color(0.02, 0.04, 0.1, 0.95), Color(0.15, 0.9, 1.0, 0.45), 10, 2)
	le.shadow_size = 0
	le.content_margin_left = 16
	le.content_margin_right = 16
	var lef := le.duplicate()
	lef.border_color = Palette.CYAN
	lef.shadow_color = Color(0.15, 0.9, 1.0, 0.3)
	lef.shadow_size = 10
	lef.shadow_offset = Vector2.ZERO
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_font("font", "LineEdit", _weighted("res://assets/fonts/Exo2-Variable.ttf", 800, [ThemeDB.fallback_font] as Array[Font]))
	t.set_font_size("font_size", "LineEdit", 26)
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.22))
	t.set_color("caret_color", "LineEdit", Palette.CYAN)
	t.set_color("selection_color", "LineEdit", Color(0.15, 0.9, 1.0, 0.35))
	t.set_constant("caret_width", "LineEdit", 3)

	# HSlider
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate()
	fill.bg_color = Palette.CYAN
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_texture(10, Color.WHITE, Palette.CYAN))
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(12, Color.WHITE, Palette.CYAN))

	# Tooltip / Panel
	t.set_stylebox("panel", "PanelContainer", glass())
	t.set_stylebox("panel", "Panel", glass())
	_theme = t
	return t


# ------------------------------------------------------------------ fábricas
static func label(text: String, size: int = 18, color: Color = Palette.INK,
		font: Font = null, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Aplica "brilho neon" a um Label via sombra sem deslocamento.
static func glow(l: Label, color: Color, strength: int = 8) -> void:
	l.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", strength)


static func outline(l: Label, color: Color = Color(0, 0, 0, 0.85), size: int = 6) -> void:
	l.add_theme_color_override("font_outline_color", color)
	l.add_theme_constant_override("outline_size", size)


## Variação da fonte com espaçamento extra entre letras (títulos "tracking").
static func spaced(font: Font, px: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = font
	fv.spacing_glyph = px
	return fv


static func caption(text: String, color: Color = Palette.INK_DIM, size: int = 12) -> Label:
	return label(text, size, color, spaced(body_bold(), 2))
