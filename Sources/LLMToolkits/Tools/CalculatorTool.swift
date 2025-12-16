import Foundation
import LLMClient
import LLMTool

// MARK: - CalculatorTool

/// 数学計算を実行するツール
///
/// 数式を評価し、正確な数値結果を提供します。
/// 基本的な四則演算、一般的な数学関数、定数をサポートします。
///
/// ## サポートされる演算
/// - 基本演算: +, -, *, /, % (剰余)
/// - べき乗: ** または pow(x, y)
/// - 平方根: sqrt(x)
/// - 三角関数: sin, cos, tan (ラジアン単位)
/// - 対数: log (自然対数), log10
/// - 定数: pi, e
/// - 絶対値: abs(x)
/// - 丸め: floor, ceil, round
///
/// ## 適用されたベストプラクティス
/// - **明確なエラーメッセージ**: 問題と解決方法を説明
/// - **安全な評価**: 制御された式評価を使用
/// - **精度制御**: 設定可能な小数点以下桁数
///
/// ## 使用例
///
/// ```swift
/// let tools = ToolSet {
///     CalculatorTool()
/// }
/// ```
@Tool(
    "Evaluate mathematical expressions. " +
    "Supports basic arithmetic (+, -, *, /, %), power (**), " +
    "sqrt, sin, cos, tan, log, abs, floor, ceil, round, " +
    "and constants (pi, e). " +
    "Returns the numerical result with specified precision.",
    name: "calculator"
)
public struct CalculatorTool {

    /// The mathematical expression to evaluate
    @ToolArgument(
        "The mathematical expression to calculate. " +
        "Examples: '2 + 2', 'sqrt(16)', '3.14 * 2 ** 2', 'sin(pi/2)'. " +
        "Use ** for power, pi for π, e for Euler's number."
    )
    public var expression: String

    /// Number of decimal places in the result
    @ToolArgument(
        "Number of decimal places for the result (0-15). " +
        "Default is 6. Use 0 for integer results."
    )
    public var precision: Int?

    public func call() async throws -> String {
        let precisionValue = min(max(precision ?? 6, 0), 15)

        // Normalize the expression
        var normalizedExpr = expression
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        // Replace common mathematical notations
        normalizedExpr = preprocessExpression(normalizedExpr)

        do {
            let result = try evaluateExpression(normalizedExpr)

            // Format result with precision
            if precisionValue == 0 {
                return String(format: "%.0f", result)
            } else {
                let formatString = "%.\(precisionValue)f"
                var formatted = String(format: formatString, result)
                // Remove trailing zeros for cleaner output
                if formatted.contains(".") {
                    formatted = formatted.replacingOccurrences(
                        of: "\\.?0+$",
                        with: "",
                        options: .regularExpression
                    )
                }
                return formatted
            }
        } catch CalculatorError.invalidExpression(let message) {
            return "Error: \(message)"
        } catch CalculatorError.divisionByZero {
            return "Error: Division by zero."
        } catch CalculatorError.domainError(let message) {
            return "Error: \(message)"
        } catch {
            return "Error: Could not evaluate expression '\(expression)'. " +
                   "Ensure it uses valid operators (+, -, *, /, **, %), " +
                   "functions (sqrt, sin, cos, tan, log, abs), " +
                   "and constants (pi, e)."
        }
    }

    // MARK: - プライベートヘルパー

    private func preprocessExpression(_ expr: String) -> String {
        var result = expr

        // Replace constants
        result = result.replacingOccurrences(of: "pi", with: String(Double.pi))
        result = result.replacingOccurrences(of: "π", with: String(Double.pi))
        result = result.replacingOccurrences(of: "e", with: String(M_E))

        // Replace ** with pow notation for later processing
        // e.g., "2**3" -> "pow(2,3)"
        result = convertPowerOperator(result)

        return result
    }

