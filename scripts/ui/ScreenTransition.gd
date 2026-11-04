class_name ScreenTransition
extends CanvasLayer
## Transições entre telas no formato de uma FENDA que rasga a tela,
## e o cartão de apresentação de setor exibido enquanto a tela está coberta.

signal card_skipped

var wipe: ColorRect
var card: Control
var _mat: ShaderMaterial
var _card_sector := 0
var _card_t := 0.0
var _card_labels: Array[Label] = []
var _waiting_skip := false
var _card_token := 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	wipe = ColorRect.new()
	wipe.size = Vector2(1152, 648)
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/rift_wipe.gdshader")
	_mat.set_shader_parameter("progress", 0.0)
	wipe.material = _mat
	add_child(wipe)
	card = Control.new()
	card.size = Vector2(1152, 648)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	card.draw.connect(_draw_card)
	add_child(card)


func is_covered() -> bool:
	return float(_mat.get_shader_parameter("progress")) >= 0.99


func cover(edge: Color = Palette.CYAN, dur: float = 0.55) -> void:
	wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	_mat.set_shader_parameter("edge_color", edge)
	_mat.set_shader_parameter("seed", randf() * 100.0)
	AudioManager.play("whoosh")
	var tw := create_tween()
	tw.tween_method(_set_p, 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


func reveal(dur: float = 0.55) -> void:
	var tw := create_tween()
	tw.tween_method(_set_p, 1.0, 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_p(v: float) -> void:
	_mat.set_shader_parameter("progress", v)


## Cartão de entrada de setor (tela já coberta). Clique/tecla adianta.
func show_sector_card(sector: int, hold: float = 1.6) -> void:
	_card_sector = sector
	_card_t = 0.0
	for l in _card_labels:
		l.queue_free()
	_card_labels.clear()
	var s := Palette.sector(sector)
	var top := UiKit.caption("ENTRANDO NO", Palette.INK_DIM, 14)
	var name_l := UiKit.label(s.name.to_upper(), 58, Color.WHITE, UiKit.spaced(UiKit.display_bold(), 10), HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.glow(name_l, s.main, 16)
	var title_l := UiKit.label(s.title.to_upper(), 22, s.main, UiKit.spaced(UiKit.display(), 6), HORIZONTAL_ALIGNMENT_CENTER)
	var cont := UiKit.label(s.content, 18, Palette.INK_DIM, UiKit.body(), HORIZONTAL_ALIGNMENT_CENTER)
	var ys := [262, 282, 356, 396]
	var i := 0
	for l in [top, name_l, title_l, cont]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(1152, 70)
		l.position = Vector2(0, ys[i])
		l.modulate.a = 0.0
		card.add_child(l)
		_card_labels.append(l)
		var tw: Tween = l.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(l, "modulate:a", 1.0, 0.35)
		tw.parallel().tween_property(l, "position:y", ys[i] - 10.0, 0.5).from(ys[i] + 12.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1
	card.visible = true
	card.modulate.a = 1.0
	AudioManager.play("unlock", 0.8, -4.0)
	var t := create_tween()
	t.tween_property(self, "_card_t", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_waiting_skip = true
	_card_token += 1
	var tok := _card_token
	var timer := get_tree().create_timer(hold)
	timer.timeout.connect(func():
		if _waiting_skip and tok == _card_token:
			emit_signal("card_skipped"))
	await card_skipped
	_waiting_skip = false
	var out := create_tween()
	out.tween_property(card, "modulate:a", 0.0, 0.25)
	await out.finished
	card.visible = false


func _input(event: InputEvent) -> void:
	if _waiting_skip and _card_t > 0.6 and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_waiting_skip = false
		get_viewport().set_input_as_handled()
		emit_signal("card_skipped")


func _process(_d: float) -> void:
	if card.visible:
		card.queue_redraw()


func _draw_card() -> void:
	var s := Palette.sector(_card_sector)
	var c := Vector2(576, 170)
	var k := _card_t
	var col: Color = s.main
	Icons.soft_light(card, c, 120.0 * k, Color(col.r, col.g, col.b, 0.35), 6)
	# emblema do setor desenhando-se
	var n: int = [3, 64, 5][_card_sector]
	var r := 52.0
	var pts := PackedVector2Array()
	var steps := int(n * k)
	for i in steps + 1:
		var a := -PI / 2 + i * TAU / n + Time.get_ticks_msec() / 3000.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	if pts.size() >= 2:
		Icons.glow_polyline(card, pts, col, 3.0, 1.4)
	Icons.glow_circle(card, c, r * 1.45 * k, Color(col.r, col.g, col.b, 0.35), 1.5, 0.6)
	# linha que se expande
	var lw := 420.0 * k
	card.draw_line(Vector2(576 - lw, 348), Vector2(576 + lw, 348), Color(col.r, col.g, col.b, 0.7), 2.0)
	card.draw_line(Vector2(576 - lw * 0.6, 440), Vector2(576 + lw * 0.6, 440), Color(1, 1, 1, 0.15), 1.0)
