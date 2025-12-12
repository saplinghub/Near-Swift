import SwiftUI
import Combine

struct CalendarView: View {
    @EnvironmentObject var aiService: AIService
    @State private var viewMode: Int = 0 // 0: Almanac (黄历), 1: Calendar (日历)
    @State private var almanac: AlmanacResponse?
    @State private var currentDate = Date()
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 16) {
            // Mode Switcher
            Picker("Mode", selection: $viewMode) {
                Text("今日黄历").tag(0)
                Text("月历").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 40)
            .padding(.top, 4)
            
            if viewMode == 0 {
                // Almanac View
                almanacView
            } else {
                // Calendar View
                customCalendarView
            }
        }
        .padding(.bottom, 20)
        .onAppear {
            loadAlmanac()
        }
    }
    
    // MARK: - Almanac View
    private var almanacView: some View {
        VStack(spacing: 20) {
            if let almanac = almanac {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Date Header
                        VStack(spacing: 8) {
                            Text(almanac.date)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.nearTextPrimary)
                            Text("农历 " + almanac.lunarDate)
                                .font(.system(size: 16))
                                .foregroundColor(.nearTextSecondary)
                        }
                        
                        // Yi / Ji Cards
                        HStack(alignment: .top, spacing: 16) {
                            // Yi (Suitable)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("宜")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                }
                                Text(almanac.yi)
                                    .font(.body)
                                    .foregroundColor(.nearTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(12)
                            
                            // Ji (Unsuitable)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("忌")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                Text(almanac.ji)
                                    .font(.body)
                                    .foregroundColor(.nearTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(12)
                        }
                        
                        // Fortune
                        VStack(spacing: 12) {
                            Text("今日运势")
                                .font(.headline)
                                .foregroundColor(.nearPrimary)
                            
                            Text(almanac.fortune)
                                .font(.system(size: 16, weight: .medium))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.nearTextPrimary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(gradient: Gradient(colors: [Color.nearPrimary.opacity(0.1), Color.nearPrimary.opacity(0.05)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.nearPrimary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Refresh Button
                        Button(action: {
                            refreshAlmanac()
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("AI 刷新运势")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.nearPrimary.opacity(0.1))
                            .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.nearPrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            } else if aiService.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("AI 正在推算今日运势...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .frame(maxHeight: .infinity)
            } else {
                // Empty / Error State
                VStack(spacing: 16) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.nearSecondary)
                    Text("暂无黄历信息")
                    Button("获取今日运势") {
                        refreshAlmanac()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Custom Calendar View
    private var customCalendarView: some View {
        VStack {
            // Month Header
            HStack {
                Text(currentDate.monthYearString())
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                HStack(spacing: 20) {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(.nearPrimary)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            
            // Weekday Headers
            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            
            // Days Grid
            let days = currentDate.daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                // Empty specs for start offset
                ForEach(0..<currentDate.firstWeekdayOfMonth() - 1, id: \.self) { _ in
                    Color.clear
                        .frame(height: 30)
                }
                
                ForEach(days, id: \.self) { date in
                    let isToday = Calendar.current.isDateInToday(date)
                    let isWeekend = Calendar.current.isDateInWeekend(date)
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                        .foregroundColor(isToday ? .white : (isWeekend ? .secondary : .primary))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isToday ? Color.nearPrimary : Color.clear)
                        )
                }
            }
            .padding(.horizontal, 10)
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Logic
    
    private func loadAlmanac() {
        // Try load from UserDefaults
        let key = "Almanac_" + DateFormatter.yyyyMMdd.string(from: Date())
        if let data = UserDefaults.standard.data(forKey: key),
           let cached = try? JSONDecoder().decode(AlmanacResponse.self, from: data) {
            self.almanac = cached
            return
        }
        
        // Fetch new
        refreshAlmanac()
    }
    
    private func refreshAlmanac() {
        aiService.fetchAlmanac(date: Date())
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                self.almanac = response
                // Save to cache
                if let data = try? JSONEncoder().encode(response) {
                     let key = "Almanac_" + DateFormatter.yyyyMMdd.string(from: Date())
                     UserDefaults.standard.set(data, forKey: key)
                }
            })
            .store(in: &cancellables)
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
}

// Helpers
extension Date {
    func monthYearString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: self)
    }
    
    func daysInMonth() -> [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: self),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: self)) else {
            return []
        }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    func firstWeekdayOfMonth() -> Int {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: self)) else {
            return 1
        }
        return calendar.component(.weekday, from: startOfMonth)
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
