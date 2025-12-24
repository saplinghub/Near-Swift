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
                    // Compact Mode for Calendars
                    HStack(spacing: 4) {
                        Image(systemName: weatherIcon(code: weather.current.icon))
                            .font(.system(size: 14))
                            .foregroundColor(.nearPrimary)
                        Text("\(weather.current.temp)°")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.nearTextPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(20)
                } else {
                    // Standard Mode - Enhanced Aesthetics
                    HStack(spacing: 12) {
                        // Left: Icon + Temp (Fixed Width to prevent squeezing center)
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.nearPrimary.opacity(0.1), Color.nearPrimary.opacity(0.02)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: weatherIcon(code: weather.current.icon))
                                    .font(.system(size: 20))
                                    .foregroundColor(.nearPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(weather.current.temp)°")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(.nearTextPrimary)
                                
                                if let today = weather.forecast.first {
                                    Text("\(today.tempMin)°/\(today.tempMax)°")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.nearTextSecondary)
                                }
                                
                                Text(weather.current.text)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.nearPrimary)
                            }
                        }
                        .frame(width: 90, alignment: .leading)
                        
                        Divider().frame(height: 30)
                        
                        // Center Area - Expansion Allowed
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.nearSecondary)
                                Text(weather.cityName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.nearSecondary)
                            }
                            
                            if let summary = weather.minutelySummary {
                                Text(summary)
                                    .font(.system(size: 10))
                                    .foregroundColor(.nearTextSecondary)
                                    .lineLimit(1)
                            }
                            
                            HStack(spacing: 8) {
                                // Air Quality from new airNow source
                                if let air = weather.airNow {
                                    Text(formatAirQuality(air.category))
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(aqiColor(level: air.level).opacity(0.1))
                                        .foregroundColor(aqiColor(level: air.level))
                                        .cornerRadius(4)
                                        .help("空气质量: \(air.category) (AQI: \(air.aqi))")
                                }
                                
                                // UV (Now comes from daily forecast as indices/1d type 6 is removed, or check if still requested)
                                // Actually, I removed type 6 from fetchIndices and didn't add uv back to header? 
                                // User said: "生活建议不需要这么多，只需要四个即可，运动、穿衣、旅游、钓鱼"
                                // And indices/1d?type=1,3,5,8 was requested. So UV isn't in indices anymore.
                                // We can use UV from daily forecast if needed, but for now focus on Air Quality as requested.
                            }
                        }
                        
                        Spacer()
                        
                        // Right: Forecast Mini
                        HStack(spacing: 12) {
                            ForEach(weather.forecast.prefix(2)) { day in
                                VStack(spacing: 4) {
                                    Text(dayLabel(for: day.fxDate))
                                        .font(.system(size: 9))
                                        .foregroundColor(.nearTextSecondary)
                                    Image(systemName: weatherIcon(code: day.iconDay))
                                        .font(.system(size: 14))
                                        .foregroundColor(.nearPrimary.opacity(0.8))
                                    Text("\(day.tempMax)°")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.nearTextPrimary)
                                }
                                .frame(width: 32)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.5))
                            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
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
    
    private func dayLabel(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            if Calendar.current.isDateInToday(date) { return "今天" }
            if Calendar.current.isDateInTomorrow(date) { return "明天" }
            formatter.dateFormat = "E"
            return formatter.string(from: date)
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
