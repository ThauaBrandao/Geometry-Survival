extends OverlayScreen
## Configurações: volume da música e dos efeitos, tela cheia, tremor de tela
## e movimento reduzido (acessibilidade). Salvas automaticamente.

var music: HSlider
var sfx: HSlider
var music_val: Label
var sfx_val: Label
var t_full: ToggleSwitch
var t_shake: ToggleSwitch
var t_motion: ToggleSwitch
var btn_back: FxButton


func _ready() -> void:
	build_frame(Vector2(560, 470))
	add_title("CONFIGURAÇÕES", 24)
	var y := 90.0
	var sec := UiKit.caption("ÁUDIO", Palette.CYAN, 11)
	sec.position = Vector2(40, y)
	content.add_child(sec)
	music = _slider("Música", y + 26, Settings.music_volume)
	music_val = _val_label(y + 26)
	sfx = _slider("Efeitos sonoros", y + 76, Settings.sfx_volume)
	sfx_val = _val_label(y + 76)
	music.value_changed.connect(func(v):
		music_val.text = "%d%%" % int(v * 100)
		Settings.set_value("music_volume", v))
	sfx.value_changed.connect(func(v):
		sfx_val.text = "%d%%" % int(v * 100)
		Settings.set_value("sfx_volume", v))
	sfx.drag_ended.connect(func(_c): AudioManager.play("correct"))
	y = 230.0
	var sec2 := UiKit.caption("VÍDEO E ACESSIBILIDADE", Palette.CYAN, 11)
	sec2.position = Vector2(40, y)
	content.add_child(sec2)
	t_full = _toggle("Tela cheia", "", y + 24, "fullscreen")
	t_shake = _toggle("Tremor de tela", "Impacto visual quando a fenda se expande", y + 74, "screen_shake")
	t_motion = _toggle("Movimento reduzido", "Menos parallax e animações contínuas", y + 124, "reduced_motion")
	if OS.has_feature("web"):
		t_full.disabled = true
	btn_back = FxButton.make("VOLTAR", "back", true, Vector2(200, 48))
	btn_back.position = Vector2(180, 404)
	btn_back.sfx_press = "ui_back"
	btn_back.pressed.connect(func(): emit_signal("back_requested"))
	content.add_child(btn_back)


func _slider(text: String, y: float, v: float) -> HSlider:
	var l := UiKit.label(text, 17, Palette.INK, UiKit.body_bold())
	l.position = Vector2(40, y + 4)
	content.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = v
	s.position = Vector2(230, y + 6)
	s.size = Vector2(220, 24)
	s.focus_mode = Control.FOCUS_ALL
	content.add_child(s)
	return s


func _val_label(y: float) -> Label:
	var l := UiKit.label("", 15, Palette.CYAN, UiKit.display_bold(), HORIZONTAL_ALIGNMENT_RIGHT)
	l.position = Vector2(456, y + 6)
	l.size = Vector2(64, 20)
	content.add_child(l)
	return l


func _toggle(text: String, sub: String, y: float, key: String) -> ToggleSwitch:
	var l := UiKit.label(text, 17, Palette.INK, UiKit.body_bold())
	l.position = Vector2(40, y + (0 if sub != "" else 8))
	content.add_child(l)
	if sub != "":
		var s := UiKit.label(sub, 13, Palette.INK_DIM, UiKit.body())
		s.position = Vector2(40, y + 22)
		content.add_child(s)
	var t := ToggleSwitch.new()
	t.position = Vector2(456, y + 4)
	t.size = Vector2(64, 32)
	content.add_child(t)
	t.set_on(bool(Settings.get(key)))
	t.toggled.connect(func(on): Settings.set_value(key, on))
	return t


func _on_opened() -> void:
	music.set_value_no_signal(Settings.music_volume)
	sfx.set_value_no_signal(Settings.sfx_volume)
	music_val.text = "%d%%" % int(Settings.music_volume * 100)
	sfx_val.text = "%d%%" % int(Settings.sfx_volume * 100)
	t_full.set_on(Settings.fullscreen)
	t_shake.set_on(Settings.screen_shake)
	t_motion.set_on(Settings.reduced_motion)
	music.call_deferred("grab_focus")
