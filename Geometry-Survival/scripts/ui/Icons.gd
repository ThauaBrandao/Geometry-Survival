class_name Icons
extends RefCounted
## Ícones vetoriais desenhados por código (substituem glifos como ♥ e ⚠,
## que não existem nas fontes Web — BL-13). Todos cabem em um quadrado de lado s.

static func draw(ci: CanvasItem, icon: String, c: Vector2, s: float, col: Color, w: float = 2.0) -> void:
	var h := s * 0.5
	match icon:
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.6, -h * 0.8),
				c + Vector2(h * 0.8, 0), c + Vector2(-h * 0.6, h * 0.8)]), col)
		"continue":
			for i in 2:
				var o := Vector2(-h * 0.55 + i * h * 0.75, 0)
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(-h * 0.4, -h * 0.7),
					c + o + Vector2(h * 0.45, 0), c + o + Vector2(-h * 0.4, h * 0.7)]), col)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-h * 0.6, -h * 0.7), Vector2(h * 0.4, h * 1.4)), col)
			ci.draw_rect(Rect2(c + Vector2(h * 0.2, -h * 0.7), Vector2(h * 0.4, h * 1.4)), col)
		"gear":
			var pts := PackedVector2Array()
			for i in 32:
				var a := i * TAU / 32.0
				var r := h * (0.95 if (i / 2) % 2 == 0 else 0.72)
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c, h * 0.32, Palette.BG_MID)
		"help":
			ci.draw_arc(c, h * 0.9, 0, TAU, 32, col, w, true)
			var q := PackedVector2Array()
			for i in 13:
				var a := PI * 1.05 + i * (PI * 1.25 / 12.0)
				q.append(c + Vector2(0, -h * 0.2) + Vector2(cos(a), sin(a)) * h * 0.33)
			q.append(c + Vector2(0, h * 0.2))
			ci.draw_polyline(q, col, w, true)
			ci.draw_circle(c + Vector2(0, h * 0.5), w * 0.9, col)
		"exit":
			ci.draw_rect(Rect2(c + Vector2(-h * 0.8, -h * 0.85), Vector2(h * 1.0, h * 1.7)), col, false, w)
			ci.draw_line(c + Vector2(-h * 0.1, 0), c + Vector2(h * 0.9, 0), col, w, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(h * 0.55, -h * 0.35),
				c + Vector2(h * 0.9, 0), c + Vector2(h * 0.55, h * 0.35)]), col, w, true)
		"back":
			ci.draw_polyline(PackedVector2Array([c + Vector2(h * 0.2, -h * 0.6),
				c + Vector2(-h * 0.45, 0), c + Vector2(h * 0.2, h * 0.6)]), col, w * 1.3, true)
		"map":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h, -h * 0.6), c + Vector2(-h * 0.35, -h * 0.8),
				c + Vector2(h * 0.35, -h * 0.55), c + Vector2(h, -h * 0.8), c + Vector2(h, h * 0.6),
				c + Vector2(h * 0.35, h * 0.8), c + Vector2(-h * 0.35, h * 0.55), c + Vector2(-h, h * 0.8),
				c + Vector2(-h, -h * 0.6)]), col, w, true)
			ci.draw_line(c + Vector2(-h * 0.35, -h * 0.8), c + Vector2(-h * 0.35, h * 0.55), col, w * 0.7)
			ci.draw_line(c + Vector2(h * 0.35, -h * 0.55), c + Vector2(h * 0.35, h * 0.8), col, w * 0.7)
		"heart":
			ci.draw_colored_polygon(heart_points(c, s), col)
		"heart_empty":
			var hp := heart_points(c, s)
			hp.append(hp[0])
			ci.draw_polyline(hp, col, w, true)
		"lock":
			ci.draw_rect(Rect2(c + Vector2(-h * 0.7, -h * 0.1), Vector2(h * 1.4, h * 1.0)), col)
			ci.draw_arc(c + Vector2(0, -h * 0.1), h * 0.45, PI, TAU, 16, col, w * 1.3, true)
			ci.draw_circle(c + Vector2(0, h * 0.35), h * 0.14, Palette.BG_DEEP)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.6, 0), c + Vector2(-h * 0.15, h * 0.5),
				c + Vector2(h * 0.7, -h * 0.55)]), col, w * 1.6, true)
		"star":
			ci.draw_colored_polygon(star_points(c, h, h * 0.45), col)
		"star_empty":
			var sp := star_points(c, h, h * 0.45)
			sp.append(sp[0])
			ci.draw_polyline(sp, col, w, true)
		"warning":
			var tri := PackedVector2Array([c + Vector2(0, -h * 0.9), c + Vector2(h, h * 0.8), c + Vector2(-h, h * 0.8)])
			ci.draw_colored_polygon(tri, col)
			ci.draw_line(c + Vector2(0, -h * 0.35), c + Vector2(0, h * 0.25), Palette.BG_DEEP, w * 1.3)
			ci.draw_circle(c + Vector2(0, h * 0.52), w * 0.8, Palette.BG_DEEP)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.9, -h * 0.3), c + Vector2(-h * 0.45, -h * 0.3),
				c + Vector2(0, -h * 0.75), c + Vector2(0, h * 0.75), c + Vector2(-h * 0.45, h * 0.3),
				c + Vector2(-h * 0.9, h * 0.3)]), col)
			ci.draw_arc(c + Vector2(0.1 * h, 0), h * 0.45, -0.9, 0.9, 10, col, w, true)
			ci.draw_arc(c + Vector2(0.1 * h, 0), h * 0.8, -0.9, 0.9, 12, col, w, true)
		"home":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.9, -h * 0.05), c + Vector2(0, -h * 0.85),
				c + Vector2(h * 0.9, -h * 0.05)]), col, w * 1.2, true)
			ci.draw_rect(Rect2(c + Vector2(-h * 0.6, -h * 0.15), Vector2(h * 1.2, h * 0.95)), col, false, w)
		"triangle":
			var t := PackedVector2Array([c + Vector2(0, -h * 0.85), c + Vector2(h * 0.9, h * 0.7), c + Vector2(-h * 0.9, h * 0.7), c + Vector2(0, -h * 0.85)])
			ci.draw_polyline(t, col, w, true)
		"circle":
			ci.draw_arc(c, h * 0.85, 0, TAU, 40, col, w, true)
		"square":
			ci.draw_rect(Rect2(c - Vector2(h, h) * 0.75, Vector2(h, h) * 1.5), col, false, w)


