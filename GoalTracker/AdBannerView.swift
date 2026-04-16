//
//  AdBannerView.swift
//  GoalTracker
//

import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
// AdBannerView.swift の該当部分
        
        let bannerView = BannerView(adSize: AdSizeBanner)
        
        // 🟢 直接IDを書かず、Configから読み込む
        bannerView.adUnitID = Config.adBannerUnitID
        bannerView.rootViewController = viewController
        viewController.view.addSubview(bannerView)
        viewController.view.frame = CGRect(origin: .zero, size: AdSizeBanner.size)
        
        let request = Request()
        bannerView.load(request)
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
