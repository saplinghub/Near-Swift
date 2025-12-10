import SwiftUI
import Cocoa

extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        // 验证十六进制字符串
        guard !cleanHex.isEmpty,
              cleanHex.allSatisfy({ "0123456789ABCDEFabcdef".contains($0) }),
              [3, 6, 8].contains(cleanHex.count) else {
            // 无效输入时使用默认颜色（黑色）
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
            return
        }

        var int: UInt64 = 0
        guard Scanner(string: cleanHex).scanHexInt64(&int) else {
            // 扫描失败时使用默认颜色
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
            return
        }

        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:
            // RGB 格式：#RGB -> #RRGGBB
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            // RRGGBB 格式
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            // AARRGGBB 格式
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            // 理论上不会到达这里，但保险起见
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

extension Color {
    // 主题色
    static let nearPrimary = Color(hex: "#6366F1")
    static let nearPrimaryDark = Color(hex: "#4F46E5")
    static let nearSecondary = Color(hex: "#8B5CF6")
    
    // 背景色
    static let nearBackgroundStart = Color(hex: "#FAFBFF")
    static let nearBackgroundEnd = Color(hex: "#F1F5F9")
    
    // 文本色
    static let nearTextPrimary = Color(hex: "#1E293B")
    static let nearTextSecondary = Color(hex: "#64748B")
    static let nearTextLight = Color(hex: "#CBD5E1")
    
    // 功能色
    static let nearHoverRed = Color(hex: "#EF4444")
    static let nearHoverRedBg = Color(hex: "#FEF2F2")
    static let nearHoverBlueBg = Color(hex: "#EEF2FF")
}

extension NSColor {
    convenience init(hex: String) {
        let color = Color(hex: hex)
        self.init(color)
    }
}