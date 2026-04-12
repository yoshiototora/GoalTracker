//
//  TutorialView.swift
//  GoalTracker
//

import SwiftUI

struct TutorialView: View {
    @ObservedObject var viewModel: GoalViewModel
    @Binding var isShowing: Bool
    
    @State private var step = 0
    @State private var firstGoalTitle = ""
    @FocusState private var isInputFocused: Bool
    
    @State private var isReplay = UserDefaults.standard.bool(forKey: "hasCompletedMainTutorial")
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack {
                // 🟢 ① メインコンテンツ（ステップごとに切り替わる部分）
                VStack(spacing: 30) {
                    Spacer()
                    
                    if step == 0 {
                        Image(systemName: "target").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.blue)
                        Text("ようこそ！\nまずは最初の目標を決めましょう").font(.title2.bold()).multilineTextAlignment(.center)
                        
                        Text("このアプリは「なりたい自分」に\n近づくための場所です。\n\nまずは、小さな一歩から。\n毎日続けたい行動を1つ教えてください。\n（例：読書を10分、英単語を10個覚える）")
                            .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                        
                        TextField("最初の目標を入力...", text: $firstGoalTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isInputFocused)
                            .padding(.horizontal, 40)
                        
                    } else if step == 1 {
                        Image(systemName: "house.fill").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.orange)
                        Text("目標が毎日のタスクに").font(.title2.bold())
                        
                        Text("先ほど入力した目標は、毎日「ホーム画面」に\nタスクとして自動で表示されます。\n\n完了したらタップするだけ。\n小さな達成を、毎日積み重ねていきましょう。")
                            .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                        
                    } else if step == 2 {
                        Image(systemName: "square.and.pencil").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.green)
                        Text("成長は「振り返り」から").font(.title2.bold())
                        
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("・Keep (よかったこと)")
                                Text("・Problem (課題)")
                                Text("・Try (次やること)")
                            }
                            
                            Text("この3つを書くだけで、\n明日の行動が少しずつ変わっていきます。\n\n週末や月末には、少し長いスパンで振り返り、\n自分の変化や成長を実感しましょう。")
                                .multilineTextAlignment(.center)
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        
                    } else if step == 3 {
                        Image(systemName: "calendar").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.purple)
                        Text("努力をカレンダーに刻む").font(.title2.bold())
                        
                        Text("毎日のタスクを達成すると、\nカレンダーが濃く色付いていきます。\n\n振り返ったとき、\nそこには「続けてきた証」が残ります。")
                            .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                        
                    } else if step == 4 {
                        Image(systemName: "sparkles").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.pink)
                        Text("未来の自分を描く").font(.title2.bold())
                        
                        Text("目標は「ゴール」ではありません。\nその先に、どんな自分になりたいか。\n\n「未来の自分」画面では、理想の姿から逆算して\n今やるべきことを整理できます。\n\nただのタスク管理ではなく、\n「自分の人生」をデザインしていきましょう。")
                            .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                    
                    Spacer()
                }
                
                // 🟢 ② ボタンとインジケーター（画面下部に固定）
                VStack(spacing: 24) {
                    // 各ステップのボタンを出し分ける
                    if step == 0 {
                        Button(action: {
                            isInputFocused = false
                            saveFirstGoal()
                            withAnimation { step += 1 }
                        }) {
                            Text(isReplay ? "次へ（スキップ可）" : "次へ")
                                .font(.headline).foregroundColor(.white)
                                .padding().frame(maxWidth: .infinity)
                                .background((firstGoalTitle.isEmpty && !isReplay) ? Color.gray : Color.blue)
                                .cornerRadius(12).padding(.horizontal, 40)
                        }
                        .disabled(firstGoalTitle.isEmpty && !isReplay)
                        
                    } else if step == 4 {
                        Button(action: {
                            UserDefaults.standard.set(true, forKey: "hasCompletedMainTutorial")
                            isShowing = false
                        }) {
                            Text("さっそく始める！")
                                .font(.headline).foregroundColor(.white)
                                .padding().frame(maxWidth: .infinity)
                                .background(Color.pink)
                                .cornerRadius(12).padding(.horizontal, 40)
                        }
                    } else {
                        nextButton()
                    }
                    
                    // ページインジケーター（ドット）
                    HStack(spacing: 8) {
                        ForEach(0..<5) { i in
                            Circle().fill(i == step ? Color.blue : Color.gray.opacity(0.3)).frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.bottom, 20) // 画面一番下からの余白
            }
        }
    }
    
    private func nextButton() -> some View {
        Button(action: { withAnimation { step += 1 } }) {
            Text("次へ")
                .font(.headline).foregroundColor(.white)
                .padding().frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12).padding(.horizontal, 40)
        }
    }
    
    private func saveFirstGoal() {
        if firstGoalTitle.isEmpty { return }
        let today = Date()
        var currentMonthData = viewModel.getMonthData(for: today)
        
        if !currentMonthData.dailyGoals.contains(where: { $0.title == firstGoalTitle }) {
            currentMonthData.dailyGoals.append(Goal(title: firstGoalTitle, categoryId: "none"))
            viewModel.updateMonthlyGoals(currentMonthData.dailyGoals, field: .daily, date: today)
            viewModel.syncAll(for: today)
        }
    }
}
