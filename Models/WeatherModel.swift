import Foundation

/// QWeather (和风天气) Data Models

// MARK: - Core Weather Data
struct WeatherNowResponse: Codable {
    let code: String
    let now: WeatherNow?
}

struct WeatherNow: Codable {
    let obsTime: String      // Observation time
    let temp: String         // Temperature
    let feelsLike: String    // Feels like temperature
    let icon: String         // Weather condition icon code
    let text: String         // Weather condition text
    let windDir: String      // Wind direction
    let windScale: String    // Wind scale
    let humidity: String     // Humidity percentage
    let precip: String       // Precipitation
    let pressure: String     // Atmospheric pressure
}

// MARK: - Daily Forecast
struct WeatherDailyResponse: Codable {
    let code: String
    let daily: [DailyForecast]?
}

struct DailyForecast: Codable, Identifiable {
    var id: String { fxDate }
    let fxDate: String       // Forecast date
    let tempMax: String      // Maximum temperature
    let tempMin: String      // Minimum temperature
    let iconDay: String      // Weather icon during day
    let textDay: String      // Weather text during day
    let uvIndex: String?     // UV Index (Optionally from daily)
}

// MARK: - Hourly Forecast
struct WeatherHourlyResponse: Codable {
    let code: String
    let hourly: [HourlyForecast]?
}

struct HourlyForecast: Codable, Identifiable {
    var id: String { fxTime }
    let fxTime: String       // Forecast time
    let temp: String         // Temperature
    let icon: String         // Weather icon
    let text: String         // Weather text
}

// MARK: - Minutely Precipitation
struct WeatherMinutelyResponse: Codable {
    let code: String
    let summary: String?
    let minutely: [MinutelyPrecip]?
}

struct MinutelyPrecip: Codable {
    let fxTime: String
    let precip: String
    let type: String
}

// MARK: - Life Indices
struct WeatherIndicesResponse: Codable {
    let code: String
    let daily: [WeatherIndex]?
}

struct WeatherIndex: Codable, Identifiable {
    var id: String { type }
    let date: String
    let type: String         // Index type code
    let name: String         // Index name
    let level: String        // Index level
    let category: String     // Index category name
    let text: String         // Index description
}

// MARK: - Air Quality
struct AirNowResponse: Codable {
    let code: String
    let now: AirNow?
}

struct AirNow: Codable {
    let pubTime: String
    let aqi: String
    let level: String
    let category: String
    let primary: String
    let pm10: String
    let pm2p5: String
    let no2: String
    let so2: String
    let co: String
    let o3: String
}

// MARK: - Geo API
struct GeoLookupResponse: Codable {
    let code: String
    let location: [LocationInfo]?
}

struct LocationInfo: Codable, Identifiable {
    var id: String           // Location ID
    let name: String         // Location name
    let lat: String          // Latitude
    let lon: String          // Longitude
    let adm2: String         // Second-level administrative division (District/City)
    let adm1: String         // First-level administrative division (Province/State)
    let country: String      // Country
    let tz: String?          // Timezone (Optional for robustness)
    let utcOffset: String?   // UTC offset (Optional for robustness)
    let isDst: String?       // Is daylight saving time
    let type: String         // Location type (e.g., city)
    let rank: String?        // Location rank (Optional for robustness)
    let fxLink: String?      // Forecast link (Optional for robustness)
}

// MARK: - App Domain Model
struct WeatherData {
    let current: WeatherNow
    let forecast: [DailyForecast]
    let hourly: [HourlyForecast]
    let indices: [WeatherIndex]
    let minutelySummary: String?
    let airNow: AirNow?         // Can be nil if new API fails or is used instead
    let locationId: String
    let cityName: String
    let updateTime: Date
}
