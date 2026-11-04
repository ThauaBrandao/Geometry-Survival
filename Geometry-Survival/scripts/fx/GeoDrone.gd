class_name GeoDrone
extends Node2D
## Geo, a IA analítica (GDD §9/§16): drone esférico com olho que acompanha
## o estado da FSM (cor e animação).

var mood: Color = Palette.CYAN
var alert: float = 0.0
var _t := 0.0


func set_mood(c: Color, is_alert: bool = false) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "mood", c, 0.3)
	tw.tween_property(self, "alert", 1.0 if is_alert else 0.0, 0.3)


func _process(delta: float) -> void:
	_t += delta * (0.3 + 0.7 * Settings.motion())
	queue_redraw()


func _draw() -> void:
	var o := Vector2(0, sin(_t * 2.6) * 3.0)
	Icons.soft_light(self, o, 34.0, Color(mood.r, mood.g, mood.b, 0.35), 5)
	# anel orbital
	draw_set_transform(o, sin(_t) * 0.2, Vector2(1.0, 0.35))
	draw_arc(Vector2.ZERO, 24.0, 0, TAU, 40, Color(mood.r, mood.g, mood.b, 0.7), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_circle(o, 15.0, Color("0a1226"))
	Icons.glow_circle(self, o, 15.0, mood, 2.0, 1.0)
	var look := Vector2(cos(_t * 0.7) * 3.0, sin(_t * 1.1) * 2.0)
	var eye_r := 5.0 + alert * 1.5 * (0.5 + 0.5 * sin(_t * 18.0))
	draw_circle(o + look, eye_r, mood.lerp(Color.WHITE, 0.4))
	draw_circle(o + look, 2.0, Color.WHITE)
