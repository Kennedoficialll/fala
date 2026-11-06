import AppKit
import AVFoundation
import ScreenCaptureKit

struct LiveLine: Identifiable {
    let id = UUID()
    let speaker: String   // "Você" ou "Outros"
    let start: Double     // segundos desde o início
    let text: String
}

/// Grava o microfone (Você) e o som do Mac (Outros) e transcreve ao vivo, em trechos de ~8 s.
final class Meeting: NSObject, SCStreamOutput {
    static let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Fala")
    static let rate = 16_000

    private final class Track {
        let speaker: String
        var samples: [Float] = []
        var consumed = 0          // amostras já enviadas (para o horário de cada fala)
        init(_ speaker: String) { self.speaker = speaker }
    }

    private let store = Store.shared
    private var stream: SCStream?
    private let engine = AVAudioEngine()
    private let audioQ = DispatchQueue(label: "fala.meeting.audio")
    private let workQ = DispatchQueue(label: "fala.meeting.work")   // uma transcrição por vez
    private var tracks = [Track("Você"), Track("Outros")]
    private var timer: Timer?
    private var startedAt = Date()
    private var endedAt = Date()
    private var language = "pt"
    private var words: [String] = []

    // MARK: começar e parar

    func start() async throws {
        language = store.saved.language
        words = store.saved.words
        tracks = [Track("Você"), Track("Outros")]
        try await Task.detached(priority: .userInitiated) { try Servers.whisper.start() }.value

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw FalaError("Nenhuma tela encontrada para capturar o áudio.") }
        let cfg = SCStreamConfiguration()
        cfg.capturesAudio = true
        cfg.excludesCurrentProcessAudio = true
        cfg.sampleRate = Self.rate
        cfg.channelCount = 1
        cfg.width = 2                                     // vídeo mínimo: só o áudio interessa
        cfg.height = 2
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        let s = SCStream(filter: SCContentFilter(display: display, excludingApplications: [], exceptingWindows: []),
                         configuration: cfg, delegate: nil)
        try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQ)

        try startMic()
        try await s.startCapture()
        stream = s
        startedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in self?.flush(final: false) }
    }

    /// Para, transcreve o que faltou e salva o arquivo. Devolve o .md criado.
    func stop() async throws -> URL {
        timer?.invalidate()
        timer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? await stream?.stopCapture()
        stream = nil
        endedAt = Date()
        flush(final: true)
        await withCheckedContinuation { c in audioQ.async { self.workQ.async { c.resume() } } }   // espera as filas
        await MainActor.run {}                                                                    // e as falas chegarem à tela
        Servers.whisper.stop()
        return try await MainActor.run { try save() }
    }

    // MARK: áudio

    private func startMic() throws {
        let input = engine.inputNode
        let inFmt = input.outputFormat(forBus: 0)
        guard inFmt.sampleRate > 0,
              let outFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(Self.rate), channels: 1, interleaved: false),
              let conv = AVAudioConverter(from: inFmt, to: outFmt) else {
            throw FalaError("Não consegui usar o microfone. Libere em Ajustes do Sistema → Privacidade → Microfone.")
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: inFmt) { [weak self] buf, _ in
            guard let self,
                  let out = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: AVAudioFrameCount(Double(buf.frameLength) * Double(Self.rate) / inFmt.sampleRate) + 64)
            else { return }
            var fed = false
            conv.convert(to: out, error: nil) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true
                status.pointee = .haveData
                return buf
            }
            guard let ch = out.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
            self.audioQ.async { self.tracks[0].samples += samples }
        }
        engine.prepare()
        try engine.start()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, var asbd = sb.formatDescription?.audioStreamBasicDescription,
              let fmt = AVAudioFormat(streamDescription: &asbd),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(sb.numSamples)) else { return }
        buf.frameLength = buf.frameCapacity
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sb, at: 0, frameCount: Int32(sb.numSamples), into: buf.mutableAudioBufferList) == noErr,
              let ch = buf.floatChannelData?[0] else { return }
        tracks[1].samples += UnsafeBufferPointer(start: ch, count: Int(buf.frameLength))   // já estamos na audioQ
    }

    // MARK: transcrição ao vivo

    private func flush(final: Bool) {
        audioQ.async {
            for t in self.tracks {
                let n = t.samples.count
                guard n > (final ? Self.rate / 10 : Self.rate * 6) else { continue }
                let cut = final ? n : Self.quietCut(t.samples)          // corta numa pausa, não no meio da palavra
                let chunk = Array(t.samples[0..<cut])
                let offset = Double(t.consumed) / Double(Self.rate)
                t.samples.removeFirst(cut)
                t.consumed += cut
                guard Self.rms(chunk) > 0.003 else { continue }          // silêncio: nem manda para o Whisper
                let (speaker, language, words) = (t.speaker, self.language, self.words)
                self.workQ.async {
                    guard let segs = try? Whisper.serverSegments(chunk, language: language, words: words), !segs.isEmpty else { return }
                    let lines = segs.map { LiveLine(speaker: speaker, start: offset + $0.start, text: $0.text) }
                    DispatchQueue.main.async {
                        self.store.live.append(contentsOf: lines)
                        self.store.live.sort { $0.start < $1.start }
                    }
                }
            }
        }
    }

    /// Ponto mais silencioso nos últimos 2 s do trecho.
    private static func quietCut(_ s: [Float]) -> Int {
        let win = rate / 10
        var best = s.count, bestEnergy = Float.greatestFiniteMagnitude
        var i = max(0, s.count - rate * 2)
        while i + win <= s.count {
            var e: Float = 0
            for k in i..<(i + win) { e += s[k] * s[k] }
            if e < bestEnergy { bestEnergy = e; best = i + win / 2 }
            i += win / 2
        }
        return best
    }

    private static func rms(_ s: [Float]) -> Float {
        guard !s.isEmpty else { return 0 }
        return (s.reduce(0) { $0 + $1 * $1 } / Float(s.count)).squareRoot()
    }

    // MARK: arquivo

    /// Escreve (ou reescreve, depois do resumo) o .md da reunião.
    @MainActor @discardableResult
    func save() throws -> URL {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "dd/MM/yyyy HH:mm"
        let title = store.meetingTitle.trimmingCharacters(in: .whitespaces)
        var md = "# \(title.isEmpty ? "Reunião \(df.string(from: startedAt))" : title)\n\n"
        md += "_\(df.string(from: startedAt)) · \(Self.clock(endedAt.timeIntervalSince(startedAt)))_\n\n"
        md += "> Transcrição feita localmente pelo Fala. Avise os participantes antes de transcrever.\n\n"
        if !store.summary.isEmpty { md += store.summary + "\n\n" }
        let notes = store.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { md += "## Minhas notas\n\n\(notes)\n\n" }
        md += "## Transcrição\n\n"
        md += store.live.isEmpty ? "_Nada foi transcrito._\n"
            : store.live.map { "**[\(Self.clock($0.start))] \($0.speaker):** \($0.text)" }.joined(separator: "\n\n") + "\n"

        df.dateFormat = "yyyy-MM-dd-HHmm"
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let out = Self.folder.appendingPathComponent("Reuniao-\(df.string(from: startedAt)).md")
        try md.write(to: out, atomically: true, encoding: .utf8)
        store.meetingFile = out
        return out
    }

    static func clock(_ s: Double) -> String {
        let t = Int(max(0, s))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
                         : String(format: "%02d:%02d", t / 60, t % 60)
    }
}
