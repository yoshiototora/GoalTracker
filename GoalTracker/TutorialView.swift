//
//  TutorialView.swift
//  GoalTracker
//

import SwiftUI

struct TutorialPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct TutorialView: View {
    @Binding var isShowing: Bool
    
    let pages = [
        TutorialPage(title: "目標を立てる", description: "日次・週次・月次の目標を設定して、進むべき方向を明確にしましょう。", imageName: "target", color: .green),
        
        TutorialPage(title: "日々のタスクを完了する", description: "目標から自動でタスクが生成されます。毎日すべてのタスクを完了させて、連続達成バッジ（ストリーク）を育てましょう！", imageName: "flame.fill", color: .orange),
        
        TutorialPage(title: "KPTで振り返る", description: "Keep, Problem, Tryで1日を振り返り、自己成長のループを回しましょう。\n日曜日には「週次振り返り」、月末には「月次振り返り」も行えます。設定した「Try」は、次のタスクとして自動で引き継がれます！", imageName: "lightbulb.fill", color: .blue),
        
        TutorialPage(title: "記録を積み上げる", description: "カレンダーのヒートマップが濃くなるほど、あなたの努力が形に残ります。", imageName: "calendar", color: .purple),
        
        TutorialPage(title: "未来の自分を描く", description: "「未来の自分」リストを作り、具体的なステップに分解しましょう。\nすべてのステップ（100%）を完了すると、年末の振り返り画面から大きな目標を達成でき、特別な演出が待っています！", imageName: "sparkles", color: .pink)
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
                            Text(pages[index].title).font(.title.bold())
                            Text(pages[index].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 40)
                                .lineSpacing(4)
                        }
                        
                        Spacer()
                        
                        if index == pages.count - 1 {
                            Button(action: { isShowing = false }) {
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
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}
