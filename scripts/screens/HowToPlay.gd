extends OverlayScreen
## "Como Jogar": 4 páginas ilustradas com os componentes reais do jogo
## (fenda, forma, medidor de risco, Axi-01 e arquipélago), navegáveis por
## setas, teclado (←/→) ou pelos indicadores.

const PAGES := [
	["A FENDA SE ABRE", "A cada onda, uma fenda dimensional se abre e uma Forma Caótica surge dela.\n\nObserve as medidas indicadas nas cotas: são tudo o que você precisa para calcular a área."],
	["LEIA O RISCO", "Geo mostra o Risco de Colapso de cada fenda.\n\nAté 70%: fenda estável — errar não custa vida.\nAcima de 70%: acertar vale +50 de bônus, mas errar custa 1 vida."],
	["CALCULE E SELE", "Digite a área (vírgula ou ponto) e pressione ENTER.\n\nAcertou? Axi-01 sela a fenda. Errou? Geo mostra a resolução passo a passo. Valores aproximados são aceitos (±2% no Alpha, ±5% no Beta e Gamma)."],
	["RESTAURE O ARQUIPÉLAGO", "Cada setor tem 3 fendas: Alpha (polígonos), Beta (círculos) e Gamma (formas compostas).\n\nVocê começa com 3 vidas. Sele todas as fendas para vencer a Entropia!"],
]

var page := 0
var art: Control
var art_root: Node2D
var page_title: Label
var page_text: Label
var dots: Control
var btn_prev: FxButton
var btn_next: FxButton
var btn_close: FxButton
var _t := 0.0


func _ready() -> void:
	build_frame(Vector2(840, 480))
	add_title("COMO JOGAR", 22)
	art = Control.new()
	art.position = Vector2(30, 76)
	art.size = Vector2(360, 300)
	art.clip_contents = true
	art.add_theme_stylebox_override("panel", UiKit.glass())
	var bg := Panel.new()
	bg.size = art.size
	bg.add_theme_stylebox_override("panel", UiKit.glass(Color(0.02, 0.03, 0.08, 0.9), Color(1, 1, 1, 0.08), 12))
	art.add_child(bg)
	content.add_child(art)
	page_title = UiKit.label("", 22, Palette.CYAN, UiKit.spaced(UiKit.display_bold(), 3))
	page_title.position = Vector2(420, 96)
	content.add_child(page_title)
	page_text = UiKit.label("", 17, Palette.INK, UiKit.body())
	page_text.position = Vector2(420, 140)
	page_text.size = Vector2(390, 230)
	page_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(page_text)
	dots = Control.new()
	dots.position = Vector2(370, 398)
	dots.size = Vector2(100, 20)
	dots.draw.connect(_draw_dots)
	content.add_child(dots)
	btn_prev = FxButton.make("", "back", false, Vector2(56, 46))
	btn_prev.position = Vector2(290, 386)
	btn_prev.pressed.connect(func(): set_page(page - 1))
	content.add_child(btn_prev)
	btn_next = FxButton.make("", "play", false, Vector2(56, 46))
	btn_next.position = Vector2(494, 386)
	btn_next.pressed.connect(func(): set_page(page + 1))
	content.add_child(btn_next)
	btn_close = FxButton.make("ENTENDI", "check", true, Vector2(170, 46))
	btn_close.position = Vector2(640, 412)
	btn_close.sfx_press = "ui_back"
	btn_close.pressed.connect(func(): emit_signal("back_requested"))
	content.add_child(btn_close)


func _on_opened() -> void:
	set_page(0)
	btn_close.call_deferred("grab_focus")


