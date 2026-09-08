import Foundation

/// PI (Perplexity CLI Agent) 集成管理：负责把"near-pet 扩展"安装到 PI 的全局扩展目录。
///
/// PI 会从 `~/.pi/agent/extensions/*.ts` 自动发现扩展（jiti 直跑 TS，无需编译）。
/// 扩展监听生命周期事件并把状态推给本 App 的 PetCommandServer。
enum PIIntegration {
    /// PI 全局扩展目录
    static var extensionsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".pi/agent/extensions", isDirectory: true)
    }

    /// 扩展文件路径
    static var extensionFile: URL {
        extensionsDirectory.appendingPathComponent("near-pet.ts", isDirectory: false)
    }

    /// 扩展是否已安装
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: extensionFile.path)
    }

    /// 扩展源码（与仓库 docs/pi-near-pet-hook.ts 保持一致）
    static let extensionSource = """
    import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
    import net from "node:net";

    // Near 桌宠本地命令通道（与 App 内 PetCommandServer 端口一致）
    const PET_HOST = "127.0.0.1";
    const PET_PORT = \(PetCommandServer.port);

    /** 向桌宠发一条命令（尽力而为：超时与错误静默，绝不影响 PI） */
    function sendToPet(semantic: string, message?: string): void {
      const socket = net.connect({ host: PET_HOST, port: PET_PORT });
      socket.setTimeout(500);
      socket.on("connect", () => {
        socket.end(JSON.stringify({ semantic, message: message ?? "" }) + "\\n");
      });
      socket.on("error", () => {});
      socket.on("timeout", () => socket.destroy());
    }

    let sawToolError = false;

    export default function (pi: ExtensionAPI) {
      pi.on("session_start", () => {
        sawToolError = false;
        sendToPet("idle", "主子，PI 已就位，随时听候差遣");
      });
      pi.on("agent_start", () => {
        sawToolError = false;
        sendToPet("working");
      });
      pi.on("tool_execution_end", (event) => {
        if (event.isError && !sawToolError) {
          sawToolError = true;
          sendToPet("failure");
        }
      });
      pi.on("agent_end", () => {
        if (!sawToolError) {
          sendToPet("success");
        }
        sawToolError = false;
      });
      pi.on("session_shutdown", () => {
        sendToPet("idle", "奴才告退~");
      });
    }
    """

    /// 一键安装/更新扩展（幂等）。返回错误信息（nil = 成功）。
    @discardableResult
    static func install() -> String? {
        do {
            try FileManager.default.createDirectory(at: extensionsDirectory, withIntermediateDirectories: true)
            try extensionSource.data(using: .utf8)?.write(to: extensionFile, options: .atomic)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// 卸载扩展
    @discardableResult
    static func uninstall() -> String? {
        guard isInstalled else { return nil }
        do {
            try FileManager.default.removeItem(at: extensionFile)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
