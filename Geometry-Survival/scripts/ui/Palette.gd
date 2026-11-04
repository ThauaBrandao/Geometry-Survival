class_name Palette
extends RefCounted
## Paleta única do jogo (resolve BL-18: GDD §10 × §13 × código).
## Fundo espacial profundo + neon; cada setor tem cor principal e acento.

const BG_DEEP   := Color("05070f")
const BG_MID    := Color("0b1128")
const INK       := Color("eaf2ff")   # texto principal
const INK_DIM   := Color("8fa3cc")   # texto secundário
const INK_FAINT := Color("4b5b82")
const CYAN      := Color("27e8ff")   # UI / Axi-01
const VIOLET    := Color("a45bff")
const GOLD      := Color("ffc94a")   # pontuação, recordes, Líder Aleatório
const SUCCESS   := Color("3dffa8")
const WARN      := Color("ffae42")
const DANGER    := Color("ff3b5c")   # Entropia, risco alto
const VOID      := Color("0a0514")   # interior da fenda

const PANEL      := Color(0.035, 0.055, 0.13, 0.82)
const PANEL_SOFT := Color(0.05, 0.08, 0.18, 0.55)
const EDGE       := Color(0.15, 0.9, 1.0, 0.45)

## Setores (ordem = GameManager.Sector). "sky" = três tons do fundo nebular.
const SECTORS := [
	{
		"key": "ALPHA", "name": "Setor Alpha", "title": "Planícies Euclidianas",
		"content": "Triângulo · Quadrado · Retângulo",
		"main": Color("27e8ff"), "accent": Color("4f7bff"),
		"sky": [Color("040a1a"), Color("0b2a4d"), Color("0f5f7a")],
	},
	{
		"key": "BETA", "name": "Setor Beta", "title": "Câmara dos Arcos",
		"content": "Círculo · π × r²",
		"main": Color("c05bff"), "accent": Color("ffc94a"),
		"sky": [Color("0c0518"), Color("2a0f4d"), Color("6b2a7a")],
	},
	{
		"key": "GAMMA", "name": "Setor Gamma", "title": "Nexo da Entropia",
		"content": "Formas Compostas",
		"main": Color("ff3b5c"), "accent": Color("ffc94a"),
		"sky": [Color("0a0306"), Color("3a0a16"), Color("7a1a24")],
	},
]

## Fundo do menu / mapa (mistura dos três setores).
const MENU_SKY := [Color("04060f"), Color("1a1245"), Color("0f4a6b")]


static func sector(i: int) -> Dictionary:
	return SECTORS[clampi(i, 0, 2)]


static func risk_color(risk: int) -> Color:
	if risk > GameRules.HIGH_RISK_THRESHOLD:
		return DANGER
	if risk > 45:
		return WARN
	return SUCCESS
