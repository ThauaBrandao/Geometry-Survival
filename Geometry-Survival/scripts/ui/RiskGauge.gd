class_name RiskGauge
extends Control
## Medidor semicircular do Risco de Colapso (Pilar 2 — Risco Legível).
## Zonas verde → âmbar → vermelha; ponteiro com mola; acima de 70% pulsa.

var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()
var target: int = 0
var _t := 0.0


func set_risk(r: int, animate: bool = true) -> void:
	target = r
	if animate:
		var tw := create_tween()
		tw.tween_property(self, "value", float(r), 0.9).from(0.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		value = r


func _process(delta: float) -> void:
	_t += delta
	if target > GameRules.HIGH_RISK_THRESHOLD:
		queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.y - 10)
	var r := minf(size.x / 2.0 - 12, size.y - 22)
	var a0 := PI
	# trilha em zonas
	var zones := [[0.0, 45.0, Palette.SUCCESS], [45.0, 70.0, Palette.WARN], [70.0, 100.0, Palette.DANGER]]
	for z in zones:
		var s: float = a0 + PI * z[0] / 100.0
		var e: float = a0 + PI * z[1] / 100.0
		var col: Color = z[2]
		draw_arc(c, r, s + 0.02, e - 0.02, 24, Color(col.r, col.g, col.b, 0.22), 10.0, true)
	# preenchimento até o valor
	var vcol := Palette.risk_color(int(value))
	var ve := a0 + PI * clampf(value, 0, 100) / 100.0
	var pulse := 1.0
	if target > GameRules.HIGH_RISK_THRESHOLD:
		pulse = 0.75 + 0.25 * sin(_t * 8.0)
	draw_arc(c, r, a0, ve, 48, Color(vcol.r, vcol.g, vcol.b, 0.25 * pulse), 22.0, true)
	draw_arc(c, r, a0, ve, 48, Color(vcol.r, vcol.g, vcol.b, pulse), 10.0, true)
	# marcas
	for i in 11:
		var a := a0 + PI * i / 10.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (r - 14), c + d * (r - (20 if i % 5 == 0 else 17)), Color(1, 1, 1, 0.35), 1.5)
	# limiar 70%
	var at := a0 + PI * 0.7
	var dt := Vector2(cos(at), sin(at))
	draw_line(c + dt * (r - 8), c + dt * (r + 10), Color(1, 1, 1, 0.8), 2.0)
	# ponteiro
	var nd := Vector2(cos(ve), sin(ve))
	draw_line(c, c + nd * (r - 18), Color.WHITE, 3.0, true)
	draw_circle(c, 7, Color.WHITE)
	draw_circle(c, 3, vcol)
