import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let dictation = Dictation()
    private let meeting = Meeting()
    private let meetingItem = NSMenuItem(title: "Transcrever reunião", action: #selector(toggleMeeting), keyEquivalent: "")
    private let modelItem = NSMenuItem(title: "", action: #selector(downloadModel), keyEquivalent: "")

    func applicationDidFinishLaunching(_ n: Notification) {
        setIcon("mic")
        let menu = NSMenu()
        menu.addItem(withTitle: "Ditado: segure ⌥ direito e fale", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        meetingItem.target = self
        menu.addItem(meetingItem)
        let folder = NSMenuItem(title: "Abrir pasta de reuniões", action: #selector(openFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)
        menu.addItem(.separator())
        modelItem.target = self
        menu.addItem(modelItem)
        menu.addItem(withTitle: "Sair do Fala", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        refreshModelItem()

        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        // Acessibilidade: necessária para ouvir a tecla e colar o texto.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)

        dictation.onState = { [weak self] s in
            switch s {
            case .idle: self?.setIcon("mic")
            case .recording: self?.setIcon("mic.fill")
            case .transcribing: self?.setIcon("ellipsis.circle")
            }
        }
        dictation.onError = { [weak self] in self?.alert($0) }
        dictation.start()
    }

    @objc private func toggleMeeting() {
        Task { @MainActor in
            do {
                if meeting.isRunning {
                    meetingItem.title = "Transcrevendo…"
                    meetingItem.isEnabled = false
                    setIcon("ellipsis.circle")
                    let file = try await meeting.stop()
                    NSWorkspace.shared.open(file)
                } else {
                    guard confirmConsent() else { return }
                    try await meeting.start()
                    meetingItem.title = "Parar e transcrever reunião"
                    setIcon("record.circle")
                    return
                }
            } catch {
                alert(error.localizedDescription)
            }
            meetingItem.title = "Transcrever reunião"
            meetingItem.isEnabled = true
            setIcon("mic")
        }
    }

    private func confirmConsent() -> Bool {
        let a = NSAlert()
        a.messageText = "Transcrever esta reunião?"
        a.informativeText = "Avise os participantes de que a conversa será transcrita. O Fala grava seu microfone e o som do Mac, transcreve tudo no seu computador e apaga o áudio no final."
        a.addButton(withTitle: "Começar")
        a.addButton(withTitle: "Cancelar")
        NSApp.activate(ignoringOtherApps: true)
        return a.runModal() == .alertFirstButtonReturn
    }

    @objc private func openFolder() {
        try? FileManager.default.createDirectory(at: Meeting.folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Meeting.folder)
    }

    @objc private func downloadModel() {
        guard !Whisper.hasModel else { return }
        modelItem.title = "Baixando modelo… (≈550 MB)"
        modelItem.isEnabled = false
        URLSession.shared.downloadTask(with: Whisper.modelDownload) { tmp, resp, err in
            var failure = err?.localizedDescription
            if let tmp, (resp as? HTTPURLResponse)?.statusCode == 200 {
                do {
                    try FileManager.default.createDirectory(at: Whisper.modelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.moveItem(at: tmp, to: Whisper.modelURL)
                } catch { failure = error.localizedDescription }
            } else if failure == nil {
                failure = "O download do modelo falhou."
            }
            DispatchQueue.main.async {
                if let failure { self.alert(failure) }
                self.refreshModelItem()
            }
        }.resume()
    }

    private func refreshModelItem() {
        modelItem.title = Whisper.hasModel ? "Modelo do Whisper: pronto" : "Baixar modelo do Whisper (≈550 MB)"
        modelItem.isEnabled = !Whisper.hasModel
    }

    private func setIcon(_ symbol: String) {
        status.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Fala")
    }

    private func alert(_ text: String) {
        let a = NSAlert()
        a.messageText = "Fala"
        a.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
