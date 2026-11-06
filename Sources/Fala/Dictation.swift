import AppKit
import AVFoundation

/// Segure ⌥ (Option) direito, fale, solte: o texto é colado no app em foco.
final class Dictation {
    enum State { case idle, recording, transcribing }
    var onState: (State) -> Void = { _ in }
    var onError: (String) -> Void = { _ in }

    // ponytail: tecla fixa (keyCode 61 = Option direito); deixar configurável quando alguém pedir
    static let hotKey: UInt16 = 61

    private let file = FileManager.default.temporaryDirectory.appendingPathComponent("fala-ditado.wav")
    private var recorder: AVAudioRecorder?
    private var startedAt = Date()
    private var monitor: Any?

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] e in
            guard e.keyCode == Self.hotKey else { return }
            if e.modifierFlags.contains(.option) { self?.begin() } else { self?.end() }
        }
    }

    private func begin() {
        guard recorder == nil else { return }
        guard let r = try? AVAudioRecorder(url: file, settings: Audio.wav16k), r.record() else {
            onError("Não consegui usar o microfone. Libere em Ajustes do Sistema → Privacidade → Microfone.")
            return
        }
        recorder = r
        startedAt = Date()
        onState(.recording)
    }

    private func end() {
        guard let r = recorder else { return }
        r.stop()
        recorder = nil
        guard Date().timeIntervalSince(startedAt) > 0.4 else { onState(.idle); return }  // toque acidental

        onState(.transcribing)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let text = try Whisper.text(self.file)
                DispatchQueue.main.async {
                    if !text.isEmpty { Paster.paste(text) }
                    self.onState(.idle)
                }
            } catch {
                DispatchQueue.main.async { self.onError(error.localizedDescription); self.onState(.idle) }
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
