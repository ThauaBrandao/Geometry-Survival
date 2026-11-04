extends Node
## Sistema de Geração de Formas (GDD §6) — EAP 1.3.1 / 1.3.3.
## Gera um desafio válido para o setor e a onda atuais. A dificuldade
## cresce dentro de cada setor (onda 1 → 3) e entre setores (Alpha → Gamma).
##
## Saída (Dictionary):
##   shape_type    GameManager.ShapeType
##   params        dimensões da forma (unidades)
##   correct_area  área correta (float > 0)
##   formula_hint  dica exibida por Geo
##   solution      resolução passo a passo exibida no feedback de erro
##   size_units    Vector2 com largura/altura da forma (para caber na tela)
##   signature     texto único usado para evitar desafios repetidos em sequência

const MAX_REROLLS := 10

var _last_signature: String = ""


func generate(sector: int, wave: int = 1) -> Dictionary:
	var data: Dictionary = {}
	for i in MAX_REROLLS:
		data = _generate_once(sector, clampi(wave, 1, GameRules.WAVES_PER_SECTOR))
		if data.signature != _last_signature:
			break
	_last_signature = data.signature
	return data


func reset_history() -> void:
	_last_signature = ""


func _generate_once(sector: int, wave: int) -> Dictionary:
	match sector:
		GameManager.Sector.BETA:
			return _generate_beta(wave)
		GameManager.Sector.GAMMA:
			return _generate_gamma(wave)
	return _generate_alpha(wave)


# ---------------------------------------------------------------- ALPHA
# Onda 1: quadrado/retângulo pequenos (multiplicação direta)
# Onda 2: retângulo maior ou triângulo com área inteira
# Onda 3: triângulo com área possivelmente decimal (,5) ou retângulo grande
func _generate_alpha(wave: int) -> Dictionary:
	match wave:
		1:
			if randi() % 2 == 0:
				return _square(randi_range(2, 5))
			return _rectangle(randi_range(3, 6), randi_range(2, 5))
		2:
			if randi() % 2 == 0:
				return _rectangle(randi_range(4, 8), randi_range(2, 6))
			return _triangle(2 * randi_range(1, 4), randi_range(2, 7))
		_:
			if randi() % 3 == 0:
				return _rectangle(randi_range(6, 10), randi_range(3, 8))
			return _triangle(randi_range(3, 9), randi_range(3, 8))


# ---------------------------------------------------------------- BETA
# Onda 1: raio inteiro · Onda 2: raio com meio · Onda 3: diâmetro informado
func _generate_beta(wave: int) -> Dictionary:
	match wave:
		1:
			return _circle(float(randi_range(1, 5)), false)
		2:
			return _circle(randi_range(1, 5) + 0.5, false)
		_:
			return _circle(float(randi_range(2, 10)) / 2.0, true)


# ---------------------------------------------------------------- GAMMA
# Onda 1: retângulo + triângulo · Onda 2: retângulo + semicírculo
# Onda 3: "Fenda do Líder Aleatório" — qualquer composta, dimensões maiores
func _generate_gamma(wave: int) -> Dictionary:
	match wave:
		1:
			return _comp_rect_tri(2 * randi_range(1, 4), randi_range(2, 5), randi_range(2, 5))
		2:
			return _comp_rect_semi([2, 4, 6][randi_range(0, 2)], randi_range(2, 5))
		_:
			if randi() % 2 == 0:
				return _comp_rect_tri(randi_range(3, 10), randi_range(3, 6), randi_range(2, 6))
			return _comp_rect_semi([4, 6, 8, 10][randi_range(0, 3)], randi_range(3, 6))


# ---------------------------------------------------------------- builders
func _square(s: int) -> Dictionary:
	var a := float(s * s)
	return _pack(GameManager.ShapeType.SQUARE, {"side": s}, a,
		"A = lado²",
		"A = lado² = %d² = %s" % [s, GameRules.fmt(a)],
		Vector2(s, s))


func _rectangle(w: int, h: int) -> Dictionary:
	var a := float(w * h)
	return _pack(GameManager.ShapeType.RECTANGLE, {"width": w, "height": h}, a,
		"A = base × altura",
		"A = base × altura = %d × %d = %s" % [w, h, GameRules.fmt(a)],
		Vector2(w, h))


func _triangle(b: int, h: int) -> Dictionary:
	var a := b * h / 2.0
	return _pack(GameManager.ShapeType.TRIANGLE, {"base": b, "height": h}, a,
		"A = base × altura ÷ 2",
		"A = base × altura ÷ 2 = %d × %d ÷ 2 = %s" % [b, h, GameRules.fmt(a)],
		Vector2(b, h))


func _circle(r: float, show_diameter: bool) -> Dictionary:
	var a := PI * r * r
	var params := {"radius": r, "show_diameter": show_diameter}
	var hint := "A = π × r²"
	var sol := "A = π × r² = π × %s² ≈ 3,14 × %s ≈ %s" % [
		GameRules.fmt(r), GameRules.fmt(r * r), GameRules.fmt(a)]
	if show_diameter:
		params["diameter"] = r * 2.0
		hint = "A = π × r²   (r = diâmetro ÷ 2)"
		sol = "r = %s ÷ 2 = %s  →  " % [GameRules.fmt(r * 2.0), GameRules.fmt(r)] + sol
	return _pack(GameManager.ShapeType.CIRCLE, params, a, hint, sol, Vector2(r * 2.0, r * 2.0))


func _comp_rect_tri(rw: int, rh: int, th: int) -> Dictionary:
	var a_rect := float(rw * rh)
	var a_tri := rw * th / 2.0
	var a := a_rect + a_tri
	return _pack(GameManager.ShapeType.COMPOSITE_RECT_TRI,
		{"rect_w": rw, "rect_h": rh, "tri_height": th}, a,
		"A = retângulo + triângulo",
		"Retângulo: %d × %d = %s  +  Triângulo: %d × %d ÷ 2 = %s  →  A = %s" % [
			rw, rh, GameRules.fmt(a_rect), rw, th, GameRules.fmt(a_tri), GameRules.fmt(a)],
		Vector2(rw, rh + th))


func _comp_rect_semi(rw: int, rh: int) -> Dictionary:
	var r := rw / 2.0
	var a_rect := float(rw * rh)
	var a_semi := PI * r * r / 2.0
	var a := a_rect + a_semi
	return _pack(GameManager.ShapeType.COMPOSITE_RECT_SEMI,
		{"rect_w": rw, "rect_h": rh, "radius": r}, a,
		"A = retângulo + semicírculo   (r = largura ÷ 2)",
		"Retângulo: %d × %d = %s  +  Semicírculo: π × %s² ÷ 2 ≈ %s  →  A ≈ %s" % [
			rw, rh, GameRules.fmt(a_rect), GameRules.fmt(r), GameRules.fmt(a_semi), GameRules.fmt(a)],
		Vector2(rw, rh + r))


func _pack(t: int, params: Dictionary, area: float, hint: String, solution: String, size: Vector2) -> Dictionary:
	return {
		"shape_type": t,
		"params": params,
		"correct_area": area,
		"formula_hint": hint,
		"solution": solution,
		"size_units": size,
		"signature": "%d:%s" % [t, str(params)],
	}
