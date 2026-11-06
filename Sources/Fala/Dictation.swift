import AppKit
import AVFoundation

/// Segure a tecla escolhida, fale, solte: o texto é colado no app em foco.
final class Dictation {
    var onError: (String) -> Void = { _ in }

    private let store = Store.shared
    private let file = FileManager.default.temporaryDirectory.appendingPathComponent("fala-ditado.wav")
    private var recorder: AVAudioRecorder?
    private var startedAt = Date()
    private var monitors: [Any] = []

    func start() {
        let handle: (NSEvent) -> Void = { [weak self] e in
            guard let self, e.keyCode == self.store.hotKey.code else { return }
            if e.modifierFlags.contains(self.store.hotKey.flag) { self.begin() } else { self.end() }
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handle) { monitors.append(m) }
        // Também quando a janela do Fala está na frente.
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { handle($0); return $0 }) { monitors.append(m) }
    }

    /// Clique no botão flutuante: começa ou termina o ditado.
    func toggle() { recorder == nil ? begin() : end() }

    private func begin() {
        guard recorder == nil, !store.meetingRunning else { return }
        guard let r = try? AVAudioRecorder(url: file, settings: Audio.wav16k), r.record() else {
            onError("Não consegui usar o microfone. Libere em Ajustes do Sistema → Privacidade → Microfone.")
            return
        }
        recorder = r
        startedAt = Date()
        store.status = .recording
        if store.saved.sounds { NSSound(named: "Tink")?.play() }
    }

    private func end() {
        guard let r = recorder else { return }
        r.stop()
        recorder = nil
        let seconds = Date().timeIntervalSince(startedAt)
        guard seconds > 0.4 else { store.status = .idle; return }  // toque acidental

        store.status = .transcribing
        let lang = store.saved.language, words = store.saved.words
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let raw = try Whisper.text(self.file, language: lang, words: words)
                DispatchQueue.main.async {
                    if !raw.isEmpty {
                        Paster.paste(self.store.expandSnippet(raw))
                        if self.store.saved.sounds { NSSound(named: "Pop")?.play() }
                        self.store.saved.dictations.insert(DictationEntry(date: Date(), text: raw, seconds: seconds), at: 0)
                    }
                    self.store.status = .idle
                }
            } catch {
                DispatchQueue.main.async { self.onError(error.localizedDescription); self.store.status = .idle }
            }
        }
    }
}

enum Paster {
    /// Cola via Cmd+V e devolve o que estava na área de transferência.
    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        let old = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: down)  // 9 = V
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let old else { return }
            pb.clearContents()
            pb.setString(old, forType: .string)
        }
    }
}
