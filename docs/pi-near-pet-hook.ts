import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import net from "node:net";

// Near 桌宠本地命令通道（与 App 内 PetCommandServer 端口一致）
const PET_HOST = "127.0.0.1";
const PET_PORT = 47521;

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
