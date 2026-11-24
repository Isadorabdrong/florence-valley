# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/);
versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [1.0.0] — 2026-11-24 · Fase 9: Entrega

### Adicionado
- Executáveis: presets de exportação para macOS (universal) e Windows (x86_64) e `tools/export_builds.sh`.
- Vídeo de apresentação (`docs/video/trailer.mp4`) e GIF no README, gravados com o Movie Maker do Godot usando o passeio automático `DemoTour` (`--tour=farm|dusk|winter`, `--tour-timelapse`).
- `tools/capture_screenshots.sh` refaz todas as capturas do README.

### Alterado
- A versão do menu não mostra mais a fase.
- Paleta: verdes mais naturais, rosas mais quentes e dourados (ajuste aplicado na geração dos sprites por `tools/palette_grade.gd`) e luz do dia levemente dourada, mais forte à tarde.

## [0.8.0] — 2026-11-23 · Fase 8: Polimento

### Adicionado
- **Trilha sonora original**: uma faixa por estação e o tema do menu, compostas e sintetizadas por `tools/generate_music.gd` (loops sem emenda). Troca com crossfade; mais baixa dentro de casa.
- **Passos** com som conforme o chão (grama, pedra/caminhos construídos, madeira) e **ambiente**: pássaros em dias calmos de primavera e verão, água no Lago Cristalino.
- **Slider de música** nas configurações.
- **Luzes noturnas** (`NightLight`): lampiões, janelas das casas e lojas e a estufa acendem ao anoitecer e apagam ao amanhecer.
- **Shaders sazonais** com o uniforme global `season`: árvores e arbustos ficam âmbar no outono e ganham neve no inverno; o chão recebe folhas caídas ou manchas de neve (o solo arado não). As plantações mantêm suas cores.
- **Animações**: fade-in dos painéis, "squash" da personagem ao usar ferramentas e poeira ao correr.
- Opção `--demo-season=<0-3>` para capturas de tela.
- 12 testes novos (`tests/integration/test_polish.gd`); total de 248.

### Alterado
- A barra de XP do HUD atualiza por sinal (`Progression.xp_changed`) em vez de consultar a cada quadro.
- As células protegidas do mapa (saídas e chegadas) ficam em cache.
- `tools/build_assets.sh` também regenera efeitos sonoros e música.

## [0.7.0] — 2026-11-23 · Fase 7: Personalização e progressão

### Adicionado
- **Progressão** (`Progression`, `data/progression/progression.json`):
  - XP de jardinagem por colher (proporcional ao tempo de cultivo), coletar, montar buquês, vender, entregar encomendas, construir, descobrir e concluir missões.
  - **Níveis de 1 a 10**, com recompensas: adubo, sementes especiais e sementes raras.
  - Os níveis também liberam sementes nas lojas e itens na oficina.
  - Estatísticas e **17 conquistas** com recompensas.
  - Tudo passa por `GameState.record(evento)`.
- **11 flores novas**, com sprites para todos os estágios, ícones e textos:
  - 6 especiais: orquídea, peônia, flor de cerejeira, dália, íris e lótus;
  - 5 raras: rosa-dourada, Flor da Lua, Lírio Celestial, Orquídea Azul e Flor Estelar.
  
  Há uma condição nova: "só na estufa". As sementes raras nunca são vendidas; vêm dos níveis e de missões.
- **6 receitas novas** de buquê, incluindo a "Coroa Dourada" (2.100 ✿) e o "Arranjo Celestial".
- **A estufa da vovó**: está em ruínas ao lado do poço. Para reformá-la são 1.500 ✿, 30 pedras, 20 fibras e 3 ametistas. Dentro, os canteiros cultivam qualquer flor em qualquer estação, e é o único lugar onde crescem orquídeas, o Lírio Celestial e a Orquídea Azul. O solo é separado por mapa (`GameState.soil_for`). A reforma vem com a missão principal "Recuperar a antiga estufa" e a página 10 do diário.
- **Modo de construção**:
  - Com um item de construção na mão, uma prévia verde ou vermelha mostra onde ele cabe.
  - A validação considera o mapa, o tipo de chão, objetos, canteiros arados, o jogador, as saídas e os pontos de chegada.
  - Objetos podem ocupar mais de uma célula.
  - A picareta recolhe a construção, o que permite reposicioná-la.
