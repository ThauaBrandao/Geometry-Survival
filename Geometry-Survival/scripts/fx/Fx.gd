class_name Fx
extends RefCounted
## Efeitos reutilizáveis: explosão de partículas, onda de choque, texto
## flutuante e "pop" de escala. Tudo gerado por código.

static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 40,
		speed: float = 260.0, life: float = 0.9, gravity: float = 0.0, size: float = 3.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.spread = 180.0
	p.direction = Vector2.UP
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = speed * 0.6
	p.damping_max = speed * 1.2
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), color, Color(color.r, color.g, color.b, 0.0)])
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	return p


## Poeira contínua (camada de profundidade): partículas lentas em uma área.
static func dust(parent: Node, rect: Rect2, color: Color, amount: int = 40) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = rect.get_center()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size / 2.0
	p.direction = Vector2(0.3, -1)
	p.spread = 40
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 4
	p.initial_velocity_max = 18
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	var ramp := Gradient.new()
	var clear := Color(color.r, color.g, color.b, 0.0)
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([clear, color, color, clear])
	p.color_ramp = ramp
	parent.add_child(p)
	return p


static func shockwave(parent: Node, pos: Vector2, color: Color, radius: float = 180.0,
		dur: float = 0.6, width: float = 6.0) -> void:
	var w := Shockwave.new()
	w.position = pos
	w.color = color
	w.max_radius = radius
	w.width = width
	parent.add_child(w)
	var tw := w.create_tween()
	tw.tween_property(w, "t", 1.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(w.queue_free)


static func float_text(parent: Node, pos: Vector2, text: String, color: Color,
		size: int = 34, rise: float = 70.0, dur: float = 1.1) -> Label:
	var l := UiKit.label(text, size, color, UiKit.display_bold(), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.outline(l, Color(0, 0, 0, 0.8), 8)
	UiKit.glow(l, color, 10)
	l.size = Vector2(400, size * 1.6)
	l.position = pos - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.4, 0.4)
	parent.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - rise, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	tw.chain().tween_callback(l.queue_free)
	return l


static func pop(node: CanvasItem, amount: float = 0.15, dur: float = 0.3) -> void:
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2.0
	var base: Vector2 = node.scale
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base * (1.0 + amount), dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, dur * 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func shake_control(node: CanvasItem, strength: float = 10.0, dur: float = 0.35) -> void:
	var base: Vector2 = node.position
	var tw := node.create_tween()
	var steps := 7
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(node, "position", base + Vector2(randf_range(-1, 1) * strength * k, 0), dur / steps)
	tw.tween_property(node, "position", base, dur / steps)
