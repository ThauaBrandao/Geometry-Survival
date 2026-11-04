# Plano de Implementação: Geometry Survival — O Cálculo Final

## Contexto

Criar um protótipo funcional e completo do Core Game Loop de um jogo educacional de geometria e probabilidade em Godot 4 GDScript. O loop deve ser completável do início ao fim:

**Setor → Forma → Cálculo → Feedback → Risco → Próxima Onda → Vitória/Derrota**

O projeto parte do zero (diretório vazio). Todos os arquivos serão criados. Sem arte externa — apenas primitivos do Godot (`ColorRect`, `Polygon2D`, `Label`, `draw_*`).

---

## Estrutura de Arquivos (18 arquivos)

```
geometry-survival-game/
├── project.godot
├── icon.svg
├── scenes/
│   ├── Main.tscn            ← Node2D + Main.gd
│   ├── SectorMap.tscn       ← Node2D + SectorMap.gd
│   ├── ShapeEncounter.tscn  ← Node2D + ShapeEncounter.gd + filho ShapeDisplay
│   ├── HUD.tscn             ← CanvasLayer + HUD.gd
│   └── ResultScreen.tscn    ← CanvasLayer + ResultScreen.gd
└── scripts/
    ├── GameManager.gd       ← Autoload singleton (estado + sinais)
    ├── ShapeGenerator.gd    ← Autoload (gera formas por setor)
    ├── Main.gd              ← Gerencia visibilidade das sub-cenas
    ├── SectorMap.gd         ← 3 botões estilizados; emite sinal de setor escolhido
    ├── ShapeDisplay.gd      ← Node2D com _draw(); renderiza formas geométricas
    ├── ShapeEncounter.gd    ← UI de encontro: input, feedback, risco
    ├── HUD.gd               ← Labels score/vidas/setor/onda no topo
    └── ResultScreen.gd      ← Game Over e Vitória com botão Restart
```

**Abordagem code-first:** Os `.tscn` contêm apenas o nó raiz + script vinculado. Toda a árvore de filhos é construída em `_ready()` via GDScript — elimina dependência de nós criados no editor, facilita leitura e evita erros de UID.

---

## project.godot

```ini
config_version=5

[application]
config/name="Geometry Survival: O Cálculo Final"
config/description="Jogo educacional de geometria - Ensino Médio"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
config/icon="res://icon.svg"

[autoload]
GameManager="*res://scripts/GameManager.gd"
ShapeGenerator="*res://scripts/ShapeGenerator.gd"

[display]
window/size/viewport_width=1152
window/size/viewport_height=648
window/size/resizable=false
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="forward_plus"
```

---

## GameManager.gd — Enums, Variáveis, Sinais

```gdscript
enum GameState { SECTOR_MAP, ENCOUNTER, RESULT_WAVE, GAME_OVER, GAME_WIN }
enum ShapeType { TRIANGLE, SQUARE, RECTANGLE, CIRCLE, COMPOSITE_RECT_TRI, COMPOSITE_RECT_SEMI }
enum Sector    { ALPHA, BETA, GAMMA }

var current_state: GameState = GameState.SECTOR_MAP
var current_sector: Sector   = Sector.ALPHA
var current_wave: int        = 1         # 1..3
var score: int               = 0
var lives: int               = 3
var sectors_completed: Array[bool] = [false, false, false]

var current_shape_params: Dictionary = {}
var correct_area: float = 0.0
var risk_percent: int   = 0              # 10..90

signal state_changed(new_state: GameState)
signal lives_changed(new_lives: int)
signal score_changed(new_score: int)
signal wave_changed(wave: int, sector: Sector)
signal encounter_result(success: bool, risk_was_high: bool)
```

### Métodos principais

