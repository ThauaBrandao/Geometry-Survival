class_name Logo
extends Control
## Logotipo animado: emblema (triângulo + quadrado + círculo que se montam),
## "GEOMETRY SURVIVAL" com brilho e falha cromática ocasional, e o subtítulo.

var build: float = 0.0:
	set(v):
		build = v
		queue_redraw()
var _t := 0.0
var _glitch := 0.0
var _next_glitch := 3.0


func _init() -> void:
	size = Vector2(620, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play_intro() -> void:
	build = 0.0
	var tw := create_tween()
	tw.tween_property(self, "build", 1.0, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_next_glitch -= delta
	if _next_glitch <= 0.0 and Settings.motion() > 0.0:
		_next_glitch = randf_range(3.0, 6.0)
		_glitch = 1.0
	_glitch = move_toward(_glitch, 0.0, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	var cx := size.x / 2.0
	var e := Vector2(cx, 62)
	var k1 := clampf(build * 2.0, 0.0, 1.0)
	var k2 := clampf(build * 2.0 - 0.5, 0.0, 1.0)
	var k3 := clampf(build * 1.6 - 0.6, 0.0, 1.0)
	# emblema: peças voam de fora até o centro
	var rot := _t * 0.4
	var tri := PackedVector2Array()
	for i in 4:
		var a := -PI / 2 + i * TAU / 3.0 + rot
		tri.append(e + Vector2(-260, -40) * (1.0 - k1) + Vector2(cos(a), sin(a)) * 54.0)
	Icons.soft_light(self, e, 120.0 * k2, Color(0.15, 0.9, 1.0, 0.25), 6)
	Icons.glow_polyline(self, tri, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, k1), 2.5, 1.2)
	var sq_c := e + Vector2(260, 30) * (1.0 - k2)
	var sq := PackedVector2Array()
	for i in 5:
		var a := PI / 4 + i * TAU / 4.0 - rot * 0.7
		sq.append(sq_c + Vector2(cos(a), sin(a)) * 30.0)
	Icons.glow_polyline(self, sq, Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, k2), 2.5, 1.0)
	Icons.glow_circle(self, e + Vector2(0, 160) * (1.0 - k1), 20.0, Color(Palette.VIOLET.r, Palette.VIOLET.g, Palette.VIOLET.b, k1), 2.5, 1.0)
	draw_circle(e, 4.0 * k2, Color.WHITE)
	# texto
	var f := UiKit.spaced(UiKit.display_bold(), 8)
	var a := k3
	var y1 := 170.0
	var y2 := 222.0
	var g := _glitch * 6.0
	if g > 0.1:
		draw_string(f, Vector2(g, y1), "GEOMETRY", HORIZONTAL_ALIGNMENT_CENTER, size.x, 54, Color(1, 0.2, 0.35, 0.6 * a))
		draw_string(f, Vector2(-g, y1), "GEOMETRY", HORIZONTAL_ALIGNMENT_CENTER, size.x, 54, Color(0.1, 0.9, 1, 0.6 * a))
	for i in 3:
		draw_string_outline(f, Vector2(0, y1), "GEOMETRY", HORIZONTAL_ALIGNMENT_CENTER, size.x, 54, 10 + i * 8, Color(0.15, 0.9, 1.0, 0.07 * a))
	draw_string(f, Vector2(0, y1), "GEOMETRY", HORIZONTAL_ALIGNMENT_CENTER, size.x, 54, Color(1, 1, 1, a))
	for i in 3:
		draw_string_outline(f, Vector2(0, y2), "SURVIVAL", HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, 10 + i * 8, Color(1, 0.79, 0.29, 0.06 * a))
	draw_string(f, Vector2(0, y2), "SURVIVAL", HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, a))
	# subtítulo com filetes
	var sub := UiKit.spaced(UiKit.body_bold(), 6)
	var sa := clampf(build * 2.0 - 1.0, 0.0, 1.0)
	draw_string(sub, Vector2(0, 250), "O CÁLCULO FINAL", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(0.8, 0.88, 1, sa))
	var lw := 90.0 * sa
	draw_line(Vector2(cx - 110 - lw, 244), Vector2(cx - 110, 244), Color(1, 1, 1, 0.35 * sa), 1.0)
	draw_line(Vector2(cx + 110, 244), Vector2(cx + 110 + lw, 244), Color(1, 1, 1, 0.35 * sa), 1.0)
