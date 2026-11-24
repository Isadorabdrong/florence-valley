# Arquitetura: Florence Valley

## Princípios

- **Lógica pura separada de nós.** As regras (movimento, layout do mapa, validação de perfil) ficam em classes `RefCounted` estáticas e testáveis (`MovementLogic`, `MapLayout`, `ProfileRules`, `TerrainAtlas`). Os nós (`Player`, `WorldMap`) só aplicam essas regras.
- **Conteúdo em dados.** Mapas (`data/maps/*.txt`), legenda (`data/configuration/map_legend.json`), opções de personagem (`character_options.json`) e textos (`data/localization/strings.csv`) são editáveis sem tocar em código.
- **Autoloads mínimos.** São três: `GameState` (estado da sessão, dono dos dados), `SceneManager` (transições) e `AudioManager` (efeitos sonoros).
- **Sinais para desacoplar.** Exemplos: `WorldMap.built`, `Player.facing_changed`, `GameState.profile_changed`, `SceneManager.scene_changed`.
- **Tipagem estática** em todo o GDScript.

## Fluxo de cenas

```
main_menu.tscn ──Novo Jogo──▶ character_creation.tscn ──Começar──▶ farm.tscn
      ▲                                                               │
      └────────────────────── Pausa ▸ Menu principal ─────────────────┘
```

Todas as transições passam por `SceneManager.change_scene()`, com fade e bloqueio de cliques durante a troca.

## Mundo e mapas (Fase 4)

- **`data/maps/world.json`** é a fonte de verdade do mundo:
  - `maps`: tipo de cada mapa (fazenda, ao ar livre ou interior), se permite cultivo, ambiente e posição no mapa do vale;
  - `spawns`: pontos de chegada com nome;
  - `exits`: células nas bordas que levam a outro mapa;
  - `interactions`: o que cada objeto faz, com chave `"mapa:x,y"`. Os tipos são porta, placa, porta trancada, marco e loja;
  - `forage`: tabelas de coleta por região e estação.
- **`WorldGraph`** lê o arquivo, faz os sorteios determinísticos de coleta e valida tudo:
  - pontos de chegada em células livres;
  - saídas, portas e lojas apontando para destinos que existem;
  - textos traduzidos;
  - todos os mapas alcançáveis a partir da fazenda.
- **`GameplayScene`** é a única cena de jogo. Ela lê `GameState.current_map` e monta o mapa, além de cuidar do jogador, das saídas, da luz, do clima e do ambiente. A fazenda é só um mapa com `farming: true`, que exibe o `SoilView`.
- **Viagem**: `GameState.travel(mapa, chegada)` seguido de `SceneManager.change_scene(map_scene)`. Nos testes, `allow_scene_changes = false` atualiza só o estado.
- **Objetos interativos** têm `object_kind = "interact"` (prédios, placas, estantes, balcões, marcos). O `FarmController` consulta o `world.json` para decidir o que acontece. Assim, uma porta nova é só uma linha de dados.
- **Interiores** usam o mesmo `WorldMap`, com terrenos `wood`, `wall` e `doormat`. A colisão das paredes, da água e dos penhascos vem do TileSet. Salas menores que a tela ficam centralizadas.

## Floricultura (Fase 5)

- **`FloristShop`** (`GameState.florist`) é lógica pura e cuida de:
  - reforma, vitrines (item, quantidade e preço) e clientes;
  - fila de atendimento, encomendas, reputação, melhorias e decorações;
  - montagem de buquês e salvamento.
  
  Todos os sorteios usam um `RandomNumberGenerator` recebido de fora, com semente derivada de `world_seed`, dia e horário. Por isso a simulação é reproduzível e testável.
- **Ajustes** ficam em `data/florist/florist.json`: horário, ritmo de clientes, efeito do clima e do fim de semana, perfis de cliente, melhorias, decorações e encomendas.
- **Simulação**:
  - O `GameState` chama `tick()` a cada 10 minutos do relógio, em qualquer mapa. Por isso a loja vende mesmo com você longe.
  - A chance de compra é `clamp((tolerância + 0,35 − preço/valor) / 0,8)`. A tolerância depende do perfil do cliente, das melhorias, das estrelas e da estação do buquê.
  - Preços justos (até 115%) dão reputação; preços acima de 140% que espantam o cliente tiram reputação.
