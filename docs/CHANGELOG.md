# Changelog

## v1.4 — 22/09/2026 (EAP 1.4 — Vertical Slice: apresentação, UI e áudio)

Reformulação completa da experiência visual e sonora. As regras do jogo (GameRules, AnswerValidator, ShapeGenerator) não mudaram.

### Adicionado

- **A Fenda Dimensional** (`scripts/fx/Rift.gd`), elemento do GDD que não existia no código: abre a cada onda, pulsa e muda de cor conforme o risco, emite faíscas e raios de instabilidade, é **selada** com clarão e onda de choque no acerto, **resiste** no erro de risco baixo e **se expande** (Entropia) no erro de risco alto. A transição entre telas também tem o formato de uma fenda rasgando a tela.
- **Tela inicial** com logotipo que se monta (triângulo, quadrado e círculo) e **Menu principal** com Jogar, Continuar, Configurações, Como Jogar e Sair: opções em faixa animada com hover/foco, som, navegação por teclado e a cena de Axi-01 diante de uma fenda distante.
- **Axi-01** animada (idle, lançamento de feixe, comemoração, dano, vitória, derrota) e **Geo** como drone com olho que muda de cor conforme a FSM.
- **Cenário em camadas**: nebulosa em shader, estrelas em duas profundidades, formas distantes e próximas, grade cartesiana em perspectiva, poeira luminosa e parallax pelo mouse; paleta muda por setor.
- **Seleção de setores** como o Arquipélago Dimensional: ilhas flutuantes com volume e sombra, emblemas holográficos, trilhas de energia, estrelas por setor e animação de desbloqueio.
- **HUD** novo: pontuação com contagem animada, recorde, barra de progresso das ondas, corações vetoriais que se partem, chip de sequência de acertos e botão de pausa.
- **Console do encontro**: Geo com texto digitado, caixa de resolução, fórmula, campo de resposta, **medidor semicircular de risco** e aviso claro de recompensa/penalidade.
- **Forma com animação de construção** (contorno traçado), cotas técnicas, cores por parte nas formas compostas, glitch no erro e estilhaçamento no acerto.
- **Pausa** (Esc) com fundo desfocado, **Configurações** (música, efeitos, tela cheia, tremor de tela, movimento reduzido), **Como Jogar** ilustrado em 4 páginas, diálogos de confirmação.
- **Transição de setor** (cartão de apresentação) e **fim de setor** com estrelas, pontos e aviso do setor liberado.
- **Vitória** com fogos, contagem da pontuação, desempenho por setor e selo de NOVO RECORDE; **Derrota** com a Entropia dominando a tela, mensagem encorajadora e resolução da última fenda.
- **Áudio 100% procedural** (`scripts/AudioManager.gd`): 20 efeitos sonoros e música generativa por contexto (menu, Alpha, Beta, Gamma, vitória, derrota), com barramentos Music/SFX.
- **Salvamento automático** ao voltar ao mapa (`SaveGame.gd`), habilitando "Continuar"; recorde persistente.
- `GameManager`: sequência de acertos, recorde anterior à partida, abandono de setor pela pausa e restauração de partida salva.
- Tipografia: Orbitron (títulos) e Exo 2 (textos e números), licença SIL OFL em `assets/fonts/`.
- Paleta única em `scripts/ui/Palette.gd` (resolve o conflito GDD §10 × §13 — BL-18) e ícones vetoriais em `scripts/ui/Icons.gd` (substituem ♥/⚠ — BL-13).
- 5 novos grupos de testes (sequência/recorde, abandono de setor, restauração, áudio e fumaça da interface completa).

### Alterado

- Janela redimensionável com proporção preservada (BL-15). HUD some fora do jogo (BL-14).
- Tela de erro em risco alto balança a tela (desativável em Configurações).

## v1.3 — 22/09/2026 (EAP 1.3 — Refinamento do Core Game Loop)

### Adicionado

- `GameRules.gd`: todo o balanceamento centralizado em um só arquivo.
- `AnswerValidator.gd`: aceita vírgula ou ponto e rejeita texto, "1.2.3", notação científica, zero e negativos.
- Tolerância por setor (Alpha ±2%, Beta e Gamma ±5%) e faixa de risco por setor.
- Curva de dificuldade por onda. A onda 3 do Beta informa o diâmetro. A onda 3 do Gamma é a "Fenda do Líder Aleatório".
- FSM do Geo (IDLE, ANALISANDO, ALERTANDO, APRESENTANDO, AVALIANDO) com mensagens na tela.
- Resolução passo a passo exibida após cada erro e na tela de derrota.
- Recorde da sessão e registro de tentativas, com acertos por setor no Mapa e no Resultado.
- Suíte de testes headless em `tests/test_runner.gd`, README e evidências em `docs/evidencias/`.

### Corrigido

- Beta e Gamma podiam ser jogados desde o início; agora o desbloqueio é sequencial.
- Formas do Gamma chegavam a 560 px de altura e cobriam a interface; agora a escala é automática.
- Entrada inválida virava 0 e consumia a onda.
- A tecla Enter não confirmava a resposta.
- A tolerância de ±10% aceitava respostas erradas no Alpha.
- A mesma onda podia ser respondida duas vezes.
- O feedback "ERRADO!" contrariava o Pilar 3 do GDD.

### Alterado

- Renderer trocado de Forward+ para Compatibility, necessário para o export Web.
- Cotas desenhadas junto às arestas, com linhas guia de altura, raio e diâmetro.
