# Geometry Survival: O Cálculo Final — Revisão da Baseline, Backlog e Refinamento do Core Game Loop

**Pacotes da EAP cobertos:** 1.1.2 (parcial), 1.2.1, 1.2.2, 1.2.3, 1.2.4, 1.3.1, 1.3.2, 1.3.3, 1.3.4
**Versão:** v1.0 — 22/09/2026
**Entradas analisadas:** Project Charter v1.1, EAP v1.1, GDD Completo (N3), Relatório Final PAC Extensionista, Plano de Tratamento de Riscos v1.0, código-fonte `geometry-survival-game.zip` (Godot 4.3).

---

## 1. Decisões de projeto registradas

| ID | Decisão | Justificativa | Aprovação |
|---|---|---|---|
| **DD-01** | **O jogo permanece 2D.** | O conteúdo é *área de figuras planas*: a leitura exata de base, altura e raio é o próprio desafio, e uma câmera 3D introduziria perspectiva e oclusão que distorcem essas medidas. O protótipo já é 2D e *code-first* (Pilar 5 do GDD); migrar para 3D seria uma reconstrução, que o Charter coloca **fora do escopo**. O 2D também reduz o custo de execução em computadores escolares e viabiliza o export Web previsto no GDD, sem exigir modelagem 3D que a equipe não domina (Relatório §4.3). Sensação de profundidade pode vir em 1.4.2 com parallax, brilho e sombras em 2D. | Proposta — confirmar com o Sponsor no checkpoint |
| **DD-02** | Renderer trocado de *Forward+* para *Compatibility (OpenGL/WebGL)*. | No Godot 4.3 o export Web exige o renderer Compatibility; com Forward+ a plataforma "Web (HTML5)" declarada no GDD §2 não funciona. O Compatibility também é mais leve para máquinas modestas. | Executada (reversível) |
| **DD-03** | Tolerância de resposta por setor: **Alpha ±2%**, **Beta ±5%**, **Gamma ±5%** (antes ±10% fixo). | Com ±10%, no Alpha a resposta 45 era aceita para um quadrado de área 49, ou seja, respostas erradas eram premiadas. No Alpha as áreas são inteiras ou terminam em ,5, então basta uma margem de arredondamento. Em Beta e Gamma, ±5% aceita π ≈ 3,14 e π ≈ 3 (erro de 4,5%), mas rejeita confusões conceituais como 2πr. | Proposta — validar com Thauã (1.2.3) |
| **DD-04** | Faixa de risco por setor: Alpha 10–75%, Beta 25–90%, Gamma 40–90%. | O GDD (linha do tempo T2) descreve o Beta como setor de "maior risco médio", mas o código sorteava 10–90% para todos os setores. | Proposta |
| **DD-05** | "Reinício preserva o placar" (GDD Pilar 3) passa a significar **recorde da sessão preservado**; a partida em si recomeça do zero. | O texto do GDD era ambíguo e o código zerava tudo. A solução mantém o reinício justo e ainda valoriza o esforço anterior. | Proposta |

---

## 2. Revisão do GDD existente (1.2.1)

Critério de aceite: divergências corrigidas ou registradas.

