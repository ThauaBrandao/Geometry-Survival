extends Node
## Estado global do jogo (GDD §6 — GameManager). EAP 1.3.
## Mudanças da fase de evolução estão resumidas em docs/CHANGELOG.md.

enum GameState { SECTOR_MAP, ENCOUNTER, RESULT_WAVE, GAME_OVER, GAME_WIN }
enum ShapeType { TRIANGLE, SQUARE, RECTANGLE, CIRCLE, COMPOSITE_RECT_TRI, COMPOSITE_RECT_SEMI }
enum Sector    { ALPHA, BETA, GAMMA }
## FSM do Geo (GDD §16).
enum GeoState  { IDLE, ANALISANDO, ALERTANDO, APRESENTANDO, AVALIANDO }

var current_state: GameState = GameState.SECTOR_MAP
var current_sector: Sector   = Sector.ALPHA
var current_wave: int        = 1
var score: int               = 0
var best_score: int          = 0   # recorde — preservado ao reiniciar e salvo em disco
var best_before_run: int     = 0   # recorde no início da partida (detecta "novo recorde")
var streak: int              = 0   # acertos seguidos (apenas feedback visual)
var sector_start_score: int  = 0
var sector_attempt_start: int = 0
var _snapshot: Dictionary    = {}  # estado no início do setor (para abandonar o setor)
var lives: int               = GameRules.STARTING_LIVES
var sectors_completed: Array[bool] = [false, false, false]
var geo_state: GeoState      = GeoState.IDLE

var current_shape_params: Dictionary = {}
var current_shape_type: ShapeType = ShapeType.TRIANGLE
var current_formula_hint: String = ""
var current_solution: String = ""
var current_size_units: Vector2 = Vector2.ONE
var correct_area: float = 0.0
var risk_percent: int   = 0
var wave_resolved: bool = false   # impede resposta dupla na mesma onda

## Registro das tentativas da partida (base para a validação piloto — EAP 1.5.3).
var attempts: Array[Dictionary] = []

signal state_changed(new_state: GameState)
signal lives_changed(new_lives: int)
signal score_changed(new_score: int)
signal wave_changed(wave: int, sector: Sector)
signal encounter_result(success: bool, risk_was_high: bool)
signal geo_state_changed(new_state: GeoState)


# ------------------------------------------------------------ progressão
## Setores são liberados em sequência (GDD §5 — Progressão por Setores).
func is_sector_unlocked(sector: int) -> bool:
	if sector == Sector.ALPHA:
		return true
	return sectors_completed[sector - 1]


func is_sector_available(sector: int) -> bool:
	return is_sector_unlocked(sector) and not sectors_completed[sector]


func start_encounter(sector: Sector) -> bool:
	if current_state != GameState.SECTOR_MAP or not is_sector_available(sector):
		return false
	current_sector = sector
	current_wave = 1
	sector_start_score = score
	sector_attempt_start = attempts.size()
	_snapshot = {"score": score, "lives": lives, "attempts": attempts.size(), "streak": streak}
	_load_shape()
	emit_signal("wave_changed", current_wave, current_sector)
	_set_state(GameState.ENCOUNTER)
	return true


func _load_shape() -> void:
	_set_geo(GeoState.ANALISANDO)
	var data := ShapeGenerator.generate(current_sector, current_wave)
	current_shape_type   = data.shape_type
	current_shape_params = data.params
	current_formula_hint = data.formula_hint
	current_solution     = data.solution
	current_size_units   = data.size_units
	correct_area         = data.correct_area
	var rr := GameRules.risk_range_for(current_sector)
	risk_percent = randi_range(rr.x, rr.y)
	wave_resolved = false
	_set_geo(GeoState.ALERTANDO if GameRules.is_high_risk(risk_percent) else GeoState.APRESENTANDO)


# ------------------------------------------------------------ resposta
## Recebe o valor já validado sintaticamente (ver AnswerValidator.parse).
## Retorna false se a resposta não pôde ser processada (estado inválido
## ou onda já resolvida), sem alterar pontuação/vidas.
func submit_answer(valor: float) -> bool:
	if current_state != GameState.ENCOUNTER or wave_resolved:
		return false
	wave_resolved = true
	_set_geo(GeoState.AVALIANDO)

	var tol := GameRules.tolerance_for(current_sector)
	var success := AnswerValidator.is_correct(valor, correct_area, tol)
	var risk_was_high := GameRules.is_high_risk(risk_percent)

	attempts.append({
		"sector": current_sector, "wave": current_wave,
		"shape_type": current_shape_type, "correct_area": correct_area,
		"answer": valor, "success": success, "risk": risk_percent,
	})

	streak = streak + 1 if success else 0
	var pts := GameRules.points_for(success, risk_was_high)
	if pts > 0:
		score += pts
		best_score = maxi(best_score, score)
		emit_signal("score_changed", score)

	# O resultado é emitido ANTES da perda de vida para que a tela de
	# encontro mostre o feedback mesmo quando a partida termina.
	emit_signal("encounter_result", success, risk_was_high)

	if GameRules.lives_lost_for(success, risk_was_high) > 0:
		lose_life()
	return true


