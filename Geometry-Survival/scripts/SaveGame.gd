extends Node
## Salvamento automático do progresso (autoload) — habilita "Continuar".
## O jogo é salvo sempre que o jogador volta ao Mapa de Setores.
## O recorde é guardado à parte e sobrevive ao fim da partida.

const SAVE_PATH := "user://savegame.json"
const RECORD_PATH := "user://records.cfg"

var persist: bool = true   # desligado nos testes automatizados


func _ready() -> void:
	GameManager.best_score = load_record()


func has_save() -> bool:
	return persist and FileAccess.file_exists(SAVE_PATH)


func save_progress() -> void:
	save_record()
	if not persist:
		return
	var data := {
		"version": 1,
		"sectors_completed": Array(GameManager.sectors_completed),
		"score": GameManager.score,
		"lives": GameManager.lives,
		"attempts": GameManager.attempts,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## Restaura a partida salva e leva o jogo ao Mapa. Retorna false se não houver save válido.
func load_progress() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("sectors_completed"):
		return false
	return GameManager.restore(data)


func clear_progress() -> void:
	save_record()
	if persist and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func load_record() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD_PATH) != OK:
		return 0
	return int(cfg.get_value("records", "best_score", 0))


func save_record() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_score", GameManager.best_score)
	cfg.save(RECORD_PATH)
