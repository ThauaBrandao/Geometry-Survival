extends Node2D
## Forma Caótica da onda atual, desenhada por primitivos (_draw).
## - Escala automática: a forma sempre cabe em GameRules.SHAPE_BOX.
## - Visual neon: preenchimento translúcido, contorno com brilho; em formas
##   compostas cada parte tem cor própria e há uma linha divisória tracejada
##   (ajuda a decompor a figura — objetivo pedagógico do Setor Gamma).
## - Cotas técnicas (linhas de dimensão com marcadores) junto às arestas.
## - Animações: "construção" (contorno sendo traçado), flutuação, glitch
##   (erro) e estilhaçamento (fenda selada).

signal appeared

const MAX_SCALE := 40.0
const FONT_SIZE := 17
const LABEL_COLOR := Color(1.0, 0.9, 0.45)

var shape_type: GameManager.ShapeType = GameManager.ShapeType.TRIANGLE
var params: Dictionary = {}
var size_units: Vector2 = Vector2.ONE
var scale_px: float = MAX_SCALE

var main_color: Color = Palette.CYAN
var accent_color: Color = Color("4f7bff")

var appear: float = 1.0       # 0..1 traçado do contorno
var labels_alpha: float = 1.0
var glitch: float = 0.0
var shatter: float = 0.0      # 0..1 fragmentos voando
var bob_enabled := true

var _parts: Array = []        # [{pts, color}]
var _guides: Array = []       # linhas tracejadas [a, b]
var _dims: Array = []         # cotas [{a, b, text, side}]
var _frags: Array = []
var _t := 0.0


func setup(s_type: GameManager.ShapeType, s_params: Dictionary, s_size: Vector2 = Vector2.ZERO) -> void:
	shape_type = s_type
	params = s_params
	size_units = s_size if s_size != Vector2.ZERO else Vector2.ONE
	scale_px = compute_scale(size_units)
	shatter = 0.0
	glitch = 0.0
	_frags.clear()
	_build()
	queue_redraw()


func set_colors(main: Color, accent: Color) -> void:
	main_color = main
	accent_color = accent
	queue_redraw()


static func compute_scale(units: Vector2) -> float:
	var box := GameRules.SHAPE_BOX
	return minf(MAX_SCALE, minf(box.x / maxf(units.x, 0.01), box.y / maxf(units.y, 0.01)))


# ------------------------------------------------------------------ animações
func play_appear(dur: float = 0.8) -> void:
	appear = 0.0
	labels_alpha = 0.0
	modulate.a = 1.0
	scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, dur * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "appear", 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "labels_alpha", 1.0, 0.3)
	tw.chain().tween_callback(func(): emit_signal("appeared"))


func play_glitch(strong: bool) -> void:
	var tw := create_tween()
	tw.tween_property(self, "glitch", 1.0 if strong else 0.6, 0.05)
	tw.tween_property(self, "glitch", 0.25 if strong else 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Estilhaça a forma em triângulos que são sugados para o centro da fenda.
func play_shatter() -> void:
	_frags.clear()
	var rng := RandomNumberGenerator.new()
	for part in _parts:
		var pts: PackedVector2Array = part.pts
		var idx := Geometry2D.triangulate_polygon(pts)
		for i in range(0, idx.size(), 3):
			var tri := PackedVector2Array([pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]])
			var c := (tri[0] + tri[1] + tri[2]) / 3.0
			_frags.append({"tri": tri, "c": c, "col": _col(part),
				"vel": (c.normalized() if c.length() > 0.1 else Vector2.UP) * rng.randf_range(80, 220) + Vector2(0, rng.randf_range(-60, 20)),
				"spin": rng.randf_range(-6, 6)})
	var tw := create_tween()
	tw.tween_property(self, "shatter", 1.0, 0.75).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func play_vanish(dur: float = 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, dur)


func _process(delta: float) -> void:
	_t += delta * Settings.motion()
	queue_redraw()


