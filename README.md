# 🌸 Florence Valley

*Plante sonhos, cultive felicidade.*

Florence Valley é um simulador cozy de fazenda, jardinagem e vida no campo, em pixel art 2D top-down, feito com **Godot 4** e **GDScript**. Você herda a antiga propriedade da sua avó, uma cultivadora de flores famosa no vale, e precisa recuperá-la.

> **Versão 1.0.0.** As 9 fases do [roadmap](docs/ROADMAP.md) foram concluídas: cultivo de 17 flores, floricultura, 6 moradores com história, 14 mapas, construções, progressão, música original, estações e executáveis para macOS e Windows.

![Florence Valley em movimento](docs/video/trailer.gif)

🎬 [Vídeo de apresentação (MP4, 27 s)](docs/video/trailer.mp4)

| Construções | Estufa | Conquistas |
|---|---|---|
| ![Construções](docs/screenshots/builds.png) | ![Estufa](docs/screenshots/greenhouse.png) | ![Conquistas](docs/screenshots/achievements.png) |

| Moradores | Conversa | Diário do jogador |
|---|---|---|
| ![Moradores](docs/screenshots/villagers.png) | ![Conversa](docs/screenshots/dialogue.png) | ![Diário](docs/screenshots/journal.png) |

| Floricultura | Administração da loja | Mesa de arranjos |
|---|---|---|
| ![Floricultura](docs/screenshots/florist_shop.png) | ![Painel](docs/screenshots/florist_panel.png) | ![Mesa](docs/screenshots/workbench.png) |

| Vilarejo | Floresta das Cerejeiras | Casa da Vovó |
|---|---|---|
| ![Vilarejo](docs/screenshots/map_village.png) | ![Floresta](docs/screenshots/map_cherry_forest.png) | ![Casa](docs/screenshots/map_house.png) |

| Bosque à noite | Montanhas de Lavanda | Mapa do vale |
|---|---|---|
| ![Bosque](docs/screenshots/map_rare_grove.png) | ![Montanhas](docs/screenshots/map_lavender_mountains.png) | ![Mapa](docs/screenshots/world_map.png) |

| Fim de tarde com chuva | Loja | Baú e inventário |
|---|---|---|
| ![Chuva](docs/screenshots/evening_rain.png) | ![Loja](docs/screenshots/shop.png) | ![Baú](docs/screenshots/chest.png) |

| Menu principal | Criação de personagem | Fazenda |
|---|---|---|
| ![Menu](docs/screenshots/main_menu.png) | ![Criação](docs/screenshots/character_creation.png) | ![Fazenda](docs/screenshots/farm.png) |

## Baixar e jogar

Gere os executáveis com o comando abaixo (os arquivos ficam em `builds/`) ou baixe-os na página de *Releases* do repositório, quando publicados.

```bash
tools/export_builds.sh /Applications/Godot.app/Contents/MacOS/Godot
```

- **macOS** (Apple Silicon e Intel): descompacte `FlorenceValley.zip` e abra `Florence Valley.app`. O app não é assinado pela Apple, então na primeira vez clique com o botão direito → **Abrir** (ou permita em Ajustes do Sistema → Privacidade e Segurança).
- **Windows** (64 bits): execute `FlorenceValley.exe`. O Windows SmartScreen pode avisar que o arquivo não é assinado; clique em **Mais informações → Executar assim mesmo**.

O progresso fica salvo na pasta de dados do usuário do Godot (`user://saves`).

## Como executar pelo código