| Método | Responsabilidade |
|--------|-----------------|
| `start_encounter(sector)` | Chama `ShapeGenerator.generate()`, sorteia `risk_percent`, emite `state_changed(ENCOUNTER)` |
| `submit_answer(valor)` | Valida com `±10%`; correto: `+100` pts (e `+50` se risk>70); errado: `lose_life()`; emite `encounter_result` |
| `advance_wave()` | Incrementa onda; se onda>3: marca setor completo → MAP ou GAME_WIN; senão: novo ENCOUNTER |
| `lose_life()` | Decrementa vidas; se vidas==0: `state=GAME_OVER` |
| `reset_game()` | Zera tudo, `state=SECTOR_MAP` |

**Lógica de validação em `submit_answer()`:**
```gdscript
var margin  = correct_area * 0.10
var success = abs(valor - correct_area) <= margin
var risk_was_high = risk_percent > 70

if success:
    score += 100
    if risk_was_high: score += 50   # bônus por defender com risco alto
else:
    if risk_was_high: lose_life()   # penalidade por risco alto + erro

emit_signal("encounter_result", success, risk_was_high)
```

---

## ShapeGenerator.gd — Geração por Setor

Retorna `{shape_type, params, correct_area, formula_hint}`.

### Formas e faixas de valores

**Setor ALPHA — Básico**

| Forma | Parâmetros | Faixa | Fórmula |
|-------|-----------|-------|---------|
| TRIANGLE | base, height | inteiros 2–7 | `base × height / 2` |
| SQUARE | side | inteiros 2–8 | `side²` |
| RECTANGLE | width, height | width 2–8, height 2–6 | `width × height` |

**Setor BETA — Avançado**

| Forma | Parâmetros | Faixa | Fórmula |
|-------|-----------|-------|---------|
| CIRCLE | radius | 1.0–5.0 (step 0.5) | `π × r²` |

**Setor GAMMA — Complexo**

| Forma | Parâmetros | Faixa | Fórmula |
|-------|-----------|-------|---------|
| COMPOSITE_RECT_TRI | rect_w, rect_h, tri_height | inteiros 2–7 | `rect_w×rect_h + rect_w×tri_h/2` |
| COMPOSITE_RECT_SEMI | rect_w (par), rect_h, radius=rect_w/2 | rect_w: 4,6,8 | `rect_w×rect_h + π×r²/2` |

---

## ShapeDisplay.gd — _draw() com Escala 40 px/unidade

Nó `Node2D` filho de ShapeEncounter, posicionado em `(576, 230)` (centro da tela). Recebe dados via `setup(shape_type, params)` → `queue_redraw()`.

```gdscript
const SCALE = 40.0  # pixels por unidade de medida

func _draw():
    match shape_type:
        GameManager.ShapeType.TRIANGLE:
            var b = params.base   * SCALE
            var h = params.height * SCALE
            var pts = PackedVector2Array([
                Vector2(-b/2, h/2), Vector2(b/2, h/2), Vector2(0, -h/2)
            ])
            draw_colored_polygon(pts, Color(0.2, 0.8, 0.4))
            draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 2.0)

        GameManager.ShapeType.SQUARE:
            var s = params.side * SCALE
            draw_rect(Rect2(-s/2, -s/2, s, s), Color(0.3, 0.5, 1.0))
            draw_rect(Rect2(-s/2, -s/2, s, s), Color.WHITE, false, 2.0)

        GameManager.ShapeType.RECTANGLE:
            var w = params.width * SCALE;  var h = params.height * SCALE
            draw_rect(Rect2(-w/2, -h/2, w, h), Color(0.3, 0.5, 1.0))
            draw_rect(Rect2(-w/2, -h/2, w, h), Color.WHITE, false, 2.0)

        GameManager.ShapeType.CIRCLE:
            var r = params.radius * SCALE
            draw_circle(Vector2.ZERO, r, Color(1.0, 0.4, 0.2))
            # Contorno via polyline de 64 pontos

        GameManager.ShapeType.COMPOSITE_RECT_TRI:
            # Retângulo embaixo + triângulo em cima, centrados em Y=0
            # total_h = rect_h + tri_h; oy = total_h/2
            # Retângulo: Rect2(-rw/2, -oy + tri_h, rw, rh)
            # Triângulo: vértices no topo do retângulo e ápice em y=-oy

        GameManager.ShapeType.COMPOSITE_RECT_SEMI:
            # Retângulo embaixo + semicírculo em cima
            # Semicírculo: 33 pontos, ângulo 0..PI

    # Ao final: draw_string() com dimensões em amarelo abaixo da forma
```