- **Atendimento**: com o jogador dentro da loja (`current_map == florist_shop`), quem decide comprar entra em `pending` e espera no balcão por até 30 minutos. `serve_next()` paga com gorjeta; sem atendimento, a venda se conclui sozinha quando o prazo acaba. `end_day()` fecha o caixa, vence encomendas atrasadas e cria as novas.
- **`BouquetBook`**: as receitas pedem exatamente 3 ingredientes, cada um definido por item, lista de alternativas (`any`) ou tag. A primeira receita que casar vence, e a ordem no arquivo vai de raro a simples. Os itens de buquê são gerados pelo `ItemRegistry` a partir das receitas, como já acontece com sementes e flores.
- **Tags** (`ItemData.tags`, como "flower", "wild", "romantic", "rare" e "decor") ligam receitas, clientes e vitrines sem depender de ids fixos.
- **Visual**: o `FloristView` reflete os sinais da simulação. Clientes (`CustomerNPC`, com cores variadas pelo shader de paleta) entram, vão à vitrine, esperam no balcão com "!" e saem. As `DisplayStand` mostram o estoque; as `DecorSpot` aparecem quando a decoração ou melhoria é comprada.

## Moradores, diálogos e missões (Fase 6)

- **Dados**:
  - `data/npcs/villagers.json`: perfis, cores, retrato, aniversário, gostos, pedidos possíveis e rotinas;
  - `data/dialogues/villagers.json`: falas;
  - `data/quests/quests.json`: missões;
  - `data/dialogues/diary.json`: páginas do diário.
  
  Conteúdo longo usa texto embutido nos dois idiomas, no formato `{"pt_BR": …, "en": …}`, lido por `Loc.text()`. Textos curtos de interface continuam no CSV.
- **Rotinas**: `Villagers.where(id, minutos, dia_semana, estação, chuva)` escolhe a primeira variante cujas condições batem (`weekdays`, `seasons`, `rain`) e devolve o último ponto já alcançado no horário, ou `{}` se o morador está em casa. O `NpcDirector`, criado em cada `GameplayScene`, posiciona os moradores do mapa e os faz caminhar ou sumir quando o relógio muda.
- **`Relationships`** guarda pontos (100 por coração), a última conversa e o último presente, os eventos vistos e os gostos descobertos.
- **`VillagerChat.compose()`** decide a conversa, nesta prioridade:
  1. apresentação;
  2. aniversário;
  3. evento de corações;
  4. entrega;
  5. oferta de missão;
  6. fala do dia, escolhida com semente por dia, por isso estável ao longo do dia.
  
  O `FarmController` executa o efeito (marcar evento, aceitar missão, entregar) e a `DialogueBox` exibe a conversa.
- **`QuestLog`**:
  - Os objetivos são de dois tipos. `event` avança por `notify(evento, alvo, quantidade)` (eventos: colher, montar buquê, descobrir, conhecer, reformar a loja, ler o diário, visitar). `deliver` se cumpre conversando com o morador e entregando os itens.
  - Ao concluir uma missão, o `QuestLog` emite `quest_completed`. O `GameState` aplica a recompensa (dinheiro, itens, amizade, com `"*"` valendo para todos) e o próximo passo da história começa sozinho.
- **Dados JSON**: números chegam como `float`; use `JsonUtil.has_int` para testar se um número está numa lista.

## Progressão, estufa e construções (Fase 7)

- **`GameState.record(evento, alvo, quantidade)`** é a única porta de entrada para os eventos de jogo. Ela avança missões (`QuestLog.notify`), estatísticas e XP (`Progression`) e verifica as conquistas. `stat_value()` junta os contadores com valores calculados na hora (estrelas da loja, corações, receitas conhecidas, mapas visitados…). Os níveis e conquistas ficam em `data/progression/progression.json`.
- **Solo por mapa**: `GameState.soil_for(mapa)` devolve o `farm_soil` ou o `greenhouse_soil`. A estufa usa `all_seasons = true`: as flores crescem em qualquer estação e as `GREENHOUSE_ONLY` podem ser plantadas. A `GameplayScene` e o `FarmController` usam sempre o solo do mapa atual.
- **Construções**:
  - `ItemData` ganhou `place_scene` ou `place_floor` (caminho ou laguinho), `footprint` (um `Rect2i` relativo à célula-alvo) e `place_where` (fora, dentro ou ambos).
  - O registro fica em `GameState.placed[mapa]["x,y"] = item`.
  - `Placement.validate()` é pura e testável. O `BuildView` instancia as cenas e registra cada célula ocupada no `WorldMap`, desenha caminhos (`BuiltFloor`) e laguinhos (`BuiltWater`, com colisão do TileSet) com bordas automáticas e mantém as cercas conectadas.
  - O `FarmController` mostra a prévia, coloca (`PLACE`) e recolhe com a picareta (`PICK_UP`).
- **Ferramentas melhores**: `ItemData.area` (células em linha) e `capacity`. A compra na oficina usa `replaces` para trocar a ferramenta antiga no mesmo espaço do inventário.
- **Lojas**: cada item do estoque pode ter `materials`, `min_level` e `replaces`. O nível também vem de `FlowerData.min_level`.

## Mapa da fazenda

