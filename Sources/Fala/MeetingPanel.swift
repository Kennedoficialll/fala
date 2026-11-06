import SwiftUI

enum MeetingTab: String, CaseIterable {
    case notes = "Minhas notas", transcript = "Transcrição", summary = "Resumo"
}

/// Janela da reunião: transcrição ao vivo, notas, resumo e perguntas.
struct MeetingPanel: View {
    @EnvironmentObject var store: Store
    @StateObject private var tab = Box(MeetingTab.transcript)
    @StateObject private var question = Box("")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            Divider().overlay(Theme.line)
            Group {
                switch tab.v {
                case .notes: NotesEditor()
                case .transcript: TranscriptList()
                case .summary: SummaryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if store.asking || !store.answer.isEmpty { answer }
            footer
        }
        .background(Theme.canvas)
        .ignoresSafeArea()
        .frame(minWidth: 420, minHeight: 620)
        .onChange(of: store.summarizing) { if store.summarizing { withAnimation(Theme.spring) { tab.v = .summary } } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Reunião sem título", text: $store.meetingTitle)
                .textFieldStyle(.plain)
                .display(28)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                Chip(icon: "calendar", text: Date().formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                if store.meetingPreparing {
                    Chip(icon: "hourglass", text: "Preparando…")
                } else if store.meetingRunning, let start = store.meetingStartedAt {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Chip(icon: "record.circle", text: Meeting.clock(ctx.date.timeIntervalSince(start)), tint: .red)
                    }
                } else if store.meetingBusy {
                    Chip(icon: "ellipsis", text: "Finalizando…")
                }
            }
        }
        .padding(.horizontal, 28).padding(.top, 46).padding(.bottom, 18)
    }

    private var tabs: some View {
        HStack(spacing: 24) {
            ForEach(MeetingTab.allCases, id: \.self) { t in
                Button { withAnimation(Theme.spring) { tab.v = t } } label: {
                    VStack(spacing: 9) {
                        HStack(spacing: 6) {
                            if t == .transcript && store.meetingRunning {
                                WaveBars(style: AnyShapeStyle(Theme.brasa)).scaleEffect(0.62).frame(width: 16, height: 12)
                            }
                            Text(t.rawValue)
                                .font(.system(size: 14, weight: tab.v == t ? .semibold : .regular))
                                .foregroundStyle(tab.v == t ? Theme.ink : Theme.muted)
                        }
                        Capsule().fill(tab.v == t ? Theme.ink : Color.clear).frame(height: 2)
                    }
                    .fixedSize()
                }
                .buttonStyle(Press())
            }
        }
        .padding(.horizontal, 28)
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Eyebrow(text: "Resposta")
                Spacer()
                if !store.asking { IconButton(icon: "xmark", help: "Fechar") { store.answer = "" } }
            }
            if store.asking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Pensando no seu Mac…").font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            } else {
                ScrollView { MarkdownBlock(text: store.answer) }.frame(maxHeight: 180)
            }
        }
        .card(16)
        .padding(.horizontal, 20).padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text("Sempre peça consentimento antes de transcrever outras pessoas.")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                if store.meetingRunning {
                    PrimaryButton(title: "Parar", icon: "stop.fill", danger: true) { store.toggleMeeting() }
                } else if store.meetingBusy || store.meetingPreparing {
                    ProgressView().controlSize(.small)
                } else if let f = store.meetingFile {
                    PrimaryButton(title: "Abrir arquivo", icon: "doc.text") { NSWorkspace.shared.open(f) }
                }
                HStack(spacing: 8) {
                    TextField(LLM.hasModel ? "Pergunte algo sobre a reunião…" : "Baixe a IA de resumo nos Ajustes",
                              text: $question.v)
                        .textFieldStyle(.plain).font(.system(size: 13.5))
                        .onSubmit(send)
                    Button { store.ask("O que perdi?") } label: {
                        Text("O que perdi?").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(Theme.field, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                    .buttonStyle(Press())
                }
                .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line))
                .disabled(!LLM.hasModel || store.asking || store.live.isEmpty)
                .opacity(LLM.hasModel ? 1 : 0.6)
            }
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 18)
        .overlay(alignment: .top) { Divider().overlay(Theme.line) }
        .animation(Theme.spring, value: store.asking)
    }

    private func send() {
        let q = question.v.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        store.ask(q)
        question.v = ""
    }
}

