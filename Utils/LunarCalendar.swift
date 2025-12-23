import Foundation

/// Chinese Lunar Calendar Utility
/// Uses Apple's native Calendar API for accurate lunar date conversion
class LunarCalendar {
    
    private static let chineseCalendar = Calendar(identifier: .chinese)
    private static let gregorianCalendar = Calendar(identifier: .gregorian)
    
    // Chinese lunar month names
    private static let monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
    
    // Chinese lunar day names
    private static let dayNames = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]
    
    /// Get lunar date components for a solar date
    static func getLunarComponents(from date: Date) -> (year: Int, month: Int, day: Int, isLeapMonth: Bool) {
        let components = chineseCalendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 1
        let day = components.day ?? 1
        let isLeapMonth = components.isLeapMonth ?? false
        return (year, month, day, isLeapMonth)
    }
    
    /// Get lunar date string for display (e.g., "腊月初八")
    static func getLunarDateString(for date: Date) -> String {
        let lunar = getLunarComponents(from: date)
        
        let monthStr: String
        if lunar.isLeapMonth {
            monthStr = "闰\(monthNames[lunar.month - 1])"
        } else {
            monthStr = monthNames[lunar.month - 1]
        }
        
        let dayStr = lunar.day <= 30 ? dayNames[lunar.day - 1] : "三十"
        
        return "\(monthStr)月\(dayStr)"
    }
    
    /// Get the solar date for a lunar holiday in a given year
    /// - Parameters:
    ///   - year: The Gregorian year to search in
    ///   - lunarMonth: The lunar month (1-12)
    ///   - lunarDay: The lunar day (1-30)
    ///   - isLeapMonth: Whether to look in the leap month
    /// - Returns: The corresponding Gregorian date, or nil if not found
    static func getLunarHolidayDate(year: Int, lunarMonth: Int, lunarDay: Int, isLeapMonth: Bool = false) -> Date? {
        // Strategy: Iterate through all days of the Gregorian year and find matching lunar date
        // This is more reliable than trying to reverse-calculate
        
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        
        guard let startOfYear = gregorianCalendar.date(from: components) else { return nil }
        
        // Search through the entire year plus some buffer for lunar year overlap
        for dayOffset in 0..<400 {
            guard let date = gregorianCalendar.date(byAdding: .day, value: dayOffset, to: startOfYear) else { continue }
            
            let lunar = getLunarComponents(from: date)
            
            // Check if lunar year is reasonable (within 1 year of Gregorian)
            let gregorianYear = gregorianCalendar.component(.year, from: date)
            if gregorianYear > year { break }
            
            if lunar.month == lunarMonth && lunar.day == lunarDay && lunar.isLeapMonth == isLeapMonth {
                return date
            }
        }
        
        return nil
    }
    
    /// Get the solar date for Chinese New Year (正月初一) in a given Gregorian year
    static func getChineseNewYear(year: Int) -> Date? {
        return getLunarHolidayDate(year: year, lunarMonth: 1, lunarDay: 1)
    }
    
    /// Check if a given date is 除夕 (New Year's Eve - the day before 春节)
    static func isChuxi(date: Date) -> Bool {
        guard let tomorrow = gregorianCalendar.date(byAdding: .day, value: 1, to: date) else { return false }
        let lunar = getLunarComponents(from: tomorrow)
        return lunar.month == 1 && lunar.day == 1
    }
    
    /// Get 除夕 date for a given year
    static func getChuxi(year: Int) -> Date? {
        guard let springFestival = getChineseNewYear(year: year) else { return nil }
        return gregorianCalendar.date(byAdding: .day, value: -1, to: springFestival)
    }
}
