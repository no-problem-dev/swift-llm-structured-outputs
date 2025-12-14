//
//  WeatherTool.swift
//  AgentExample
//
//  天気情報ツール（Open-Meteo API）
//

import Foundation
import LLMStructuredOutputs

/// 天気情報ツール
///
/// Open-Meteo API を使用して現在の天気情報を取得します。
/// APIキー不要で利用可能です。
@Tool("指定された都市や場所の現在の天気情報を取得します。天気、気温、湿度などの情報が含まれます。", name: "get_weather")
struct WeatherTool {
    @ToolArgument("天気を取得したい場所（例: 東京、Paris、New York）")
    var location: String

    func call() async throws -> String {
        // まず場所名から座標を取得（Geocoding API）
        guard let coordinates = try await geocode(location: location) else {
            return "場所「\(location)」の座標が見つかりませんでした。"
        }

        // Open-Meteo API で天気を取得
        let weatherURL = "https://api.open-meteo.com/v1/forecast?latitude=\(coordinates.lat)&longitude=\(coordinates.lon)&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto"

        guard let url = URL(string: weatherURL) else {
            return "URLの構築に失敗しました"
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let response = try? JSONDecoder().decode(WeatherResponse.self, from: data) else {
            return "天気データのデコードに失敗しました"
        }

        let current = response.current
        let weatherDescription = weatherCodeToDescription(current.weatherCode)

        return """
        === \(location)の現在の天気 ===
        天気: \(weatherDescription)
        気温: \(current.temperature)°C
        湿度: \(current.humidity)%
        風速: \(current.windSpeed) km/h
        """
    }

    private func geocode(location: String) async throws -> (lat: Double, lon: Double)? {
        guard let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedLocation)&count=1") else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let response = try? JSONDecoder().decode(GeocodingResponse.self, from: data),
              let result = response.results?.first else {
            return nil
        }

        return (lat: result.latitude, lon: result.longitude)
    }

    private func weatherCodeToDescription(_ code: Int) -> String {
        switch code {
        case 0: return "快晴"
        case 1: return "晴れ"
        case 2: return "一部曇り"
        case 3: return "曇り"
        case 45, 48: return "霧"
        case 51, 53, 55: return "霧雨"
        case 56, 57: return "凍結霧雨"
        case 61, 63, 65: return "雨"
        case 66, 67: return "凍結雨"
        case 71, 73, 75: return "雪"
        case 77: return "雪粒"
        case 80, 81, 82: return "にわか雨"
        case 85, 86: return "にわか雪"
        case 95: return "雷雨"
        case 96, 99: return "雷雨（雹あり）"
        default: return "不明"
        }
    }
}

// MARK: - API Response Models

private struct GeocodingResponse: Codable {
    let results: [GeocodingResult]?
}

private struct GeocodingResult: Codable {
    let latitude: Double
    let longitude: Double
}

private struct WeatherResponse: Codable {
    let current: CurrentWeather

    struct CurrentWeather: Codable {
        let temperature: Double
        let humidity: Int
        let weatherCode: Int
        let windSpeed: Double

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case humidity = "relative_humidity_2m"
            case weatherCode = "weather_code"
            case windSpeed = "wind_speed_10m"
        }
    }
}
