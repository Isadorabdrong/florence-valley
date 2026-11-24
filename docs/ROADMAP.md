# Roadmap

Legenda: ✅ concluído e testado · 🟡 parcial · ⬜ pendente

## Fase 1: Fundação ✅

| Item | Estado | Onde |
|---|---|---|
| Projeto Godot, resolução, pixel-perfect | ✅ | `project.godot` |
| Estrutura de diretórios | ✅ | — |
| Personagem + movimento em 8 direções + corrida | ✅ | `scripts/player/` |
| Animações em 4 orientações | ✅ | `CharacterSpriteFrames` |
| Câmera com suavização e limites | ✅ | `player.tscn`, `Player.set_camera_limits` |
| Cenário inicial (fazenda) | ✅ | `data/maps/farm.txt`, `WorldMap` |
| Colisões (objetos, água, bordas) | ✅ | testes de integração |
| Menu principal, criação de personagem, pausa | ✅ | `scenes/main/`, `scenes/ui/` |
| Localização pt-BR/en | ✅ | `data/localization/strings.csv` |

## Fase 2: Agricultura ✅
Concluída (v0.2.0). Inventário básico, calendário e dormir foram antecipados por serem necessários ao ciclo de cultivo.

<details><summary>Escopo original</summary>

Ferramentas (enxada, regador, foice) · barra de ferramentas · interação por célula à frente da personagem · limpar pedras e ervas · arar · sementes como Resource (`FlowerData.tres`) · plantio · rega · crescimento em 6 estágios · colheita · 6 flores iniciais (rosa, tulipa, margarida, girassol, lavanda, lírio).
</details>

## Fase 3: Sistemas principais ✅
Concluída (v0.3.0).

| Item | Estado | Onde |
|---|---|---|
| Inventário: arrastar e soltar, dividir, descartar, baú | ✅ | `Inventory`, `SlotGridView`, `TrashSlot` |
| Moeda e economia | ✅ | `Wallet`, preços em `resources/` |
| Loja de compra e venda | ✅ | `Shop`, `data/shops/` |
| Relógio do dia | ✅ | `GameClock` |
| Estações | ✅ | Calendário, tons e shaders sazonais (neve, folhas de outono) |
| Clima | ✅ | `Weather`, `WeatherView` |
| Salvamento versionado com 3 espaços, autosave, validação e backup | ✅ | `SaveSystem`, `GameState.to_save_data()` |
| Continuar e Carregar | ✅ | `main_menu`, `LoadPanel` |
| Configurações | ✅ | Música, efeitos, ambiente, tela cheia e idioma |

Itens da lista de salvamento que ainda não existem no jogo (construções, decorações, missões, relacionamentos, floricultura) entram no arquivo junto com suas fases. O formato já tem migrações para isso.

## Fase 4: Mundo ✅
Concluída (v0.4.0).

| Item | Estado | Onde |
|---|---|---|
| Vilarejo (praça, mercado, cafeteria, biblioteca, oficina, casas, centro comunitário, espaço de festivais, floricultura) | ✅ | `data/maps/village.txt` |
| Interiores | 🟡 | Casa, Mercado, Cafeteria, Biblioteca e Centro Comunitário. A oficina, as casas dos moradores e a floricultura ficam fechadas (com texto explicando) até ganharem conteúdo nas Fases 5 a 7 |
| Transições entre mapas | ✅ | `WorldGraph`, saídas e portas em `world.json` |
| 5 regiões com recursos e descobertas | ✅ | coleta, marcos e ambientes próprios |
| Mapa do vale | ✅ | `MapPanel` (M) |

Pendente nas próximas fases: moradores (Fase 6), a floricultura do jogador (Fase 5), estufa e construções (Fase 7).

## Fase 5: Floricultura ✅
Concluída (v0.5.0).

| Item | Estado | Onde |
|---|---|---|
| Colocar flores à venda, definir preços, administrar estoque | ✅ | `FloristShop`, aba Vitrines |
| Criar buquês combinando espécies (5 tipos, sprites e valores) | ✅ | `BouquetBook`, `data/recipes/bouquets.json`, mesa de arranjos |
| Receber encomendas | ✅ | quadro de encomendas |
| Atender clientes | ✅ | clientes visíveis e atendimento no balcão |
| Melhorar a loja e desbloquear decorações | ✅ | `data/florist/florist.json` |
| Reputação comercial | ✅ | estrelas, clientes, encomendas e decorações |

Os clientes ainda são visitantes genéricos. Na Fase 6, os moradores do vilarejo (com nome e rotina) passam a frequentar a loja.

## Fase 6: Personagens e história ✅
Concluída (v0.6.0).

