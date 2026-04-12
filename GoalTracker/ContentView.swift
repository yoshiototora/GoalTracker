//
//  ContentView.swift
//  GoalTracker
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = GoalViewModel()
    @State private var selectedTab = 0
    @State private var showTutorial = false
    @State private var isKeyboardVisible = false
    
    var body: some View {
        ZStack {
            // 背景をタップしてキーボードを閉じるための見えないボタン
            Color(UIColor.systemBackground)
                .onTapGesture { hideKeyboard() }
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    HomeView(viewModel: viewModel, selectedTab: $selectedTab)
                        .tabItem { Image(systemName: "house"); Text("ホーム") }.tag(0)
                    
                    ReflectionView(viewModel: viewModel)
                        .tabItem { Image(systemName: "square.and.pencil"); Text("振り返り") }.tag(1)
                    
                    CalendarView(viewModel: viewModel, selectedTab: $selectedTab)
                        .tabItem { Image(systemName: "calendar"); Text("カレンダー") }.tag(2)
                    
                    FutureVisionView(viewModel: viewModel)
                        .tabItem { Image(systemName: "sparkles"); Text("未来の自分") }.tag(3)
                    
                    SettingsView(viewModel: viewModel)
                        .tabItem { Image(systemName: "gearshape"); Text("設定") }.tag(4)
                }
                // 💡 修正：古いiOSでもエラーにならず、タブバーがキーボードの下に潜り込むようにする
                .ignoresSafeArea(.keyboard, edges: .bottom)
                
                // キーボードが開いていない時だけ広告を表示
                if !isKeyboardVisible {
                    AdBannerView()
                        .frame(width: 320, height: 50)
                        .background(Color(UIColor.systemBackground))
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasCompletedMainTutorial") {
                showTutorial = true
            }
        }
        // 重複していた処理を1つに統合
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView(viewModel: viewModel, isShowing: $showTutorial)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.refreshNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = false }
        }
    }
}