- **12 construções**: cerca (conecta-se às da fazenda), caminho de pedra, canteiro elevado, banco, luminária, vaso, mudas de cerejeira e de carvalho, fonte (3×2), laguinho (2×2, com colisão; conta como água para flores que amam água), mesa e estante (para dentro de casa ou da estufa).
- **Oficina do Bento** aberta no vilarejo: vende construções e ferramentas melhores em troca de ✿ e materiais, conforme o nível.
- **Ferramentas novas**: regador de cobre (40 cargas, rega 3 canteiros em linha) e enxada de aço (ara 3 de uma vez). Ficam no espaço da ferramenta antiga.
- **Interface**: nível e barra de XP no HUD, aba "Conquistas" no diário e avisos de subida de nível e de conquista.
- **Salvamento**: esquema v5, com migração a partir do v4.
- 26 testes novos (236 no total).

## [0.6.0] — 2026-11-23 · Fase 6: Personagens e história

### Adicionado
- **6 moradores originais** (`data/npcs/villagers.json`): Celeste, Lívia, Tomás, Benício, Aurora e Bento. Cada um tem retrato, aparência própria (pele, cabelo e roupa via shader de paleta), personalidade, história, aniversário, gostos e **rotina diária** que varia com o horário, o dia da semana, a estação e a chuva. Eles caminham entre os pontos da rotina e somem quando vão para casa.
- **Conversas** (`data/dialogues/villagers.json`, em português e inglês): apresentação, falas que mudam com a amizade, a estação e a chuva, aniversários, eventos especiais aos 4 corações e escolhas (aceitar missão, entregar itens).
- **Amizade** (`Relationships`): até 10 corações. Conversar dá pontos uma vez por dia. Presentes valem um por dia, com reações ama/gosta/neutro/não gosta; no aniversário o efeito triplica. O diário registra os gostos já descobertos.
- **Missões** (`QuestLog`, `data/quests/quests.json`):
  - 9 missões principais: ler o diário, colher as primeiras flores, conhecer os vizinhos, cultivar dez rosas, reformar a floricultura, montar o primeiro buquê, levar flores para Celeste, encontrar a flor rara e recuperar a praça.
  - 6 missões pessoais, que cada morador oferece aos 2 corações.
  - Pedidos diários dos moradores.
- **O diário da vovó Amélia**: 9 páginas que você destrava ao concluir as missões da história. Comece pela estante da Casa da Vovó.
- **Diário do jogador** (tecla L): missões ativas e concluídas, pedidos, páginas do diário e moradores (corações, aniversário, história e gostos).
- **Caixa de diálogo** com retrato, corações, texto que aparece letra por letra, várias páginas e escolhas. Um "!" sobre o morador indica que ele tem algo a dizer.
- Encomendas da floricultura feitas por moradores também aumentam a amizade.
- **Salvamento**: esquema v4, com migração a partir do v3.
- 34 testes novos (210 no total).

### Corrigido
- Números lidos de JSON chegam como `float`, então `[6].has(6)` falhava. Por isso as rotinas por dia da semana e estação nunca eram aplicadas, e as encomendas sazonais da floricultura nunca apareciam. A comparação agora é feita por `JsonUtil.has_int`, com teste de regressão.

## [0.5.0] — 2026-11-23 · Fase 5: Floricultura

### Adicionado
- **Reforma da floricultura da vovó** no vilarejo: custa 800 ✿, 10 pedras e 10 fibras. O prédio troca a aparência de ruína pela de loja reformada.
- **Interior da loja** com vitrines (que mostram os itens à venda), mesa de arranjos, quadro de encomendas, balcão e espaços para decorações.
- **Buquês**:
  - 9 receitas em `data/recipes/bouquets.json`, cobrindo os 5 tipos: simples, romântico, sofisticado, sazonal e raro.
  - Cada buquê usa 3 itens, combinando flores cultivadas e coletadas. As receitas são descobertas ao montar e ficam registradas no livro de receitas.
  - Cada buquê tem ícone e valor próprios, sempre maior que o das flores usadas.
- **Vendas** (`FloristShop`):
  - Vitrines com preços definidos pelo jogador (50%–300% do valor de mercado).
  - Clientes de 4 perfis (casual, romântico, decorador, colecionador), com preferências e tolerância a preço próprias.
  - A loja funciona das 09:00 às 17:00, com movimento que varia com o clima e o fim de semana.
