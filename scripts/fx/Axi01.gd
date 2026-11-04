class_name Axi01
extends Node2D
## Axi-01, a Arquiteta Dimensional (GDD §9) — personagem vetorial animada.
## Componentes: cabeça com visor, torso geométrico, núcleo de energia, capa
## em fitas, mãos flutuantes, halo pentagonal e satélites (triângulo,
## quadrado e círculo) orbitando em profundidade.
## Estados: idle · cast (feixe até a fenda) · success · hurt · victory · defeat.

const BODY := Color("27e8ff")
const CORE := Color("ffc94a")
const DARK := Color("0a1226")

var show_platform := true
var state := "idle"
var arm: float = 0.0          # 0 = repouso, 1 = braço estendido (lançando)
var lift: float = 0.0         # deslocamento vertical extra
var knock: float = 0.0        # recuo horizontal
var kneel: float = 0.0
var hurt_flash: float = 0.0
var glow_boost: float = 0.0
var halo_speed: float = 0.4
var arms_up: float = 0.0
var beam: float = 0.0         # 0..1 intensidade do feixe
var beam_target: Vector2 = Vector2(400, -40)   # coordenadas locais

var _t := 0.0
var _halo_rot := 0.0
var _tw: Tween


func _process(delta: float) -> void:
	var m := Settings.motion()
	_t += delta * (0.3 + 0.7 * m)
	_halo_rot += delta * halo_speed * (0.3 + 0.7 * m)
	queue_redraw()


func _anim() -> Tween:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	return _tw


func idle() -> void:
	state = "idle"
	var tw := _anim().set_parallel(true)
	for p in ["arm", "lift", "knock", "kneel", "arms_up", "glow_boost", "beam"]:
		tw.tween_property(self, p, 0.0, 0.4)
	tw.tween_property(self, "halo_speed", 0.4, 0.6)


## Lança o feixe em direção a um ponto global (a fenda).
func cast_at(global_target: Vector2) -> void:
	state = "cast"
	beam_target = to_local(global_target)
	var tw := _anim()
	tw.tween_property(self, "arm", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "beam", 1.0, 0.1)
	tw.tween_interval(0.25)
	tw.tween_property(self, "beam", 0.0, 0.25)


func success() -> void:
	state = "success"
	var tw := _anim()
	tw.set_parallel(true)
	tw.tween_property(self, "lift", 26.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "glow_boost", 1.0, 0.2)
	tw.tween_property(self, "halo_speed", 6.0, 0.2)
	tw.tween_property(self, "arms_up", 1.0, 0.25)
	tw.tween_property(self, "arm", 0.0, 0.2)
	tw.tween_property(self, "beam", 0.0, 0.2)
	tw.chain().tween_property(self, "lift", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "arms_up", 0.0, 0.6).set_delay(0.3)
	tw.tween_property(self, "halo_speed", 0.4, 1.2)
	tw.tween_property(self, "glow_boost", 0.0, 1.0)


func hurt(strong: bool = true) -> void:
	state = "hurt"
	var tw := _anim()
	tw.set_parallel(true)
	tw.tween_property(self, "knock", -26.0 if strong else -10.0, 0.08).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "hurt_flash", 1.0, 0.05)
	tw.tween_property(self, "arm", 0.0, 0.1)
	tw.tween_property(self, "beam", 0.0, 0.15)
	tw.chain().tween_property(self, "knock", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "hurt_flash", 0.0, 0.7)


func victory() -> void:
	state = "victory"
	var tw := _anim().set_parallel(true)
	tw.tween_property(self, "arms_up", 1.0, 0.4)
	tw.tween_property(self, "lift", 18.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "halo_speed", 2.5, 0.6)
	tw.tween_property(self, "glow_boost", 0.7, 0.6)


