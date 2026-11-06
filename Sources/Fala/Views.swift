import SwiftUI
import AppKit

/// Substitui @State (macro que só vem com o Xcode).
final class Box<T>: ObservableObject {
    @Published var v: T
    init(_ v: T) { self.v = v }
}

// MARK: - Tema

enum Theme {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { a in
            let hex = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                           blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        })
    }
    static let sidebar = dyn(0xF3F0EA, 0x121110)
    static let canvas = dyn(0xFCFBF8, 0x1A1917)
    static let card = dyn(0xFFFFFF, 0x22211E)
    static let field = dyn(0xF7F5F1, 0x1C1B19)
    static let line = dyn(0xE8E3DA, 0x2F2D29)
    static let ink = dyn(0x1D1B18, 0xF2EFEA)
    static let muted = dyn(0x7A746C, 0x9A948B)
    static let hover = dyn(0xEAE5DC, 0x252320)
    /// Brasa: a cor da marca, tirada da logo. Só para o que está vivo (ouvindo, ativo, selecionado).
    static let accent = Color(red: 0.925, green: 0.416, blue: 0.173)          // #EC6A2C
    static let brasa = LinearGradient(colors: [Color(red: 1, green: 0.643, blue: 0.357),      // #FFA45B
                                               Color(red: 0.925, green: 0.416, blue: 0.173),  // #EC6A2C
                                               Color(red: 0.761, green: 0.267, blue: 0.102)], // #C2441A
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    /// Tracking proporcional ao tamanho: títulos grandes mais fechados, texto corrido em 0.
    static func tracking(_ size: CGFloat) -> CGFloat { size >= 28 ? -0.018 * size : size >= 18 ? -0.01 * size : 0 }

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static let spring = Animation.spring(response: 0.3, dampingFraction: 1)
}

struct CardStyle: ViewModifier {
    var padding: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

extension View {
    func card(_ padding: CGFloat = 20) -> some View { modifier(CardStyle(padding: padding)) }
    /// Título da marca: New York (serifa do sistema) com tracking do tamanho.
    func display(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        font(Theme.serif(size, weight)).tracking(Theme.tracking(size))
    }
}

/// Resposta no clique: encolhe na hora em que aperta, não quando solta.
struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.2).foregroundStyle(Theme.muted)
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).display(34).foregroundStyle(Theme.ink)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(Theme.muted)
        }
    }
}

struct Page<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) { content }
                .padding(.horizontal, 44)
                .padding(.vertical, 40)
                .frame(maxWidth: 960, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }
}

struct Keycap: View {
    let text: String
    var dark = false
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(dark ? Color.white.opacity(0.14) : Theme.field, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(dark ? Color.white.opacity(0.22) : Theme.line))
    }
}

struct InputField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Theme.field, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
            .onSubmit(onSubmit)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var danger = false
    var disabled = false
    let action: () -> Void
    @StateObject private var hover = Box(false)
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(danger ? Color.white : Theme.canvas)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background((danger ? Color.red : Theme.ink).opacity(hover.v ? 0.86 : 1), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(Press())
        .opacity(disabled ? 0.4 : 1)
        .disabled(disabled)
        .onHover { h in withAnimation(Theme.spring) { hover.v = h } }
    }
}

struct IconButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @StateObject private var hover = Box(false)
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hover.v ? Theme.ink : Theme.muted)
                .frame(width: 28, height: 28)
                .background(hover.v ? Theme.hover : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .help(help)
        .onHover { hover.v = $0 }
    }
}

// MARK: - Estrutura

enum Screen: String, CaseIterable {
    case dictation = "Ditado", meetings = "Reuniões", dictionary = "Dicionário", snippets = "Atalhos de voz", settings = "Ajustes"
    static let main: [Screen] = [.dictation, .meetings, .dictionary, .snippets]
    var icon: String {
        switch self {
        case .dictation: "waveform"
        case .meetings: "person.2.wave.2"
        case .dictionary: "character.book.closed"
        case .snippets: "text.badge.plus"
        case .settings: "gearshape"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
            Group {
                switch store.screen {
                case .dictation: DictationView()
                case .meetings: MeetingsView()
                case .dictionary: DictionaryView()
                case .snippets: SnippetsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.03), radius: 12, y: 2)
            .padding(.vertical, 10).padding(.trailing, 10)
        }
        .overlay(alignment: .topTrailing) {
            IconButton(icon: store.saved.dark ? "sun.max" : "moon", help: store.saved.dark ? "Modo claro" : "Modo escuro") {
                store.saved.dark.toggle()
            }
            .padding(.top, 20).padding(.trailing, 26)
        }
        .background(Theme.sidebar)
        .ignoresSafeArea()
        .frame(minWidth: 940, minHeight: 620)
    }
}

