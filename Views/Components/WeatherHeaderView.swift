import SwiftUI

struct WeatherHeaderView: View {
    @EnvironmentObject var weatherService: WeatherService
    var isCompact: Bool = false
    
    var body: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            if weatherService.isLoading {
                ProgressView().scaleEffect(isCompact ? 0.5 : 0.7)
            } else if let weather = weatherService.weather {
                if isCompact {
                    // Refined Pill Mode for Calendars
                    HStack(spacing: 6) {
                        Image(systemName: weatherIcon(code: weather.current.icon))
                            .font(.system(size: 14))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.nearPrimary)
                        
                        HStack(spacing: 2) {
                            Text("\(weather.current.temp)°")
                                .font(.system(size: 14, weight: .bold))
                            
                            Text(weather.current.text)
                                .font(.system(size: 12))
                                .foregroundColor(.nearTextSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
                } else {
                    // Standard Mode - Enhanced Aesthetics
                    // Standard Mode - Sophisticated Multi-Segment Layout
                    HStack(alignment: .center, spacing: 0) {
                        // 1. Core Weather (Fixed presence, flexible width)
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.nearPrimary.opacity(0.12), Color.nearPrimary.opacity(0.04)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 42, height: 42)
                                
                                Image(systemName: weatherIcon(code: weather.current.icon))
                                    .font(.system(size: 20))
                                    .foregroundColor(.nearPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text("\(weather.current.temp)")
                                        .font(.system(size: 32, weight: .black))
                                    Text("°")
                                        .font(.system(size: 20, weight: .bold))
                                }
                                .foregroundColor(.nearTextPrimary)
                                
                                if let today = weather.forecast.first {
                                    Text("\(today.tempMin)°/\(today.tempMax)° · \(weather.current.text)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.nearPrimary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .frame(minWidth: 100, alignment: .leading)
                        .layoutPriority(2) // Core info gets highest priority
                        
                        Divider().frame(height: 30).padding(.horizontal, 12)
                        
                        // 2. Location & Forecast Summary (Flexible)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.nearSecondary)
                                Text(weather.cityName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.nearSecondary)
                                    .lineLimit(1)
                            }
                            
                            if let summary = weather.minutelySummary {
                                Text(summary)
                                    .font(.system(size: 10))
                                    .foregroundColor(.nearTextSecondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                                    .help(summary) // Added hover tooltip for full content
                            }
                            
                            if let air = weather.airNow {
                                Text(formatAirQuality(air.category))
                                    .font(.system(size: 8, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(aqiColor(level: air.level).opacity(0.1))
                                    .foregroundColor(aqiColor(level: air.level))
                                    .cornerRadius(3)
                            }
                        }
                        .layoutPriority(1) // Middle content can shrink first
                        
                        Spacer(minLength: 12)
                        
                        // 3. Mini Forecast List
                        HStack(spacing: 10) {
                            ForEach(weather.forecast.prefix(2)) { day in
                                VStack(spacing: 4) {
                                    Text(dayLabel(for: day.fxDate))
                                        .font(.system(size: 9))
                                        .foregroundColor(.nearTextSecondary)
                                    Image(systemName: weatherIcon(code: day.iconDay))
                                        .font(.system(size: 13))
                                        .foregroundColor(.nearPrimary.opacity(0.8))
                                    Text("\(day.tempMax)°")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.nearTextPrimary)
                                }
                                .frame(width: 32)
                            }
                        }
                        .layoutPriority(0.5) // Right items are nice to have
                    }
                    .padding(16)
                    .background(.ultraThinMaterial.opacity(0.2)) // Unified glass effect
                    .cornerRadius(20)
                }
            } else {
                Text(weatherService.errorMessage ?? "未配置")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if weatherService.weather == nil {
                weatherService.fetchWeather()
            }
        }
    }
    
    // Mapping QWeather codes to SF Symbols
    private func weatherIcon(code: String) -> String {
        switch code {
        case "100": return "sun.max.fill"
        case "101", "102", "103": return "cloud.sun.fill"
        case "104": return "cloud.fill"
        case "150": return "moon.stars.fill"
        case "300", "301": return "cloud.sun.rain.fill"
        case "305", "306", "307": return "cloud.heavyrain.fill"
        case "400", "401": return "cloud.snow.fill"
        default: return "cloud.fill"
        }
    }
    
    private func getTimeString() -> String {
        let formatter = SharedUtils.dateFormatter(format: "HH:mm")
        return formatter.string(from: Date())
    }
    
    private func dayLabel(for dateString: String) -> String {
        let formatter = SharedUtils.dateFormatter(format: "yyyy-MM-dd")
        if let date = formatter.date(from: dateString) {
            if Calendar.current.isDateInToday(date) { return "今天" }
            if Calendar.current.isDateInTomorrow(date) { return "明天" }
            let dayFormatter = SharedUtils.dateFormatter(format: "E")
            return dayFormatter.string(from: date)
        }
        return ""
    }

    private func formatAirQuality(_ raw: String) -> String {
        if raw.contains("优") || raw.contains("好") || raw.contains("极好") { return "空气 优" }
        if raw.contains("良") || raw.contains("各适宜") || raw.contains("较好") { return "空气 良" }
        if raw.contains("中") || raw.contains("一般") { return "轻度污染" }
        if raw.contains("差") || raw.contains("不宜") { return "中度污染" }
        if raw.contains("极差") { return "重度污染" }
        return "空气 \(raw)"
    }
    
    private func aqiColor(level: String) -> Color {
        switch level {
        case "1": return .green
        case "2": return .yellow
        case "3": return .orange
        case "4": return .red
        case "5": return .purple
        case "6": return .brown
        default: return .secondary
        }
    }
}
