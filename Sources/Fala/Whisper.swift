import Foundation
import AVFoundation

struct Segment {
    let start: Double   // segundos desde o início do arquivo
    let text: String
}

struct FalaError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

enum Audio {
    /// WAV 16 kHz mono 16-bit: o formato que o Whisper espera.
    static let wav16k: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]
}

enum Whisper {
    static let modelName = "ggml-large-v3-turbo-q5_0.bin"
    static let modelDownload = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(modelName)")!
    static let modelURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Fala/\(modelName)")

    static var hasModel: Bool { FileManager.default.fileExists(atPath: modelURL.path) }

    static var cli: String? {
        ["/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Texto corrido, para o ditado.
    static func text(_ wav: URL, language: String, words: [String]) throws -> String {
        try segments(wav, language: language, words: words).map(\.text).joined(separator: " ")
    }

    /// Trechos com horário, para a reunião.
    static func segments(_ wav: URL, language: String, words: [String]) throws -> [Segment] {
        guard let cli else { throw FalaError("whisper-cli não encontrado. Instale com: brew install whisper-cpp") }
        guard hasModel else { throw FalaError("Modelo do Whisper não baixado. Use \"Baixar modelo\" no menu do Fala.") }

        let out = wav.deletingPathExtension()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cli)
        var args = ["-m", modelURL.path, "-l", language, "-f", wav.path, "-oj", "-of", out.path, "-np",
                    "-t", String(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))]
        if !words.isEmpty { args += ["--prompt", words.joined(separator: ", ")] }  // dicionário: puxa a grafia certa
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw FalaError("O Whisper falhou (código \(p.terminationStatus)).") }

        struct Result: Decodable {
            struct Item: Decodable {
                struct Offsets: Decodable { let from: Int }
                let offsets: Offsets
                let text: String
            }
            let transcription: [Item]
        }
        let json = out.appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: json) }
        let result = try JSONDecoder().decode(Result.self, from: Data(contentsOf: json))
        return result.transcription
            .map { Segment(start: Double($0.offsets.from) / 1000, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.text.isEmpty && !isHallucination($0.text) }
    }

    /// Frases que o Whisper inventa em silêncio em português.
    // ponytail: lista fixa; trocar por VAD (--vad) se continuar aparecendo lixo
    static func isHallucination(_ t: String) -> Bool {
        let s = t.lowercased()
        return s.hasPrefix("[") || s.hasPrefix("(") || s.contains("amara.org") || s.contains("zanotto")
            || ["música", "música.", "♪"].contains(s) || s.contains("inscreva-se no canal") || s.contains("obrigado por assistir")
    }
}