struct Sidebar: View {
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if let logo = NSImage(named: "Logo") {
                    Image(nsImage: logo).resizable().frame(width: 30, height: 30)
                }
                Text("Fala").display(23, .semibold)
            }
            .foregroundStyle(Theme.ink)
            .padding(.leading, 10).padding(.top, 50).padding(.bottom, 24)

            ForEach(Screen.main, id: \.self) { s in
                NavItem(screen: s, selected: store.screen == s) { withAnimation(Theme.spring) { store.screen = s } }
            }
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Whisper.hasModel ? Color.green : Theme.accent).frame(width: 7, height: 7)
                    Text(Whisper.hasModel ? "Pronto, 100% local" : "Falta baixar o modelo")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink)
                }
                HStack(spacing: 5) {
                    Text("Segure").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Keycap(text: store.hotKey.name)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
            .padding(.bottom, 8)

            NavItem(screen: .settings, selected: store.screen == .settings) { withAnimation(Theme.spring) { store.screen = .settings } }
        }
        .padding(.horizontal, 12).padding(.bottom, 14)
        .frame(width: 224)
    }
}

struct NavItem: View {
    let screen: Screen
    let selected: Bool
    let action: () -> Void
    @StateObject private var hover = Box(false)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: screen.icon).font(.system(size: 13, weight: .medium)).frame(width: 18)
                    .foregroundStyle(selected ? Theme.accent : Theme.ink.opacity(0.75))
                Text(screen.rawValue)
                Spacer()
            }
            .font(.system(size: 13.5, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Theme.ink : Theme.ink.opacity(0.75))
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(selected ? Theme.card : hover.v ? Theme.hover : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: .black.opacity(selected ? 0.06 : 0), radius: 3, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover.v = h } }
    }
}

// MARK: - Ditado

struct DictationView: View {
    @EnvironmentObject var store: Store
    @StateObject private var search = Box("")

    private var firstName: String { NSFullUserName().split(separator: " ").first.map(String.init) ?? "" }

    private var days: [(String, [DictationEntry])] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEEE, d 'de' MMMM"
        let items = store.saved.dictations.filter { search.v.isEmpty || $0.text.localizedCaseInsensitiveContains(search.v) }
        var out: [(String, [DictationEntry])] = []
        for e in items {
            let cal = Calendar.current
            let d = cal.isDateInToday(e.date) ? "Hoje" : cal.isDateInYesterday(e.date) ? "Ontem" : f.string(from: e.date)
            if out.last?.0 == d { out[out.count - 1].1.append(e) } else { out.append((d, [e])) }
        }
        return out
    }

    var body: some View {
        Page {
            PageHeader(title: firstName.isEmpty ? "Olá" : "Olá, \(firstName)",
                       subtitle: "Fale em qualquer app. O texto aparece onde está o cursor.")

            HStack(alignment: .top, spacing: 16) {
                Hero(hotKey: store.hotKey.name)
                VStack(alignment: .leading, spacing: 14) {
                    StatLine(value: store.totalWords.formatted(), label: "palavras ditadas")
                    Divider().overlay(Theme.line)
                    StatLine(value: "\(store.wpm)", label: "palavras por minuto")
                    Divider().overlay(Theme.line)
                    StatLine(value: "\(store.saved.dictations.count)", label: "ditados")
                }
                .card()
                .frame(width: 250)
            }

            HStack {
                Eyebrow(text: "Histórico")
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    TextField("Buscar", text: $search.v).textFieldStyle(.plain).font(.system(size: 13))
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line))
                .frame(width: 230)
            }

            if days.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "waveform").font(.system(size: 28, weight: .light)).foregroundStyle(Theme.muted)
                    Text(search.v.isEmpty ? "Seu primeiro ditado aparece aqui" : "Nada encontrado")
                        .font(Theme.serif(19)).foregroundStyle(Theme.ink)
                    if search.v.isEmpty {
                        HStack(spacing: 5) {
                            Text("Segure").foregroundStyle(Theme.muted)
                            Keycap(text: store.hotKey.name)
                            Text("fale e solte.").foregroundStyle(Theme.muted)
                        }
                        .font(.system(size: 13))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 44)
                .card(0)
            }

            ForEach(days, id: \.0) { day, entries in
                VStack(alignment: .leading, spacing: 10) {
                    Text(day.prefix(1).uppercased() + day.dropFirst())
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.muted)
                    VStack(spacing: 0) {
                        ForEach(entries) { e in
                            EntryRow(entry: e)
                            if e.id != entries.last?.id { Divider().overlay(Theme.line).padding(.leading, 92) }
                        }
                    }
                    .card(0)
                }
            }
        }
    }
}