    private func convertPowerOperator(_ expr: String) -> String {
        var result = expr

        // Handle ** operator by converting to pow() calls
        // This is a simplified approach - handles basic cases like "2**3" or "x**2"
        while let range = result.range(of: "**") {
            // Find the base (number or parenthesized expression before **)
            let beforeRange = result.startIndex..<range.lowerBound
            let afterRange = range.upperBound..<result.endIndex

            let beforeStr = String(result[beforeRange])
            let afterStr = String(result[afterRange])

            // Extract base (last number or closing paren)
            let base = extractTrailingOperand(from: beforeStr)
            // Extract exponent (first number or opening paren expression)
            let exponent = extractLeadingOperand(from: afterStr)

            let prefix = String(beforeStr.dropLast(base.count))
            let suffix = String(afterStr.dropFirst(exponent.count))

            result = prefix + "pow(\(base),\(exponent))" + suffix
        }

        return result
    }

    private func extractTrailingOperand(from string: String) -> String {
        var operand = ""
        var parenCount = 0

        for char in string.reversed() {
            if char == ")" {
                parenCount += 1
                operand.insert(char, at: operand.startIndex)
            } else if char == "(" {
                parenCount -= 1
                operand.insert(char, at: operand.startIndex)
                if parenCount == 0 {
                    break
                }
            } else if parenCount > 0 {
                operand.insert(char, at: operand.startIndex)
            } else if char.isNumber || char == "." {
                operand.insert(char, at: operand.startIndex)
            } else {
                break
            }
        }

        return operand
    }

    private func extractLeadingOperand(from string: String) -> String {
        var operand = ""
        var parenCount = 0

        for char in string {
            if char == "(" {
                parenCount += 1
                operand.append(char)
            } else if char == ")" {
                parenCount -= 1
                operand.append(char)
                if parenCount == 0 {
                    break
                }
            } else if parenCount > 0 {
                operand.append(char)
            } else if char.isNumber || char == "." || (operand.isEmpty && char == "-") {
                operand.append(char)
            } else {
                break
            }
        }

        return operand
    }

    private func evaluateExpression(_ expr: String) throws -> Double {
        // Use a simple recursive descent parser for safety
        // This avoids NSExpression security concerns

        var index = expr.startIndex
        return try parseAddSub(expr, &index)
    }

    private func parseAddSub(_ expr: String, _ index: inout String.Index) throws -> Double {
        var result = try parseMulDiv(expr, &index)

        while index < expr.endIndex {
            skipWhitespace(expr, &index)
            if index >= expr.endIndex { break }

            let char = expr[index]
            if char == "+" {
                index = expr.index(after: index)
                result += try parseMulDiv(expr, &index)
            } else if char == "-" {
                index = expr.index(after: index)
                result -= try parseMulDiv(expr, &index)
            } else {
                break
            }
        }

        return result
    }

    private func parseMulDiv(_ expr: String, _ index: inout String.Index) throws -> Double {
        var result = try parseUnary(expr, &index)

        while index < expr.endIndex {
            skipWhitespace(expr, &index)
            if index >= expr.endIndex { break }

            let char = expr[index]
            if char == "*" {
                index = expr.index(after: index)
                result *= try parseUnary(expr, &index)
            } else if char == "/" {
                index = expr.index(after: index)
                let divisor = try parseUnary(expr, &index)
                if divisor == 0 {
                    throw CalculatorError.divisionByZero
                }
                result /= divisor
            } else if char == "%" {
                index = expr.index(after: index)
                let divisor = try parseUnary(expr, &index)
                if divisor == 0 {
                    throw CalculatorError.divisionByZero
                }
                result = result.truncatingRemainder(dividingBy: divisor)
            } else {
                break
            }
        }

        return result
    }

