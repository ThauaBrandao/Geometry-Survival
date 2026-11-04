class_name Rift
extends Node2D
## A FENDA DIMENSIONAL (GDD §1, §9, §11): o rasgo por onde as Formas Caóticas
## entram. Abre a cada onda, pulsa conforme o risco de colapso, é SELADA
## quando o jogador acerta e SE EXPANDE (Entropia) quando ele erra.
## Desenhada 100% por código: bordas irregulares animadas, halo de luz,
## túnel interno com profundidade, faíscas e raios de instabilidade.

signal sealed
signal opened

const HEIGHT := 330.0
const MAX_HALF := 165.0
const SEGMENTS := 30

var openness: float = 0.0
var widen: float = 1.0
var instability: float = 0.2      # 0..1 (vem do risco)
var flash: float = 0.0
var color: Color = Palette.CYAN
var base_color: Color = Palette.CYAN

var _t := 0.0
var _arcs: Array = []
var _arc_timer := 0.0
var _sparks: CPUParticles2D
var _tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_sparks = CPUParticles2D.new()
	_sparks.amount = 36
	_sparks.lifetime = 1.1
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.emission_rect_extents = Vector2(40, HEIGHT * 0.4)
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 180
	_sparks.gravity = Vector2(0, -20)
	_sparks.initial_velocity_min = 20
	_sparks.initial_velocity_max = 90
	_sparks.scale_amount_min = 1.5
	_sparks.scale_amount_max = 3.5
	_sparks.emitting = false
	add_child(_sparks)
	_update_spark_color()


func set_theme_color(c: Color) -> void:
	base_color = c
	_recolor()


func _recolor() -> void:
	color = base_color.lerp(Palette.DANGER, clampf((instability - 0.55) * 2.2, 0.0, 1.0))
	_update_spark_color()


func _update_spark_color() -> void:
	if _sparks == null:
		return
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color.WHITE, color, Color(color.r, color.g, color.b, 0)])
	_sparks.color_ramp = ramp


func _anim() -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	return _tween


## Abre a fenda. risk (10–90) define a instabilidade visual.
func open(risk: int) -> void:
	instability = clampf((risk - 10) / 80.0, 0.0, 1.0)
	widen = 1.0
	_recolor()
	_sparks.emitting = true
	_sparks.amount = int(24 + 40 * instability)
	var tw := _anim()
	tw.tween_property(self, "openness", 1.0, 0.85).from(0.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): emit_signal("opened"))


## Selar: a fenda se fecha rapidamente com clarão e onda de choque.
func seal() -> void:
	var tw := _anim()
	tw.tween_property(self, "widen", 1.12, 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "openness", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_sparks.emitting = false
		flash = 1.0
		Fx.shockwave(get_parent(), position, color.lerp(Color.WHITE, 0.4), 260.0, 0.7, 5.0)
		Fx.shockwave(get_parent(), position, Palette.GOLD, 150.0, 0.5, 3.0)
		Fx.burst(get_parent(), position, color, 70, 420.0, 0.9)
		emit_signal("sealed"))
	tw.tween_property(self, "flash", 0.0, 0.5)