1. Instale o **Godot 4.7** (versão padrão, não a .NET). No macOS: `brew install --cask godot`, ou baixe em [godotengine.org](https://godotengine.org/download).
2. Abra o Godot, clique em **Importar** e selecione `project.godot`.
3. Pressione **F5** para jogar.

Pelo terminal (macOS):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

### Controles

| Ação | Teclado | Controle |
|---|---|---|
| Andar (8 direções) | WASD / setas | Analógico esquerdo / D-pad |
| Correr | Shift (segurar) | B |
| Usar item selecionado | Espaço / J / clique esquerdo | X |
| Interagir (colher, dormir, encher regador) | E / clique direito | A |
| Selecionar item | 1–9, 0, -, = / roda do mouse | LB / RB |
| Inventário | Tab / I | Y |
| Mapa do vale | M | Back/Select |
| Diário (missões, diário da vovó, moradores) | L | — |
| Pausa | Esc | Start |
| Navegar menus | Setas + Enter, ou mouse | D-pad + A |

## Como cultivar

1. Limpe o terreno: **foice** nas ervas daninhas, **picareta** nas pedras (2 golpes).
2. Are a terra com a **enxada**.
3. Selecione um pacote de **sementes** e plante.
4. **Regue** todos os dias. O regador tem 20 cargas; encha no poço ou no lago.
5. Opcional: use **adubo** (+25% de velocidade e colheita dobrada). A rosa só floresce com adubo; o lírio cresce mais rápido perto da água.
6. Entre em casa (**E** na porta) e durma na cama para passar o dia.
7. Quando a flor desabrochar, colha com **E** ou com a foice. Às vezes a colheita também dá uma semente.
8. Venda as flores no **Carrinho de Flores** (no fim do caminho, a leste da casa) e compre mais sementes e adubo.

## Construir e evoluir

- **Nível de jardinagem** (no canto da tela): colher, coletar, montar buquês, vender, construir e concluir missões dão XP. Cada nível libera sementes nas lojas, itens na oficina e recompensas, como as sementes raras dos níveis 5 a 10.
- **Oficina do Bento** (no vilarejo, ao sul da praça): compre construções em troca de ✿ e materiais (pedra, fibra, argila, conchas…). A partir do nível 3, há também o **regador de cobre**, e a partir do 4, a **enxada de aço**; as duas trabalham 3 canteiros de uma vez.
- **Construir**: selecione a construção na barra e mire. A prévia **verde** indica que cabe e a **vermelha**, que não. Use **Espaço** para construir; para recolher (e mudar de lugar), use a **picareta**. Caminhos, cercas, bancos, luminárias, árvores, fonte e laguinho ficam na fazenda; mesa, estante e vaso também podem ir para dentro de casa ou da estufa.
- **A estufa** (ao lado do poço): reforme-a com 1.500 ✿, 30 pedras, 20 fibras e 3 ametistas. Lá dentro, qualquer flor cresce em qualquer estação, inclusive orquídeas e as raras que só crescem na estufa.
- **Conquistas**: veja-as no diário (**L**), na aba "Conquistas".

## Os moradores e a história

- **Comece pela estante** da Casa da Vovó: o diário dela abre a história. As páginas seguintes aparecem conforme você completa as missões principais (veja no diário, tecla **L**).
- **Moradores**: Celeste (Mercado), Lívia (Cafeteria), Tomás (Biblioteca), Benício (lago), Aurora (pintora, no Jardim das Borboletas) e Bento (marceneiro). Cada um tem rotina própria e muda de lugar conforme o horário, o dia, a estação e a chuva.
- **Conversar** (**E**) dá amizade uma vez por dia. Um **"!"** indica que o morador tem algo especial: primeira conversa, aniversário, evento, missão ou entrega.
- **Presentes**: selecione um item e use (**Espaço**) no morador. Vale um por dia, e no aniversário vale o triplo. O diário registra o que cada um ama ou detesta.
- **Missões pessoais**: aos 2 corações, cada morador pede um favor. Aos 4 corações acontece um momento especial com uma lembrança da vovó.

## A floricultura

1. No vilarejo, a antiga floricultura da vovó fica ao norte da praça. Para reformá-la (**E** na porta) você precisa de **800 ✿, 10 pedras e 10 fibras**. Pedras vêm das rochas (picareta) e fibras das ervas daninhas (foice).
2. **Mesa de arranjos**: combine 3 flores ou enfeites para montar buquês. Experimente combinações para descobrir as 9 receitas: rosas fazem buquês românticos, lírio com lavanda e rosa vira um arranjo sofisticado, e as flores coletadas formam arranjos silvestres e raros.
3. **Vitrines** (no balcão ou nas próprias vitrines): coloque itens à venda e ajuste os preços. Até cerca de 115% do valor, a reputação sobe; acima de 140%, os clientes vão embora.
4. **Abra a loja** no painel. Os clientes vêm das 09:00 às 17:00, mesmo com você fora. Quando você está lá dentro, eles esperam no balcão com um "!": atenda com **E** para ganhar gorjeta e mais reputação.
5. **Encomendas**: no quadro aparecem pedidos de moradores, com prazo e recompensa.
6. **Melhorias e decorações**: com mais estrelas de reputação, você libera vitrines extras e enfeites que atraem mais clientes. Muitos pedem itens coletados nas regiões.

## Como explorar

- **Saídas**: ao sul da fazenda fica o **vilarejo**, e a oeste, a **Floresta das Cerejeiras**. Do vilarejo dá para ir ao **Lago das Águas Claras** (leste) e ao **Jardim das Borboletas** (sul). Ao norte do lago ficam as **Montanhas de Lavanda**, e ao norte da floresta, o **Bosque das Flores Raras**.
- **Coleta**: itens brilhando no chão podem ser coletados com **E**. Eles mudam a cada dia e a cada estação.
- **Marcos**: cada região guarda um marco para descobrir. Leia as placas e os livros da biblioteca para conhecer a história da vovó e do vale.
- **Mapa**: a tecla **M** mostra o mapa, com os lugares visitados e as descobertas.

Outras dicas:
- O dia começa às 06:00. Durma antes das 02:00, senão você desmaia de cansaço.
- Dias de chuva regam tudo sozinhos.
- O **baú** ao lado da casa guarda até 24 pilhas de itens.
- No inventário: arraste para mover, use o clique direito para dividir e a lixeira para descartar (clique nela para desfazer).
- O jogo salva sozinho toda vez que você dorme. Pelo menu de pausa (Esc) também dá para salvar e abrir as configurações.

O cursor na frente da personagem fica mais forte quando o item selecionado pode ser usado ali. Com o mouse, você pode mirar em qualquer espaço vizinho.

## Testes

São 236 testes automatizados (unidade e integração), com um executor próprio e sem dependências externas:

```bash
tools/run_tests.sh /Applications/Godot.app/Contents/MacOS/Godot
```

Os testes de integração carregam a fazenda de verdade e controlam a personagem com entradas simuladas. Eles verificam movimento, colisões e câmera, além do ciclo completo de cultivo: arar, plantar, regar por vários dias, colher, quebrar pedras, cortar ervas, dormir e manter o estado ao recarregar a fazenda. Também cobrem loja, baú, relógio, salvamento (inclusive arquivo corrompido, backup e migração) e configurações.

Para gerar um screenshot com canteiros de exemplo:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/farm/farm.tscn -- --demo=farming --capture=$PWD/shot.png
```

## Arte e som

Toda a pixel art é **original**, gerada de forma determinística por [`tools/generate_assets.gd`](tools/generate_assets.gd), com a paleta definida em [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md). A personagem é desenhada pixel a pixel em [`tools/art/player_art.gd`](tools/art/player_art.gd). Para regenerar:

```bash
tools/build_assets.sh /Applications/Godot.app/Contents/MacOS/Godot
```

Os PNGs resultantes podem ser refinados no Aseprite. Basta manter os mesmos tamanhos e layouts de *sprite sheet*.

A música (uma faixa por estação e o tema do menu) e os efeitos sonoros também são **originais**, sintetizados por [`tools/generate_music.gd`](tools/generate_music.gd) e [`tools/generate_audio.gd`](tools/generate_audio.gd).

| Noite | Outono | Inverno |
|---|---|---|
| ![Noite](docs/screenshots/night_lights.png) | ![Outono](docs/screenshots/autumn.png) | ![Inverno](docs/screenshots/winter.png) |

## Documentação

- [Arquitetura](docs/ARCHITECTURE.md): sistemas, cenas, convenções e decisões técnicas
- [Roadmap](docs/ROADMAP.md): fases e o que está pendente
- [Direção de arte](docs/ART_DIRECTION.md): paleta e regras visuais
- [Changelog](CHANGELOG.md)

## Publicar no GitHub

O projeto já é um repositório git com o commit inicial. Para publicá-lo:

1. Entre na sua conta do GitHub pelo terminal (uma vez só): `gh auth login`.
2. Na pasta do projeto, crie o repositório e envie o código: `gh repo create florence-valley --public --source . --push` (troque `--public` por `--private` se preferir).
3. Para disponibilizar os executáveis, gere os builds e crie uma *release*: `gh release create v1.0.0 builds/macos/FlorenceValley.zip builds/windows/FlorenceValley.exe --title "Florence Valley 1.0.0" --notes-file CHANGELOG.md`.

A pasta `builds/` não vai para o repositório (está no `.gitignore`); os executáveis ficam só nas *releases*.

## Licença

Código sob licença MIT (veja [LICENSE](LICENSE)). A arte gerada pelas ferramentas deste repositório faz parte do projeto e segue a mesma licença.