- **Atender clientes**: com você dentro da loja, os clientes entram, olham as vitrines e esperam no balcão. Atender pessoalmente rende gorjeta de 10% e mais reputação; quem espera 30 minutos paga no caixa e vai embora.
- **Encomendas**: pedidos diários de moradores, com prazo, recompensa e um bilhete. Se vencerem, a reputação cai.
- **Reputação** de 0 a 5 estrelas, que libera clientes exigentes, encomendas melhores e decorações.
- **Melhorias**: 2ª e 3ª vitrines, letreiro, difusor de lavanda e mesa profissional.
- **4 decorações**: vaso, guirlanda, lustre de ametista e fonte de mesa. Custam ✿ e itens coletados nas regiões, e aparecem na loja.
- **Painel de administração** com abas Vitrines, Encomendas, Melhorias e Relatório, e resumo das vendas no banner da manhã.
- **Arte nova**: 9 ícones de buquê, a loja reformada, móveis e decorações, 2 modelos de cliente com roupas e cabelos variados (o shader de troca de paleta agora também recolore o cabelo) e o balão de espera.
- **Salvamento**: esquema v3, com migração automática a partir do v2.
- 25 testes novos (176 no total).

## [0.4.0] — 2026-11-23 · Fase 4: Mundo

### Adicionado
- **Registro do mundo** (`data/maps/world.json`, `WorldGraph`): mapas, pontos de chegada nomeados, saídas pelas bordas, interações por célula (portas, placas, lojas, marcos) e tabelas de coleta. Uma validação garante que tudo é consistente e alcançável a partir da fazenda.
- **Cena única para todos os mapas** (`GameplayScene`, `map_scene.tscn`): a fazenda, as regiões e os interiores usam o mesmo código. Interiores pequenos ficam centralizados na tela, com luz interna própria e sem clima.
- **Vilarejo de Florence**: praça com fonte, bancos e postes; Mercado, Cafeteria, Biblioteca, Centro Comunitário, Oficina, a antiga floricultura da vovó (em reforma), casas de moradores e palco de festivais.
- **5 interiores**: Casa da Vovó (cama para dormir, baú, estante com o diário), Mercado (balcão com loja), Cafeteria, Biblioteca (4 livros com a história do vale) e Centro Comunitário (avisos, fotos e troféus).
- **5 regiões**, cada uma com coleta própria, um marco para descobrir e ambiente próprio: Floresta das Cerejeiras, Bosque das Flores Raras (vaga-lumes à noite), Lago das Águas Claras (praia e píer), Montanhas de Lavanda (penhascos, rampas e rochas de ametista) e Jardim das Borboletas (borboletas animadas).
- **Coleta**: 12 itens silvestres com tabelas por região e estação. Cada ponto é sorteado por dia (determinístico) e só pode ser coletado uma vez por dia.
- **Mapa do vale** (tecla M), com lugares visitados, descobertas e a sua posição atual.
- **Novos terrenos**: calçamento, areia, penhasco, chão de floresta, campo de lavanda, prado, chão de bosque, piso de madeira, tapete, paredes e capacho.
- **Arte nova**: 8 prédios, adereços da praça, móveis e ícones de coleta.
- **Dormir**: agora é na cama da casa. Quem desmaia fora de casa acorda em casa.
- **Salvamento**: guarda o mapa atual, as descobertas, os lugares visitados e as coletas do dia. Esquema v2, com migração automática de saves v1.
- 23 testes novos (151 no total). Um deles carrega todos os 12 mapas.

## [0.3.0] — 2026-11-23 · Fase 3: Sistemas principais

### Adicionado
- **Relógio** (`GameClock`): o dia vai das 06:00 às 02:00, com 10 minutos de jogo a cada 7 s reais. O tempo para em menus. À meia-noite aparece um aviso; às 02:00 a personagem desmaia e acorda no dia seguinte.
- **Luz do dia e da noite** com `CanvasModulate`: amanhecer, entardecer quente e noite azulada, escurecidos também pelo clima.
- **Clima diário determinístico** (`Weather`): sol, chuva, tempestade (com relâmpagos), neblina, neve e ventania, com probabilidades por estação. Chuva e tempestade regam as plantações.
- **Estações:** tons sazonais no chão e na vegetação; pétalas de cerejeira só aparecem na primavera.
- **Economia:** moeda Pétalas (✿), 500 ✿ no início e `Wallet`.
- **Loja** (`Shop`, `data/shops/flora_cart.json`): o Carrinho de Flores da Dona Celeste vende sementes da estação e adubo, e compra flores, sementes e materiais.
- **Inventário:**
  - Arrastar e soltar entre espaços e entre inventários.
  - Dividir pilhas com o clique direito.
  - Lixeira com desfazer (ferramentas não podem ser descartadas).
  - Baú com 24 espaços ao lado da casa.