| # | Seção do GDD | Divergência encontrada | Tratamento |
|---|---|---|---|
| G1 | §2 Plataforma | Web prometida, mas o renderer Forward+ não exporta para Web. | Corrigido no código (DD-02); o GDD deve citar o renderer Compatibility. |
| G2 | §3 Pilar 3 | O pilar diz que o jogo nunca mostra "resposta errada", mas o código exibia "ERRADO!". | Corrigido no código: o feedback agora é narrativo ("A fenda resistiu…") e mostra a resolução. |
| G3 | §3 Pilar 3 | "Reinício preserva o placar" é ambíguo. | Definido por DD-05; atualizar o texto do GDD. |
| G4 | §4 Core Gameplay | A confirmação "com tecla Enter" não existia no código. | Corrigido no código. |
| G5 | §5 / §6 Validação | Tolerância fixa de ±10% e nenhum tratamento de entrada inválida (texto virava 0 e consumia a onda). | Corrigido (DD-03 e novo `AnswerValidator`); atualizar a tabela do sistema no GDD. |
| G6 | §5 Progressão / §17 | O GDD prevê desbloqueio sequencial, mas o código deixava Beta e Gamma jogáveis desde o início. | Corrigido no código. |
| G7 | §5 Risco / §11 T2 | Risco uniforme de 10–90% em todos os setores. | Corrigido (DD-04). |
| G8 | §8 Progressão | A curva de dificuldade existia só entre setores, não entre as ondas de um mesmo setor. | Implementada a curva por onda (tabela na seção 4); documentar no GDD. |
| G9 | §10 × §13 | Paletas conflitantes: §10 diz Alpha azul-fria, Beta magenta/dourado e Gamma vermelho/preto; §13 diz Alpha verde/azul e Beta azul/roxo; o código usa Gamma roxo. | **Registrado**: decidir uma paleta única em 1.4.2 (BL-18). |
| G10 | §12 Wireframe | O botão do Alpha diz "Triângulos e Quadrados", mas o setor também tem retângulo. | Corrigido no código; ajustar o wireframe. |
| G11 | §14 Animações / §15 Áudio / Axi-01 | O Relatório §4.3 descreve animações, Axi-01 e áudio procedural (Vertical Slice), mas **o .zip recebido não contém nada disso** e também não tem o README citado no Apêndice B. | **Registrado como bloqueio** (BL-16): é preciso localizar o pacote `geometry-survival-game_verticalslice.zip`. |
| G12 | §16 IA (Geo) | A FSM do Geo não estava implementada; só havia o texto de risco. | Implementada (`GeoState` no GameManager, mensagens do Geo na tela). |

---

## 3. Revisão técnica do protótipo (1.2.2)

**Execução:** o projeto importa e roda no Godot 4.3 (modo headless e com renderização via Xvfb) sem erros de script. O loop completo funciona.

**Arquitetura (baseline):** dois autoloads (`GameManager` para o estado e `ShapeGenerator` para a geração de formas). As cenas `.tscn` contêm só o nó raiz, e toda a UI é construída por código. Os sistemas se comunicam por sinais, conforme o GDD §6. A base é simples e legível, adequada para evoluir.

**Débitos técnicos encontrados:**

1. A regra de negócio (validação e pontuação) estava misturada com o texto da UI, e os números de balanceamento estavam espalhados pelo código.
2. Não havia nenhum teste automatizado.
3. O `ShapeDisplay` usava escala fixa de 40 px por unidade, e as formas do Gamma chegavam a 560 px de altura em uma tela de 648 px, cobrindo o risco, a dica, o campo de resposta e o botão (evidência em `docs/evidencias/baseline_gamma_overflow.png`).
4. O estado `RESULT_WAVE` estava declarado, mas nunca era usado.
5. Era possível enviar a resposta duas vezes (por exemplo, com Enter depois do clique) sem nenhuma trava na lógica.
6. O renderer era incompatível com a Web (ver DD-02).
7. Os glifos ♥ e ⚠ dependem de fontes do sistema; na Web podem não aparecer (o ⚠ já falhou na captura).
8. O `PLAN.md` descreve o `ShapeDisplay` como nó filho do `.tscn`, mas no código ele é criado dinamicamente (divergência pequena).

---

## 4. Revisão pedagógica e curva de dificuldade (1.2.3)

**Fórmulas:** as 6 fórmulas conferem com a matemática. Foram verificadas por teste automatizado em 2.700 desafios gerados: triângulo b·h/2, quadrado l², retângulo b·h, círculo πr², retângulo + triângulo e retângulo + semicírculo com r = largura/2. O conteúdo está alinhado à habilidade BNCC EM13MAT307 (obtenção e aplicação da medida de área).

**Problemas pedagógicos na baseline:**