# ------------------------------------------------------------------ geometria
func _build() -> void:
	_parts.clear()
	_guides.clear()
	_dims.clear()
	if params.is_empty():
		return
	var k := scale_px
	match shape_type:
		GameManager.ShapeType.TRIANGLE:
			var b: float = params.base * k
			var h: float = params.height * k
			_parts.append({"pts": PackedVector2Array([Vector2(-b/2, h/2), Vector2(b/2, h/2), Vector2(0, -h/2)]), "role": 0})
			_guides.append([Vector2(0, -h/2), Vector2(0, h/2)])
			_dims.append({"a": Vector2(-b/2, h/2), "b": Vector2(b/2, h/2), "text": "base = %d" % params.base, "side": "below"})
			_dims.append({"a": Vector2(b/2, -h/2), "b": Vector2(b/2, h/2), "text": "altura = %d" % params.height, "side": "right"})
		GameManager.ShapeType.SQUARE:
			var s: float = params.side * k
			_parts.append({"pts": _rect_pts(Rect2(-s/2, -s/2, s, s)), "role": 0})
			_dims.append({"a": Vector2(-s/2, s/2), "b": Vector2(s/2, s/2), "text": "lado = %d" % params.side, "side": "below"})
		GameManager.ShapeType.RECTANGLE:
			var w: float = params.width * k
			var h: float = params.height * k
			_parts.append({"pts": _rect_pts(Rect2(-w/2, -h/2, w, h)), "role": 0})
			_dims.append({"a": Vector2(-w/2, h/2), "b": Vector2(w/2, h/2), "text": "base = %d" % params.width, "side": "below"})
			_dims.append({"a": Vector2(w/2, -h/2), "b": Vector2(w/2, h/2), "text": "altura = %d" % params.height, "side": "right"})
		GameManager.ShapeType.CIRCLE:
			var r: float = params.radius * k
			var pts := PackedVector2Array()
			for i in 64:
				pts.append(Vector2(cos(i * TAU / 64.0), sin(i * TAU / 64.0)) * r)
			_parts.append({"pts": pts, "role": 0})
			if params.get("show_diameter", false):
				_dims.append({"a": Vector2(-r, 0), "b": Vector2(r, 0), "text": "diâmetro = %s" % GameRules.fmt(params.diameter), "side": "inside"})
			else:
				_dims.append({"a": Vector2.ZERO, "b": Vector2(r, 0), "text": "r = %s" % GameRules.fmt(params.radius), "side": "inside"})
		GameManager.ShapeType.COMPOSITE_RECT_TRI:
			var rw: float = params.rect_w * k
			var rh: float = params.rect_h * k
			var th: float = params.tri_height * k
			var oy := (rh + th) / 2.0
			var top := oy - rh
			_parts.append({"pts": _rect_pts(Rect2(-rw/2, top, rw, rh)), "role": 0})
			_parts.append({"pts": PackedVector2Array([Vector2(-rw/2, top), Vector2(rw/2, top), Vector2(0, top - th)]), "role": 1})
			_guides.append([Vector2(0, top - th), Vector2(0, top)])
			_guides.append([Vector2(-rw/2, top), Vector2(rw/2, top)])
			_dims.append({"a": Vector2(-rw/2, oy), "b": Vector2(rw/2, oy), "text": "largura = %d" % params.rect_w, "side": "below"})
			_dims.append({"a": Vector2(rw/2, top), "b": Vector2(rw/2, oy), "text": "alt. retângulo = %d" % params.rect_h, "side": "right"})
			_dims.append({"a": Vector2(rw/2, top - th), "b": Vector2(rw/2, top), "text": "alt. triângulo = %d" % params.tri_height, "side": "right"})
		GameManager.ShapeType.COMPOSITE_RECT_SEMI:
			var rw: float = params.rect_w * k
			var rh: float = params.rect_h * k
			var r: float = params.radius * k
			var oy := (rh + r) / 2.0
			var top := oy - rh
			_parts.append({"pts": _rect_pts(Rect2(-rw/2, top, rw, rh)), "role": 0})
			var semi := PackedVector2Array()
			for i in 33:
				var ang := i * PI / 32.0
				semi.append(Vector2(cos(ang) * r, top - sin(ang) * r))
			_parts.append({"pts": semi, "role": 1})
			_guides.append([Vector2(-rw/2, top), Vector2(rw/2, top)])
			_dims.append({"a": Vector2(-rw/2, oy), "b": Vector2(rw/2, oy), "text": "largura = %d" % params.rect_w, "side": "below"})
			_dims.append({"a": Vector2(rw/2, top), "b": Vector2(rw/2, oy), "text": "altura = %d" % params.rect_h, "side": "right"})


func _col(part: Dictionary) -> Color:
	return main_color if part.role == 0 else accent_color


func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


# ------------------------------------------------------------------ desenho
func _draw() -> void:
	if _parts.is_empty():
		return
	var bob := Vector2(0, sin(_t * 1.6) * 5.0) if bob_enabled else Vector2.ZERO
	if shatter > 0.0:
		_draw_fragments(bob)
		return
	# sombra projetada (profundidade)
	draw_set_transform(bob + Vector2(10, 16), 0, Vector2.ONE)
	for part in _parts:
		draw_colored_polygon(part.pts, Color(0, 0, 0, 0.35 * appear))
	draw_set_transform(bob, 0, Vector2.ONE)
	if glitch > 0.01:
		var off := Vector2(randf_range(-1, 1), randf_range(-0.3, 0.3)) * 10.0 * glitch
		for part in _parts:
			var p1: PackedVector2Array = part.pts.duplicate()
			var p2: PackedVector2Array = part.pts.duplicate()
			for i in p1.size():
				p1[i] += off
				p2[i] -= off
			p1.append(p1[0])
			p2.append(p2[0])
			draw_polyline(p1, Color(1, 0.2, 0.3, 0.7 * glitch), 2.0, true)
			draw_polyline(p2, Color(0.2, 0.9, 1, 0.7 * glitch), 2.0, true)
	for part in _parts:
		var c: Color = _col(part)
		var fill_a := 0.26 * clampf(appear * 1.4 - 0.4, 0.0, 1.0)
		draw_colored_polygon(part.pts, Color(c.r, c.g, c.b, fill_a))
		# brilho interno (faixa superior mais clara → volume)
		draw_colored_polygon(part.pts, Color(1, 1, 1, 0.04 * appear))
	for part in _parts:
		var outline: PackedVector2Array = part.pts.duplicate()
		outline.append(outline[0])
		Icons.glow_polyline(self, _partial(outline, appear), _col(part).lerp(Color.WHITE, 0.25), 2.5, 1.2)
	var gcol := Color(1, 1, 1, 0.55 * labels_alpha)
	for g in _guides:
		draw_dashed_line(g[0], g[1], gcol, 1.5, 6.0, true)
	_draw_dims()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _partial(pts: PackedVector2Array, t: float) -> PackedVector2Array:
	if t >= 1.0:
		return pts
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var goal := total * t
	var out := PackedVector2Array([pts[0]])
	var acc := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg >= goal:
			out.append(pts[i].lerp(pts[i + 1], (goal - acc) / maxf(seg, 0.001)))
			break
		out.append(pts[i + 1])
		acc += seg
	return out


