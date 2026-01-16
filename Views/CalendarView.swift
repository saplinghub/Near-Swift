import SwiftUI
import Combine

struct CalendarView: View {
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var countdownManager: CountdownManager
    @EnvironmentObject var weatherService: WeatherService
    @AppStorage("calendarViewMode") private var viewMode: Int = 0
    @State private var almanac: AlmanacResponse?
    @State private var currentDate = Date()
    @State private var selectedDate: Date? = nil
    @State private var selectedHoliday: HolidayInfo? = nil
    @State private var selectedCountdown: CountdownEvent? = nil
    @State private var cancellables = Set<AnyCancellable>()
    
    // Holiday info with description
    struct HolidayInfo: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let isLunar: Bool
    }
    
    // Solar holidays with descriptions
    private let solarHolidays: [String: HolidayInfo] = [
        "01-01": HolidayInfo(name: "元旦", description: "新年第一天，法定假日。庆祝新一年的开始，辞旧迎新。", isLunar: false),
        "02-14": HolidayInfo(name: "情人节", description: "西方情人节，表达爱意的日子。情侣们互赠礼物，共度浪漫时光。", isLunar: false),
        "03-08": HolidayInfo(name: "妇女节", description: "国际劳动妇女节，纪念女性权益运动。部分女性员工可享受半天假期。", isLunar: false),
        "03-12": HolidayInfo(name: "植树节", description: "中国植树节，倡导植树造林，保护生态环境。", isLunar: false),
        "04-01": HolidayInfo(name: "愚人节", description: "西方节日，可以开善意玩笑的日子。注意分寸，保持友好。", isLunar: false),
        "04-04": HolidayInfo(name: "清明节", description: "传统祭祖扫墓的日子，也是踏青郊游的好时节。法定假日。", isLunar: false),
        "04-05": HolidayInfo(name: "清明节", description: "传统祭祖扫墓的日子，也是踏青郊游的好时节。法定假日。", isLunar: false),
        "05-01": HolidayInfo(name: "劳动节", description: "国际劳动节，向全世界劳动者致敬。法定假日。", isLunar: false),
        "05-04": HolidayInfo(name: "青年节", description: "纪念五四运动，弘扬爱国、进步、民主、科学精神。部分青年可享受半天假期。", isLunar: false),
        "06-01": HolidayInfo(name: "儿童节", description: "国际儿童节，关爱儿童，保障儿童权益。儿童可享受假期。", isLunar: false),
        "08-01": HolidayInfo(name: "建军节", description: "中国人民解放军建军纪念日，向军人致敬。", isLunar: false),
        "09-10": HolidayInfo(name: "教师节", description: "尊师重教，感谢老师的辛勤付出。", isLunar: false),
        "10-01": HolidayInfo(name: "国庆节", description: "中华人民共和国国庆日，庆祝祖国生日。法定假日，举国欢庆。", isLunar: false),
        "10-31": HolidayInfo(name: "万圣节", description: "西方传统节日，孩子们会装扮成各种角色进行 Trick or Treat 活动。", isLunar: false),
        "11-11": HolidayInfo(name: "双十一", description: "原为光棍节，现已成为全球最大的网络购物狂欢节。", isLunar: false),
        "12-13": HolidayInfo(name: "国家公祭日", description: "南京大屠杀死难者国家公祭日，铭记历史，珍爱和平。", isLunar: false),
        "12-24": HolidayInfo(name: "平安夜", description: "圣诞节前夜，西方传统节日。人们互赠礼物，共度温馨时光。", isLunar: false),
        "12-25": HolidayInfo(name: "圣诞节", description: "西方重要节日，庆祝耶稣诞生。装饰圣诞树，交换礼物。", isLunar: false)
    ]
    
    // Lunar holidays with lunar month/day
    private let lunarHolidays: [(month: Int, day: Int, name: String, description: String)] = [
        (12, 8, "腊八节", "农历腊月初八，喝腊八粥，祈求丰收和吉祥。"),
        (1, 1, "春节", "农历新年，中国最重要的传统节日。拜年、发红包、放烟花。法定假日。"),
        (1, 15, "元宵节", "正月十五，赏花灯、吃元宵、猜灯谜。"),
        (2, 2, "龙抬头", "二月二龙抬头，传统上这天理发会带来好运。"),
        (5, 5, "端午节", "纪念屈原，吃粽子、赛龙舟。法定假日。"),
        (7, 7, "七夕节", "中国情人节，牛郎织女相会的日子。"),
        (7, 15, "中元节", "祭祀祖先、超度亡魂的传统节日。"),
        (8, 15, "中秋节", "团圆节，赏月、吃月饼。法定假日。"),
        (9, 9, "重阳节", "登高望远、敬老爱老的传统节日。")
    ]
    
    var body: some View {
            VStack(spacing: 12) {
                NearTabPicker(items: ["黄历", "月历", "天气"], selection: $viewMode)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
                
                if viewMode == 0 {
                    almanacView
                } else if viewMode == 1 {
                    customCalendarView
                } else {
                    weatherDetailsView
                }
            }
            .padding(.bottom, 20)
        .padding(.bottom, 20)
        .onAppear {
            loadAlmanac()
            selectToday()
        }
    }
    
    private func selectToday() {
        let today = Date()
        selectedDate = today
        selectedHoliday = getHoliday(for: today)
        selectedCountdown = getCountdown(for: today)
    }
    
    // MARK: - Almanac View
    private var almanacView: some View {
        VStack(spacing: 20) {
            if let almanac = almanac {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text(almanac.date)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.nearTextPrimary)
                            Text(LunarCalendar.getLunarDateString(for: Date()))
                                .font(.system(size: 16))
                                .foregroundColor(.nearTextSecondary)
                            
                            // Integrated Weather Info
                            if let weather = weatherService.weather {
                                HStack(spacing: 8) {
                                    Image(systemName: weatherIcon(code: weather.current.icon))
                                        .font(.system(size: 14))
                                        .foregroundColor(.nearPrimary)
                                    
                                    Text("\(weather.current.text) \(weather.current.temp)°C")
                                        .font(.system(size: 14, weight: .medium))
                                    
                                    Text("·")
                                        .foregroundColor(.nearTextSecondary.opacity(0.3))
                                    
                                    Text("湿度 \(weather.current.humidity)%")
                                        .font(.system(size: 12))
                                        .foregroundColor(.nearTextSecondary)
                                    
                                    if let air = weather.airNow {
                                        Text("·")
                                            .foregroundColor(.nearTextSecondary.opacity(0.3))
                                        Text("空气 \(air.category)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.nearTextSecondary)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        HStack(alignment: .top, spacing: 16) {
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
                        
                        VStack(spacing: 12) {
                            Text("✨ 今日运势")
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
                        
                        Button(action: { refreshAlmanac() }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("刷新黄历")
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
                    ProgressView().scaleEffect(1.5)
                    Text("AI 正在推算今日运势...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.nearSecondary)
                    Text("暂无黄历信息")
                    Button("获取今日运势") { refreshAlmanac() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Custom Calendar View
    private var customCalendarView: some View {
        VStack(spacing: 0) {
            // Month Header
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left").font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                Text(currentDate.monthYearString())
                    .font(.title2).fontWeight(.bold)
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right").font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .foregroundColor(.nearPrimary)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Weekday Headers
            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption).fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
            
            // Days Grid
            let days = currentDate.daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(0..<currentDate.firstWeekdayOfMonth() - 1, id: \.self) { _ in
                    Color.clear.frame(height: 48)
                }
                
                ForEach(days, id: \.self) { date in
                    calendarDayCell(for: date)
                }
            }
            .padding(.horizontal, 4)
            
            // Info Panel
            infoPanelView
            
            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    private func calendarDayCell(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isWeekend = Calendar.current.isDateInWeekend(date)
        let holiday = getHoliday(for: date)
        let countdown = getCountdown(for: date)
        let isSelected = selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!)
        
        return Button(action: {
            selectedDate = date
            selectedHoliday = holiday
            selectedCountdown = countdown
        }) {
            VStack(spacing: 1) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(isToday ? .white : (isWeekend ? .nearPrimary : .primary))
                
                // Holiday name (truncated) or dots
                if let h = holiday {
                    Text(h.name.prefix(2))
                        .font(.system(size: 8))
                        .foregroundColor(isToday ? .white.opacity(0.9) : .nearPrimary)
                        .lineLimit(1)
                } else {
                    Color.clear.frame(height: 10)
                }
                
                // Indicator dots
                HStack(spacing: 2) {
                    if holiday != nil {
                        Circle().fill(Color.nearPrimary).frame(width: 4, height: 4)
                    }
                    if countdown != nil {
                        Circle().fill(Color.orange).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle()) // Makes entire area tappable
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isToday ? Color.nearPrimary : (isSelected ? Color.nearPrimary.opacity(0.15) : Color.clear))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var infoPanelView: some View {
        Group {
            if let selected = selectedDate {
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Date + Lunar Date
                        HStack {
                            let dateStr = SharedUtils.dateFormatter(format: "yyyy年M月d日").string(from: selected)
                            Text(dateStr)
                                .font(.subheadline)
                                .foregroundColor(.nearTextPrimary)
                            Text(LunarCalendar.getLunarDateString(for: selected))
                                .font(.subheadline)
                                .foregroundColor(.nearSecondary)
                        }
                        
                        // Holiday
                        if let holiday = selectedHoliday {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.nearPrimary)
                                    Text(holiday.name)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(.nearTextPrimary)
                                }
                                Text(holiday.description)
                                    .font(.caption)
                                    .foregroundColor(.nearTextSecondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        // Countdown
                        if let countdown = selectedCountdown {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundColor(.orange)
                                    Text(countdown.name)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(.nearTextPrimary)
                                    Image(systemName: countdown.icon.sfSymbol)
                                        .foregroundColor(Color(hex: countdown.icon.color))
                                }
                                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: countdown.targetDate).day ?? 0
                                Text(daysLeft > 0 ? "还有 \(daysLeft) 天" : (daysLeft == 0 ? "就是今天！" : "已过 \(-daysLeft) 天"))
                                    .font(.caption)
                                    .foregroundColor(.nearTextSecondary)
                            }
                        }
                        
                        if selectedHoliday == nil && selectedCountdown == nil {
                            Text("今日暂无特殊安排。")
                                .font(.caption)
                                .foregroundColor(.nearTextSecondary.opacity(0.5))
                                .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Compact Weather in Corner
                    if let weather = weatherService.weather,
                       let dayForecast = weather.forecast.first(where: { $0.fxDate == DateFormatter.yyyyMMdd.string(from: selected) }) {
                        HStack(spacing: 4) {
                            Image(systemName: weatherIcon(code: dayForecast.iconDay))
                                .font(.system(size: 14))
                                .foregroundColor(.nearPrimary)
                            Text("\(dayForecast.tempMin)°/\(dayForecast.tempMax)°")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.nearTextPrimary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.nearPrimary.opacity(0.05))
                        .cornerRadius(8)
                        .padding(12)
                    }
                }
                .background(Color.white.opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getHoliday(for date: Date) -> HolidayInfo? {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Check solar holidays
        let key = String(format: "%02d-%02d", month, day)
        if let solar = solarHolidays[key] {
            return solar
        }
        
        // Check lunar holidays
        for lunar in lunarHolidays {
            if let holidayDate = LunarCalendar.getLunarHolidayDate(year: year, lunarMonth: lunar.month, lunarDay: lunar.day) {
                if calendar.isDate(date, inSameDayAs: holidayDate) {
                    return HolidayInfo(name: lunar.name, description: lunar.description, isLunar: true)
                }
            }
        }
        
        return nil
    }
    
    private func getCountdown(for date: Date) -> CountdownEvent? {
        let calendar = Calendar.current
        for countdown in countdownManager.countdowns {
            if calendar.isDate(countdown.targetDate, inSameDayAs: date) {
                return countdown
            }
        }
        return nil
    }
    
    private func loadAlmanac() {
        let key = "Almanac_" + DateFormatter.yyyyMMdd.string(from: Date())
        if let data = UserDefaults.standard.data(forKey: key),
           let cached = try? JSONDecoder().decode(AlmanacResponse.self, from: data) {
            self.almanac = cached
            return
        }
        refreshAlmanac()
    }
    
    private func refreshAlmanac() {
        aiService.fetchAlmanac()
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                self.almanac = response
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
            selectedDate = nil
            selectedHoliday = nil
            selectedCountdown = nil
        }
    }

    // MARK: - Weather Details View
    private var weatherDetailsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) { // More breathing room
                // Main Weather Card - Seamlessly integrated
                WeatherHeaderView(isCompact: false)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                
                if let weather = weatherService.weather {
                    // Highlights Section - Glassy
                    HStack(spacing: 12) {
                        WeatherStatBox(title: "湿度", value: "\(weather.current.humidity)%", icon: "humidity.fill", color: .blue)
                        WeatherStatBox(title: "风力", value: "\(weather.current.windScale)级", icon: "wind", color: .green)
                        WeatherStatBox(title: "能见度", value: "良好", icon: "eye.fill", color: .orange)
                    }
                    .padding(.horizontal, 24)

                    // Indices Grid - Integrated
                    VStack(alignment: .leading, spacing: 12) {
                        Text("💡 生活建议")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.nearTextPrimary)
                            .padding(.horizontal, 24)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            let selectedTypes = ["1", "3", "5", "8"]
                            ForEach(weather.indices.filter { selectedTypes.contains($0.type) }) { index in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(index.name)
                                            .font(.system(size: 12, weight: .bold))
                                        Spacer()
                                        Text(index.category)
                                            .font(.system(size: 10))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.nearPrimary.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    Text(index.text)
                                        .font(.system(size: 11))
                                        .foregroundColor(.nearTextSecondary)
                                        .lineLimit(3)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Forecast - Seamless
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📅 近期预报")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.nearTextPrimary)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 8) {
                            ForEach(weather.forecast) { day in
                                HStack {
                                    Text(dayLabel(for: day.fxDate))
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: weatherIcon(code: day.iconDay))
                                            .font(.system(size: 14))
                                            .foregroundColor(.nearPrimary)
                                        Text(day.textDay)
                                            .font(.system(size: 12))
                                            .foregroundColor(.nearTextSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 12) {
                                        Text("\(day.tempMin)°").foregroundColor(.nearTextSecondary)
                                        Text("\(day.tempMax)°").fontWeight(.bold)
                                    }
                                    .font(.system(size: 12, design: .monospaced))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial.opacity(0.5))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    struct WeatherStatBox: View {
        let title: String
        let value: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                VStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 14, weight: .bold))
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial.opacity(0.3))
            .cornerRadius(16)
        }
    }
    
    private func dayLabel(for dateString: String) -> String {
        let inputFormatter = SharedUtils.dateFormatter(format: "yyyy-MM-dd")
        if let date = inputFormatter.date(from: dateString) {
            if SharedUtils.calendar.isDateInToday(date) { return "今天" }
            if SharedUtils.calendar.isDateInTomorrow(date) { return "明天" }
            return SharedUtils.dateFormatter(format: "EEEE").string(from: date)
        }
        return dateString
    }
    
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
}

// MARK: - Extensions
extension Date {
    func monthYearString() -> String {
        return SharedUtils.dateFormatter(format: "yyyy年MM月").string(from: self)
    }
    
    func daysInMonth() -> [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: self),
              let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: self)) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
    }
    
    func firstWeekdayOfMonth() -> Int {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: self)) else { return 1 }
        return calendar.component(.weekday, from: startOfMonth)
    }
}

extension DateFormatter {
    static var yyyyMMdd: DateFormatter {
        return SharedUtils.dateFormatter(format: "yyyy-MM-dd")
    }
}