struct Hero: View {
    let hotKey: String
    private let bars: [CGFloat] = [18, 34, 52, 30, 64, 42, 76, 48, 28, 58, 36, 22, 40, 16]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            (Text("Fale.") + Text(" O Fala escreve.").italic())
                .display(30).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Segure")
                    Keycap(text: hotKey, dark: true)
                }
                Text("em qualquer app e solte quando terminar.")
            }
            .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.82))
            .frame(maxWidth: 320, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10))
                Text("Nada sai do seu Mac")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.white.opacity(0.12), in: Capsule())
        }
        .padding(26)
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
        .background {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(colors: [Color(red: 0.09, green: 0.08, blue: 0.07), Color(red: 0.20, green: 0.12, blue: 0.08)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Theme.accent.opacity(0.75), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 320)
                HStack(alignment: .center, spacing: 5) {
                    ForEach(bars.indices, id: \.self) { i in
                        Capsule().fill(Theme.brasa).opacity(0.42).frame(width: 4, height: bars[i] * 0.8)
                    }
                }
                .padding(26)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

struct StatLine: View {
    let value: String, label: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value).display(28).foregroundStyle(Theme.ink)
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
    }
}

struct EntryRow: View {
    @EnvironmentObject var store: Store
    let entry: DictationEntry
    @StateObject private var hover = Box(false)

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(entry.date, format: .dateTime.hour().minute())
                .font(.system(size: 12.5, weight: .medium)).monospacedDigit()
                .foregroundStyle(Theme.muted)
                .frame(width: 54, alignment: .leading)
                .padding(.top, 2)
            Text(entry.text)
                .font(.system(size: 14.5)).lineSpacing(4)
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 2) {
                IconButton(icon: "doc.on.doc", help: "Copiar") { copy(entry.text) }
                IconButton(icon: "trash", help: "Apagar") {
                    withAnimation(Theme.spring) { store.saved.dictations.removeAll { $0.id == entry.id } }
                }
            }
            .opacity(hover.v ? 1 : 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 15)
        .background(hover.v ? Theme.hover.opacity(0.45) : Color.clear)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover.v = h } }
    }

    private func copy(_ t: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(t, forType: .string)
    }
}

// MARK: - Reuniões

struct MeetingsView: View {
    @EnvironmentObject var store: Store
    @StateObject private var files = Box<[URL]>([])

    var body: some View {
        Page {
            PageHeader(title: "Reuniões", subtitle: "Meet, Zoom, Teams: o Fala transcreve a conversa inteira no seu Mac.")

            HStack(spacing: 22) {
                ZStack {
                    Circle().fill(store.meetingRunning ? Color.red.opacity(0.12) : Theme.field).frame(width: 64, height: 64)
                    Image(systemName: store.meetingRunning ? "waveform" : "mic.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(store.meetingRunning ? Color.red : Theme.ink)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.meetingBusy ? "Transcrevendo a reunião…" : store.meetingRunning ? "Gravando a reunião" : "Transcrever uma reunião")
                        .font(Theme.serif(22)).foregroundStyle(Theme.ink)
                    if store.meetingRunning, let start = store.meetingStartedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            Text(Meeting.clock(ctx.date.timeIntervalSince(start)))
                                .font(.system(size: 13, weight: .medium)).monospacedDigit().foregroundStyle(.red)
                        }
                    } else {
                        Text("Grava você (microfone) e os outros (som do Mac). Ao parar, gera o texto separado por pessoa.")
                            .font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                PrimaryButton(title: store.meetingBusy ? "Transcrevendo…" : store.meetingRunning ? "Parar e transcrever" : "Começar",
                              icon: store.meetingRunning ? "stop.fill" : "record.circle",
                              danger: store.meetingRunning,
                              disabled: store.meetingBusy) { store.toggleMeeting() }
            }
            .card(24)

            HStack(spacing: 10) {
                Tip(icon: "headphones", text: "Use fone de ouvido")
                Tip(icon: "person.wave.2", text: "Avise os participantes")
                Tip(icon: "trash", text: "O áudio é apagado no final")
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow(text: "Transcrições")
                    Spacer()
                    Button("Abrir pasta") { NSWorkspace.shared.open(Meeting.folder) }
                        .buttonStyle(Press()).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.muted)
                }
                if files.v.isEmpty {
                    Text("Nenhuma reunião transcrita ainda.")
                        .font(.system(size: 13.5)).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 32).card(0)
                } else {
                    VStack(spacing: 0) {
                        ForEach(files.v, id: \.self) { f in
                            MeetingRow(file: f)
                            if f != files.v.last { Divider().overlay(Theme.line).padding(.leading, 58) }
                        }
                    }
                    .card(0)
                }
            }
        }
        .onAppear { files.v = store.meetings() }
        .onChange(of: store.meetingBusy) { files.v = store.meetings() }
    }
}

