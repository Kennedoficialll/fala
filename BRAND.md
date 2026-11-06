# Marca do Fala

> **Fale. O Fala escreve.**

O Fala transforma a sua voz em texto, no seu Mac, sem mandar nada para a internet. A marca precisa passar três coisas: **calma**, **confiança** e **privacidade**. Cada decisão abaixo existe para servir a uma delas.

## Princípios

1. **Um trabalho só.** Voz vira texto, onde o cursor estiver. Tudo que não ajuda nisso fica de fora.
2. **Seu, de verdade.** Privacidade é a promessa central: "Nada sai do seu Mac" aparece onde importa, sem alarde.
3. **Silencioso até ser útil.** O app some quando não está sendo usado (painel recolhido, pílula invisível) e responde na hora quando é chamado.
4. **Feito com cuidado.** Nenhum valor é aleatório: cor, espaço, tempo de animação e tamanho de letra seguem esta página.

## Logo

Um balão de fala com o **F** formado por três linhas de texto vazadas: a fala virando escrita.

| Arquivo | Uso |
|---|---|
| `design/logo-B.svg` | Ícone do app (fundo creme, balão Brasa) |
| `design/menubar.svg` | Barra de menus: forma única, pintada pelo macOS (template) |
| `Resources/AppIcon.icns` | Ícone final em todos os tamanhos |

- Margem livre mínima: a altura de uma linha do F em volta do balão.
- Não girar, não contornar, não trocar as cores do balão, não colocar sombra extra.
- Em tamanhos abaixo de 20 px use sempre a versão da barra de menus.

## Cores

| Nome | Claro | Escuro | Uso |
|---|---|---|---|
| **Brasa** | `#EC6A2C` | `#EC6A2C` | Cor da marca. Só para o que está **vivo**: ouvindo, ativo, selecionado. |
| Brasa (degradê) | `#FFA45B → #EC6A2C → #C2441A` | igual | Logo, ondas de áudio, botão de ditado ativo |
| Grafite | `#1D1B18` | `#F2EFEA` | Texto principal, botão principal |
| Pedra | `#7A746C` | `#9A948B` | Texto secundário |
| Creme (fundo) | `#F3F0EA` | `#121110` | Barra lateral, moldura |
| Papel (painel) | `#FCFBF8` | `#1A1917` | Área de conteúdo |
| Cartão | `#FFFFFF` | `#22211E` | Cartões |
| Linha | `#E8E3DA` | `#2F2D29` | Bordas e divisórias |
| Gravação | `systemRed` | `systemRed` | Só para "gravando reunião" (o vermelho que todo mundo já reconhece) |

A Brasa é usada com economia: se tudo é laranja, nada chama atenção.

## Tipografia

| Papel | Fonte | Tamanho | Tracking |
|---|---|---|---|
| Título de tela | New York (serifa do sistema) | 34 | −0,6 |
| Destaque / números | New York | 28–30 | −0,5 |
| Título de cartão | New York | 19–22 | −0,2 |
| Texto | SF Pro | 13,5–14,5 | 0 |
| Rótulo em maiúsculas | SF Pro Semibold | 11 | +1,2 |
| Horários | SF Pro, números monoespaçados | 12,5 | 0 |

- Títulos grandes ficam mais fechados (tracking negativo); texto corrido fica em 0. Use `.display(tamanho)` no código.
- Hierarquia vem de tamanho, peso e espaço juntos, não só de tamanho.

## Movimento

- Padrão: mola **sem quique** (amortecimento 1,0, resposta 0,3 s), em tudo que aparece, troca de tela e realce.
- Clique responde **ao apertar** (encolhe para 97 %), não ao soltar.
- A pílula **materializa** (cresce de 88 % a partir da base e aparece), e sai pelo mesmo caminho.
- O painel lateral sai da beirada esquerda e volta para ela.
- Com **Reduzir movimento** ligado no macOS: só aparecer e sumir, ondas paradas.

## Materiais

- Painéis flutuantes (pílula e botões laterais) são escuros e quase opacos, com uma **borda de luz em cima**, para serem lidos sobre qualquer fundo.
- O conteúdo fica num painel de papel com sombra suave, "flutuando" sobre a moldura creme.

## Som

- Um toque curto ao **começar** a ouvir (Tink) e ao **colar** o texto (Pop).
- Só nesses dois momentos, nunca em erro ou navegação. Dá para desligar em Ajustes → Sons.

## Tom de voz

- Português simples, frases curtas, falando com **você**.
- Diga o que acontece, não como funciona por dentro: "Segure ⌥ e fale", não "Inicie a captura de áudio".
- Sem jargão (modelo, inferência, ASR) na interface. Quando inevitável, explique em uma linha.
- Erros dizem o que fazer: "Libere em Ajustes do Sistema → Privacidade → Microfone."

| Em vez de | Escreva |
|---|---|
| Processando transcrição… | Transcrevendo… |
| Erro de permissão de áudio | Não consegui usar o microfone. Libere em Ajustes… |
| Iniciar sessão de gravação | Começar |
