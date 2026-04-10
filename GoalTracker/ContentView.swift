//
//  ContentView.swift
//  GoalTracker
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = GoalManager()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                HomeView(dataManager: dataManager)
                    .tabItem { Image(systemName: "house"); Text("ホーム") }.tag(0)
                
                ReflectionView(dataManager: dataManager)
                    .tabItem { Image(systemName: "square.and.pencil"); Text("振り返り") }.tag(1)
                
                CalendarView(dataManager: dataManager, selectedTab: $selectedTab)
                    .tabItem { Image(systemName: "calendar"); Text("カレンダー") }.tag(2)
                
                FutureVisionView(dataManager: dataManager)
                    .tabItem { Image(systemName: "sparkles"); Text("未来の自分") }.tag(3)
                
                SettingsView(dataManager: dataManager)
                    .tabItem { Image(systemName: "gearshape"); Text("設定") }.tag(4)
            }
            
            // 📱 全画面の共通下部メニューの上に広告を配置
            AdBannerView()
                .frame(width: 320, height: 50)
                .background(Color(UIColor.systemBackground))
        }
    }
}

#Preview {
    ContentView()
}
