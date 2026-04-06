//
//  ContentView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/03.
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
            
            SettingsView(dataManager: dataManager)
                .tabItem { Image(systemName: "gearshape"); Text("設定") }.tag(3)
        }
        .contentShape(Rectangle()) // 透明部分でもタップを検知
        .onTapGesture { hideKeyboard() }
    }
}

#Preview {
    ContentView()
}
