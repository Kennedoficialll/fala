# Fala

Ditado e transcrição de reuniões para macOS, **100% no seu Mac**, grátis e sem conta. Usa o [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

- **Ditado:** segure **⌥ Option direito** (ou outra tecla, nos Ajustes), fale, solte. O texto aparece onde o cursor estiver, em qualquer app.
- **Reunião ao vivo:** funciona com **Google Meet, Zoom, Teams, Slack, WhatsApp** ou qualquer chamada, porque o Fala ouve o som do Mac (os outros) e o seu microfone (você). Abre uma janela com a transcrição aparecendo na hora, separada por **Você** e **Outros**, um campo de **notas** e, ao parar, salva tudo em `~/Documents/Fala`. O áudio é apagado no final.
- **Resumo e "O que perdi?":** com a IA de resumo (Qwen3 4B, 2,5 GB, baixada uma vez em Ajustes), o Fala gera resumo, decisões e próximos passos, e responde perguntas sobre a reunião. Também roda no seu Mac.

- **Janela do Fala:** histórico de tudo que você ditou (com busca), reuniões, **Dicionário** (nomes e termos que ele deve escrever certo), **Atalhos de voz** (fale "meu e-mail" e ele cola o texto completo) e Ajustes (tecla, idioma, sons, modo claro/escuro).
- **Botões flutuantes:** um filete na beirada esquerda da tela que abre ao passar o mouse, com botões de ditar e de gravar reunião. Clique direito para escolher o microfone, colar o último ditado ou ocultar por 1 hora.

Nenhum áudio ou texto sai do seu computador.

## Requisitos

- macOS 14 ou mais novo
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools: `xcode-select --install`

## Instalar

```bash
brew install whisper-cpp llama.cpp
git clone https://github.com/Kennedoficialll/fala.git
cd fala
./build.sh --install
```

Na primeira vez:

1. Clique no ícone do Fala na barra de menus → **Baixar modelo do Whisper** (≈550 MB, uma vez só). Para resumos, em **Ajustes → IA de resumo → Baixar** (2,5 GB).
2. Libere em **Ajustes do Sistema → Privacidade e Segurança**:
   - **Microfone** → Fala
   - **Acessibilidade** → Fala (para ouvir a tecla e colar o texto)
   - **Gravação de Tela e Áudio do Sistema** → Fala (só para reuniões)

Se você recompilar o app, o macOS pode pedir a Acessibilidade de novo.

## Dicas

- Em reunião, **use fone de ouvido**. Sem fone, o microfone também capta a voz dos outros e ela aparece duplicada como "Você".
- A transcrição da reunião acontece durante a chamada, em trechos de alguns segundos. O resumo leva de 30 segundos a 1 minuto depois que você para.
- Para ouvir os outros, o Fala precisa da permissão **Gravação de Tela e Áudio do Sistema** (ele não grava a tela, só o som).

## Aviso legal

Avise os participantes antes de transcrever uma reunião. Em muitos lugares (no Brasil, pela LGPD) é preciso consentimento. O Fala mostra esse aviso antes de começar.

## Marca

Cores, tipografia, logo e tom de voz estão em [BRAND.md](BRAND.md).

## Licença

MIT. Modelos baixados à parte: Whisper (MIT) e Qwen3 4B (Apache 2.0).
