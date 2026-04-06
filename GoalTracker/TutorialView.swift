import SwiftUI

// チュートリアルの各ページの内容を定義する構造体
struct TutorialPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String // システムアイコン（SFSymbols）の名前
    let color: Color
}

struct TutorialView: View {
    @Binding var isShowing: Bool // 画面を閉じるためのフラグ
    
    let pages = [
        TutorialPage(title: "目標を立てる", description: "日次・週次・月次の目標を設定して、進むべき方向を明確にしましょう。", imageName: "target", color: .green),
        TutorialPage(title: "日々のタスクを完了する", description: "目標から自動でタスクが生成されます。毎日チェックして達成感を味わいましょう。", imageName: "checkmark.circle.fill", color: .orange),
        TutorialPage(title: "KPTで振り返る", description: "Keep, Problem, Tryで1日を振り返り、自己成長のループを回しましょう。", imageName: "lightbulb.fill", color: .blue),
        TutorialPage(title: "記録を積み上げる", description: "カレンダーのヒートマップが濃くなるほど、あなたの努力が形に残ります。", imageName: "calendar", color: .purple)
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            TabView {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack(spacing: 30) {
                        Spacer()
                        
                        Image(systemName: pages[index].imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .foregroundColor(pages[index].color)
                        
                        VStack(spacing: 15) {
                            Text(pages[index].title)
                                .font(.title.bold())
                            
                            Text(pages[index].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                        }
                        
                        Spacer()
                        
                        // 最後のページだけ「はじめる」ボタンを出す
                        if index == pages.count - 1 {
                            Button(action: {
                                isShowing = false
                            }) {
                                Text("はじめる")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 40)
                            }
                        }
                        
                        Spacer().frame(height: 50)
                    }
                }
            }
            .tabViewStyle(.page) // 👈 これで横スワイプになります
            .indexViewStyle(.page(backgroundDisplayMode: .always)) // 下の「...」を表示
        }
    }
}
//
//  TutorialView.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/06.
//

