import AppKit
import AVFoundation
import ScreenCaptureKit

/// Grava o microfone (Você) e o áudio do Mac (Outros) e, ao parar, gera a transcrição em Markdown.
final class Meeting: NSObject, SCStreamOutput {
    static let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Fala")

    private(set) var isRunning = false
    private var stream: SCStream?
    private var mic: AVAudioRecorder?
    private var systemFile: AVAudioFile?
    private var startedAt = Date()
    private let queue = DispatchQueue(label: "fala.meeting.audio")
    private let tmp = FileManager.default.temporaryDirectory
    private var micURL: URL { tmp.appendingPathComponent("fala-voce.wav") }
    private var systemURL: URL { tmp.appendingPathComponent("fala-outros.wav") }

    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw FalaError("Nenhuma tela encontrada para capturar o áudio.") }

        let cfg = SCStreamConfiguration()
        cfg.capturesAudio = true
        cfg.excludesCurrentProcessAudio = true
        cfg.sampleRate = 16_000
        cfg.channelCount = 1
        cfg.width = 2                                   // vídeo mínimo: só o áudio interessa
        cfg.height = 2
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let s = SCStream(filter: SCContentFilter(display: display, excludingApplications: [], exceptingWindows: []),
                         configuration: cfg, delegate: nil)
        try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)

        try? FileManager.default.removeItem(at: systemURL)
        guard let m = try? AVAudioRecorder(url: micURL, settings: Audio.wav16k), m.record() else {
            throw FalaError("Não consegui usar o microfone. Libere em Ajustes do Sistema → Privacidade → Microfone.")
        }
        try await s.startCapture()
        mic = m
        stream = s
        startedAt = Date()
        isRunning = true
    }

    /// Para a gravação, transcreve e devolve o arquivo .md criado.
    func stop() async throws -> URL {
        isRunning = false
        try? await stream?.stopCapture()
        stream = nil
        mic?.stop()
        mic = nil
        queue.sync { systemFile = nil }                 // fecha o WAV

        // ponytail: os dois arquivos começam juntos; sem alinhamento fino de relógio, ok para reunião
        let you = try Whisper.segments(micURL).map { ($0, "Você") }
        let others = FileManager.default.fileExists(atPath: systemURL.path)
            ? try Whisper.segments(systemURL).map { ($0, "Outros") } : []
        let lines = (you + others).sorted { $0.0.start < $1.0.start }
            .map { "**[\(Self.clock($0.0.start))] \($0.1):** \($0.0.text)" }

        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy HH:mm"
        let md = """
        # Reunião \(df.string(from: startedAt))

        > Transcrição feita localmente pelo Fala. Avise os participantes antes de transcrever.

        \(lines.isEmpty ? "_Nada foi transcrito._" : lines.joined(separator: "\n\n"))

        """
        df.dateFormat = "yyyy-MM-dd-HHmm"
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let out = Self.folder.appendingPathComponent("Reuniao-\(df.string(from: startedAt)).md")
        try md.write(to: out, atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: micURL)    // não guarda o áudio
        try? FileManager.default.removeItem(at: systemURL)
        return out
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, let buf = Self.pcm(sb) else { return }
        if systemFile == nil {
            systemFile = try? AVAudioFile(forWriting: systemURL, settings: Audio.wav16k,
                                          commonFormat: buf.format.commonFormat, interleaved: buf.format.isInterleaved)
        }
        try? systemFile?.write(from: buf)
    }

    private static func pcm(_ sb: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard var asbd = sb.formatDescription?.audioStreamBasicDescription,
              let fmt = AVAudioFormat(streamDescription: &asbd),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(sb.numSamples)) else { return nil }
        buf.frameLength = buf.frameCapacity
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sb, at: 0, frameCount: Int32(sb.numSamples),
                                                                  into: buf.mutableAudioBufferList)
        return status == noErr ? buf : nil
    }

    static func clock(_ s: Double) -> String {
        let t = Int(s)
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
                         : String(format: "%02d:%02d", t / 60, t % 60)
    }
}
