//
//  ContentView.swift
//  AgentExample
//
//  メインコンテンツビュー
//

import SwiftUI

/// メインコンテンツビュー
///
/// アプリのエントリーポイントとなるビューです。
/// エージェント実行画面と設定画面をタブで切り替えます。
struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AgentRunnerView()
            }
            .tabItem {
                Label("リサーチ", systemImage: "magnifyingglass.circle.fill")
            }
            .tag(0)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape.fill")
            }
            .tag(1)
        }
        .onAppear {
            // 環境変数からAPIキーを同期
            APIKeyManager.syncFromEnvironment()
        }
    }
}

#Preview {
    ContentView()
}