struct Tip: View {
    let icon: String, text: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11.5, weight: .medium))
            Text(text).font(.system(size: 12.5))
        }
        .foregroundStyle(Theme.muted)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line))
    }
}

struct MeetingRow: View {
    let file: URL
    @StateObject private var hover = Box(false)

    private var title: String {
        let name = file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "Reuniao-", with: "")
        let p = DateFormatter()
        p.dateFormat = "yyyy-MM-dd-HHmm"
        guard let d = p.date(from: name) else { return name }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d 'de' MMMM 'de' yyyy, HH:mm"
        return f.string(from: d)
    }

    var body: some View {
        Button { NSWorkspace.shared.open(file) } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.text").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    .frame(width: 28, height: 28)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(title).font(.system(size: 14)).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted).opacity(hover.v ? 1 : 0)
            }
            .padding(.horizontal, 18).padding(.vertical, 13)
            .background(hover.v ? Theme.hover.opacity(0.45) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(Press())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover.v = h } }
    }
}

// MARK: - Dicionário

struct DictionaryView: View {
    @EnvironmentObject var store: Store
    @StateObject private var word = Box("")

    var body: some View {
        Page {
            PageHeader(title: "Dicionário", subtitle: "Nomes, marcas e termos que o Fala deve escrever do seu jeito.")

            HStack(spacing: 10) {
                InputField(placeholder: "Ex.: Hype, Negrito, CEMAP", text: $word.v, onSubmit: add)
                PrimaryButton(title: "Adicionar", icon: "plus",
                              disabled: word.v.trimmingCharacters(in: .whitespaces).isEmpty, action: add)
            }
            .card(14)

            if store.saved.words.isEmpty {
                Text("Nenhuma palavra ainda. O que você adicionar aqui vira dica para o Whisper acertar a grafia.")
                    .font(.system(size: 13.5)).foregroundStyle(Theme.muted)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10, alignment: .leading)],
                          alignment: .leading, spacing: 10) {
                    ForEach(store.saved.words, id: \.self) { w in
                        WordChip(word: w) { withAnimation(Theme.spring) { store.saved.words.removeAll { $0 == w } } }
                    }
                }
            }
        }
    }

    private func add() {
        let w = word.v.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty, !store.saved.words.contains(w) else { return }
        withAnimation(Theme.spring) { store.saved.words.append(w) }
        word.v = ""
    }
}

struct WordChip: View {
    let word: String
    let remove: () -> Void
    @StateObject private var hover = Box(false)
    var body: some View {
        HStack(spacing: 6) {
            Text(word).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Theme.ink).lineLimit(1)
            Spacer(minLength: 0)
            Button(action: remove) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                .buttonStyle(Press()).foregroundStyle(Theme.muted).opacity(hover.v ? 1 : 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line))
        .onHover { hover.v = $0 }
    }
}

// MARK: - Atalhos de voz

struct SnippetsView: View {
    @EnvironmentObject var store: Store
    @StateObject private var trigger = Box("")
    @StateObject private var text = Box("")

