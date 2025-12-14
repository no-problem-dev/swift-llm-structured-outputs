//
//  UnitConverterTool.swift
//  AgentExample
//
//  単位変換ツール
//

import Foundation
import LLMStructuredOutputs

/// 単位変換ツール
///
/// 長さ、重さ、温度などの単位変換を行います。
@Tool("単位変換を行います。長さ（km, m, mile, ft）、重さ（kg, g, lb, oz）、温度（C, F, K）に対応しています。", name: "convert_unit")
struct UnitConverterTool {
    @ToolArgument("変換する数値")
    var value: Double

    @ToolArgument("変換元の単位（例: km, m, mile, ft, kg, g, lb, oz, C, F, K）")
    var fromUnit: String

    @ToolArgument("変換先の単位（例: km, m, mile, ft, kg, g, lb, oz, C, F, K）")
    var toUnit: String

    func call() async throws -> String {
        let from = fromUnit.lowercased().trimmingCharacters(in: .whitespaces)
        let to = toUnit.lowercased().trimmingCharacters(in: .whitespaces)

        // 同じ単位の場合
        if from == to {
            return "\(formatNumber(value)) \(fromUnit) = \(formatNumber(value)) \(toUnit)"
        }

        // 変換を試行
        if let result = convertLength(value, from: from, to: to) {
            return "\(formatNumber(value)) \(fromUnit) = \(formatNumber(result)) \(toUnit)"
        }

        if let result = convertWeight(value, from: from, to: to) {
            return "\(formatNumber(value)) \(fromUnit) = \(formatNumber(result)) \(toUnit)"
        }

        if let result = convertTemperature(value, from: from, to: to) {
            return "\(formatNumber(value)) \(fromUnit) = \(formatNumber(result)) \(toUnit)"
        }

        return "変換できませんでした: \(fromUnit) から \(toUnit) への変換はサポートされていません。"
    }

    // MARK: - Length Conversion

    private func convertLength(_ value: Double, from: String, to: String) -> Double? {
        // まずメートルに変換
        guard let meters = toMeters(value, from: from) else { return nil }
        // メートルから目的の単位に変換
        return fromMeters(meters, to: to)
    }

    private func toMeters(_ value: Double, from: String) -> Double? {
        switch from {
        case "m", "meter", "meters", "メートル":
            return value
        case "km", "kilometer", "kilometers", "キロメートル":
            return value * 1000
        case "cm", "centimeter", "centimeters", "センチメートル":
            return value / 100
        case "mm", "millimeter", "millimeters", "ミリメートル":
            return value / 1000
        case "mile", "miles", "マイル":
            return value * 1609.344
        case "ft", "feet", "foot", "フィート":
            return value * 0.3048
        case "in", "inch", "inches", "インチ":
            return value * 0.0254
        case "yd", "yard", "yards", "ヤード":
            return value * 0.9144
        default:
            return nil
        }
    }

    private func fromMeters(_ meters: Double, to: String) -> Double? {
        switch to {
        case "m", "meter", "meters", "メートル":
            return meters
        case "km", "kilometer", "kilometers", "キロメートル":
            return meters / 1000
        case "cm", "centimeter", "centimeters", "センチメートル":
            return meters * 100
        case "mm", "millimeter", "millimeters", "ミリメートル":
            return meters * 1000
        case "mile", "miles", "マイル":
            return meters / 1609.344
        case "ft", "feet", "foot", "フィート":
            return meters / 0.3048
        case "in", "inch", "inches", "インチ":
            return meters / 0.0254
        case "yd", "yard", "yards", "ヤード":
            return meters / 0.9144
        default:
            return nil
        }
    }

    // MARK: - Weight Conversion

    private func convertWeight(_ value: Double, from: String, to: String) -> Double? {
        // まずグラムに変換
        guard let grams = toGrams(value, from: from) else { return nil }
        // グラムから目的の単位に変換
        return fromGrams(grams, to: to)
    }

    private func toGrams(_ value: Double, from: String) -> Double? {
        switch from {
        case "g", "gram", "grams", "グラム":
            return value
        case "kg", "kilogram", "kilograms", "キログラム":
            return value * 1000
        case "mg", "milligram", "milligrams", "ミリグラム":
            return value / 1000
        case "lb", "lbs", "pound", "pounds", "ポンド":
            return value * 453.592
        case "oz", "ounce", "ounces", "オンス":
            return value * 28.3495
        default:
            return nil
        }
    }

    private func fromGrams(_ grams: Double, to: String) -> Double? {
        switch to {
        case "g", "gram", "grams", "グラム":
            return grams
        case "kg", "kilogram", "kilograms", "キログラム":
            return grams / 1000
        case "mg", "milligram", "milligrams", "ミリグラム":
            return grams * 1000
        case "lb", "lbs", "pound", "pounds", "ポンド":
            return grams / 453.592
        case "oz", "ounce", "ounces", "オンス":
            return grams / 28.3495
        default:
            return nil
        }
    }

    // MARK: - Temperature Conversion

    private func convertTemperature(_ value: Double, from: String, to: String) -> Double? {
        // まず摂氏に変換
        guard let celsius = toCelsius(value, from: from) else { return nil }
        // 摂氏から目的の単位に変換
        return fromCelsius(celsius, to: to)
    }

    private func toCelsius(_ value: Double, from: String) -> Double? {
        switch from {
        case "c", "celsius", "°c", "摂氏":
            return value
        case "f", "fahrenheit", "°f", "華氏":
            return (value - 32) * 5 / 9
        case "k", "kelvin", "ケルビン":
            return value - 273.15
        default:
            return nil
        }
    }

    private func fromCelsius(_ celsius: Double, to: String) -> Double? {
        switch to {
        case "c", "celsius", "°c", "摂氏":
            return celsius
        case "f", "fahrenheit", "°f", "華氏":
            return celsius * 9 / 5 + 32
        case "k", "kelvin", "ケルビン":
            return celsius + 273.15
        default:
            return nil
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && abs(value) < 1_000_000 {
            return String(format: "%.0f", value)
        } else if abs(value) >= 0.01 && abs(value) < 1_000_000 {
            return String(format: "%.4f", value).replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        } else {
            return String(format: "%.6g", value)
        }
    }
}