```
Farm (farm.gd)
├─ FarmMap (WorldMap)            ← constrói tudo a partir de data/maps/farm.txt
│  ├─ Ground  (TileMapLayer)     grama, caminho, solo arado
│  ├─ Water   (TileMapLayer)     água + shader + colisão do TileSet
│  ├─ Entities (Node2D, y-sort)  objetos instanciados + Player
│  └─ Bounds  (StaticBody2D)     paredes invisíveis (criadas em código)
├─ PetalAmbience (CanvasLayer)   partículas de pétalas
├─ HUD ▸ LocationBanner
└─ PauseMenu
```

- **Layout em texto:** cada caractere é uma célula de 16×16. Os terrenos (`.` grama, `,` grama florida, `=` caminho, `~` água, `#` solo) e os objetos (`T`, `C`, `p`, `R`, `w`, `B`, `b`, `v`, `F`, `W`, `H`) estão definidos na legenda JSON. `P` é o ponto de surgimento.
- **Bordas automáticas:** caminho, água e solo usam uma máscara de 4 bits dos vizinhos (N=1, L=2, S=4, O=8), e a máscara é a coluna do tile no atlas. Assim, qualquer forma desenhada no texto recebe bordas corretas.
- **Terreno sob objetos:** uma célula com objeto herda o terreno mais comum entre os 4 vizinhos (nunca água; em empate, vence o terreno específico). Por isso uma pedra no campo fica sobre solo arado.
- **Âncoras:** todo objeto tem a origem no centro da base da célula, que é onde ficam os "pés". O y-sort compara essa posição, então a personagem passa corretamente atrás da casa e das árvores.
- **Cercas** recebem a máscara de vizinhos iguais (`configure_neighbors`) e escolhem sprite e colisão sozinhas.

### Camadas de física

| Bit | Nome | Usado por |
|---|---|---|
| 1 | world | água, objetos, bordas |
| 2 | player | personagem (máscara = world) |
| 3 | interactable | reservado (Fase 2) |

## Personagem

- `Player` (CharacterBody2D, `motion_mode` flutuante, típico de top-down) lê `Input.get_vector()` e delega para `MovementLogic.step_velocity()` (aceleração, atrito, normalização de diagonais).
- `MovementLogic.facing_from_direction()` converte 8 direções em 4 orientações de sprite. Na diagonal pura, mantém a orientação anterior para evitar que o sprite pisque.
- Sprite sheet 16×24 com 3 linhas (baixo, cima, direita; a esquerda é espelhada) e 4 colunas (parado, passo E, contato, passo D). `CharacterSpriteFrames` monta o `SpriteFrames` e será reutilizado pelos NPCs.
- As cores da roupa são trocadas pelo shader `palette_swap.gdshader`, então um único sheet atende todas as opções.

## Renderização

- Resolução base 640×360, esticada em modo `canvas_items` para 1280×720. A pixel art fica nítida (filtro nearest + snap) e o texto da interface é renderizado em alta resolução.
- Usa o renderizador **Compatibility**: leve, ideal para 2D e compatível com Apple Silicon (via Metal/ANGLE).
- Shaders: `water` (brilhos e ondulações só nos pixels azulados), `wind_sway` (balanço por instância, deslocamento arredondado para pixels inteiros) e `palette_swap`.
- Observação sobre o Godot 4: no `fragment()` de canvas_item, `COLOR` já chega com textura × modulate. Os shaders usam `COLOR` diretamente; amostrar `TEXTURE` de novo multiplicaria a cor duas vezes.

## Entradas e localização

- As ações são registradas em código (`InputBindings.register_defaults()`, chamado pelo `GameState`). Isso facilita revisar e testar, e prepara o menu de remapeamento. Ações já existentes nunca são sobrescritas.
- Os textos da interface usam chaves (`MENU_NEW_GAME`…) traduzidas automaticamente a partir de `strings.csv`. Para adicionar um idioma, basta criar uma coluna nova.

## Fazenda e agricultura (Fase 2)

- `SoilGrid` guarda o estado de cada célula arada: rega, adubo e a planta com estágio, crescimento, dias sem água e se murchou. Também simula a noite em `advance_day()`.
- `FlowerData` define cada espécie (um `.tres` por espécie). O `ItemRegistry` gera a partir dele os itens de semente e de flor colhida.
- `FarmActionResolver` contém as regras puras de "o que este item faz nesta célula". O `FarmController` executa a ação e dá o retorno visual e sonoro; o `SoilView` desenha.

## Tempo, clima e estações (Fase 3)

- `GameClock` avança só quando a cena de jogo chama `advance()`. A fazenda não chama enquanto há pausa, menus ou diálogos abertos.
- `Weather.for_day(seed, dia, estação)` é determinístico, então recarregar um save mantém o clima do dia. Chuva e tempestade chamam `SoilGrid.water_all()`.
- Na tela, `CanvasModulate` aplica a luz (`GameClock.light_color` × `Weather.light_factor`), `WeatherView` mostra partículas, neblina e relâmpagos, e `WorldMap.apply_season` aplica os tons de cada estação.

