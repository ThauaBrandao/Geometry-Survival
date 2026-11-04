extends SceneTree
## Testes automatizados do Core Game Loop — EAP 1.3 / 1.5.1.
## Execução (na pasta do projeto):
##   godot --headless --import .        (apenas na primeira vez)
##   godot --headless -s tests/test_runner.gd
## Código de saída 0 = todos os testes passaram.

var passed := 0
var failed := 0
var current := ""
var gm: Node
var sg: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node("GameManager")
	sg = root.get_node("ShapeGenerator")
	# nunca grava arquivos do jogador durante os testes
	root.get_node("Settings").persist = false
	root.get_node("SaveGame").persist = false
	seed(20260922)
	for t in [
		"test_parse_valid", "test_parse_invalid", "test_tolerance_boundaries",
		"test_generator_types_by_sector", "test_generator_area_matches_formula",
		"test_generator_fits_screen", "test_generator_no_immediate_repeat",
		"test_generator_wave_difficulty", "test_risk_ranges",
		"test_scoring_and_lives_matrix", "test_double_submit_blocked",
		"test_sector_lock_sequence", "test_full_victory_run", "test_game_over_and_reset",
		"test_streak_and_record", "test_abandon_sector", "test_restore_progress",
		"test_audio_assets", "test_ui_smoke",
	]:
		current = t
		gm.reset_game()
		await call(t)
	print("\n==== RESULTADO: %d verificações OK, %d falhas ====" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  [FALHA] %s :: %s" % [current, msg])


# ----------------------------------------------------------------- validação
func test_parse_valid() -> void:
	var cases := {"12": 12.0, "12,5": 12.5, " 12.5 ": 12.5, "0,5": 0.5, ",5": 0.5,
		"19,63": 19.63, "1 000": 1000.0, "+7": 7.0, "28,": 28.0}
	for k in cases:
		var r := AnswerValidator.parse(k)
		check(r.ok and is_equal_approx(r.value, cases[k]), "parse('%s') deveria ser %s, veio %s" % [k, cases[k], r])


func test_parse_invalid() -> void:
	var cases := {"": AnswerValidator.ParseError.EMPTY, "   ": AnswerValidator.ParseError.EMPTY,
		"abc": AnswerValidator.ParseError.NOT_A_NUMBER, "1.2.3": AnswerValidator.ParseError.NOT_A_NUMBER,
		"1,2,3": AnswerValidator.ParseError.NOT_A_NUMBER, "12a": AnswerValidator.ParseError.NOT_A_NUMBER,
		"1e3": AnswerValidator.ParseError.NOT_A_NUMBER, "π": AnswerValidator.ParseError.NOT_A_NUMBER,
		"0": AnswerValidator.ParseError.NOT_POSITIVE, "-4": AnswerValidator.ParseError.NOT_POSITIVE}
	for k in cases:
		var r := AnswerValidator.parse(k)
		check(not r.ok and r.error == cases[k], "parse('%s') deveria falhar com %d, veio %s" % [k, cases[k], r])


func test_tolerance_boundaries() -> void:
	check(AnswerValidator.is_correct(49, 49, 0.02), "valor exato aceito")
	check(AnswerValidator.is_correct(49.98, 49, 0.02), "limite superior (+2%) aceito")
	check(not AnswerValidator.is_correct(45, 49, 0.02), "45 para 49 rejeitado no Alpha (bug da baseline)")
	check(not AnswerValidator.is_correct(5, 4.5, 0.02), "arredondar 4,5 para 5 rejeitado no Alpha")
	var circ := PI * 25.0
	check(AnswerValidator.is_correct(78.5, circ, 0.05), "π≈3,14 aceito no Beta")
	check(AnswerValidator.is_correct(75.0, circ, 0.05), "π≈3 aceito no Beta")
	check(not AnswerValidator.is_correct(25.0 * 2.0, circ, 0.05), "2πr (perímetro/confusão) rejeitado")
	check(not AnswerValidator.is_correct(NAN, 10, 0.05), "NaN rejeitado")
	check(not AnswerValidator.is_correct(10, 0, 0.05), "área-alvo inválida rejeitada")


# ----------------------------------------------------------------- geração
const ALLOWED := {0: [2, 1, 0], 1: [3], 2: [4, 5]}  # SQUARE=1 RECT=2 TRI=0 CIRCLE=3 COMP=4,5

func _recompute(d: Dictionary) -> float:
	var p: Dictionary = d.params
	match d.shape_type:
		0: return p.base * p.height / 2.0
		1: return float(p.side * p.side)
		2: return float(p.width * p.height)
		3: return PI * p.radius * p.radius
		4: return p.rect_w * p.rect_h + p.rect_w * p.tri_height / 2.0
		5: return p.rect_w * p.rect_h + PI * pow(p.rect_w / 2.0, 2) / 2.0
	return -1.0


func test_generator_types_by_sector() -> void:
	for s in 3:
		var seen := {}
		for w in range(1, 4):
			for i in 300:
				var d: Dictionary = sg.generate(s, w)
				seen[d.shape_type] = true
				check(d.shape_type in ALLOWED[s], "setor %d gerou tipo %d" % [s, d.shape_type])
		for t in ALLOWED[s]:
			check(seen.has(t), "setor %d nunca gerou o tipo %d" % [s, t])


func test_generator_area_matches_formula() -> void:
	for s in 3:
		for w in range(1, 4):
			for i in 300:
				var d: Dictionary = sg.generate(s, w)
				check(d.correct_area > 0.0 and is_finite(d.correct_area), "área inválida %s" % d)
				check(is_equal_approx(d.correct_area, _recompute(d)), "área ≠ fórmula: %s" % d)
				check(d.formula_hint != "" and d.solution != "", "dica/solução vazias")


func test_generator_fits_screen() -> void:
	var SD = load("res://scripts/ShapeDisplay.gd")
	var worst := Vector2.ZERO
	for s in 3:
		for w in range(1, 4):
			for i in 300:
				var d: Dictionary = sg.generate(s, w)
				var px: Vector2 = d.size_units * SD.compute_scale(d.size_units)
				worst = Vector2(maxf(worst.x, px.x), maxf(worst.y, px.y))
				var sc: float = SD.compute_scale(d.size_units)
				check(sc >= 18.0, "escala muito pequena (%s) para %s" % [sc, d.size_units])
	check(worst.x <= GameRules.SHAPE_BOX.x + 0.01 and worst.y <= GameRules.SHAPE_BOX.y + 0.01,
		"forma excede a área reservada: %s" % worst)


func test_generator_no_immediate_repeat() -> void:
	sg.reset_history()
	var last := ""
	var repeats := 0
	for i in 500:
		var d: Dictionary = sg.generate(1, 1)   # Beta onda 1 = só 5 opções: pior caso
		if d.signature == last:
			repeats += 1
		last = d.signature
	check(repeats == 0, "%d repetições consecutivas" % repeats)


func test_generator_wave_difficulty() -> void:
	# Alpha e Gamma: média da área (tamanho dos números) cresce da onda 1 para a 3.
	# Beta: a dificuldade da onda 3 é conceitual (converter diâmetro em raio).
	for s in [0, 2]:
		var avg := []
		for w in range(1, 4):
			var tot := 0.0
			for i in 400:
				tot += sg.generate(s, w).correct_area
			avg.append(tot / 400.0)
		check(avg[0] < avg[2], "setor %d: dificuldade não cresce (médias %s)" % [s, avg])
	# Beta onda 3 sempre informa o diâmetro
	for i in 50:
		check(sg.generate(1, 3).params.get("show_diameter", false), "Beta onda 3 sem diâmetro")


func test_risk_ranges() -> void:
	gm.sectors_completed.assign([true, true, false])
	for s in 3:
		var rr := GameRules.risk_range_for(s)
		for i in 200:
			gm.current_sector = s
			gm._load_shape()
			check(gm.risk_percent >= rr.x and gm.risk_percent <= rr.y, "risco fora da faixa")


# ----------------------------------------------------------------- regras
func _prepare(area: float, risk: int) -> void:
	gm.current_state = gm.GameState.ENCOUNTER
	gm.current_sector = gm.Sector.ALPHA
	gm.correct_area = area
	gm.risk_percent = risk
	gm.wave_resolved = false


func test_scoring_and_lives_matrix() -> void:
	# [risco, acerta?, pontos esperados, vidas perdidas]
	var matrix := [[35, true, 100, 0], [70, true, 100, 0], [71, true, 150, 0],
		[35, false, 0, 0], [70, false, 0, 0], [78, false, 0, 1]]
	for row in matrix:
		gm.reset_game()
		_prepare(12.0, row[0])
		gm.submit_answer(12.0 if row[1] else 20.0)
		check(gm.score == row[2], "risco %d acerto=%s: score %d ≠ %d" % [row[0], row[1], gm.score, row[2]])
		check(gm.lives == 3 - row[3], "risco %d acerto=%s: vidas %d" % [row[0], row[1], gm.lives])


func test_double_submit_blocked() -> void:
	_prepare(12.0, 80)
	check(gm.submit_answer(12.0), "primeira resposta aceita")
	check(not gm.submit_answer(12.0), "segunda resposta bloqueada")
	check(gm.score == 150, "pontuação não duplicou (score=%d)" % gm.score)
	gm.reset_game()
	_prepare(12.0, 80)
	gm.submit_answer(1.0)
	gm.submit_answer(1.0)
	check(gm.lives == 2, "vida não descontada duas vezes (vidas=%d)" % gm.lives)


func test_sector_lock_sequence() -> void:
	check(gm.is_sector_available(0), "Alpha disponível no início")
	check(not gm.is_sector_available(1) and not gm.is_sector_available(2), "Beta/Gamma bloqueados no início")
	check(not gm.start_encounter(gm.Sector.BETA), "não inicia Beta bloqueado (bug da baseline)")
	check(gm.current_state == gm.GameState.SECTOR_MAP, "estado segue no mapa")
	check(gm.start_encounter(gm.Sector.ALPHA), "inicia Alpha")
	check(not gm.start_encounter(gm.Sector.ALPHA), "não reinicia setor durante encontro")
	gm.advance_wave()
	check(gm.current_wave == 1, "não avança onda sem responder")


func _play_sector(s: int, answer_right: bool) -> void:
	gm.start_encounter(s)
	for w in 3:
		gm.risk_percent = 10
		gm.submit_answer(gm.correct_area if answer_right else gm.correct_area * 3)
		gm.advance_wave()


func test_full_victory_run() -> void:
	_play_sector(0, true)
	check(gm.sectors_completed[0] and gm.current_state == gm.GameState.SECTOR_MAP, "Alpha concluído → mapa")
	check(gm.is_sector_available(1) and not gm.is_sector_available(2), "Beta liberado, Gamma bloqueado")
	_play_sector(1, false)   # erros em risco baixo não bloqueiam a progressão
	check(gm.lives == 3, "erro em risco baixo não tira vida")
	_play_sector(2, true)
	check(gm.current_state == gm.GameState.GAME_WIN, "vitória após 3 setores")
	check(gm.score == 600 and gm.best_score == 600, "score 600 (6 acertos × 100)")
	check(gm.attempts.size() == 9 and gm.total_correct() == 6, "registro de 9 tentativas")
	check(gm.stats_for_sector(1) == Vector2i(0, 3), "estatística do Beta")


func test_game_over_and_reset() -> void:
	gm.start_encounter(0)
	gm.score = 0
	for i in 3:
		gm.risk_percent = 90
		gm.submit_answer(gm.correct_area + 1000)
		if gm.current_state == gm.GameState.ENCOUNTER:
			gm.advance_wave()
	check(gm.current_state == gm.GameState.GAME_OVER and gm.lives == 0, "derrota com 0 vidas")
	gm.best_score = 450
	gm.reset_game()
	check(gm.score == 0 and gm.lives == 3 and gm.best_score == 450, "reset zera partida e preserva recorde")
	check(gm.attempts.is_empty() and not gm.sectors_completed.has(true), "reset limpa progresso")


# ----------------------------------------------------------------- v1.4
func test_streak_and_record() -> void:
	gm.best_score = 100
	gm.reset_game()
	check(gm.best_before_run == 100 and gm.streak == 0, "reset registra recorde anterior e zera sequência")
	gm.start_encounter(0)
	for i in 2:
		gm.submit_answer(gm.correct_area)
		gm.advance_wave()
	check(gm.streak == 2, "sequência conta acertos seguidos")
	check(gm.is_new_record(), "novo recorde detectado ao superar o anterior")
	gm.risk_percent = 10
	gm.submit_answer(gm.correct_area * 3.0)
	check(gm.streak == 0, "erro zera a sequência")
	check(gm.current_sector_attempts().size() == 3, "tentativas do setor atual")


func test_abandon_sector() -> void:
	gm.start_encounter(0)
	_prepare(10.0, 90)
	gm.submit_answer(10.0)
	gm.advance_wave()
	_prepare(10.0, 90)
	gm.submit_answer(99.0)
	check(gm.score > 0 and gm.lives == 2, "pré-condição: pontos e vida perdida no setor")
	check(gm.abandon_sector(), "abandonar setor em andamento")
	check(gm.current_state == gm.GameState.SECTOR_MAP, "volta ao mapa")
	check(gm.score == 0 and gm.lives == 3 and gm.attempts.is_empty(), "abandonar desfaz pontos, vidas e tentativas do setor")
	check(not gm.sectors_completed[0] and gm.is_sector_available(0), "setor abandonado continua disponível")
	check(not gm.abandon_sector(), "abandonar fora de encontro é ignorado")


func test_restore_progress() -> void:
	_play_sector(0, true)
	var data := {"sectors_completed": Array(gm.sectors_completed), "score": gm.score,
		"lives": gm.lives, "attempts": gm.attempts.duplicate(true)}
	var json = JSON.parse_string(JSON.stringify(data))   # simula ida e volta pelo disco
	gm.reset_game()
	check(gm.restore(json), "restaura partida salva")
	check(gm.sectors_completed[0] and not gm.sectors_completed[1], "setores concluídos restaurados")
	check(gm.score == data.score and gm.lives == data.lives, "pontuação e vidas restauradas")
	check(gm.stats_for_sector(0).y == 3, "estatísticas restauradas (JSON)")
	check(gm.current_state == gm.GameState.SECTOR_MAP and gm.is_sector_available(1), "continua no mapa com Beta liberado")
	check(not gm.restore({"sectors_completed": [true]}), "save inválido é rejeitado")
	check(not gm.restore({"sectors_completed": [true, true, true]}), "save de partida já vencida é rejeitado")


func test_audio_assets() -> void:
	var am = root.get_node("AudioManager")
	for n in ["ui_hover", "ui_select", "correct", "seal", "wrong", "life_lost", "rift_open",
			"rift_expand", "unlock", "whoosh", "victory", "defeat"]:
		check(am._sfx.has(n) and am._sfx[n].data.size() > 0, "efeito sonoro procedural '%s'" % n)
	for t in ["menu", "alpha", "beta", "gamma", "victory", "defeat"]:
		check(am.TRACKS.has(t), "trilha '%s'" % t)
	check(AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("SFX") != -1, "barramentos Music/SFX")


func _wait(obj: Object, sig: String, timeout: float = 10.0) -> bool:
	var done := [false]
	var cb := func(_a = null, _b = null): done[0] = true
	obj.connect(sig, cb, CONNECT_ONE_SHOT)
	var t := 0.0
	while not done[0] and t < timeout:
		await process_frame
		t += 1.0 / 60.0
	if not done[0] and obj.is_connected(sig, cb):
		obj.disconnect(sig, cb)
	return done[0]


func _until(cond: Callable, timeout: float = 10.0) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await process_frame
		t += 1.0 / 60.0
	return cond.call()


# ----------------------------------------------------------------- UI (smoke)
func test_ui_smoke() -> void:
	Engine.time_scale = 6.0
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var smap = main.sector_map
	var enc = main.shape_encounter
	check(main.menu.visible and main.screen == "menu", "jogo abre na tela inicial")
	check(main.menu.options.size() >= 4, "menu com Jogar/Continuar/Configurações/Como Jogar")
	check(main.menu.opt_continue.disabled, "Continuar desabilitado sem partida salva")
	main.menu.show_menu(false)
	main._push_overlay(main.howto)
	check(main.howto.is_open, "Como Jogar abre")
	main._pop_overlay()
	main._push_overlay(main.settings_screen)
	check(main.settings_screen.is_open, "Configurações abre")
	main._pop_overlay()
	main.start_new_game()
	check(await _until(func(): return main.screen == "map" and not main.busy), "Jogar leva ao mapa")
	check(smap.visible and not enc.visible, "mapa visível")
	check(smap.buttons[1].disabled and smap.buttons[2].disabled and not smap.buttons[0].disabled,
		"ilhas Beta/Gamma bloqueadas")
	smap.buttons[1].emit_signal("pressed")
	await process_frame
	check(gm.current_state == gm.GameState.SECTOR_MAP and main.screen == "map", "clique em setor bloqueado ignorado")
	smap.buttons[0].emit_signal("pressed")
	check(await _wait(enc, "ready_for_input"), "onda 1 pronta (fenda aberta, forma construída)")
	check(enc.visible and not smap.visible and enc.rift.openness > 0.9, "encontro visível com a fenda aberta")
	# entrada inválida não consome a onda
	enc.answer_input.text = "abc"
	enc._on_text_submitted("abc")
	check(not gm.wave_resolved and gm.attempts.is_empty(), "entrada inválida não consome a onda")
	check(enc.geo_label.text.contains("não consegui ler"), "Geo explica a entrada inválida")
	# Enter confirma resposta correta
	enc.answer_input.text = GameRules.fmt(gm.correct_area).replace(".", ",")
	enc._on_text_submitted(enc.answer_input.text)
	check(gm.wave_resolved and gm.attempts[0].success, "Enter confirma (resposta correta)")
	check(await _wait(enc, "result_shown"), "sequência de acerto concluída")
	check(enc.rift.openness < 0.05, "fenda selada após acerto")
	check(not enc.feedback_label.text.contains("ERRADO"), "feedback sem 'ERRADO' (Pilar 3)")
	check(enc.btn_next.visible, "botão Próxima Onda visível")
	# Enter novamente avança
	enc._on_text_submitted("")
	check(await _wait(enc, "ready_for_input"), "Enter avança para a onda 2")
	check(gm.current_wave == 2 and not gm.wave_resolved, "onda 2 ativa")
	# pausa congela e retoma
	main.open_pause()
	check(paused and main.pause_menu.is_open, "pausa abre e congela o jogo")
	main.close_pause()
	check(not paused, "pausa fecha")
	# erro em risco alto: fenda se expande, perde vida, mostra resolução
	gm.risk_percent = 90
	enc.answer_input.text = "9999"
	enc._on_confirm_pressed()
	check(await _wait(enc, "result_shown"), "sequência de erro concluída")
	check(gm.lives == 2 and enc.rift.widen > 1.2, "fenda se expande e custa 1 vida")
	check(enc.solution_box.visible and enc.solution_label.text.begins_with("A ="), "resolução passo a passo exibida")
	# conclui o setor
	enc._on_next_pressed()
	await _wait(enc, "ready_for_input")
	enc.answer_input.text = GameRules.fmt(gm.correct_area)
	enc._on_confirm_pressed()
	await _wait(enc, "result_shown")
	enc._on_next_pressed()
	check(await _until(func(): return main.sector_clear.is_open), "tela de setor selado")
	await _until(func(): return main.sector_clear.btn.modulate.a > 0.9)
	main.sector_clear._on_continue()
	check(await _until(func(): return main.screen == "map" and not main.busy), "volta ao mapa após o setor")
	check(not smap.buttons[1].disabled and smap.buttons[0].disabled, "Beta liberado, Alpha concluído")
	# abandonar setor pela pausa
	smap.buttons[1].emit_signal("pressed")
	await _wait(enc, "ready_for_input")
	var score_before: int = gm.sector_start_score
	main._leave_sector()
	await main.go_map()
	check(gm.current_state == gm.GameState.SECTOR_MAP and gm.score == score_before and gm.is_sector_available(1),
		"abandonar setor pela pausa preserva o progresso anterior")
	main.queue_free()
	await process_frame
	Engine.time_scale = 1.0