    var body: some View {
        Page {
            PageHeader(title: "Atalhos de voz", subtitle: "Fale uma frase curta e o Fala cola o texto completo no lugar.")

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Quando eu falar")
                        InputField(placeholder: "meu e-mail", text: $trigger.v)
                    }
                    .frame(width: 240)
                    Image(systemName: "arrow.right").foregroundStyle(Theme.muted).padding(.bottom, 11)
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "O Fala cola")
                        InputField(placeholder: "voce@exemplo.com", text: $text.v)
                    }
                }
                HStack {
                    Spacer()
                    PrimaryButton(title: "Adicionar atalho", icon: "plus", disabled: trigger.v.isEmpty || text.v.isEmpty) {
                        withAnimation(Theme.spring) { store.saved.snippets.append(Snippet(trigger: trigger.v, text: text.v)) }
                        trigger.v = ""
                        text.v = ""
                    }
                }
            }
            .card(20)

            if !store.saved.snippets.isEmpty {
                VStack(spacing: 0) {
                    ForEach(store.saved.snippets) { s in
                        SnippetRow(snippet: s)
                        if s.id != store.saved.snippets.last?.id { Divider().overlay(Theme.line) }
                    }
                }
                .card(0)
            }
        }
    }
}

struct SnippetRow: View {
    @EnvironmentObject var store: Store
    let snippet: Snippet
    @StateObject private var hover = Box(false)
    var body: some View {
        HStack(spacing: 14) {
            Text("“\(snippet.trigger)”").font(Theme.serif(16)).foregroundStyle(Theme.ink).frame(width: 220, alignment: .leading)
            Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text(snippet.text).font(.system(size: 13.5)).foregroundStyle(Theme.muted).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(icon: "trash", help: "Apagar") {
                withAnimation(Theme.spring) { store.saved.snippets.removeAll { $0.id == snippet.id } }
            }
            .opacity(hover.v ? 1 : 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .onHover { hover.v = $0 }
    }
}

// MARK: - Ajustes

struct SettingsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Page {
            PageHeader(title: "Ajustes", subtitle: "Tudo roda no seu Mac. Nada é enviado para a internet.")

            SettingsGroup(title: "Ditado") {
                SettingsRow(title: "Tecla para falar", detail: "Segure enquanto fala e solte para colar o texto.") {
                    Picker("", selection: $store.saved.hotKey) {
                        ForEach(Store.hotKeys) { Text($0.name).tag($0.code) }
                    }
                    .labelsHidden().fixedSize()
                }
                if store.saved.hotKey == 63 {
                    Text("Para usar fn: em Ajustes do Sistema → Teclado, mude \"Pressionar 🌐 para\" para \"Não fazer nada\".")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20).padding(.bottom, 14)
                }
                Divider().overlay(Theme.line)
                SettingsRow(title: "Sons", detail: "Um toque curto ao começar e ao colar o texto.") {
                    Toggle("", isOn: $store.saved.sounds).toggleStyle(.switch).labelsHidden().tint(Theme.accent)
                }
                Divider().overlay(Theme.line)
                SettingsRow(title: "Idioma", detail: "Idioma em que você costuma falar.") {
                    Picker("", selection: $store.saved.language) {
                        ForEach(Store.languages, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .labelsHidden().fixedSize()
                }
            }

            SettingsGroup(title: "Modelo") {
                SettingsRow(title: "Whisper large-v3-turbo", detail: "Reconhecimento de voz rodando no seu Mac.") {
                    HStack(spacing: 6) {
                        Circle().fill(Whisper.hasModel ? Color.green : Theme.accent).frame(width: 7, height: 7)
                        Text(Whisper.hasModel ? "Pronto" : "Baixe pelo ícone da barra de menus")
                    }
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink)
                }
            }

            SettingsGroup(title: "Permissões") {
                SettingsRow(title: "Microfone", detail: "Para ouvir o que você dita.") { OpenButton(pane: "Privacy_Microphone") }
                Divider().overlay(Theme.line)
                SettingsRow(title: "Acessibilidade", detail: "Para ouvir a tecla e colar o texto em outros apps.") { OpenButton(pane: "Privacy_Accessibility") }
                Divider().overlay(Theme.line)
                SettingsRow(title: "Gravação de tela e áudio", detail: "Só para transcrever reuniões.") { OpenButton(pane: "Privacy_ScreenCapture") }
            }

            Text("Fala 0.2 · Código aberto (MIT)").font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: title)
            VStack(spacing: 0) { content }.card(0)
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String, detail: String
    @ViewBuilder let control: Control
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(Theme.muted)
            }
            Spacer()
            control
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

struct OpenButton: View {
    let pane: String
    @StateObject private var hover = Box(false)
    var body: some View {
        Button {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
        } label: {
            Text("Abrir").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(hover.v ? Theme.hover : Theme.field, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line))
        }
        .buttonStyle(Press())
        .onHover { hover.v = $0 }
    }
}

