import SwiftUI

struct SystemView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // CPU Section
                SystemCard(title: "CPU", icon: "cpu", color: .nearPrimary) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("负载")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            Spacer()
                            Text(String(format: "%.1f%%", systemMonitor.cpuUsage * 100))
                                .fontWeight(.bold)
                                .foregroundColor(.nearPrimary)
                        }
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(LinearGradient(gradient: Gradient(colors: [.nearPrimary, .nearHoverBlueBg]), startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geometry.size.width * CGFloat(systemMonitor.cpuUsage), height: 8)
                                    .animation(.spring(), value: systemMonitor.cpuUsage)
                            }
                        }
                        .frame(height: 8)
                        
                        Divider().padding(.vertical, 4)
                        
                        HStack {
                            Text("温度 (估算)")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            Spacer()
                            Text("\(String(format: "%.1f", systemMonitor.cpuTemperature))°C")
                                .font(.system(size: 12, weight: .bold))
                            
                            Text(systemMonitor.thermalState)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(thermalColor(state: systemMonitor.thermalState))
                        }
                    }
                }
                
                // Memory Section
                SystemCard(title: "内存", icon: "memorychip", color: .purple) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("已用 / 总计")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            Spacer()
                            Text(String(format: "%.1f GB / %.1f GB", systemMonitor.memoryUsage.used, systemMonitor.memoryUsage.total))
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        
                        let progress = systemMonitor.memoryUsage.total > 0 ? systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total : 0
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                                    .animation(.spring(), value: progress)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                
                // Disk Section
                SystemCard(title: "磁盘", icon: "internaldrive", color: .orange) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("已用")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            Spacer()
                            Text(String(format: "%.1f GB", systemMonitor.diskUsage.used))
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        
                        HStack {
                            Text("剩余")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            Spacer()
                            Text(String(format: "%.1f GB", systemMonitor.diskUsage.total - systemMonitor.diskUsage.used))
                                .font(.system(size: 12))
                        }
                        
                        let progress = systemMonitor.diskUsage.total > 0 ? systemMonitor.diskUsage.used / systemMonitor.diskUsage.total : 0
                         
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(LinearGradient(gradient: Gradient(colors: [.orange, .yellow]), startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                                    .animation(.spring(), value: progress)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
            .padding(.top, 16)
        }
    }
    
    func thermalColor(state: String) -> Color {
        switch state {
        case "正常": return .green
        case "温热": return .orange
        case "过热": return .red
        case "严重过热": return .purple
        default: return .secondary
        }
    }
}

struct SystemCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.nearTextPrimary)
            }
            
            content
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