| Item | Estado | Onde |
|---|---|---|
| NPCs com nome, aparência, personalidade, história, preferências | ✅ | `data/npcs/villagers.json` |
| Rotinas por horário, dia da semana, estação e chuva | ✅ | `Villagers.where`, `NpcDirector` |
| Diálogos e conversas | ✅ | `data/dialogues/villagers.json`, `VillagerChat`, `DialogueBox` |
| Amizade, presentes, aniversários, evolução dos relacionamentos | ✅ | `Relationships` |
| Eventos especiais | ✅ | evento de 4 corações para cada morador |
| Missões pessoais, principais e pedidos diários | ✅ | `QuestLog`, `data/quests/quests.json` |
| A história da avó | ✅ | 9 páginas do diário, destravadas pelas missões principais |

Limites atuais:
- Os moradores andam em linha reta entre os pontos da rotina, sem desviar de obstáculos.
- As casas deles continuam fechadas.
- A missão "A praça do vilarejo" é concluída, mas ainda não muda a aparência da praça (fica para as Fases 7 e 8, com construções e festivais).

## Fase 7: Personalização e progressão ✅
Concluída (v0.7.0).

| Item | Estado | Onde |
|---|---|---|
| Construções e decorações com grade, validação, remoção e reposicionamento | ✅ | `Placement`, `BuildView`, `resources/build/` |
| Cercas, caminhos, canteiros, estufa, lagos, fontes, bancos, luminárias, vasos, móveis, árvores ornamentais | ✅ | 12 construções + a estufa |
| XP, níveis de jardinagem, desbloqueio de sementes | ✅ | `Progression` |
| Novas ferramentas | ✅ | regador de cobre e enxada de aço |
| Novas flores (especiais e raras) e novas receitas | ✅ | 11 flores, 6 receitas |
| Conquistas | ✅ | 17 conquistas |
| Melhorias da propriedade | ✅ | estufa reformada |

Limites atuais:
- O interior da estufa usa as mesmas paredes da casa, e não vidro (fica para o polimento).
- A missão "A praça do vilarejo" ainda não muda a aparência da praça.
- Só é possível construir na fazenda (e mobiliar a casa e a estufa).

## Fase 8: Polimento ✅
| Item | Status | Observação |
|---|---|---|
| Trilha sonora | ✅ | 5 faixas originais (uma por estação + tema do título), sintetizadas por `tools/generate_music.gd`, com crossfade e volume menor em interiores |
| Efeitos sonoros | ✅ | passos por tipo de chão (grama, pedra, madeira); ambiente de pássaros e de água |
| Iluminação | ✅ | luzes noturnas (`NightLight`) em lampiões, casas, lojas e estufa, acesas do anoitecer ao amanhecer |
| Estações | ✅ | shaders sazonais: folhas cor de âmbar no outono, neve no chão e nas copas no inverno |
| Animações | ✅ | fade-in dos painéis, "squash" ao usar ferramentas, poeira ao correr |
| Configurações | ✅ | slider de música |
| Otimização | ✅ | barra de XP por sinal (sem polling), células protegidas em cache, teste de orçamento de carga/quadro |
| Fonte pixel | ⬜ | ficou de fora; a interface usa a fonte padrão do Godot |

Limites atuais:
- A música não foi ouvida por uma pessoa durante o desenvolvimento; foi validada por análise (pico, volume, emenda do loop).
- Não houve teste de jogo com teclado de verdade nesta fase; os testes automatizados cobrem a lógica.

## Fase 9: Entrega ✅
| Item | Status | Observação |
|---|---|---|
| Paleta final | ✅ | verde natural com rosado e dourado (`tools/palette_grade.gd`), luz do dia dourada |
| Executáveis | ✅ | `export_presets.cfg` + `tools/export_builds.sh`: macOS universal (.app em .zip) e Windows x86_64 (.exe com dados embutidos) |
| Vídeo | ✅ | `docs/video/trailer.mp4` (27 s, gravado com o Movie Maker do Godot a partir de um passeio automático, `DemoTour`) e GIF no README |
| Capturas | ✅ | todas refeitas com `tools/capture_screenshots.sh` |
| Repositório | ✅ | repositório git local com commit inicial; a publicação no GitHub é feita pela dona do projeto (passo a passo no README) |

Limites atuais:
- O app de macOS foi aberto e testado nesta máquina; o .exe de Windows foi gerado, mas não foi executado (não há Windows aqui).
- Os executáveis não são assinados (Apple/Microsoft), por isso os sistemas mostram um aviso na primeira abertura.
- A fonte pixel e a arte refinada à mão ficam como melhorias futuras.

## Limitações conhecidas da Fase 1
- A interface usa a fonte padrão do Godot. Uma fonte pixel com licença livre entra na Fase 8.
- A arte é procedural. Está pronta para refinamento manual no Aseprite mantendo os mesmos layouts.
