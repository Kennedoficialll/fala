import Foundation

/// Servidor local (whisper.cpp ou llama.cpp) que mantém o modelo carregado na memória.
final class LocalServer {
    private let binaries: [String]
    private let args: () -> [String]
    let port: Int
    private let readyPath: String
    private var process: Process?
    private let lock = NSLock()

    init(binaries: [String], port: Int, readyPath: String, args: @escaping () -> [String]) {
        self.binaries = binaries
        self.port = port
        self.readyPath = readyPath
        self.args = args
    }

    /// Abre o servidor e espera o modelo carregar. Bloqueia: chame fora da thread principal.
    func start() throws {
        lock.lock(); defer { lock.unlock() }
        if ping() { return }   // já está de pé (inclusive um que sobrou de uma execução anterior)
        guard let bin = binaries.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw FalaError("Não encontrei \(binaries.first.map { ($0 as NSString).lastPathComponent } ?? "o servidor"). Instale com: brew install whisper-cpp llama.cpp")
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = args() + ["--host", "127.0.0.1", "--port", String(port)]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        process = p
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            if ping() { return }
            if !p.isRunning { process = nil; throw FalaError("O servidor local fechou ao abrir. Pode faltar memória.") }
            Thread.sleep(forTimeInterval: 0.4)
        }
        p.terminate()
        process = nil
        throw FalaError("O servidor local demorou demais para abrir.")
    }

    func stop() {
        process?.terminate()
        process = nil
    }

    func post(_ path: String, body: Data, contentType: String, timeout: TimeInterval) throws -> Data {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(path)")!, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, code) = try Self.send(req)
        guard code == 200 else { throw FalaError("O servidor local respondeu com erro \(code).") }
        return data
    }

    private func ping() -> Bool {
        let req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)\(readyPath)")!, timeoutInterval: 1)
        return (try? Self.send(req))?.1 == 200
    }

    private static func send(_ req: URLRequest) throws -> (Data, Int) {
        var result: (Data?, URLResponse?, Error?) = (nil, nil, nil)
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { d, r, e in result = (d, r, e); done.signal() }.resume()
        done.wait()
        if let e = result.2 { throw e }
        return (result.0 ?? Data(), (result.1 as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

enum Servers {
    static let threads = String(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))

    static let whisper = LocalServer(binaries: ["/opt/homebrew/bin/whisper-server", "/usr/local/bin/whisper-server"],
                                     port: 8178, readyPath: "/") {
        ["-m", Whisper.modelURL.path, "-bs", "1", "-bo", "1", "-t", threads]   // busca gulosa: mais rápido, bom o bastante ao vivo
    }

    static let llama = LocalServer(binaries: ["/opt/homebrew/bin/llama-server", "/usr/local/bin/llama-server"],
                                   port: 8179, readyPath: "/health") {
        ["-m", LLM.modelURL.path, "-c", "8192", "-ngl", "99"]
    }
}

extension Whisper {
    /// Transcreve áudio 16 kHz mono no servidor local (modelo já carregado).
    static func serverSegments(_ samples: [Float], language: String, words: [String]) throws -> [Segment] {
        let boundary = "fala-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("response_format", "verbose_json")
        field("language", language)
        if !words.isEmpty { field("prompt", words.joined(separator: ", ")) }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        body.append(wav(samples))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        let data = try Servers.whisper.post("/inference", body: body, contentType: "multipart/form-data; boundary=\(boundary)", timeout: 180)
        struct Result: Decodable {
            struct Item: Decodable { let start: Double; let text: String }
            let segments: [Item]?
        }
        return (try JSONDecoder().decode(Result.self, from: data).segments ?? [])
            .map { Segment(start: $0.start, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.text.isEmpty && !isHallucination($0.text) }
    }

    /// WAV 16 kHz mono 16-bit em memória.
    static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        d.append(Data("RIFF".utf8)); u32(36 + bytes); d.append(Data("WAVEfmt ".utf8))
        u32(16); u16(1); u16(1); u32(16_000); u32(32_000); u16(2); u16(16)
        d.append(Data("data".utf8)); u32(bytes)
        for s in samples {
            withUnsafeBytes(of: Int16(max(-1, min(1, s)) * 32767).littleEndian) { d.append(contentsOf: $0) }
        }
        return d
    }
}

/// IA de texto local (llama.cpp) para resumo e perguntas sobre a reunião.
enum LLM {
    static let modelName = "Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
    static let modelDownload = URL(string: "https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/\(modelName)")!
    static let modelURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Fala/\(modelName)")
    static var hasModel: Bool { FileManager.default.fileExists(atPath: modelURL.path) }

    private static let rules = "Você ajuda a entender reuniões em português do Brasil. Use só o que está na transcrição, não invente nada. \"Você\" é quem gravou; \"Outros\" são os demais participantes. Seja direto."
    // ponytail: corta transcrições longas pelo começo; resumo por partes se reuniões de horas ficarem ruins
    private static func fit(_ t: String, _ limit: Int = 18_000) -> String { t.count > limit ? "(…início omitido…)\n" + t.suffix(limit) : t }

    static func summary(_ transcript: String) throws -> String {
        try chat("Transcrição:\n\(fit(transcript))\n\nEscreva em Markdown, nesta ordem:\n## Resumo\n3 a 5 frases.\n## Decisões\nLista. Se não houver, escreva \"Nenhuma\".\n## Próximos passos\nLista, com o responsável quando for citado. Se não houver, escreva \"Nenhum\".")
    }

    static func ask(_ question: String, transcript: String) throws -> String {
        let q = question == "O que perdi?" ? "O que aconteceu nos últimos minutos? Responda em até 3 tópicos curtos." : question
        return try chat("Transcrição:\n\(fit(transcript, 12_000))\n\nPergunta: \(q)", maxTokens: 400)
    }

    private static func chat(_ user: String, maxTokens: Int = 700) throws -> String {
        try Servers.llama.start()
        let body = try JSONSerialization.data(withJSONObject: [
            "messages": [["role": "system", "content": rules], ["role": "user", "content": user]],
            "temperature": 0.3, "max_tokens": maxTokens,
        ])
        let data = try Servers.llama.post("/v1/chat/completions", body: body, contentType: "application/json", timeout: 600)
        struct R: Decodable { struct C: Decodable { struct M: Decodable { let content: String }; let message: M }; let choices: [C] }
        return try JSONDecoder().decode(R.self, from: data).choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