func _draw_dims() -> void:
	if labels_alpha <= 0.01:
		return
	var font := UiKit.body_bold()
	var lc := Color(LABEL_COLOR.r, LABEL_COLOR.g, LABEL_COLOR.b, labels_alpha)
	var line_c := Color(1, 1, 1, 0.55 * labels_alpha)
	var shadow := Color(0, 0, 0, 0.85 * labels_alpha)
	for d in _dims:
		var a: Vector2 = d.a
		var b: Vector2 = d.b
		match d.side:
			"below":
				var y := a.y + 16.0
				draw_line(Vector2(a.x, a.y + 5), Vector2(a.x, y + 5), line_c, 1.0)
				draw_line(Vector2(b.x, b.y + 5), Vector2(b.x, y + 5), line_c, 1.0)
				draw_line(Vector2(a.x, y), Vector2(b.x, y), line_c, 1.5)
				_tick(Vector2(a.x, y), line_c)
				_tick(Vector2(b.x, y), line_c)
				var w := maxf(b.x - a.x, 220.0)
				var cx := (a.x + b.x) / 2.0
				draw_string_outline(font, Vector2(cx - w / 2.0, y + 22), d.text, HORIZONTAL_ALIGNMENT_CENTER, w, FONT_SIZE, 5, shadow)
				draw_string(font, Vector2(cx - w / 2.0, y + 22), d.text, HORIZONTAL_ALIGNMENT_CENTER, w, FONT_SIZE, lc)
			"right":
				var x := a.x + 16.0
				draw_line(Vector2(a.x + 5, a.y), Vector2(x + 5, a.y), line_c, 1.0)
				draw_line(Vector2(b.x + 5, b.y), Vector2(x + 5, b.y), line_c, 1.0)
				draw_line(Vector2(x, a.y), Vector2(x, b.y), line_c, 1.5)
				_tick(Vector2(x, a.y), line_c)
				_tick(Vector2(x, b.y), line_c)
				var pos := Vector2(x + 10, (a.y + b.y) / 2.0 + FONT_SIZE / 3.0)
				draw_string_outline(font, pos, d.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, shadow)
				draw_string(font, pos, d.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, lc)
			"inside":
				draw_dashed_line(a, b, Color(1, 1, 1, 0.85 * labels_alpha), 2.0, 7.0, true)
				draw_circle(a, 3.5, Color(1, 1, 1, labels_alpha))
				draw_circle(b, 3.5, Color(1, 1, 1, labels_alpha))
				var mid := (a + b) / 2.0 + Vector2(-110, -10)
				draw_string_outline(font, mid, d.text, HORIZONTAL_ALIGNMENT_CENTER, 220, FONT_SIZE, 5, shadow)
				draw_string(font, mid, d.text, HORIZONTAL_ALIGNMENT_CENTER, 220, FONT_SIZE, lc)


func _tick(p: Vector2, c: Color) -> void:
	draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), c, 1.5, true)


func _draw_fragments(bob: Vector2) -> void:
	var t := shatter
	for f in _frags:
		# primeiro se afastam, depois são sugados para o centro da fenda
		var out: Vector2 = f.c + f.vel * t * 0.9
		var pos := out.lerp(Vector2.ZERO, clampf((t - 0.35) / 0.65, 0.0, 1.0))
		var ang: float = f.spin * t
		var sc := 1.0 - t * 0.8
		var col: Color = f.col
		var tri := PackedVector2Array()
		for p in f.tri:
			tri.append(bob + pos + (p - f.c).rotated(ang) * sc)
		draw_colored_polygon(tri, Color(col.r, col.g, col.b, 0.6 * (1.0 - t)))
		tri.append(tri[0])
		draw_polyline(tri, Color(1, 1, 1, 0.8 * (1.0 - t)), 1.5, true)