---

## Main.gd — Gerenciamento de Visibilidade

Instancia sub-cenas em `_ready()` com `load(...).instantiate()`. Conecta `GameManager.state_changed`:

```gdscript
func _on_state_changed(state):
    sector_map.visible      = (state == SECTOR_MAP)
    shape_encounter.visible = (state == ENCOUNTER or state == RESULT_WAVE)
    result_screen.visible   = (state == GAME_OVER or state == GAME_WIN)
    # HUD: sempre visível

    if state == ENCOUNTER:
        shape_encounter._setup_encounter()
```

**Ordem de add_child:** background → sector_map → shape_encounter → result_screen → hud (HUD por último para render no topo).

---

## SectorMap.gd — 3 Botões Estilizados

Cria `VBoxContainer` em `(276, 150)` com 3 `Button` (600×90 px). Cada botão usa `StyleBoxFlat`:

| Setor | Cor normal | Texto |
|-------|-----------|-------|
| Alpha | `Color(0.2, 0.6, 0.3)` | "SETOR ALPHA\nTriângulos & Quadrados" |
| Beta | `Color(0.2, 0.3, 0.8)` | "SETOR BETA\nCírculo (π·r²)" |
| Gamma | `Color(0.6, 0.2, 0.6)` | "SETOR GAMMA\nFormas Compostas" |

Botões de setores completos: `disabled=true` + cor acinzentada. Ao clicar: `GameManager.start_encounter(sector)`.

---

## ShapeEncounter.gd — UI de Encontro

**Nós criados em `_ready()`:**

```
ShapeEncounter (Node2D)
├── Label  sector_title     — "Setor Alpha — Onda 1/3"
├── Node2D ShapeDisplay     — posição (576, 230), script ShapeDisplay.gd
├── Label  risk_label       — "Risco de Colapso: 73% ⚠" (vermelho se >70%)
├── Label  formula_hint     — "Fórmula: A = base × altura / 2"
├── HBoxContainer           — posição (330, 440)
│   ├── Label  "Área ="
│   ├── LineEdit answer_input  — largura 180px
│   └── Label  "unidades²"
├── Button btn_confirm      — "Confirmar" → GameManager.submit_answer()
├── Label  feedback_label   — oculto até encounter_result
└── Button btn_next         — "Próxima Onda →" → GameManager.advance_wave()  (oculto)
```

**`_setup_encounter()`** — chamado pelo Main.gd a cada novo ENCOUNTER:
1. `var data = ShapeGenerator.generate(GameManager.current_sector)`
2. Preenche `GameManager.current_shape_params`, `correct_area`, `risk_percent`
3. `shape_display.setup(data.shape_type, data.params)`
4. Atualiza labels; limpa input; oculta feedback e btn_next

**Nota:** `answer_input.text.replace(",", ".")` antes de `float()` para compatibilidade com teclado ABNT2.

---

## HUD.gd — CanvasLayer (layer=10)

`HBoxContainer` ancorado no topo (1152×50 px, fundo `Color(0,0,0,0.8)`) com 4 painéis:

```
"SCORE: 0"  |  "VIDAS: ♥♥♥"  |  "SETOR: ALPHA"  |  "ONDA: 1/3"
```

Atualização via sinais:
- `GameManager.score_changed` → `score_label.text`
- `GameManager.lives_changed` → `"♥".repeat(v) + "♡".repeat(3-v)`
- `GameManager.wave_changed` → sector_label e wave_label

---

## ResultScreen.gd — Game Over / Vitória

