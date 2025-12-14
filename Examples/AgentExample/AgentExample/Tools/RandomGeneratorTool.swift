//
//  RandomGeneratorTool.swift
//  AgentExample
//
//  乱数・ID生成ツール
//

import Foundation
import LLMStructuredOutputs

/// 乱数・ID生成ツール
///
/// 乱数、UUID、ランダム文字列などを生成します。
@Tool("乱数やランダムな値を生成します。整数、小数、UUID、ランダム文字列などに対応しています。", name: "generate_random")
struct RandomGeneratorTool {
    @ToolArgument("生成タイプ（int: 整数, float: 小数, uuid: UUID, string: ランダム文字列, dice: サイコロ, coin: コイン投げ, choice: リストから選択）")
    var type: String

    @ToolArgument("追加パラメータ（int/float: 最小値,最大値、string: 長さ、dice: 個数、choice: カンマ区切りの選択肢）")
    var parameters: String?

    func call() async throws -> String {
        let genType = type.lowercased().trimmingCharacters(in: .whitespaces)

        switch genType {
        case "int", "integer", "整数":
            return generateInteger()

        case "float", "double", "decimal", "小数":
            return generateFloat()

        case "uuid", "guid":
            return generateUUID()

        case "string", "文字列":
            return generateRandomString()

        case "dice", "サイコロ":
            return rollDice()

        case "coin", "コイン":
            return flipCoin()

        case "choice", "選択":
            return randomChoice()

        case "password", "パスワード":
            return generatePassword()

        default:
            return """
            未知の生成タイプ: \(type)
            サポートされているタイプ:
            - int: 整数（パラメータ: 最小値,最大値）
            - float: 小数（パラメータ: 最小値,最大値）
            - uuid: UUID
            - string: ランダム文字列（パラメータ: 長さ）
            - dice: サイコロ（パラメータ: 個数）
            - coin: コイン投げ
            - choice: リストから選択（パラメータ: 選択肢）
            - password: パスワード生成（パラメータ: 長さ）
            """
        }
    }

    // MARK: - Generators

    private func generateInteger() -> String {
        var minValue = 1
        var maxValue = 100

        if let params = parameters {
            let parts = params.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2,
               let min = Int(parts[0]),
               let max = Int(parts[1]) {
                minValue = min
                maxValue = max
            } else if parts.count == 1, let max = Int(parts[0]) {
                maxValue = max
            }
        }

        if minValue > maxValue {
            swap(&minValue, &maxValue)
        }

        let result = Int.random(in: minValue...maxValue)

        return """
        === 整数乱数生成結果 ===
        範囲: \(minValue) 〜 \(maxValue)
        結果: \(result)
        """
    }

    private func generateFloat() -> String {
        var minValue = 0.0
        var maxValue = 1.0

        if let params = parameters {
            let parts = params.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2,
               let min = Double(parts[0]),
               let max = Double(parts[1]) {
                minValue = min
                maxValue = max
            } else if parts.count == 1, let max = Double(parts[0]) {
                maxValue = max
            }
        }

        if minValue > maxValue {
            swap(&minValue, &maxValue)
        }

        let result = Double.random(in: minValue...maxValue)

        return """
        === 小数乱数生成結果 ===
        範囲: \(minValue) 〜 \(maxValue)
        結果: \(String(format: "%.6f", result))
        """
    }

    private func generateUUID() -> String {
        let uuid = UUID().uuidString

        return """
        === UUID生成結果 ===
        UUID: \(uuid)
        """
    }

    private func generateRandomString() -> String {
        var length = 16

        if let params = parameters, let len = Int(params.trimmingCharacters(in: .whitespaces)) {
            length = min(max(len, 1), 256)
        }

        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let result = String((0..<length).compactMap { _ in characters.randomElement() })

        return """
        === ランダム文字列生成結果 ===
        長さ: \(length)
        結果: \(result)
        """
    }

    private func rollDice() -> String {
        var count = 1

        if let params = parameters, let cnt = Int(params.trimmingCharacters(in: .whitespaces)) {
            count = min(max(cnt, 1), 100)
        }

        let rolls = (0..<count).map { _ in Int.random(in: 1...6) }
        let sum = rolls.reduce(0, +)
        let rollsStr = rolls.map { String($0) }.joined(separator: ", ")

        return """
        === サイコロ結果 ===
        個数: \(count)
        出目: [\(rollsStr)]
        合計: \(sum)
        """
    }

    private func flipCoin() -> String {
        let result = Bool.random()
        let resultStr = result ? "表（Heads）" : "裏（Tails）"

        return """
        === コイン投げ結果 ===
        結果: \(resultStr)
        """
    }

    private func randomChoice() -> String {
        guard let params = parameters else {
            return "選択肢を指定してください（例: りんご,みかん,ぶどう）"
        }

        let choices = params.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !choices.isEmpty else {
            return "有効な選択肢がありません"
        }

        guard let selected = choices.randomElement() else {
            return "選択に失敗しました"
        }

        return """
        === ランダム選択結果 ===
        選択肢: \(choices.joined(separator: ", "))
        選ばれたもの: \(selected)
        """
    }

    private func generatePassword() -> String {
        var length = 16

        if let params = parameters, let len = Int(params.trimmingCharacters(in: .whitespaces)) {
            length = min(max(len, 8), 128)
        }

        let lowercase = "abcdefghijklmnopqrstuvwxyz"
        let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let numbers = "0123456789"
        let symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"

        // 各種文字を最低1つ含める
        var password = [Character]()
        password.append(lowercase.randomElement()!)
        password.append(uppercase.randomElement()!)
        password.append(numbers.randomElement()!)
        password.append(symbols.randomElement()!)

        // 残りをランダムに埋める
        let allChars = lowercase + uppercase + numbers + symbols
        for _ in 4..<length {
            password.append(allChars.randomElement()!)
        }

        // シャッフル
        password.shuffle()
        let result = String(password)

        return """
        === パスワード生成結果 ===
        長さ: \(length)
        パスワード: \(result)
        ※大文字・小文字・数字・記号を含んでいます
        """
    }
}
