class_name Shockwave
extends Node2D
## Anel luminoso que se expande e desaparece.

var t: float = 0.0:
	set(v):
		t = v
		queue_redraw()
var color: Color = Color.WHITE
var max_radius: float = 180.0
var width: float = 6.0


func _draw() -> void:
	var r := max_radius * t
	var a := 1.0 - t
	var c := Color(color.r, color.g, color.b, a)
	draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(c.r, c.g, c.b, a * 0.18), width * 4.0 * (1.0 - t * 0.5), true)
	draw_arc(Vector2.ZERO, r, 0, TAU, 72, c, width * (1.0 - t * 0.7), true)
