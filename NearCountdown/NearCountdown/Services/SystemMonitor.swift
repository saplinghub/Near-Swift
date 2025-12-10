import Foundation

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var temperature: String = "N/A"
    @Published var uptime: String = ""

    private var timer: Timer?

    init() {
        updateSystemInfo()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.updateSystemInfo()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func updateSystemInfo() {
        // 使用异步更新避免阻塞UI
        DispatchQueue.global(qos: .utility).async {
            let cpu = self.getCPUUsage()
            let memory = self.getMemoryUsage()
            let temp = self.getTemperature()
            let time = self.getUptime()

            DispatchQueue.main.async {
                self.cpuUsage = cpu
                self.memoryUsage = memory
                self.temperature = temp
                self.uptime = time
            }
        }
    }

    private func getCPUUsage() -> Double {
        guard FileManager.default.fileExists(atPath: "/usr/bin/top") else {
            print("top command not available")
            return 0.0
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-l", "1", "-n", "0"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()

            // 添加超时机制
            let timeoutDate = Date().addingTimeInterval(5.0)
            while task.isRunning && Date() < timeoutDate {
                usleep(100000) // 0.1秒
            }

            if task.isRunning {
                task.terminate()
                print("CPU usage task timed out")
                return 0.0
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n")
                for line in lines {
                    if line.contains("CPU usage") {
                        let parts = line.split(separator: ",")
                        for part in parts {
                            if part.contains("user") {
                                let value = part.split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
                                if let usage = Double(value?.replacingOccurrences(of: "%", with: "") ?? "0") {
                                    return min(max(usage, 0.0), 100.0) // 限制范围
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error getting CPU usage: \(error)")
            return 0.0
        }

        return 0.0
    }

    private func getMemoryUsage() -> Double {
        guard FileManager.default.fileExists(atPath: "/usr/bin/vm_stat") else {
            print("vm_stat command not available")
            return 0.0
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()

            // 添加超时机制
            let timeoutDate = Date().addingTimeInterval(3.0)
            while task.isRunning && Date() < timeoutDate {
                usleep(100000) // 0.1秒
            }

            if task.isRunning {
                task.terminate()
                print("Memory usage task timed out")
                return 0.0
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n")
                var freePages = 0
                var totalPages = 0

                for line in lines {
                    if line.contains("Pages free:") {
                        let value = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
                        freePages = Int(value?.replacingOccurrences(of: ".", with: "") ?? "0") ?? 0
                    } else if line.contains("Pages active:") {
                        let value = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
                        if let active = Int(value?.replacingOccurrences(of: ".", with: "") ?? "0") {
                            totalPages += active
                        }
                    } else if line.contains("Pages inactive:") {
                        let value = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
                        if let inactive = Int(value?.replacingOccurrences(of: ".", with: "") ?? "0") {
                            totalPages += inactive
                        }
                    } else if line.contains("Pages wired:") {
                        let value = line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
                        if let wired = Int(value?.replacingOccurrences(of: ".", with: "") ?? "0") {
                            totalPages += wired
                        }
                    }
                }

                guard totalPages > 0 else {
                    print("Invalid memory page data")
                    return 0.0
                }

                let pageSize = 4096
                let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
                let usedMemory = totalMemory - (Double(freePages * pageSize))
                let usage = (usedMemory / totalMemory) * 100
                return min(max(usage, 0.0), 100.0) // 限制范围
            }
        } catch {
            print("Error getting memory usage: \(error)")
            return 0.0
        }

        return 0.0
    }

    private func getTemperature() -> String {
        guard FileManager.default.fileExists(atPath: "/usr/sbin/ioreg") else {
            print("ioreg command not available")
            return "N/A"
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        task.arguments = ["-c", "AppleSMC", "-r"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()

            // 添加超时机制
            let timeoutDate = Date().addingTimeInterval(3.0)
            while task.isRunning && Date() < timeoutDate {
                usleep(100000) // 0.1秒
            }

            if task.isRunning {
                task.terminate()
                print("Temperature task timed out")
                return "N/A"
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n")
                for line in lines {
                    if line.contains("TC0C") || line.contains("TC0P") {
                        let parts = line.split(separator: " ")
                        for i in 0..<parts.count - 1 {
                            if parts[i] == "value" && i + 1 < parts.count {
                                let valueStr = parts[i + 1].replacingOccurrences(of: "\"", with: "")
                                if let value = Double(valueStr), value > 0 && value < 150 {
                                    return String(format: "%.1f°C", value)
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("Error getting temperature: \(error)")
            return "N/A"
        }

        return "N/A"
    }

    private func getUptime() -> String {
        guard FileManager.default.fileExists(atPath: "/usr/bin/uptime") else {
            print("uptime command not available")
            return "N/A"
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/uptime")
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()

            // 添加超时机制
            let timeoutDate = Date().addingTimeInterval(2.0)
            while task.isRunning && Date() < timeoutDate {
                usleep(100000) // 0.1秒
            }

            if task.isRunning {
                task.terminate()
                print("Uptime task timed out")
                return "N/A"
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n")
                if let firstLine = lines.first {
                    let parts = firstLine.split(separator: " ")
                    if parts.count > 2 {
                        return String(parts[2]).replacingOccurrences(of: ",", with: "")
                    }
                }
            }
        } catch {
            print("Error getting uptime: \(error)")
            return "N/A"
        }

        return "N/A"
    }
}