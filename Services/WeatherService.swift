import Foundation
import Combine

class WeatherService: ObservableObject {
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    // Default config
    private let baseUrl = "https://devapi.qweather.com/v7"
    private let qWeatherKeyPath = "qWeatherKey"
    
    // Default location (e.g., Beijing)
    private let defaultLocation = "101010100" 
    
    init() {
        startAutoUpdate()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    func startAutoUpdate() {
        // Initial fetch
        fetchWeather()
        
        // Setup timer for every 30 minutes (1800 seconds)
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetchWeather(force: true)
        }
    }
    
    func testConnection(key: String, host: String? = nil) -> AnyPublisher<Bool, Error> {
        let testLocation = "101010100" 
        let rawHost = host ?? UserDefaults.standard.string(forKey: "qWeatherHost") ?? "https://devapi.qweather.com"
        let baseUrl = rawHost.hasSuffix("/") ? String(rawHost.dropLast()) : rawHost
        let url = URL(string: "\(baseUrl)/v7/weather/now?location=\(testLocation)")!
        var request = URLRequest(url: url)
        request.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { response in
                if let httpRes = response.response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    return true
                }
                return false
            }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    func searchLocation(query: String, key: String, host: String? = nil) -> AnyPublisher<[LocationInfo], Error> {
        // Use GeoAPI specific logic
        let rawHost = host ?? UserDefaults.standard.string(forKey: "qWeatherHost") ?? "https://devapi.qweather.com"
        let baseUrl = rawHost.hasSuffix("/") ? String(rawHost.dropLast()) : rawHost
        
        var targetUrl: URL?
        
        if baseUrl.contains("qweather.com") {
            // Official QWeather Logic
            var geoHost = baseUrl.replacingOccurrences(of: "devapi.qweather.com", with: "geoapi.qweather.com")
            geoHost = geoHost.replacingOccurrences(of: "api.qweather.com", with: "geoapi.qweather.com")
            
            if let url = URL(string: geoHost), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.path = "/v2/city/lookup"
                components.queryItems = [URLQueryItem(name: "location", value: query)]
                targetUrl = components.url
            }
        } else {
            // Custom Host Logic as per user's curl: https://your_api_host/geo/v2/city/lookup
            if let url = URL(string: rawHost), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.path = "/geo/v2/city/lookup"
                components.queryItems = [URLQueryItem(name: "location", value: query)]
                targetUrl = components.url
            }
        }
        
        guard let finalUrl = targetUrl else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: finalUrl)
        request.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("GeoAPI Response: \(jsonString)")
                }
            })
            .tryMap { data in
                do {
                    return try JSONDecoder().decode(GeoLookupResponse.self, from: data)
                } catch {
                    print("Decoding Error Details: \(error)")
                    throw error
                }
            }
            .map { $0.location ?? [] }
            .eraseToAnyPublisher()
    }
    
    func fetchWeather(location: String? = nil, cityName: String? = nil, force: Bool = false) {
        // Cache logic: don't fetch if updated within 10 minutes unless forced
        if let lastUpdate = weather?.updateTime, !force {
            let diff = Date().timeIntervalSince(lastUpdate)
            if diff < 60 { // 1 minute
                LogManager.shared.append("SKIP: Weather updated \(Int(diff))s ago, skipping API call.")
                return
            }
        }
        let storage = UserDefaults.standard
        let key = storage.string(forKey: qWeatherKeyPath) ?? ""
        let rawHost = storage.string(forKey: "qWeatherHost") ?? self.baseUrl
        let baseUrl = rawHost.hasSuffix("/") ? String(rawHost.dropLast()) : rawHost
        let locId = location ?? storage.string(forKey: "qWeatherLocId") ?? defaultLocation
        let name = cityName ?? storage.string(forKey: "qWeatherLocName") ?? "北京"
        
        guard !key.isEmpty else {
            self.errorMessage = "请在设置中配置和风天气 API Key"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Setup publishers for parallel fetching
        // Create publishers with error handling to prevent one failure from blocking all
        let nowPublisher = fetchNow(location: locId, key: key, host: baseUrl)
        
        let forecastPublisher = fetchForecast(location: locId, key: key, host: baseUrl)
            .map { Optional($0) }
            .catch { _ in Just(nil).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
            
        let indicesPublisher = fetchIndices(location: locId, key: key, host: baseUrl)
            .map { Optional($0) }
            .catch { _ in Just(nil).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
            
        let hourlyPublisher = fetchHourly(location: locId, key: key, host: baseUrl)
            .map { Optional($0) }
            .catch { _ in Just(nil).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
        
        // Minutely requires "lon,lat"
        let lon = storage.string(forKey: "qWeatherLon")
        let lat = storage.string(forKey: "qWeatherLat")
        let minutelyLoc = (lon != nil && lat != nil) ? "\(lon!),\(lat!)" : locId
        
        let minutelyPublisher = fetchMinutely(location: minutelyLoc, key: key, host: baseUrl)
            .map { Optional($0) }
            .catch { _ in Just(nil).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
            
        
        // New Air Quality API (Path Parameters)
        let airPublisher: AnyPublisher<AirNow?, Error>
        if let lonStr = storage.string(forKey: "qWeatherLon"),
           let latStr = storage.string(forKey: "qWeatherLat"),
           let lonVal = Double(lonStr),
           let latVal = Double(latStr) {
            let latFmt = String(format: "%.2f", latVal)
            let lonFmt = String(format: "%.2f", lonVal)
            airPublisher = fetchAirQualityV1(lat: latFmt, lon: lonFmt, key: key, host: baseUrl)
                .map { res -> AirNow? in
                    // Map the new response to existing model or a compatible one
                    // Assuming a standard mapping for now
                    return AirNow(pubTime: "", aqi: "\(res.aqi ?? 0)", level: "", category: res.category ?? "未知", primary: "", pm10: "", pm2p5: "", no2: "", so2: "", co: "", o3: "")
                }
                .catch { _ in Just(nil).setFailureType(to: Error.self) }
                .eraseToAnyPublisher()
        } else {
            airPublisher = Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        // Using Zip to wait for all
        Publishers.Zip4(nowPublisher, forecastPublisher, indicesPublisher, hourlyPublisher)
            .combineLatest(Publishers.Zip(minutelyPublisher, airPublisher))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "核心天气抓取失败: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] basicRes, group2 in
                let (nowRes, forecastRes, indicesRes, hourlyRes) = basicRes
                let (minutelyRes, airNow) = group2
                
                guard let now = nowRes.now else {
                    self?.errorMessage = "实时天气数据为空"
                    return
                }
                
                self?.weather = WeatherData(
                    current: now,
                    forecast: forecastRes?.daily ?? [],
                    hourly: hourlyRes?.hourly ?? [],
                    indices: indicesRes?.daily ?? [],
                    minutelySummary: minutelyRes?.summary,
                    airNow: airNow,
                    locationId: locId,
                    cityName: name,
                    updateTime: Date()
                )
            }
            .store(in: &cancellables)
    }
    
    private func fetchNow(location: String, key: String, host: String) -> AnyPublisher<WeatherNowResponse, Error> {
        let url = URL(string: "\(host)/v7/weather/now?location=\(location)")!
        var request = URLRequest(url: url)
        request.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        LogManager.shared.append("REQ: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(receiveOutput: { response in
                if let http = response.response as? HTTPURLResponse {
                    LogManager.shared.append("RES [\(http.statusCode)]: \(url.path)")
                    if http.statusCode >= 400, let body = String(data: response.data, encoding: .utf8) {
                        LogManager.shared.append("BODY [\(url.path)]: \(body)")
                    }
                }
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    LogManager.shared.append("ERR: \(url.lastPathComponent) -> \(error.localizedDescription)")
                }
            })
            .map(\.data)
            .decode(type: WeatherNowResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func fetchForecast(location: String, key: String, host: String) -> AnyPublisher<WeatherDailyResponse, Error> {
        let url = URL(string: "\(host)/v7/weather/3d?location=\(location)")!
        var request = URLRequest(url: url)
        request.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        LogManager.shared.append("REQ: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(receiveOutput: { response in
                if let http = response.response as? HTTPURLResponse {
                    LogManager.shared.append("RES [\(http.statusCode)]: \(url.lastPathComponent)")
                }
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    LogManager.shared.append("ERR: \(url.lastPathComponent) -> \(error.localizedDescription)")
                }
            })
            .map(\.data)
            .decode(type: WeatherDailyResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func fetchIndices(location: String, key: String, host: String) -> AnyPublisher<WeatherIndicesResponse, Error> {
        let url = URL(string: "\(host)/v7/indices/1d?location=\(location)&type=1,3,5,8")!
        var req = URLRequest(url: url)
        req.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        LogManager.shared.append("REQ: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: req)
            .handleEvents(receiveOutput: { response in
                if let http = response.response as? HTTPURLResponse {
                    LogManager.shared.append("RES [\(http.statusCode)]: \(url.lastPathComponent)")
                }
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    LogManager.shared.append("ERR: \(url.lastPathComponent) -> \(error.localizedDescription)")
                }
            })
            .map(\.data)
            .decode(type: WeatherIndicesResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func fetchHourly(location: String, key: String, host: String) -> AnyPublisher<WeatherHourlyResponse, Error> {
        let url = URL(string: "\(host)/v7/weather/24h?location=\(location)")!
        var req = URLRequest(url: url)
        req.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        LogManager.shared.append("REQ: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: req)
            .handleEvents(receiveOutput: { response in
                if let http = response.response as? HTTPURLResponse {
                    LogManager.shared.append("RES [\(http.statusCode)]: \(url.lastPathComponent)")
                }
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    LogManager.shared.append("ERR: \(url.lastPathComponent) -> \(error.localizedDescription)")
                }
            })
            .map(\.data)
            .decode(type: WeatherHourlyResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func fetchMinutely(location: String, key: String, host: String) -> AnyPublisher<WeatherMinutelyResponse, Error> {
        // Note: Minutely requires lon,lat or location ID. devapi supports location ID for minutely as well.
        let url = URL(string: "\(host)/v7/minutely/5m?location=\(location)")!
        var req = URLRequest(url: url)
        req.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        LogManager.shared.append("REQ: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: req)
            .handleEvents(receiveOutput: { response in
                if let http = response.response as? HTTPURLResponse {
                    LogManager.shared.append("RES [\(http.statusCode)]: \(url.lastPathComponent)")
                    if http.statusCode >= 400, let body = String(data: response.data, encoding: .utf8) {
                        LogManager.shared.append("BODY: \(body)")
                    }
                }
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    LogManager.shared.append("ERR: \(url.lastPathComponent) -> \(error.localizedDescription)")
                }
            })
            .map(\.data)
            .decode(type: WeatherMinutelyResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func fetchAirNow(location: String, key: String, host: String) -> AnyPublisher<AirNowResponse, Error> {
        let url = URL(string: "\(host)/v7/air/now?location=\(location)")!
        var req = URLRequest(url: url)
        req.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        LogManager.shared.append("REQ: \(url.absoluteString)")
        
        return URLSession.shared.dataTaskPublisher(for: req)
            .handleEvents(receiveOutput: { response in
                if let http = response.response as? HTTPURLResponse {
                    LogManager.shared.append("RES [\(http.statusCode)]: \(url.lastPathComponent)")
                    if http.statusCode >= 400, let body = String(data: response.data, encoding: .utf8) {
                        LogManager.shared.append("BODY: \(body)")
                    }
                }
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    LogManager.shared.append("ERR: \(url.lastPathComponent) -> \(error.localizedDescription)")
                }
            })
            .map(\.data)
            .decode(type: AirNowResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // New Air Quality API with path parameters: /airquality/v1/current/{latitude}/{longitude}
    struct AirQualityV1Response: Codable {
        let aqi: Int?
        let category: String?
    }
    
    private func fetchAirQualityV1(lat: String, lon: String, key: String, host: String) -> AnyPublisher<AirQualityV1Response, Error> {
        let urlString = "\(host)/airquality/v1/current/\(lat)/\(lon)"
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.addValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .handleEvents(receiveOutput: { response in
                if let httpRes = response.response as? HTTPURLResponse, httpRes.statusCode >= 400 {
                    let body = String(data: response.data, encoding: .utf8) ?? ""
                    LogManager.shared.append("RES [\(httpRes.statusCode)]: \(url.path)")
                    LogManager.shared.append("BODY: \(body)")
                }
            })
            .map(\.data)
            .decode(type: AirQualityV1Response.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
