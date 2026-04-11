import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GoalViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                HomeView(viewModel: viewModel)
                    .tabItem { Image(systemName: "house"); Text("ホーム") }.tag(0)
                
                ReflectionView(viewModel: viewModel)
                    .tabItem { Image(systemName: "square.and.pencil"); Text("振り返り") }.tag(1)
                
                // 👇 カレンダーと未来の自分を復活！
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
    }
}
