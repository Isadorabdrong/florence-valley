# Direção de arte

**Tom:** acolhedor, primaveril e delicado, sem ficar infantil. Usamos tons pastel com contraste suficiente para leitura e contornos em ameixa escura (`#3d2b3d`) no lugar do preto puro.

## Paleta principal

| Uso | Cores |
|---|---|
| Rosa pastel / rosa antigo | `#fde3ea` `#f5bfd0` `#e597b2` `#c96f93` `#9c4f72` |
| Lilás / lavanda | `#d7c6f0` `#c9b3e6` `#a98bd6` `#9d8bc9` |
| Verde sálvia / floresta | `#b4d48c` `#8db86b` `#5c9656` `#3f7a4a` `#2f5a3c` |
| Creme / bege | `#fbf3e3` `#f1e4cc` `#e3d1b8` `#dcc398` |
| Madeira | `#cf9f72` `#b07d55` `#8a5d3f` `#6b4430` |
| Azul suave (água/céu) | `#e4f3f8` `#a9d3e6` `#86bcd8` `#6c9fc4` |
| Pedra (lavanda acinzentada) | `#dcd8e3` `#c2bdcc` `#9d98ab` `#7b7689` |
| Texto da interface | `#5b3a4f` |

### Ajuste de paleta (verde natural + rosado e dourado)

Todos os sprites e tiles gerados passam por [`tools/palette_grade.gd`](../tools/palette_grade.gd) ao serem salvos: verdes ficam mais naturais e quentes, rosas puxam para rosa/coral, amarelos e madeiras para o dourado, e lilases para o malva. Azuis (água, céu) não mudam. Personagens e interface ficam de fora, porque a troca de roupa e o tema dependem das cores exatas. A luz do dia também é levemente dourada, mais forte à tarde (`GameClock.light_color`).

## Regras

- **Grade de 16 px.** Tiles de 16×16 e personagens de 16×24. Os objetos ficam ancorados na base da célula.
- **Luz vinda de cima à esquerda.** Volumes usam 4 ou 5 tons com dithering ordenado (Bayer 4×4) suave.
- **Contornos coloridos.** A vegetação usa o tom mais escuro do próprio material; objetos e personagens usam ameixa.
- **Sombras no chão** em ameixa translúcida (~26–32%), nunca em preto.
- **Movimento sutil:** vento na vegetação com deslocamento de pixels inteiros, brilho na água e pétalas no ar.
- **Interface:** painéis creme com borda de madeira, botões rosa claro com borda rosa antigo e foco destacado em rosa.

## Fontes de arte

Toda a arte atual é gerada por `tools/generate_assets.gd`. Para trocar por arte feita à mão (Aseprite):

1. mantenha o tamanho do arquivo e o layout do sheet/atlas descritos nos comentários do gerador;
2. salve por cima do PNG em `assets/`;
3. pare de rodar o gerador para aquele arquivo (comente a chamada em `_initialize`).
