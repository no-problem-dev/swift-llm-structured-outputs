//
//  CalculatorTool.swift
//  AgentExample
//
//  計算ツール
//

import Foundation
import LLMStructuredOutputs

/// 計算ツール
///
/// 数式を評価して結果を返します。
/// 基本的な四則演算と括弧をサポートします。
@Tool("数式を計算して結果を返します。四則演算（+, -, *, /）と括弧が使用できます。", name: "calculator")
struct CalculatorTool {
    @ToolArgument("計算する数式（例: 2 + 3 * 4, (10 + 5) / 3, 25 * 9 / 5 + 32）")
    var expression: String

    func call() async throws -> String {
        // NSExpressionを使って数式を評価
        let sanitizedExpression = sanitize(expression)
        let nsExpression = NSExpression(format: sanitizedExpression)

        if let result = nsExpression.expressionValue(with: nil, context: nil) {
            if let doubleResult = result as? Double {
                // 整数の場合は小数点以下を省略
                if doubleResult.truncatingRemainder(dividingBy: 1) == 0 {
                    return "\(expression) = \(Int(doubleResult))"
                } else {
                    return String(format: "%@ = %.4f", expression, doubleResult)
                }
            } else if let intResult = result as? Int {
                return "\(expression) = \(intResult)"
            } else if let numberResult = result as? NSNumber {
                return "\(expression) = \(numberResult)"
            }
        }
        return "計算できませんでした: \(expression)"
    }

    /// 数式をサニタイズして安全な形式に変換
    private func sanitize(_ expr: String) -> String {
        // 危険な文字を除去し、数式として有効な文字のみを残す
        var result = expr

        // 許可される文字: 数字、演算子、括弧、小数点、スペース
        let allowedCharacters = CharacterSet(charactersIn: "0123456789+-*/().% ")
        result = String(result.unicodeScalars.filter { allowedCharacters.contains($0) })

        // ^をpow関数に変換（NSExpressionでは非対応のため）
        // ここでは単純な変換は行わず、サポートしない旨を示す

        return result
    }
}