func set_page(np: int) -> void:
	var p := clampi(np, 0, PAGES.size() - 1)
	if p != page:
		AudioManager.play("ui_hover")
	page = p
	page_title.text = PAGES[p][0]
	page_text.text = PAGES[p][1]
	page_text.visible_ratio = 0.0
	create_tween().tween_property(page_text, "visible_ratio", 1.0, 0.5)
	btn_prev.disabled = p == 0
	btn_next.disabled = p == PAGES.size() - 1
	_build_art(p)
	dots.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not is_open:
		return
	if event.is_action_pressed("ui_left"):
		set_page(page - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		set_page(page + 1)
		get_viewport().set_input_as_handled()


func _build_art(pg: int) -> void:
	if art_root:
		art_root.queue_free()
	art_root = Node2D.new()
	art.add_child(art_root)
	var c := art.size / 2.0
	match pg:
		0:
			var r := Rift.new()
			r.position = c
			r.scale = Vector2(0.7, 0.7)
			art_root.add_child(r)
			r.set_theme_color(Palette.CYAN)
			r.open(40)
			var holder := Node2D.new()   # a animação da forma controla a própria escala
			holder.position = c + Vector2(-30, -6)
			holder.scale = Vector2(0.42, 0.42)
			art_root.add_child(holder)
			var sd = load("res://scripts/ShapeDisplay.gd").new()
			holder.add_child(sd)
			sd.setup(GameManager.ShapeType.TRIANGLE, {"base": 8, "height": 5}, Vector2(8, 5))
			sd.play_appear(1.2)
		1:
			var g := RiskGauge.new()
			g.position = Vector2(60, 60)
			g.size = Vector2(240, 140)
			art_root.add_child(g)
			var tw := g.create_tween().set_loops()
			tw.tween_property(g, "value", 30.0, 1.2).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(func(): g.target = 30)
			tw.tween_interval(0.8)
			tw.tween_property(g, "value", 85.0, 1.2).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(func(): g.target = 85)
			tw.tween_interval(0.8)
			var l1 := UiKit.label("ESTÁVEL  ≤ 70%", 14, Palette.SUCCESS, UiKit.body_bold())
			l1.position = Vector2(40, 226)
			art_root.add_child(l1)
			var l2 := UiKit.label("INSTÁVEL  > 70%", 14, Palette.DANGER, UiKit.body_bold())
			l2.position = Vector2(200, 226)
			art_root.add_child(l2)
		2:
			var r := Rift.new()
			r.position = c + Vector2(90, -10)
			r.scale = Vector2(0.5, 0.5)
			art_root.add_child(r)
			r.set_theme_color(Palette.CYAN)
			r.open(30)
			var a := Axi01.new()
			a.position = c + Vector2(-110, 10)
			a.scale = Vector2(0.75, 0.75)
			art_root.add_child(a)
			var box := LineEdit.new()
			box.text = "20"
			box.editable = false
			box.focus_mode = Control.FOCUS_NONE
			box.alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.position = Vector2(110, 226)
			box.size = Vector2(140, 46)
			art_root.add_child(box)
			var tw := a.create_tween().set_loops()
			tw.tween_interval(1.0)
			tw.tween_callback(func(): a.cast_at(r.global_position))
			tw.tween_interval(0.35)
			tw.tween_callback(func(): r.seal())
			tw.tween_interval(1.2)
			tw.tween_callback(func(): r.open(30))
			tw.tween_interval(0.8)
		3:
			var map_draw := Control.new()
			map_draw.size = art.size
			art_root.add_child(map_draw)
			map_draw.draw.connect(func():
				var pts := [Vector2(70, 170), Vector2(180, 120), Vector2(290, 170)]
				for i in 3:
					var col: Color = Palette.sector(i).main
					var y := sin(_t * 1.5 + i) * 5.0
					var p: Vector2 = pts[i] + Vector2(0, y)
					Icons.soft_light(map_draw, p, 60.0, Color(col.r, col.g, col.b, 0.25), 5)
					var top := PackedVector2Array()
					for k in 9:
						var a := k * TAU / 8.0
						top.append(p + Vector2(cos(a) * 44.0, sin(a) * 13.0 + 10.0))
					map_draw.draw_colored_polygon(PackedVector2Array([top[0], top[1], top[2], top[3], top[4], p + Vector2(-10, 50)]), Color(0.05, 0.06, 0.12))
					Icons.glow_polyline(map_draw, top, col, 1.5, 1.0)
					Icons.draw(map_draw, ["triangle", "circle", "square"][i], p + Vector2(0, -22), 26.0, col, 2.0)
					for s in 3:
						Icons.draw(map_draw, "star", p + Vector2(-18 + s * 18, 76), 13.0, Palette.GOLD)
					if i < 2:
						map_draw.draw_dashed_line(p + Vector2(46, 10), pts[i + 1] + Vector2(-46, 10 + sin(_t * 1.5 + i + 1) * 5.0), Color(1, 1, 1, 0.4), 1.5, 6.0)
				for h in 3:
					Icons.draw(map_draw, "heart", Vector2(150 + h * 30, 262), 20.0, Palette.DANGER))


func _process(delta: float) -> void:
	_t += delta
	if art_root and page == 3:
		for ch in art_root.get_children():
			ch.queue_redraw()


func _draw_dots() -> void:
	for i in PAGES.size():
		var c := Vector2(20 + i * 20, 10)
		if i == page:
			dots.draw_circle(c, 5, Palette.CYAN)
		else:
			dots.draw_circle(c, 4, Color(1, 1, 1, 0.25))