- A tolerância de ±10% aceitava respostas conceitualmente erradas (resolvido por DD-03).
- Em caso de erro com risco alto, o jogo não mostrava a área correta, então o estudante perdia a vida sem aprender com o erro.
- Não havia progressão dentro do setor: a onda 1 podia ser mais difícil que a onda 3.
- O Beta nunca exercitava a conversão de diâmetro em raio, que é um erro clássico dos estudantes.

**Curva implementada:**

| Setor | Onda 1 | Onda 2 | Onda 3 |
|---|---|---|---|
| Alpha | Quadrado (2–5) ou retângulo pequeno | Retângulo maior ou triângulo com área inteira | Triângulo com possível área ,5 ou retângulo grande |
| Beta | Raio inteiro (1–5) | Raio com meio (1,5–5,5) | **Diâmetro informado** (o estudante precisa achar r) |
| Gamma | Retângulo + triângulo | Retângulo + semicírculo | "Fenda do Líder Aleatório": qualquer composta, com dimensões maiores |

**Pontos para observar na validação piloto (1.5.3):**

- A dica de fórmula aparece sempre; avaliar se isso reduz o desafio (BL-22).
- Errar em risco baixo não tem custo, o que pode incentivar o "chute" (BL-21).

---

## 5. Backlog priorizado e critérios de aceite (1.2.4)

Prioridade: **A** = alta, **M** = média, **B** = baixa. O status se refere à data desta revisão.

| ID | Item | Prior. | EAP | Responsável | Critério de aceite | Status |
|---|---|---|---|---|---|---|
| BL-01 | Desbloqueio sequencial de setores | A | 1.3.3 | Thauã / Arthur | Beta e Gamma bloqueados até concluir o setor anterior; clique em setor bloqueado é ignorado | ✅ Concluído |
| BL-02 | Formas cabem na área reservada da tela | A | 1.3.1 | Arthur | 100% das formas geradas cabem em 460×230 px, com escala ≥ 18 px/unidade | ✅ Concluído |
| BL-03 | Entrada inválida não consome a onda | A | 1.3.1 / 1.3.4 | Arthur / Vitor | Vazio, texto, "1.2.3", "1e3", 0 e negativos geram orientação do Geo, sem perda de onda ou vida | ✅ Concluído |
| BL-04 | Enter confirma e avança | M | 1.3.4 | Henrique | Enter confirma a resposta; após o feedback, Enter avança a onda | ✅ Concluído |
| BL-05 | Tolerância por setor (DD-03) | A | 1.3.1 | Thauã | Matriz de limites aprovada nos testes; parâmetros centralizados em `GameRules.gd` | ✅ Concluído (validar valores) |
| BL-06 | Feedback não punitivo com resolução passo a passo | A | 1.3.4 | Henrique / Vitor | Nenhum texto "ERRADO"; todo erro mostra a área esperada e a resolução | ✅ Concluído |
| BL-07 | Risco por setor (DD-04) | M | 1.3.2 | Arthur / Henrique | Risco sorteado sempre dentro da faixa do setor | ✅ Concluído |
| BL-08 | Dificuldade por onda, sem repetição imediata | M | 1.3.3 | Thauã | A média de área cresce da onda 1 para a 3 (Alpha e Gamma); Beta onda 3 sempre usa diâmetro; 0 repetições consecutivas | ✅ Concluído |
| BL-09 | FSM do Geo (GDD §16) | M | 1.3.2 / 1.3.4 | Arthur | Estados IDLE, ANALISANDO, ALERTANDO, APRESENTANDO e AVALIANDO emitidos pelo GameManager; mensagem do Geo em cada estado | ✅ Concluído |
| BL-10 | Recorde da sessão (DD-05) | B | 1.3.2 | Arthur | O reinício zera a partida e mantém o recorde | ✅ Concluído |
| BL-11 | Registro de tentativas e desempenho por setor | M | 1.3.2 → 1.5.3 | Vitor | Tentativas registradas; acertos por setor exibidos no mapa e no resultado | ✅ Concluído · exportar CSV fica para 1.5.3 |
| BL-12 | Renderer Compatibility (DD-02) | A | 1.2.2 → 1.4.4 | Arthur | O projeto roda em Compatibility; export Web testado em 1.5.2 | 🟡 Parcial (troca feita, export pendente) |
| BL-13 | Fonte própria para ♥/⚠ (compatível com Web) | M | 1.4.1 | Henrique | Ícones renderizam no build Web | ⬜ Aberto |
| BL-14 | HUD contextual (ocultar setor/onda no Mapa) | B | 1.4.1 | Henrique | O HUD do Mapa mostra só score e vidas | ⬜ Aberto |
| BL-15 | Layout responsivo / janela redimensionável | M | 1.4.1 / 1.5.2 | Henrique / Vitor | Layout legível em 1366×768, 1920×1080 e no navegador | ⬜ Aberto |
| BL-16 | Integrar o pacote do Vertical Slice (animações, Axi-01, áudio) | A | 1.4.2 / 1.4.3 | Arthur / Henrique | Código do VS localizado e mesclado com o refinamento 1.3, com testes verdes | ⛔ Bloqueado (arquivo ausente) |
| BL-17 | README com execução, testes e checklist | M | 1.6.1 | Vitor | README permite rodar o jogo e os testes sem ajuda | ✅ Concluído |
| BL-18 | Paleta única por setor (G9) | M | 1.4.2 | Henrique | GDD §10, GDD §13 e código com a mesma paleta | ⬜ Aberto |
| BL-19 | Suíte de testes automatizados headless | A | 1.5.1 | Vitor | Suíte roda em linha de comando e retorna código 0/1 | ✅ Concluído (base) |
| BL-20 | Atualizar o texto do GDD (G1–G12, DD-01 a DD-05) | M | 1.2.1 → 1.6.1 | Henrique | Nova versão do GDD sem divergências com o build | ⬜ Aberto |
| BL-21 | Observar o "chute" em risco baixo no piloto | B | 1.5.3 | Thauã | Item incluído no roteiro de observação | ⬜ Aberto |
| BL-22 | Avaliar a dica de fórmula sob demanda | B | 1.5.3 | Thauã | Decisão registrada com base no piloto | ⬜ Aberto |

