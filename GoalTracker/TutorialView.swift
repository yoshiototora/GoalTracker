//
//  TutorialView.swift
//  HabitSpark
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
            
            VStack(spacing: 0) {
                // コンテンツ部分をスクロール可能にして、キーボードに押されても隠れないようにする
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if step == 0 {
                            // 🟢 Step 0 ではキーボードが出ても邪魔にならないよう、アイコンを小さく＆余白を調整
                            Image(systemName: "target")
                                .resizable()
                                .scaledToFit()
                                .frame(width: isInputFocused ? 60 : 100, height: isInputFocused ? 60 : 100)
                                .foregroundColor(.blue)
                                .padding(.top, isInputFocused ? 20 : 60)
                                .animation(.spring(), value: isInputFocused)
                            
                            Text("まずは1つ、習慣を決めましょう")
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)
                            
                            Text("どんな小さなことでもOKです。\n毎日続けたい行動を1つ入力してください。\n\n例：読書10分、英単語10個")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            TextField("最初の目標を入力...", text: $firstGoalTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isInputFocused)
                                .padding(.horizontal, 40)
                                .onSubmit {
                                    if !firstGoalTitle.isEmpty { withAnimation { step += 1 } }
                                }
                            
                        } else {
                            // Step 1以降のレイアウト
                            Spacer().frame(height: 60)
                            
                            if step == 1 {
                                Image(systemName: "calendar.badge.checkmark").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.orange)
                                Text("いいですね！").font(.title2.bold())
                                Text("この目標は、毎日のタスクとして\n自動でカレンダーに登録されます。\n\n日々の積み重ねは、ヒートマップや\n連続記録（ストリーク）として可視化されます。").multilineTextAlignment(.center)
                            } else if step == 2 {
                                Image(systemName: "square.and.pencil").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.green)
                                Text("振り返りで成長する").font(.title2.bold())
                                Text("HabitSparkでは、KPTで振り返りを行います。\n\nKeep：できたこと\nProblem：課題\nTry：次にやること\n\nTryはそのまま次のタスクになります。\n\nさらに、日曜日には週次、月末には月次、年末には年次振り返りも登場します。").multilineTextAlignment(.center)
                            } else if step == 3 {
                                Image(systemName: "sparkles").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.pink)
                                Text("準備完了です！").font(.title2.bold())
                                Text("さあ、今日から始めましょう。\n\n小さな一歩が、未来を変えます。").multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // 下部の固定ボタンエリア
                VStack(spacing: 20) {
                    if step == 0 {
                        VStack(spacing: 12) {
                            Button(action: { withAnimation { step += 1 } }) {
                                Text("登録する")
                                    .font(.headline).foregroundColor(.white)
                                    .padding().frame(maxWidth: .infinity)
                                    .background(firstGoalTitle.isEmpty ? Color.gray : Color.blue)
                                    .cornerRadius(12).padding(.horizontal, 40)
                            }.disabled(firstGoalTitle.isEmpty)
                            
                            let hasExistingGoals = !viewModel.getMonthData(for: Date()).dailyGoals.isEmpty
                            if isReplay || hasExistingGoals {
                                Button(action: { withAnimation { step += 1 } }) {
                                    Text("スキップして次へ").font(.subheadline).foregroundColor(.gray)
                                }
                            }
                        }
                    } else if step == 3 {
                        Button(action: {
                            saveFirstGoal()
                            UserDefaults.standard.set(true, forKey: "hasCompletedMainTutorial")
                            isShowing = false
                        }) {
                            Text("はじめる")
                                .font(.headline).foregroundColor(.white)
                                .padding().frame(maxWidth: .infinity)
                                .background(Color.pink)
                                .cornerRadius(12).padding(.horizontal, 40)
                        }
                    } else {
                        nextButton()
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(0..<4) { i in
                            Circle().fill(i == step ? Color.blue : Color.gray.opacity(0.3)).frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.bottom, 20)
                .background(Color(.systemBackground)) // ボタンエリアの背景を固定
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if step == 0 { isInputFocused = true }
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
        if viewModel.appSettings.appStartDate == nil {
            viewModel.appSettings.appStartDate = today
            viewModel.saveSettings()
        }
    }
}
