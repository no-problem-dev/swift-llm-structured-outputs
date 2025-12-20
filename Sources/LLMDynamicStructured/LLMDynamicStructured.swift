// LLMDynamicStructured
//
// ランタイムで構造化出力の型を定義するためのモジュール
//
// `@Structured` マクロを使わずに、プログラマティックに
// 構造化出力の定義を構築できます。
//
// ## 使用例
//
// ```swift
// import LLMDynamicStructured
//
// // 構造を定義
// let userInfo = DynamicStructured("UserInfo", description: "ユーザー情報") {
//     JSONSchema.string(description: "ユーザー名", minLength: 1)
//         .named("name")
//
//     JSONSchema.integer(description: "年齢", minimum: 0, maximum: 150)
//         .named("age")
//         .optional()
//
//     JSONSchema.enum(["admin", "user", "guest"], description: "権限")
//         .named("role")
// }
//
// // LLM で生成
// let result = try await client.generate(
//     prompt: "田中太郎さん（35歳、管理者）の情報を抽出",
//     model: .sonnet,
//     output: userInfo
// )
//
// // 結果にアクセス
// print(result.string("name"))  // Optional("田中太郎")
// print(result.int("age"))      // Optional(35)
// print(result.string("role"))  // Optional("admin")
// ```

// MARK: - Re-exports from LLMClient

@_exported import LLMClient
