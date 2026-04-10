//
//  GoalTrackerApp.swift
//  GoalTracker
//

import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct GoalTrackerApp: App {
    init() {
        // 🔴 新しいSDKの初期化コード
        MobileAds.shared.start(completionHandler: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        ATTrackingManager.requestTrackingAuthorization { status in
                            // 必要に応じて処理
                        }
                    }
                }
        }
    }
}
