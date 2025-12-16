//
//  ContentView.swift
//  ConversationAgentExample
//
//  メインコンテンツビュー
//

import SwiftUI

/// メインコンテンツビュー
///
/// アプリのエントリーポイントとなるビューです。
/// 会話画面と設定画面をタブで切り替えます。
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var controller = ConversationController()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ConversationView(controller: controller)
            }
            .tabItem {
                Label("会話", systemImage: "bubble.left.and.bubble.right.fill")
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
