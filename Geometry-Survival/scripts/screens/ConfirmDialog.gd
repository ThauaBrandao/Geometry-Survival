extends OverlayScreen
## Diálogo de confirmação reutilizável. Uso: var ok = await dialog.ask(...)

signal answered(ok: bool)

var title_l: Label
var body_l: Label
var btn_yes: FxButton
var btn_no: FxButton


func _ready() -> void:
	build_frame(Vector2(480, 250), Color(1, 0.68, 0.26, 0.5))
	title_l = add_title("", 26)
	UiKit.glow(title_l, Palette.WARN, 10)
	body_l = UiKit.label("", 17, Palette.INK_DIM, UiKit.body(), HORIZONTAL_ALIGNMENT_CENTER)
	body_l.position = Vector2(40, 80)
	body_l.size = Vector2(400, 70)
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(body_l)
	btn_no = FxButton.make("CANCELAR", "back", false, Vector2(190, 48))
	btn_no.position = Vector2(40, 176)
	btn_no.sfx_press = "ui_back"
	btn_no.pressed.connect(func(): _answer(false))
	content.add_child(btn_no)
	btn_yes = FxButton.make("CONFIRMAR", "check", true, Vector2(190, 48))
	btn_yes.accent = Palette.WARN
	btn_yes.position = Vector2(250, 176)
	btn_yes.pressed.connect(func(): _answer(true))
	content.add_child(btn_yes)
	btn_yes._apply_style()
	back_requested.connect(func(): _answer(false))


func ask(title: String, body: String, yes_text: String = "CONFIRMAR") -> bool:
	title_l.text = title
	body_l.text = body
	btn_yes.text = yes_text
	open()
	btn_no.call_deferred("grab_focus")
	var ok: bool = await answered
	return ok


func _answer(ok: bool) -> void:
	if not is_open:
		return
	close()
	emit_signal("answered", ok)
