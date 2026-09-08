import Foundation
import Network

/// 本地宠物命令通道：监听 127.0.0.1 固定端口，接收外部（PI Hook / 脚本 / 其它工具）发来的 JSON 命令。
///
/// 协议：每行一个 JSON 对象，UTF-8。
/// {
///   "semantic": "working" | "success" | "failure" | "waving" | "waiting" | "review" | "speaking" | "idle",
///   "message": "可选，若提供则在播放动作的同时让宠物说话"
/// }
///
/// 只绑定回环地址，外部网络不可达；命令在 App 进程内解析，不落盘、不执行 shell。
final class PetCommandServer {
    static let shared = PetCommandServer()

    /// 本地端口（回环）。Hook / 脚本按此端口连接。
    static let port: UInt16 = 47521

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "near.pet-command-server")

    /// 收到命令后的回调（主线程）
    var onCommand: ((RemotePetCommand) -> Void)?

    /// 是否已启动
    private(set) var isRunning = false

    private init() {}

    /// 启动监听（幂等）。绑定回环地址，仅本机可访问。
    func start() {
        guard !isRunning else { return }
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            // 仅在回环接口上监听，杜绝局域网/外部访问
            let port = NWEndpoint.Port(rawValue: Self.port)!
            listener = try NWListener(using: params, on: port)
            listener?.newConnectionHandler = { [weak self] conn in
                self?.accept(conn)
            }
            // 未指定 interface：NWListener 默认绑定 0.0.0.0，这里显式限制为回环需要 loopback interface
            // 通过 NWParameters 设置 requiredInterfaceType = .loopback
            listener?.start(queue: queue)
            isRunning = true
            LogManager.shared.append("[PET-CMD] 宠物命令通道已启动 127.0.0.1:\(Self.port)")
        } catch {
            LogManager.shared.append("[PET-CMD] 监听启动失败: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isRunning = false
    }

    private func accept(_ conn: NWConnection) {
        // 只接受回环连接，防止局域网内其它设备调用
        if case .hostPort(let host, _) = conn.endpoint {
            let ip = host.debugDescription
            guard ip == "127.0.0.1" || ip == "::1" || ip == "localhost" else {
                conn.cancel()
                return
            }
        }
        connections.append(conn)
        conn.start(queue: queue)
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty, let line = String(data: data, encoding: .utf8) {
                self.handle(line)
            }
            if isComplete || error != nil {
                conn.cancel()
                self.connections.removeAll { $0 === conn }
            } else {
                self.receive(conn)
            }
        }
    }

    private func handle(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            LogManager.shared.append("[PET-CMD] 无法解析: \(trimmed.prefix(200))")
            return
        }

        let semanticRaw = obj["semantic"] as? String
        let message = (obj["message"] as? String)?.prefix(500).description

        let semantic = RemotePetCommand.semantic(from: semanticRaw)
        let command = RemotePetCommand(semantic: semantic, message: message)
        LogManager.shared.append("[PET-CMD] 收到: semantic=\(semanticRaw ?? "nil") message=\(message?.prefix(80) ?? "nil")")

        DispatchQueue.main.async { [weak self] in
            self?.onCommand?(command)
        }
    }
}

/// 一条来自外部的宠物命令（已归一化到中文语义）。
struct RemotePetCommand {
    let semantic: PetAnimSemantic
    let message: String?

    static func semantic(from raw: String?) -> PetAnimSemantic {
        guard let raw = raw else { return .idle }
        switch raw.lowercased() {
        case "working", "work", "busy", "running": return .working
        case "success", "done", "ok": return .success
        case "failure", "fail", "failed", "error": return .failure
        case "waving", "wave", "hello", "greet": return .speaking
        case "waiting", "wait": return .waiting
        case "review", "thinking": return .review
        case "speaking", "speak", "talk": return .speaking
        case "idle", "rest", "stop": return .idle
        default: return .idle
        }
    }
}