Conecta `GameManager.state_changed`. Exibe:
- **GAME_OVER:** título "DERROTA!" (vermelho), score final, botão "Reiniciar"
- **GAME_WIN:** título "VITÓRIA!" (dourado), score final, botão "Jogar Novamente"

Botão Reiniciar: `GameManager.reset_game()`

---

## Formato dos .tscn (minimalista)

Cada .tscn contém apenas o nó raiz + script. Exemplo:

```
[gd_scene load_steps=2 format=3 uid="uid://main00001"]
[ext_resource type="Script" path="res://scripts/Main.gd" id="1_main0"]
[node name="Main" type="Node2D"]
script = ExtResource("1_main0")
```

**ShapeEncounter.tscn** inclui também o filho ShapeDisplay:
```
[ext_resource type="Script" path="res://scripts/ShapeDisplay.gd" id="2_sdis0"]
[node name="ShapeDisplay" type="Node2D" parent="."]
position = Vector2(576, 230)
script = ExtResource("2_sdis0")
```

UIDs únicos por arquivo: `uid://main00001`, `uid://smap00001`, `uid://enc000001`, etc.

---

## icon.svg (mínimo Godot)

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <rect width="128" height="128" fill="#1a1a2e"/>
  <polygon points="64,10 118,100 10,100" fill="#00ccff" stroke="white" stroke-width="3"/>
</svg>
```

---

## Ordem de Implementação

1. `project.godot` + `icon.svg`
2. `scripts/GameManager.gd` (stubs de métodos; sinais funcionando)
3. `scripts/ShapeGenerator.gd` (testável isoladamente)
4. `scenes/HUD.tscn` + `scripts/HUD.gd`
5. `scenes/SectorMap.tscn` + `scripts/SectorMap.gd`
6. `scripts/ShapeDisplay.gd` (testar _draw com valores fixos)
7. `scenes/ShapeEncounter.tscn` + `scripts/ShapeEncounter.gd`
8. `scenes/Main.tscn` + `scripts/Main.gd`
9. `scenes/ResultScreen.tscn` + `scripts/ResultScreen.gd`
10. `GameManager.gd` — lógica completa (substitui stubs)

---

## Verificação — Checklist do Loop Completo

```
[ ] F5 → sem erros de compilação; SectorMap visível + HUD com SCORE:0 VIDAS:♥♥♥
[ ] Clicar ALPHA → ShapeEncounter com forma + dimensões + risco + fórmula
[ ] Resposta correta (±9%) → "CORRETO! +100", btn_next aparece
[ ] Risco >70% + resposta correta → +150 pts (100+50 bônus)
[ ] Risco >70% + resposta errada → perde vida, HUD atualiza
[ ] 3 ondas Alpha → volta ao SectorMap, botão Alpha desabilitado
[ ] Clicar BETA → círculo com hint "A = π × r²"
[ ] Clicar GAMMA → forma composta com fórmula composta
[ ] Perder 3 vidas → ResultScreen "DERROTA!" com score final
[ ] Botão Reiniciar → jogo zerado, SectorMap limpo
[ ] Completar Alpha+Beta+Gamma → ResultScreen "VITÓRIA!"
[ ] Export → HTML5: Project > Export > Web, rodar no browser local
```

---

## Fluxo de Dados Resumido

```
SectorMap.btn_pressed
    → GameManager.start_encounter(sector)
        → ShapeGenerator.generate() → preenche params, correct_area
        → risk_percent = randi_range(10, 90)
        → emit state_changed(ENCOUNTER)
            → Main._on_state_changed → shape_encounter._setup_encounter()
                → ShapeDisplay.setup() → queue_redraw() → _draw()

ShapeEncounter.btn_confirm_pressed
    → GameManager.submit_answer(float(input))
        → valida ±10%, ajusta score/lives
        → emit score_changed, lives_changed → HUD atualiza
        → emit encounter_result → ShapeEncounter mostra feedback + btn_next

ShapeEncounter.btn_next_pressed
    → GameManager.advance_wave()
        → wave++ ou setor completo
        → emit state_changed → Main troca visibilidade + HUD atualiza
```