- **Salvamento:**
  - 3 espaços, salvar manualmente pelo menu de pausa e salvamento automático ao dormir.
  - Envelope com versão de esquema, checksum SHA-256, escrita atômica e cópia `.bak` com recuperação automática.
  - Migrações de versões antigas, validação e correção de dados inválidos.
- **Menus:** Continuar e Carregar jogo (com resumo de cada espaço e opção de apagar); Configurações (volume de efeitos e de ambiente, tela cheia, idioma).
- **Áudio original sintetizado** (`tools/generate_audio.gd`): 13 efeitos e loops de chuva e vento; barramentos SFX, Ambient e Music.
- HUD com hora, ícone do clima e dinheiro.
- 40 testes novos (127 no total).

## [0.2.0] — 2026-11-23 · Fase 2: Agricultura

### Adicionado
- 6 flores como Resources (`resources/flowers/*.tres`): margarida, tulipa, rosa, girassol, lavanda, lírio — com estação, tempo de crescimento, necessidade de água, preço, raridade, reflorescimento, condição especial e chance de gerar semente.
- Crescimento em 6 estágios (semente → pronta para colher) + estado murcho, com sprites próprios por espécie.
- `SoilGrid`: arar, regar (seca à noite), adubar (+25% e colheita dobrada), plantar, crescimento por dia, seca, fora de estação, colheita, reflorescimento, `to_dict`/`load_dict`.
- Ferramentas: enxada, regador (20 cargas, encher no poço/lago), foice, picareta; pedras (2 golpes) e ervas daninhas removíveis, com remoção persistente.
- `Calendar` (dia/estação/ano/dia da semana); dormir na casa avança o dia.
- `Inventory` (36 espaços, pilhas) + `ItemRegistry`; hotbar de 12 espaços, janela de inventário (clique para mover/trocar), data no HUD, mensagens e diálogo de confirmação.
- Cursor de alvo, mira com o mouse, partículas e animação de ferramenta.
- 46 novos testes (87 no total).

## [0.1.0] — 2026-11-23 · Fase 1: Fundação

### Adicionado
- Projeto Godot 4.7 (renderizador Compatibility), resolução base 640×360 com escala para 1280×720, filtro *nearest* e *pixel snap*.
- Estrutura modular de diretórios (assets, scenes, scripts, resources, data, shaders, tests, docs, tools).
- Autoloads `GameState` (perfil da sessão) e `SceneManager` (troca de cenas com transição em fade).
- Mapeamento de entradas em código (`InputBindings`): WASD/setas, Shift, E/Espaço, Esc + controle.
- Personagem jogável: movimento em 8 direções com aceleração/atrito, corrida, animações de andar/parado em 4 orientações, sombra.
- Câmera seguindo a personagem com suavização e limites do mapa.
- Mapa da fazenda gerado a partir de `data/maps/farm.txt` + legenda JSON: TileMapLayers (grama, caminho, água, solo arado) com bordas automáticas por máscara de vizinhos.
- Objetos com y-sort e colisão: casa, poço, cercas conectáveis, carvalhos, cerejeiras, pinheiros, arbustos floridos, pedras, ervas daninhas.
- Colisões: água (TileSet), objetos, paredes invisíveis nas bordas do mapa.
- Shaders: água animada, vento na vegetação, troca de paleta da roupa.
- Partículas de pétalas de cerejeira.
- Menu principal (Novo Jogo, Créditos, Sair) com cenário vivo ao fundo.
- Criação de personagem (nome, nome da fazenda, cor da jardineira) com prévia animada e validação.
- Faixa de localização ao entrar na fazenda e dica de controles.
- Menu de pausa (Continuar, Menu principal, Sair).
- Localização pt-BR/en via CSV.
- Pixel art original gerada proceduralmente por `tools/generate_assets.gd`.
- Executor de testes próprio + 41 testes (unidade e integração).
