import AppKit
import AVFoundation
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store.shared
    private let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let dictation = Dictation()
    private let meeting = Meeting()
    private let meetingItem = NSMenuItem(title: "Transcrever reunião", action: #selector(toggleMeeting), keyEquivalent: "")
    private let modelItem = NSMenuItem(title: "", action: #selector(downloadModel), keyEquivalent: "")
    private var window: NSWindow!
    private var pill: NSPanel!
    private var dock: NSPanel!
    private let dockItem = NSMenuItem(title: "", action: #selector(toggleDock), keyEquivalent: "")
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ n: Notification) {
        buildMainMenu()
        buildStatusMenu()
        buildWindow()
        buildPill()
        buildDock()

        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        // Acessibilidade: necessária para ouvir a tecla e colar o texto.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)

        store.toggleMeeting = { [weak self] in self?.toggleMeeting() }
        store.toggleDictation = { [weak self] in self?.dictation.toggle() }
        store.open = { [weak self] screen in
            self?.store.screen = screen
            self?.showWindow()
        }
        store.hideDock = { [weak self] seconds in
            self?.dock.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { self?.refreshDock() }
        }
        store.$status.combineLatest(store.$meetingRunning, store.$meetingBusy)
            .receive(on: RunLoop.main)
            .sink { [weak self] s, running, busy in self?.render(s, running, busy) }
            .store(in: &bag)

        store.$saved.map(\.dark).removeDuplicates().receive(on: RunLoop.main)
            .sink { [weak self] dark in self?.window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua) }
            .store(in: &bag)

        dictation.onError = { [weak self] in self?.alert($0) }
        dictation.start()
        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: montagem

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "Fala"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: MainView().environmentObject(store))
        window.center()
        window.setFrameAutosaveName("FalaMain")
    }

    private func buildPill() {
        pill = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 70),
                       styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        pill.level = .statusBar
        pill.isOpaque = false
        pill.backgroundColor = .clear
        pill.ignoresMouseEvents = true
        pill.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        pill.contentView = NSHostingView(rootView: PillView().environmentObject(store))
        if let f = NSScreen.main?.visibleFrame {
            pill.setFrameOrigin(NSPoint(x: f.midX - pill.frame.width / 2, y: f.minY + 40))
        }
        pill.orderFrontRegardless()   // fica sempre lá, invisível; o SwiftUI anima a entrada e a saída
    }

    /// Botões flutuantes na lateral esquerda; não roubam o foco do app em uso.
    private func buildDock() {
        dock = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 56, height: 132),
                       styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        dock.level = .floating
        dock.isOpaque = false
        dock.backgroundColor = .clear
        dock.hasShadow = false
        dock.isMovableByWindowBackground = true
        dock.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let host = NSHostingView(rootView: DockView().environmentObject(store))
        let hover = HoverView { [weak self] inside in self?.store.dockExpanded = inside }
        hover.frame = NSRect(x: 0, y: 0, width: 56, height: 132)
        host.frame = hover.bounds
        host.autoresizingMask = [.width, .height]
        hover.addSubview(host)
        dock.contentView = hover
        if let f = NSScreen.main?.visibleFrame {
            dock.setFrameOrigin(NSPoint(x: f.minX, y: f.midY - 66))
        }
        refreshDock()
    }

    @objc private func toggleDock() {
        store.saved.showDock.toggle()
        refreshDock()
    }

    private func refreshDock() {
        store.saved.showDock ? dock.orderFrontRegardless() : dock.orderOut(nil)
        dockItem.title = store.saved.showDock ? "Ocultar botões flutuantes" : "Mostrar botões flutuantes"
    }

    private func buildStatusMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Abrir Fala", action: #selector(showWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        meetingItem.target = self
        menu.addItem(meetingItem)
        dockItem.target = self
        menu.addItem(dockItem)
        menu.addItem(.separator())
        modelItem.target = self
        menu.addItem(modelItem)
        menu.addItem(withTitle: "Sair do Fala", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        refreshModelItem()
    }

    /// Menu do app (necessário para ⌘Q, ⌘C, ⌘V nos campos de texto).
    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Ocultar Fala", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Sair do Fala", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Editar")
        edit.addItem(withTitle: "Desfazer", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Refazer", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Recortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Colar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Selecionar tudo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let winItem = NSMenuItem()
        let win = NSMenu(title: "Janela")
        win.addItem(withTitle: "Fechar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        win.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = win
        main.addItem(winItem)
        NSApp.mainMenu = main
    }

    // MARK: estado na tela

    private func render(_ s: Store.Status, _ running: Bool, _ busy: Bool) {
        let icon = busy || s == .transcribing ? "ellipsis.circle" : running ? "record.circle" : s == .recording ? "mic.fill" : "mic"
        // Parado: a logo do Fala. Gravando ou transcrevendo: símbolo de estado.
        if icon == "mic", let logo = NSImage(named: "MenuIcon") {
            logo.isTemplate = true
            logo.size = NSSize(width: 18, height: 18)
            status.button?.image = logo
        } else {
            status.button?.image = NSImage(systemSymbolName: icon, accessibilityDescription: "Fala")
        }
        meetingItem.title = busy ? "Transcrevendo…" : running ? "Parar e transcrever reunião" : "Transcrever reunião"
        meetingItem.isEnabled = !busy

        if s != .idle || running, let screen = NSScreen.main {   // a pílula segue a tela em uso
            let f = screen.visibleFrame
            pill.setFrameOrigin(NSPoint(x: f.midX - pill.frame.width / 2, y: f.minY + 40))
        }
    }

    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: ações

    @objc private func toggleMeeting() {
        Task { @MainActor in
            do {
                if store.meetingRunning {
                    store.meetingBusy = true
                    store.meetingRunning = false
                    store.meetingStartedAt = nil
                    let file = try await meeting.stop()
                    NSWorkspace.shared.open(file)
                } else {
                    guard confirmConsent() else { return }
                    try await meeting.start()
                    store.meetingStartedAt = Date()
                    store.meetingRunning = true
                }
            } catch {
                store.meetingRunning = false
                alert(error.localizedDescription)
            }
            store.meetingBusy = false
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

    private func alert(_ text: String) {
        let a = NSAlert()
        a.messageText = "Fala"
        a.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

/// Avisa quando o mouse entra ou sai, mesmo com outro app na frente.
final class HoverView: NSView {
    private let onChange: (Bool) -> Void
    init(_ onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { onChange(true) }
    override func mouseExited(with event: NSEvent) { onChange(false) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