struct Chip: View {
    let icon: String, text: String
    var tint: Color? = nil
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .medium))
            Text(text).font(.system(size: 12.5, weight: .medium)).monospacedDigit()
        }
        .foregroundStyle(tint ?? Theme.muted)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
    }
}

struct TranscriptList: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if store.live.isEmpty {
                        VStack(spacing: 10) {
                            WaveBars(style: AnyShapeStyle(Theme.brasa))
                            Text(store.meetingRunning ? "Escutando… as falas aparecem aqui em alguns segundos." : "Nada transcrito ainda.")
                                .font(.system(size: 13.5)).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                    ForEach(Array(store.live.enumerated()), id: \.element.id) { i, line in
                        if i == 0 || store.live[i - 1].speaker != line.speaker {
                            HStack(spacing: 8) {
                                Text(line.speaker).font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(line.speaker == "Você" ? Theme.ink : Theme.accent)
                                Text(Meeting.clock(line.start)).font(.system(size: 11.5)).monospacedDigit().foregroundStyle(Theme.muted)
                            }
                            .padding(.top, i == 0 ? 0 : 14)
                        }
                        HStack {
                            Text(line.text)
                                .font(.system(size: 14.5)).lineSpacing(3)
                                .foregroundStyle(Theme.ink)
                                .textSelection(.enabled)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Theme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Spacer(minLength: 40)
                        }
                        .id(line.id)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 28).padding(.vertical, 20)
            }
            .onChange(of: store.live.count) {
                guard let last = store.live.last else { return }
                withAnimation(Theme.spring) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }
}

struct NotesEditor: View {
    @EnvironmentObject var store: Store
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $store.notes)
                .font(.system(size: 14.5))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .foregroundStyle(Theme.ink)
            if store.notes.isEmpty {
                Text("Anote o que quiser durante a reunião. Fica salvo junto com a transcrição.")
                    .font(.system(size: 14.5)).foregroundStyle(Theme.muted)
                    .padding(.leading, 5).padding(.top, 1)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 23).padding(.vertical, 18)
    }
}

struct SummaryView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Group {
            if !LLM.hasModel {
                Placeholder(icon: "sparkles", title: "Resumo com IA no seu Mac",
                            text: "Baixe a IA de resumo em Ajustes (2,5 GB, uma vez só). Nada sai do seu computador.") {
                    PrimaryButton(title: "Abrir Ajustes", icon: "gearshape") { store.open(.settings) }
                }
            } else if store.summarizing {
                Placeholder(icon: "sparkles", title: "Resumindo no seu Mac…", text: "Leva de 30 segundos a 1 minuto.") {
                    ProgressView().controlSize(.small)
                }
            } else if store.summary.isEmpty {
                Placeholder(icon: "sparkles", title: "Resumo",
                            text: store.meetingRunning ? "O resumo é criado quando a reunião termina." : "Ainda não há resumo desta reunião.") {
                    PrimaryButton(title: "Gerar resumo agora", icon: "sparkles", disabled: store.live.isEmpty) { store.summarize() }
                }
            } else {
                ScrollView { MarkdownBlock(text: store.summary).padding(.horizontal, 28).padding(.vertical, 22) }
            }
        }
    }
}

struct Placeholder<Action: View>: View {
    let icon: String, title: String, text: String
    @ViewBuilder let action: Action
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 24, weight: .light)).foregroundStyle(Theme.accent)
            Text(title).display(20).foregroundStyle(Theme.ink)
            Text(text).font(.system(size: 13.5)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 300)
            action.padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Markdown simples: títulos (##), listas (-) e negrito/itálico no meio do texto.
struct MarkdownBlock: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("#") {
                    Text(Self.inline(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
                        .display(18, .semibold).foregroundStyle(Theme.ink).padding(.top, 8)
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Theme.accent).frame(width: 5, height: 5).offset(y: -2)
                        Text(Self.inline(String(line.dropFirst(2)))).font(.system(size: 14.5)).foregroundStyle(Theme.ink)
                    }
                } else if !line.isEmpty {
                    Text(Self.inline(line)).font(.system(size: 14.5)).lineSpacing(3).foregroundStyle(Theme.ink)
                }
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }
}