func defeat() -> void:
	state = "defeat"
	var tw := _anim().set_parallel(true)
	tw.tween_property(self, "kneel", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "halo_speed", 0.05, 0.8)
	tw.tween_property(self, "arm", 0.0, 0.3)
	tw.tween_property(self, "beam", 0.0, 0.2)


# ------------------------------------------------------------------ desenho
func _col(c: Color, a: float = 1.0) -> Color:
	var base := c.lerp(Palette.DANGER, hurt_flash * (0.6 + 0.4 * sin(_t * 40.0)))
	base = base.lerp(Color(0.5, 0.55, 0.65), kneel * 0.5)
	return Color(base.r, base.g, base.b, a)


func _draw() -> void:
	var bob := sin(_t * 2.0) * 5.0 * (1.0 - kneel)
	var o := Vector2(knock, -lift + bob + kneel * 22.0)
	if show_platform:
		_draw_platform()
	# sombra no chão
	var sh := 1.0 - clampf((lift - bob) / 60.0, 0.0, 0.5)
	draw_set_transform(Vector2(0, 62), 0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 34.0 * sh, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# luz ambiente da personagem
	Icons.soft_light(self, o + Vector2(0, -30), 120.0, _col(BODY, 0.10 + 0.12 * glow_boost), 6)
	_draw_satellites(o, false)
	_draw_halo(o + Vector2(0, -74))
	_draw_cape(o)
	_draw_body(o)
	_draw_hands(o)
	_draw_satellites(o, true)
	if beam > 0.01:
		_draw_beam(o)


func _draw_platform() -> void:
	var c := Vector2(0, 70)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 6:
		var a := i * TAU / 6.0 + PI / 6.0
		top.append(c + Vector2(cos(a) * 70, sin(a) * 18))
		bot.append(c + Vector2(cos(a) * 58, sin(a) * 15 + 26))
	# lateral (volume)
	var side := PackedVector2Array([top[0], top[1], top[2], bot[2], bot[1], bot[0]])
	draw_colored_polygon(side, Color(0.03, 0.07, 0.15, 0.95))
	draw_colored_polygon(top, Color(0.07, 0.16, 0.3, 0.95))
	var tl := top.duplicate()
	tl.append(tl[0])
	Icons.glow_polyline(self, tl, Color(BODY.r, BODY.g, BODY.b, 0.8), 1.5, 1.0)
	# feixe de sustentação abaixo da plataforma
	for i in 5:
		var k := float(i) / 5.0
		draw_line(c + Vector2(-20 + k * 40, 42), c + Vector2(-8 + k * 16, 110),
			Color(BODY.r, BODY.g, BODY.b, 0.08 + 0.06 * sin(_t * 3 + i)), 3.0)


func _draw_halo(c: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := _halo_rot + i * TAU / 5.0 - PI / 2
		pts.append(c + Vector2(cos(a), sin(a)) * 34.0)
	Icons.glow_polyline(self, pts, _col(CORE, 0.55 + 0.4 * glow_boost), 1.5, 0.8)


func _draw_cape(o: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 9:
			var k := float(i) / 8.0
			var wave := sin(_t * 3.0 - k * 4.0 + side) * 6.0 * k
			pts.append(o + Vector2(side * (10 + k * 16) + wave, -8 + k * 58))
		Icons.glow_polyline(self, pts, _col(BODY, 0.7), 3.0 * (1.0 - 0.3), 0.8)


func _draw_body(o: Vector2) -> void:
	var torso := PackedVector2Array([o + Vector2(-26, -50), o + Vector2(26, -50), o + Vector2(12, -2), o + Vector2(0, 8), o + Vector2(-12, -2)])
	draw_colored_polygon(torso, _col(DARK, 0.95))
	var t2 := torso.duplicate()
	t2.append(t2[0])
	Icons.glow_polyline(self, t2, _col(BODY), 2.0, 1.0 + glow_boost)
	# ombreiras
	for s in [-1.0, 1.0]:
		var sp := PackedVector2Array([o + Vector2(s * 20, -54), o + Vector2(s * 36, -46), o + Vector2(s * 24, -40)])
		draw_colored_polygon(sp, _col(BODY, 0.85))
	# núcleo de energia
	var pulse := 0.7 + 0.3 * sin(_t * 4.0)
	var core_c := o + Vector2(0, -30)
	Icons.soft_light(self, core_c, 18.0 + 10.0 * glow_boost, _col(CORE, 0.5 * pulse), 4)
	var dia := PackedVector2Array([core_c + Vector2(0, -8), core_c + Vector2(6, 0), core_c + Vector2(0, 8), core_c + Vector2(-6, 0)])
	draw_colored_polygon(dia, _col(CORE))
	# cabeça
	var head := o + Vector2(0, -74)
	draw_circle(head, 18.0, _col(DARK))
	Icons.glow_circle(self, head, 18.0, _col(BODY), 2.0, 1.0)
	var blink := 1.0 if fmod(_t, 4.3) > 0.12 else 0.2
	var visor := Rect2(head + Vector2(-12, -3 * blink), Vector2(24, 6 * blink))
	draw_rect(visor, _col(BODY.lerp(Color.WHITE, 0.5)))
	draw_rect(visor.grow(3), _col(BODY, 0.25))
	# antena
	draw_line(head + Vector2(0, -18), head + Vector2(0, -30), _col(BODY, 0.8), 2.0)
	draw_circle(head + Vector2(0, -32), 3.5, _col(Color("4f7bff")))


func _hand_pos(o: Vector2, side: float) -> Vector2:
	var rest := o + Vector2(side * 44, -16 + sin(_t * 2.4 + side) * 4.0)
	var up := o + Vector2(side * 40, -110)
	var p := rest.lerp(up, arms_up)
	if side > 0:
		var dir := (beam_target - (o + Vector2(0, -40))).normalized()
		p = p.lerp(o + Vector2(0, -40) + dir * 70.0, arm)
	return p


func _draw_hands(o: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var p := _hand_pos(o, side)
		var d := PackedVector2Array([p + Vector2(0, -9), p + Vector2(6, 0), p + Vector2(0, 9), p + Vector2(-6, 0)])
		draw_colored_polygon(d, _col(BODY))
		Icons.soft_light(self, p, 14.0, _col(BODY, 0.25), 3)
	if arm > 0.3:
		var hp := _hand_pos(o, 1.0)
		Icons.soft_light(self, hp, 30.0 * arm, _col(Color.WHITE, 0.5 * arm), 5)


func _draw_satellites(o: Vector2, front: bool) -> void:
	var kinds := ["triangle", "square", "circle"]
	for i in 3:
		var a := _t * (0.9 + i * 0.25) + i * TAU / 3.0
		var z := sin(a)
		if (z >= 0.0) != front:
			continue
		var p := o + Vector2(cos(a) * 64.0, -34 + z * 14.0 + sin(_t * 2 + i) * 4.0)
		var s := 12.0 + z * 4.0
		var cc: Color = [BODY, CORE, Color("c05bff")][i]
		Icons.draw(self, kinds[i], p, s, _col(cc, 0.55 + 0.45 * (z * 0.5 + 0.5)), 2.0)


func _draw_beam(o: Vector2) -> void:
	var from := _hand_pos(o, 1.0)
	var to := beam_target
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var k := float(i) / n
		var p := from.lerp(to, k)
		var perp := (to - from).orthogonal().normalized()
		p += perp * sin(k * 20.0 + _t * 40.0) * 5.0 * sin(k * PI)
		pts.append(p)
	Icons.glow_polyline(self, pts, Color(BODY.r, BODY.g, BODY.b, beam), 3.0, 1.6)
	draw_polyline(pts, Color(1, 1, 1, beam), 1.2, true)
	Icons.soft_light(self, to, 40.0, Color(1, 1, 1, 0.4 * beam), 4)
