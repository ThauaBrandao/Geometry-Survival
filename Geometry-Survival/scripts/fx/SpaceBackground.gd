class_name SpaceBackground
extends Node2D
## Cenário dinâmico em camadas (profundidade 2D):
##   0. nebulosa + estrelas (shader, parallax lento)
##   1. formas geométricas distantes flutuando (parallax médio)
##   2. grade cartesiana em perspectiva rolando (estilo "Tron", GDD §13)
##   3. formas próximas + poeira luminosa (parallax forte)
## Reage ao mouse (parallax) e troca de paleta suavemente por setor.

const W := 1152.0
const H := 648.0

var sky := ColorRect.new()
var far_layer := Node2D.new()
var grid_layer := Node2D.new()
var near_layer := Node2D.new()
var dust_p: CPUParticles2D

var accent: Color = Palette.CYAN
var grid_alpha: float = 0.0
var grid_target: float = 0.0
var horizon: float = 430.0
var danger: float = 0.0
var par: Vector2 = Vector2.ZERO
var _shapes: Array = []
var _t := 0.0
var _mat: ShaderMaterial
var _pal_tween: Tween


func _ready() -> void:
	sky.size = Vector2(W, H)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/nebula.gdshader")
	sky.material = _mat
	add_child(sky)
	for l in [far_layer, grid_layer, near_layer]:
		add_child(l)
	far_layer.draw.connect(_draw_shapes.bind(far_layer, false))
	grid_layer.draw.connect(_draw_grid)
	near_layer.draw.connect(_draw_shapes.bind(near_layer, true))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 22:
		var near := i >= 15
		_shapes.append({
			"pos": Vector2(rng.randf_range(0, W), rng.randf_range(0, H)),
			"depth": rng.randf_range(0.9, 1.4) if near else rng.randf_range(0.2, 0.6),
			"kind": rng.randi_range(0, 3),
			"size": rng.randf_range(28, 60) if near else rng.randf_range(10, 34),
			"rot": rng.randf_range(0, TAU),
			"spin": rng.randf_range(-0.35, 0.35),
			"vel": Vector2(rng.randf_range(-6, 6), rng.randf_range(-14, -4)),
			"near": near,
		})
	dust_p = Fx.dust(near_layer, Rect2(0, 0, W, H), Color(1, 1, 1, 0.35), 50)
	set_palette(Palette.MENU_SKY, Palette.CYAN, false, 0.0)


func set_palette(colors: Array, acc: Color, show_grid: bool, dur: float = 0.8) -> void:
	grid_target = 1.0 if show_grid else 0.0
	if _pal_tween:
		_pal_tween.kill()
	if dur <= 0.0:
		_mat.set_shader_parameter("col_a", colors[0])
		_mat.set_shader_parameter("col_b", colors[1])
		_mat.set_shader_parameter("col_c", colors[2])
		accent = acc
		return
	_pal_tween = create_tween().set_parallel(true)
	for i in 3:
		var key: String = ["col_a", "col_b", "col_c"][i]
		var from: Color = _mat.get_shader_parameter(key)
		_pal_tween.tween_method(func(c): _mat.set_shader_parameter(key, c), from, colors[i], dur)
	_pal_tween.tween_property(self, "accent", acc, dur)


func set_sector(i: int, show_grid: bool = true, dur: float = 0.8) -> void:
	var s := Palette.sector(i)
	set_palette(s.sky, s.main, show_grid, dur)


func set_danger(v: float, dur: float = 0.4) -> void:
	create_tween().tween_property(self, "danger", v, dur)


func _process(delta: float) -> void:
	var m := Settings.motion()
	_t += delta * (0.25 + 0.75 * m)
	var vp := get_viewport()
	var target := Vector2.ZERO
	if vp and m > 0.0:
		var mp := vp.get_mouse_position()
		target = ((mp / Vector2(W, H)) - Vector2(0.5, 0.5)) * 2.0
		target = target.clamp(Vector2(-1, -1), Vector2(1, 1))
	par = par.lerp(target, clampf(delta * 2.5, 0.0, 1.0))
	grid_alpha = move_toward(grid_alpha, grid_target, delta * 1.5)
	_mat.set_shader_parameter("parallax", par + Vector2(_t * 0.05, 0))
	_mat.set_shader_parameter("motion", m)
	_mat.set_shader_parameter("danger", danger)
	for s in _shapes:
		s.pos += s.vel * delta * s.depth * (0.2 + 0.8 * m)
		s.rot += s.spin * delta * (0.2 + 0.8 * m)
		if s.pos.y < -80:
			s.pos.y = H + 80
		if s.pos.x < -80:
			s.pos.x = W + 80
		elif s.pos.x > W + 80:
			s.pos.x = -80
	far_layer.position = -par * 14.0
	near_layer.position = -par * 38.0
	far_layer.queue_redraw()
	near_layer.queue_redraw()
	grid_layer.queue_redraw()


func _shape_pts(kind: int, c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var n: int = [3, 4, 24, 6][kind]
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := rot + i * TAU / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_shapes(layer: Node2D, near: bool) -> void:
	for s in _shapes:
		if s.near != near:
			continue
		var a: float = clampf(s.depth * (0.25 if near else 0.45), 0.05, 0.4)
		var col := Color(accent.r, accent.g, accent.b, a)
		var pts := _shape_pts(s.kind, s.pos, s.size, s.rot)
		if near:
			# formas próximas: desfocadas (camadas largas e translúcidas)
			layer.draw_polyline(pts, Color(col.r, col.g, col.b, a * 0.25), 10.0, true)
			layer.draw_polyline(pts, Color(col.r, col.g, col.b, a * 0.5), 3.0, true)
		else:
			layer.draw_colored_polygon(pts, Color(col.r, col.g, col.b, a * 0.12))
			layer.draw_polyline(pts, col, 1.5, true)


func _draw_grid() -> void:
	if grid_alpha <= 0.01:
		return
	var vp := Vector2(W / 2.0 - par.x * 40.0, horizon - par.y * 10.0)
	var col := Color(accent.r, accent.g, accent.b, 0.30 * grid_alpha)
	# brilho do horizonte
	for i in 6:
		var hh := 26.0 - i * 4.0
		grid_layer.draw_rect(Rect2(0, vp.y - hh / 2.0, W, hh), Color(accent.r, accent.g, accent.b, 0.035 * grid_alpha))
	grid_layer.draw_line(Vector2(0, vp.y), Vector2(W, vp.y), Color(accent.r, accent.g, accent.b, 0.55 * grid_alpha), 1.5)
	# linhas convergentes
	for i in range(-14, 15):
		var x_bottom := W / 2.0 + i * 95.0 - par.x * 90.0
		grid_layer.draw_line(vp, Vector2(x_bottom, H + 20), col, 1.0, true)
	# linhas horizontais rolando em direção ao jogador
	var scroll := fmod(_t * 0.35, 1.0)
	for i in 14:
		var z := (i + scroll) / 14.0
		var y := vp.y + (H - vp.y) * z * z
		var fade := clampf(z * 1.6, 0.0, 1.0)
		grid_layer.draw_line(Vector2(0, y), Vector2(W, y), Color(col.r, col.g, col.b, col.a * fade), 1.0)
