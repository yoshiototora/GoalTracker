//
//  ContentView.swift
//  GoalTracker
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = AppDataManager()
    @State private var selectedTab = 0
    
    var body: some View {
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
        // 🌟 修正：以下の2行を削除して、タブがタップを吸い込まれないようにしました！
        // .contentShape(Rectangle())
        // .onTapGesture { hideKeyboard() }
    }
}

#Preview {
    ContentView()
}