## A fenda resiste (erro em risco baixo): tremor e leve alargamento.
func resist() -> void:
	var tw := _anim()
	tw.tween_property(self, "widen", 1.15, 0.12)
	tw.tween_property(self, "widen", 1.05, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A Entropia vence (erro em risco alto): a fenda se expande e fica vermelha.
func expand() -> void:
	instability = 1.0
	_recolor()
	_sparks.amount = 80
	var tw := _anim()
	tw.tween_property(self, "widen", 1.7, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "widen", 1.35, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	_sparks.emitting = false
	var tw := _anim()
	tw.tween_property(self, "openness", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _process(delta: float) -> void:
	var m := Settings.motion()
	_t += delta * (0.3 + 0.7 * m)
	_sparks.emission_rect_extents = Vector2(MAX_HALF * 0.5 * openness * widen + 4, HEIGHT * 0.42 * openness + 4)
	_arc_timer -= delta
	if openness > 0.6 and _arc_timer <= 0.0 and m > 0.0:
		_arc_timer = lerpf(1.6, 0.18, instability) * _rng.randf_range(0.6, 1.4)
		_spawn_arc()
	for a in _arcs:
		a.life -= delta
	_arcs = _arcs.filter(func(a): return a.life > 0.0)
	queue_redraw()


func _spawn_arc() -> void:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var y := _rng.randf_range(-0.35, 0.35) * HEIGHT
	var start := Vector2(side * _half_at(y) * 0.95, y)
	var pts := PackedVector2Array([start])
	var p := start
	for i in 6:
		p += Vector2(side * _rng.randf_range(10, 26), _rng.randf_range(-18, 18))
		pts.append(p)
	_arcs.append({"pts": pts, "life": 0.14})


func _half_at(y: float) -> float:
	var h := HEIGHT * (0.35 + 0.65 * openness)
	var tt := clampf(y / h + 0.5, 0.0, 1.0)
	return MAX_HALF * pow(sin(PI * tt), 0.9) * openness * widen


func _edge(scale: float, jag: float) -> PackedVector2Array:
	var h := HEIGHT * (0.35 + 0.65 * openness) * scale
	var amp := jag * clampf(openness * widen, 0.0, 1.0) * scale
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var speed := 4.0 + instability * 10.0
	for i in SEGMENTS:
		var tt := (i + 0.5) / SEGMENTS
		var y := (tt - 0.5) * h
		var prof := pow(sin(PI * tt), 0.9)
		var half := MAX_HALF * prof * openness * widen * scale
		var jl := (sin(i * 1.9 + _t * speed) * 0.6 + sin(i * 4.3 - _t * speed * 1.7) * 0.4) * amp * prof * 0.5
		var jr := (sin(i * 2.3 - _t * speed * 1.2) * 0.6 + sin(i * 5.1 + _t * speed * 1.3) * 0.4) * amp * prof * 0.5
		left.append(Vector2(-half + jl, y))
		right.append(Vector2(half + jr, y))
	var poly := PackedVector2Array([Vector2(0, -h * 0.5)])
	poly.append_array(left)
	poly.append(Vector2(0, h * 0.5))
	right.reverse()
	poly.append_array(right)
	return poly


func _draw() -> void:
	if openness <= 0.01 and flash <= 0.01:
		return
	var jag := 10.0 + 22.0 * instability
	var pulse := 0.85 + 0.15 * sin(_t * (3.0 + 6.0 * instability))
	if openness > 0.01:
		# luz projetada no ambiente
		Icons.soft_light(self, Vector2.ZERO, MAX_HALF * 2.1 * openness * widen,
			Color(color.r, color.g, color.b, 0.35 * pulse), 7)
		# halo externo
		for k in [1.35, 1.18]:
			var halo := _edge(k, jag * 1.2)
			draw_colored_polygon(halo, Color(color.r, color.g, color.b, 0.10 * pulse))
		# vazio
		var core := _edge(1.0, jag)
		draw_colored_polygon(core, Palette.VOID)
		# túnel interno (profundidade): contornos concêntricos que "afundam"
		for k in 4:
			var ph := fmod(_t * 0.35 + k * 0.25, 1.0)
			var sc := 1.0 - ph * 0.85
			var ring := _edge(sc, jag * sc)
			ring.append(ring[0])
			draw_polyline(ring, Color(color.r, color.g, color.b, 0.35 * (1.0 - ph) * openness), 1.5, true)
		# borda luminosa
		var rim := core.duplicate()
		rim.append(rim[0])
		Icons.glow_polyline(self, rim, Color(color.r, color.g, color.b, 0.95), 2.5, 1.3)
		draw_polyline(rim, Color(1, 1, 1, 0.55 * pulse), 1.0, true)
		# raios de instabilidade
		for a in _arcs:
			Icons.glow_polyline(self, a.pts, Color(1, 1, 1, 0.9), 1.5, 1.0)
	if flash > 0.01:
		Icons.soft_light(self, Vector2.ZERO, 300.0 * (1.2 - flash * 0.4), Color(1, 1, 1, 0.5 * flash), 6)
		draw_line(Vector2(0, -HEIGHT * 0.5), Vector2(0, HEIGHT * 0.5), Color(1, 1, 1, flash), 3.0 * flash + 1.0)
