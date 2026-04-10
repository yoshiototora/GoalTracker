//
//  AdBannerView.swift
//  GoalTracker
//

import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // 🔴 GADを取り除いた新しい書き方
        let bannerView = BannerView(adSize: AdSizeBanner)
        
        bannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        bannerView.rootViewController = viewController
        viewController.view.addSubview(bannerView)
        viewController.view.frame = CGRect(origin: .zero, size: AdSizeBanner.size)
        
        // 🔴 GADを取り除いた新しい書き方
        let request = Request()
        bannerView.load(request)
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