func advance_wave() -> void:
	if current_state != GameState.ENCOUNTER or not wave_resolved:
		return
	current_wave += 1
	if current_wave > GameRules.WAVES_PER_SECTOR:
		sectors_completed[current_sector] = true
		_set_geo(GeoState.IDLE)
		if not sectors_completed.has(false):
			_set_state(GameState.GAME_WIN)
		else:
			_set_state(GameState.SECTOR_MAP)
	else:
		_load_shape()
		emit_signal("wave_changed", current_wave, current_sector)
		_set_state(GameState.ENCOUNTER)


func lose_life() -> void:
	lives = maxi(lives - 1, 0)
	emit_signal("lives_changed", lives)
	if lives <= 0:
		_set_geo(GeoState.IDLE)
		_set_state(GameState.GAME_OVER)


## Abandona o setor em andamento (menu de pausa): desfaz pontos, vidas e
## tentativas do setor e volta ao Mapa, sem concluí-lo.
func abandon_sector() -> bool:
	if current_state != GameState.ENCOUNTER or _snapshot.is_empty():
		return false
	score = _snapshot.score
	lives = _snapshot.lives
	streak = _snapshot.streak
	attempts.resize(_snapshot.attempts)
	_snapshot = {}
	current_wave = 1
	wave_resolved = false
	_set_geo(GeoState.IDLE)
	emit_signal("score_changed", score)
	emit_signal("lives_changed", lives)
	_set_state(GameState.SECTOR_MAP)
	return true


## Restaura uma partida salva (SaveGame). Sempre retorna ao Mapa de Setores.
func restore(data: Dictionary) -> bool:
	var sc: Array = data.get("sectors_completed", [])
	if sc.size() != 3:
		return false
	reset_game()
	for i in 3:
		sectors_completed[i] = bool(sc[i])
	if not sectors_completed.has(false):
		return false
	score = int(data.get("score", 0))
	lives = clampi(int(data.get("lives", GameRules.STARTING_LIVES)), 1, GameRules.STARTING_LIVES)
	for a in data.get("attempts", []):
		if typeof(a) == TYPE_DICTIONARY:
			attempts.append(a)
	best_score = maxi(best_score, score)
	emit_signal("score_changed", score)
	emit_signal("lives_changed", lives)
	_set_state(GameState.SECTOR_MAP)
	return true


func reset_game() -> void:
	best_before_run = best_score
	streak = 0
	sector_start_score = 0
	sector_attempt_start = 0
	_snapshot = {}
	current_sector = Sector.ALPHA
	current_wave = 1
	score = 0
	lives = GameRules.STARTING_LIVES
	sectors_completed = [false, false, false]
	current_shape_params = {}
	current_shape_type = ShapeType.TRIANGLE
	current_formula_hint = ""
	current_solution = ""
	correct_area = 0.0
	risk_percent = 0
	wave_resolved = false
	attempts.clear()
	ShapeGenerator.reset_history()
	_set_geo(GeoState.IDLE)
	emit_signal("score_changed", score)
	emit_signal("lives_changed", lives)
	emit_signal("wave_changed", current_wave, current_sector)
	_set_state(GameState.SECTOR_MAP)


# ------------------------------------------------------------ estatísticas
func stats_for_sector(sector: int) -> Vector2i:
	var ok := 0
	var total := 0
	for a in attempts:
		if a.sector == sector:
			total += 1
			if a.success:
				ok += 1
	return Vector2i(ok, total)


func current_sector_attempts() -> Array:
	return attempts.slice(sector_attempt_start)


func sector_score_gained() -> int:
	return score - sector_start_score


func is_new_record() -> bool:
	return score > 0 and score >= best_score and score > best_before_run


func total_correct() -> int:
	var ok := 0
	for a in attempts:
		if a.success:
			ok += 1
	return ok


# ------------------------------------------------------------ helpers
func _set_state(s: GameState) -> void:
	current_state = s
	emit_signal("state_changed", current_state)


func _set_geo(s: GeoState) -> void:
	geo_state = s
	emit_signal("geo_state_changed", geo_state)