// MARK: - Pílula flutuante

struct PillView: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var visible: Bool { store.status != .idle || store.meetingRunning || store.meetingBusy }

    var body: some View {
        ZStack {
            if visible {
                pill.transition(reduceMotion ? .opacity : .scale(scale: 0.88, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.32, dampingFraction: 1), value: visible)
        .animation(.spring(response: 0.32, dampingFraction: 1), value: store.status)
    }

    private var pill: some View {
        HStack(spacing: 10) {
            if store.status == .transcribing || store.meetingBusy {
                ProgressView().controlSize(.small).tint(.white)
                Text("Transcrevendo…")
            } else {
                WaveBars(style: store.meetingRunning ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.brasa))
                Text(store.meetingRunning ? "Gravando reunião" : "Ouvindo…")
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .tracking(0.1)
        .foregroundStyle(.white)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.075, blue: 0.07).opacity(0.94), in: Capsule())
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.06)],
                                                       startPoint: .top, endPoint: .bottom)))
        .shadow(color: .black.opacity(0.32), radius: 14, y: 5)
    }
}

struct WaveBars: View {
    var style = AnyShapeStyle(Color.white)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule().fill(style)
                        .frame(width: 3, height: reduceMotion ? 10 : 5 + 11 * abs(sin(t * 5.5 + Double(i) * 0.85)))
                }
            }
            .frame(height: 18)
        }
    }
}

// MARK: - Botões flutuantes (lateral da tela)

struct DockView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        ZStack(alignment: .leading) {
            if store.dockExpanded || store.status != .idle || store.meetingRunning {
                buttons.transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                // Recolhido: só um filete na beirada da tela.
                Capsule().fill(Color.gray.opacity(0.55))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                    .frame(width: 5, height: 56)
                    .padding(.leading, 3)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(Theme.spring, value: store.dockExpanded)
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            DockButton(icon: store.status == .recording ? "waveform" : store.status == .transcribing ? "ellipsis" : "mic.fill",
                       active: store.status != .idle, activeStyle: AnyShapeStyle(Theme.brasa), tall: true, help: "Ditar") { store.toggleDictation() }
            DockButton(icon: store.meetingRunning ? "stop.fill" : "record.circle",
                       active: store.meetingRunning, activeStyle: AnyShapeStyle(Color.red), tall: false, help: "Reunião") { store.toggleMeeting() }
        }
        .padding(6)
        .contextMenu {
            Button { store.hideDock(3600) } label: { Label("Ocultar por 1 hora", systemImage: "alarm") }
            Button { store.open(.settings) } label: { Label("Ajustes", systemImage: "gearshape") }
            Divider()
            Menu {
                let current = AudioInputs.current
                ForEach(AudioInputs.list()) { d in
                    Button { AudioInputs.select(d.id) } label: {
                        if d.id == current { Label(d.name, systemImage: "checkmark") } else { Text(d.name) }
                    }
                }
            } label: { Label("Microfone", systemImage: "mic") }
            Divider()
            Button { store.open(.dictation) } label: { Label("Histórico de ditados", systemImage: "list.bullet.clipboard") }
            Button {
                if let t = store.saved.dictations.first?.text { Paster.paste(t) }
            } label: { Label("Colar último ditado", systemImage: "doc.on.clipboard") }
            .disabled(store.saved.dictations.isEmpty)
        }
    }
}

struct DockButton: View {
    let icon: String
    let active: Bool
    let activeStyle: AnyShapeStyle
    let tall: Bool
    let help: String
    let action: () -> Void
    @StateObject private var hover = Box(false)
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: tall ? 17 : 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: tall ? 64 : 40)
                .background(active ? activeStyle : AnyShapeStyle(Color(red: 0.07, green: 0.065, blue: 0.06)), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(hover.v ? 0.35 : 0.15)))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                .scaleEffect(hover.v ? 1.06 : 1)
                .contentShape(Capsule())
        }
        .buttonStyle(Press())
        .help(help)
        .onHover { h in withAnimation(Theme.spring) { hover.v = h } }
    }
}