static func heart_points(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var t := i * TAU / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y + 2.0) * (s / 34.0))
	return pts


static func star_points(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return pts


## Linha com brilho neon (camadas translúcidas).
static func glow_polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float = 2.0, glow: float = 1.0) -> void:
	if pts.size() < 2:
		return
	if glow > 0.0:
		ci.draw_polyline(pts, Color(col.r, col.g, col.b, col.a * 0.10 * glow), w * 6.0, true)
		ci.draw_polyline(pts, Color(col.r, col.g, col.b, col.a * 0.22 * glow), w * 3.0, true)
	ci.draw_polyline(pts, col, w, true)


static func glow_circle(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float = 2.0, glow: float = 1.0) -> void:
	if glow > 0.0:
		ci.draw_arc(c, r, 0, TAU, 64, Color(col.r, col.g, col.b, col.a * 0.10 * glow), w * 6.0, true)
		ci.draw_arc(c, r, 0, TAU, 64, Color(col.r, col.g, col.b, col.a * 0.22 * glow), w * 3.0, true)
	ci.draw_arc(c, r, 0, TAU, 64, col, w, true)


## Brilho radial suave (disco em camadas) — "iluminação" falsa em 2D.
static func soft_light(ci: CanvasItem, c: Vector2, r: float, col: Color, layers: int = 6) -> void:
	for i in layers:
		var k := 1.0 - float(i) / layers
		ci.draw_circle(c, r * k, Color(col.r, col.g, col.b, col.a / layers))
