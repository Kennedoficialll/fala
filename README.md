# Fala

Ditado e transcrição de reuniões para macOS, **100% no seu Mac**, grátis e sem conta. Usa o [whisper.cpp](https://github.com/ggml-org/whisper.cpp).

- **Ditado:** segure **⌥ Option direito**, fale, solte. O texto aparece onde o cursor estiver, em qualquer app.
- **Reunião:** no menu do Fala, clique em **Transcrever reunião** (Meet, Zoom, Teams, qualquer coisa que toque som). Ao parar, o Fala cria um arquivo em `~/Documents/Fala` separando **Você** (microfone) e **Outros** (som do Mac). O áudio é apagado no final.

Nenhum áudio ou texto sai do seu computador.

## Requisitos

- macOS 14 ou mais novo
- [Homebrew](https://brew.sh)
- Xcode Command Line Tools: `xcode-select --install`

## Instalar

```bash
brew install whisper-cpp
git clone https://github.com/Kennedoficialll/fala.git
cd fala
./build.sh
cp -R build/Fala.app /Applications/
open /Applications/Fala.app
```

Na primeira vez:

1. Clique no ícone de microfone na barra de menus → **Baixar modelo do Whisper** (≈550 MB, uma vez só).
2. Libere em **Ajustes do Sistema → Privacidade e Segurança**:
   - **Microfone** → Fala
   - **Acessibilidade** → Fala (para ouvir a tecla e colar o texto)
   - **Gravação de Tela e Áudio do Sistema** → Fala (só para reuniões)

Se você recompilar o app, o macOS pode pedir a Acessibilidade de novo.

## Dicas

- Em reunião, **use fone de ouvido**. Sem fone, o microfone também capta a voz dos outros e ela aparece duplicada como "Você".
- A transcrição da reunião é feita quando você clica em parar. Uma reunião de 1 hora leva alguns minutos, dependendo do Mac.

## Aviso legal

Avise os participantes antes de transcrever uma reunião. Em muitos lugares (no Brasil, pela LGPD) é preciso consentimento. O Fala mostra esse aviso antes de começar.

## Licença

MIT
