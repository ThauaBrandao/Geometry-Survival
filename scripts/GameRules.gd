class_name GameRules
extends RefCounted
## Regras e parâmetros de balanceamento do Core Game Loop (EAP 1.3).
## Centralizar os números aqui permite que a equipe ajuste o balanceamento
## sem mexer na lógica (controle de mudanças — risco R3).

const WAVES_PER_SECTOR := 3
const STARTING_LIVES   := 3

## Pontuação (GDD §5): 100 por acerto, +50 se o risco era alto.
const POINTS_CORRECT   := 100
const POINTS_HIGH_RISK_BONUS := 50

## Limiar de risco alto (GDD: "acima de 70%").
const HIGH_RISK_THRESHOLD := 70

## Tolerância relativa por setor (DD-03).
## Alpha: respostas são inteiras ou terminam em ,5 → tolerância só para arredondamento.
## Beta/Gamma: aceita π ≈ 3,14 e π ≈ 3 (erro máx. ≈ 4,5%) e arredondamentos.
const TOLERANCE_BY_SECTOR := [0.02, 0.05, 0.05]

## Faixa de risco sorteada por setor (GDD T2: Beta "de maior risco médio").
const RISK_RANGE_BY_SECTOR := [Vector2i(10, 75), Vector2i(25, 90), Vector2i(40, 90)]

## Área máxima de desenho (em px) usada pelo ShapeDisplay para caber na tela.
const SHAPE_BOX := Vector2(460, 230)

const SECTOR_NAMES := ["Alpha", "Beta", "Gamma"]


static func tolerance_for(sector: int) -> float:
	return TOLERANCE_BY_SECTOR[clampi(sector, 0, 2)]


static func risk_range_for(sector: int) -> Vector2i:
	return RISK_RANGE_BY_SECTOR[clampi(sector, 0, 2)]


static func is_high_risk(risk_percent: int) -> bool:
	return risk_percent > HIGH_RISK_THRESHOLD


static func points_for(success: bool, high_risk: bool) -> int:
	if not success:
		return 0
	return POINTS_CORRECT + (POINTS_HIGH_RISK_BONUS if high_risk else 0)


## Regra de vidas (GDD §5): só perde vida quando erra uma fenda de risco alto.
static func lives_lost_for(success: bool, high_risk: bool) -> int:
	return 1 if (not success and high_risk) else 0


## Formata número no padrão pt-BR (vírgula decimal, sem zeros desnecessários).
static func fmt(value: float, decimals: int = 2) -> String:
	var s := String.num(snappedf(value, pow(10.0, -decimals)), decimals)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")
