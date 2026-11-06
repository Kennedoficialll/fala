import AppKit
import Combine

struct DictationEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var text: String
    var seconds: Double
}

struct Snippet: Codable, Identifiable {
    var id = UUID()
    var trigger: String   // o que você fala
    var text: String      // o que é colado
}

struct HotKey: Identifiable {
    let code: UInt16
    let name: String
    let flag: NSEvent.ModifierFlags
    var id: UInt16 { code }
}

/// Estado do app e o que fica salvo em ~/Library/Application Support/Fala/data.json.
final class Store: ObservableObject {
    static let shared = Store()

    struct Saved: Codable {
        var dictations: [DictationEntry] = []
        var words: [String] = []
        var snippets: [Snippet] = []
        var hotKey: UInt16 = 61
        var language = "pt"
        var showDock = true
        var dark = false
        var sounds = true

        init() {}
        // Campos novos não podem apagar os dados de quem já usa: tudo é opcional ao ler.
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            dictations = try c.decodeIfPresent([DictationEntry].self, forKey: .dictations) ?? []
            words = try c.decodeIfPresent([String].self, forKey: .words) ?? []
            snippets = try c.decodeIfPresent([Snippet].self, forKey: .snippets) ?? []
            hotKey = try c.decodeIfPresent(UInt16.self, forKey: .hotKey) ?? 61
            language = try c.decodeIfPresent(String.self, forKey: .language) ?? "pt"
            showDock = try c.decodeIfPresent(Bool.self, forKey: .showDock) ?? true
            dark = try c.decodeIfPresent(Bool.self, forKey: .dark) ?? false
            sounds = try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? true
        }
    }

    enum Status { case idle, recording, transcribing }

    @Published var saved = Saved() { didSet { save() } }
    @Published var status: Status = .idle
    @Published var meetingRunning = false
    @Published var meetingBusy = false
    @Published var meetingStartedAt: Date?
    var toggleMeeting: () -> Void = {}
    var toggleDictation: () -> Void = {}
    var open: (Screen) -> Void = { _ in }
    var hideDock: (TimeInterval) -> Void = { _ in }
    @Published var screen: Screen = .dictation
    @Published var dockExpanded = false

    static let hotKeys = [
        HotKey(code: 61, name: "⌥ Option direito", flag: .option),
        HotKey(code: 54, name: "⌘ Command direito", flag: .command),
        HotKey(code: 62, name: "⌃ Control direito", flag: .control),
        HotKey(code: 63, name: "fn (Globo)", flag: .function),
    ]
    static let languages = [("pt", "Português"), ("en", "Inglês"), ("es", "Espanhol"), ("auto", "Detectar sozinho")]

    var hotKey: HotKey { Self.hotKeys.first { $0.code == saved.hotKey } ?? Self.hotKeys[0] }

    private let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Fala/data.json")

    private init() {
        if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Saved.self, from: d) { saved = s }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(saved).write(to: url, options: .atomic)
    }

    // MARK: números do painel

    var totalWords: Int { saved.dictations.reduce(0) { $0 + Self.wordCount($1.text) } }
    var wpm: Int {
        let s = saved.dictations.reduce(0) { $0 + $1.seconds }
        return s > 0 ? Int(Double(totalWords) / s * 60) : 0
    }
    static func wordCount(_ t: String) -> Int { t.split(whereSeparator: \.isWhitespace).count }

    /// Se o que foi falado é um atalho de voz, devolve o texto dele.
    func expandSnippet(_ text: String) -> String {
        let norm: (String) -> String = { $0.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }
            .trimmingCharacters(in: .whitespaces) }
        return saved.snippets.first { norm($0.trigger) == norm(text) }?.text ?? text
    }

    func meetings() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: Meeting.folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return files.filter { $0.pathExtension == "md" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
