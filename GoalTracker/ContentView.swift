import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GoalViewModel()
    @State private var selectedTab = 0
    @State private var showTutorial = false
    
    var body: some View {
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
            
            AdBannerView()
                .frame(width: 320, height: 50)
                .background(Color(UIColor.systemBackground))
        }
        .onAppear {
            // 初回起動時のみチュートリアルを表示
            if !UserDefaults.standard.bool(forKey: "hasCompletedMainTutorial") {
                showTutorial = true
            }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView(viewModel: viewModel, isShowing: $showTutorial)
        }
    }
}