## Economia

- `Wallet` guarda as Pétalas (✿).
- `Shop` é carregada de `data/shops/*.json`. As sementes marcadas como sazonais só aparecem nas estações em que crescem.
- O preço de compra vem de `seed_price` e o de venda de `sell_price` (ambos em `FlowerData` ou `ItemData`). Um teste garante que todas as flores dão lucro, mas sem enriquecer rápido demais.

## Salvamento

- `SaveSystem` cuida do arquivo; `GameState.to_save_data()` e `apply_save_data()` cuidam do conteúdo.
- Formato (`user://saves/slot_N.json`): um envelope com `format`, `schema_version`, `game_version`, `saved_at`, `summary` (usado só na tela de carregar), `checksum` (SHA-256) e `payload`. O `payload` é o JSON do jogo guardado como texto, para o checksum cobrir exatamente os bytes gravados.
- A escrita vai primeiro para `.tmp` e depois é renomeada; o save anterior vira `.bak`. Se o arquivo principal estiver corrompido, o backup é carregado automaticamente.
- As migrações ficam em `SaveSystem.migrate()`, uma por versão (exemplo: v0 → v1 renomeia `gold` para `money`).
- `apply_save_data` valida e corrige cada parte. Itens desconhecidos são descartados, datas e dinheiro são limitados a valores válidos, e um perfil inválido torna o save inutilizável, com mensagem ao jogador.
- As configurações ficam à parte, em `user://settings.cfg` (`GameSettings`).

## Áudio

- `AudioManager` (autoload) toca efeitos no barramento SFX e adiciona sozinho o som de clique a todos os botões.
- Os sons de ambiente (chuva e vento) tocam em loop no barramento Ambient, controlados pelo `WeatherView`.
- Todo o áudio é sintetizado por `tools/generate_audio.gd`, sem material de terceiros. Em modo headless (testes) nada é tocado.

## Ferramentas e testes

- `tools/generate_assets.gd`: gera toda a pixel art (determinística, com seed fixa).
- `tools/build_tileset.gd`: gera `resources/tilesets/terrain_tileset.tres` (colisão na linha da água).
- `tests/run_tests.gd`: executor próprio. Roda `tests/unit` e `tests/integration` e termina com código ≠ 0 se algo falhar. Foi preferido a GUT/GdUnit4 nesta fase para não depender de add-on externo; os testes seguem o padrão `test_*` e migram facilmente se quisermos trocar.
- `DebugCapture`: `-- --capture=arquivo.png` salva um screenshot e fecha o jogo. Serve para gerar as imagens do README e para checagem visual.

## Decisões técnicas

| Decisão | Motivo |
|---|---|
| Mapa em texto, construído em tempo de execução | Versionável e fácil de comparar no git, com bordas automáticas. O editor de TileMap continua disponível para mapas futuros, se preferirmos. |
| Arte procedural nesta fase | Arte original e coerente desde o início, sem placeholders de terceiros. Os PNGs podem ser refinados no Aseprite mantendo os layouts. |
| Compatibility renderer | O projeto é 2D puro; menor custo e maior compatibilidade. |
| Executor de testes próprio | Zero dependências; roda em CI apenas com o binário do Godot. |

## Fase 8: polimento

- **Áudio**: `AudioManager.play_music(faixa, volume_db)` com dois players no bus *Music* e crossfade; `play_ambience("birds"|"water"|"")`. `GameplayScene._update_audio()` escolhe a faixa pela estação; `ambience_track()` decide o ambiente por mapa, hora e clima. O `Player` emite `stepped` nos quadros em que o pé toca o chão, e `GameplayScene.step_sound()` escolhe o som pelo terreno.
- **Luzes**: `NightLight` (PointLight2D com textura radial compartilhada) entra no grupo `night_lights`; `GameplayScene._update_light()` define o nível com `NightLight.level_for(minutos)`.
- **Estações**: `SeasonVisuals.set_shader_season()` publica o uniforme global `season` (declarado em `project.godot`). `shaders/wind_sway.gdshader` recolore a folhagem (o parâmetro `seasonal = false` em `crop_sway.tres` preserva as plantações) e `shaders/season_ground.gdshader` desenha folhas e neve no chão.
- **Animações**: `UiKit.pop_in()` (fade-in dos painéis, funciona com o jogo pausado), `Player.squash()` e poeira de corrida via `FarmEffects.burst`.
- **Desempenho**: `Progression.xp_changed` substitui o polling do HUD; `GameplayScene.protected_cells()` é calculado uma vez por mapa; `test_polish.gd` mede o tempo de carga e o tempo médio de quadro.