    private func parseUnary(_ expr: String, _ index: inout String.Index) throws -> Double {
        skipWhitespace(expr, &index)

        if index < expr.endIndex && expr[index] == "-" {
            index = expr.index(after: index)
            return -(try parseUnary(expr, &index))
        }
        if index < expr.endIndex && expr[index] == "+" {
            index = expr.index(after: index)
            return try parseUnary(expr, &index)
        }

        return try parsePrimary(expr, &index)
    }

    private func parsePrimary(_ expr: String, _ index: inout String.Index) throws -> Double {
        skipWhitespace(expr, &index)

        // Handle parentheses
        if index < expr.endIndex && expr[index] == "(" {
            index = expr.index(after: index)
            let result = try parseAddSub(expr, &index)
            skipWhitespace(expr, &index)
            if index < expr.endIndex && expr[index] == ")" {
                index = expr.index(after: index)
            }
            return result
        }

        // Handle functions
        let functions = ["sqrt", "sin", "cos", "tan", "log10", "log", "abs", "floor", "ceil", "round", "pow"]
        for funcName in functions {
            if expr[index...].hasPrefix(funcName) {
                index = expr.index(index, offsetBy: funcName.count)
                return try parseFunction(funcName, expr, &index)
            }
        }

        // Handle numbers
        return try parseNumber(expr, &index)
    }

    private func parseFunction(_ name: String, _ expr: String, _ index: inout String.Index) throws -> Double {
        skipWhitespace(expr, &index)

        guard index < expr.endIndex && expr[index] == "(" else {
            throw CalculatorError.invalidExpression("Expected '(' after function '\(name)'")
        }
        index = expr.index(after: index)

        let arg1 = try parseAddSub(expr, &index)

        var arg2: Double?
        skipWhitespace(expr, &index)
        if index < expr.endIndex && expr[index] == "," {
            index = expr.index(after: index)
            arg2 = try parseAddSub(expr, &index)
        }

        skipWhitespace(expr, &index)
        guard index < expr.endIndex && expr[index] == ")" else {
            throw CalculatorError.invalidExpression("Expected ')' after function arguments")
        }
        index = expr.index(after: index)

        switch name {
        case "sqrt":
            guard arg1 >= 0 else {
                throw CalculatorError.domainError("sqrt requires non-negative argument")
            }
            return sqrt(arg1)
        case "sin":
            return sin(arg1)
        case "cos":
            return cos(arg1)
        case "tan":
            return tan(arg1)
        case "log":
            guard arg1 > 0 else {
                throw CalculatorError.domainError("log requires positive argument")
            }
            return log(arg1)
        case "log10":
            guard arg1 > 0 else {
                throw CalculatorError.domainError("log10 requires positive argument")
            }
            return log10(arg1)
        case "abs":
            return abs(arg1)
        case "floor":
            return floor(arg1)
        case "ceil":
            return ceil(arg1)
        case "round":
            return round(arg1)
        case "pow":
            guard let exp = arg2 else {
                throw CalculatorError.invalidExpression("pow requires two arguments: pow(base, exponent)")
            }
            return pow(arg1, exp)
        default:
            throw CalculatorError.invalidExpression("Unknown function: \(name)")
        }
    }

    private func parseNumber(_ expr: String, _ index: inout String.Index) throws -> Double {
        var numStr = ""

        while index < expr.endIndex {
            let char = expr[index]
            if char.isNumber || char == "." {
                numStr.append(char)
                index = expr.index(after: index)
            } else {
                break
            }
        }

        guard !numStr.isEmpty, let value = Double(numStr) else {
            throw CalculatorError.invalidExpression(
                "Expected number at position \(expr.distance(from: expr.startIndex, to: index))"
            )
        }

        return value
    }

    private func skipWhitespace(_ expr: String, _ index: inout String.Index) {
        while index < expr.endIndex && expr[index].isWhitespace {
            index = expr.index(after: index)
        }
    }
}

// MARK: - CalculatorError

private enum CalculatorError: Error {
    case invalidExpression(String)
    case divisionByZero
    case domainError(String)
}