---

## 6. Refinamento do Core Game Loop (1.3) — o que foi entregue

| Pacote | Entregas no código | Evidência |
|---|---|---|
| **1.3.1** Geração e Validação | `AnswerValidator.gd` (parse e validação separados); `ShapeGenerator` por setor e onda, com resolução passo a passo e sem repetição imediata; `ShapeDisplay` com escala automática, cotas nas arestas e linhas de altura, raio e diâmetro | Testes: parse, tolerância, tipos por setor, área igual à fórmula (2.700 amostras), encaixe na tela |
| **1.3.2** Risco, Pontuação e Vidas | `GameRules.gd` centraliza o balanceamento; risco por setor; trava contra resposta dupla; FSM do Geo; recorde da sessão; registro de tentativas | Testes: matriz risco × acerto (6 casos, incluindo os limites 70/71), resposta dupla, derrota e reinício |
| **1.3.3** Progressão e Dificuldade | Desbloqueio sequencial; Mapa com estados bloqueado, disponível e concluído (com acertos); curva por onda; "Fenda do Líder Aleatório" no Gamma 3 | Testes: sequência de desbloqueio, partida completa até a vitória, dificuldade por onda |
| **1.3.4** Feedback e Experiência | Mensagens narrativas; resolução passo a passo; orientação do Geo para entrada inválida; Enter para confirmar e avançar; foco automático no campo; resolução da última fenda na tela de derrota | Teste de fumaça da UI (clique, Enter, entrada inválida, feedback); capturas em `docs/evidencias/` |

**Resultado da suíte automatizada:** 15 testes com **14.232 verificações, 0 falhas** (Godot 4.3, `--headless`).

**Pendente para fechar formalmente:**

- A equipe deve executar o checklist manual do README (em 1.5.1).
- O Thauã deve validar os valores de DD-03 e DD-04.
