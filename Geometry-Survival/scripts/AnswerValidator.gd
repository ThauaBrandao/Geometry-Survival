class_name AnswerValidator
extends RefCounted
## Sistema de Validação de Resposta (GDD §6) — EAP 1.3.1.
## Separa a interpretação do texto digitado da verificação numérica,
## para que entradas inválidas NÃO consumam a onda nem gerem punição.

enum ParseError { NONE, EMPTY, NOT_A_NUMBER, NOT_POSITIVE }


## Converte o texto digitado em número. Aceita vírgula ou ponto decimal
## (teclado ABNT2) e espaços nas bordas. Rejeita texto, múltiplos
## separadores, notação científica e valores ≤ 0 (área nunca é ≤ 0).
static func parse(raw: String) -> Dictionary:
	var txt := raw.strip_edges().replace(" ", "").replace(",", ".")
	if txt == "":
		return {"ok": false, "error": ParseError.EMPTY, "value": 0.0}
	var regex := RegEx.new()
	regex.compile("^[+-]?(\\d+(\\.\\d*)?|\\.\\d+)$")
	if regex.search(txt) == null:
		return {"ok": false, "error": ParseError.NOT_A_NUMBER, "value": 0.0}
	var v := txt.to_float()
	if v <= 0.0:
		return {"ok": false, "error": ParseError.NOT_POSITIVE, "value": v}
	return {"ok": true, "error": ParseError.NONE, "value": v}


## Verifica se a resposta está dentro da tolerância relativa (inclusive).
static func is_correct(value: float, correct_area: float, tolerance: float) -> bool:
	if correct_area <= 0.0 or not is_finite(value):
		return false
	return absf(value - correct_area) <= correct_area * tolerance + 1e-9


static func error_message(error: int) -> String:
	match error:
		ParseError.EMPTY:
			return "Geo: o campo está vazio. Digite a área calculada."
		ParseError.NOT_A_NUMBER:
			return "Geo: não consegui ler esse valor. Use apenas números (ex.: 12,5)."
		ParseError.NOT_POSITIVE:
			return "Geo: uma área é sempre maior que zero. Confira o cálculo."
	return ""
