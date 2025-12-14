//
//  LLMStructuredOutputsExampleApp.swift
//  LLMStructuredOutputsExample
//
//  Created by 谷口恭一 on 2025/12/14.
//

import SwiftUI

@main
struct LLMStructuredOutputsExampleApp: App {

    init() {
        // 環境変数からAPIキーをUserDefaultsに同期
        APIKeyManager.syncFromEnvironment()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
