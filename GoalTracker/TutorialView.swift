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
                            .onSubmit {
                                if !firstGoalTitle.isEmpty { withAnimation { step += 1 } }
                            }
                    } else if step == 1 {
                        Image(systemName: "calendar.badge.checkmark").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.orange)
                        Text("完璧です！").font(.title2.bold())
                        Text("先ほど入力した目標は、\nあなたの「日次目標（毎日のタスク）」として\nカレンダーに登録されます。\n\n毎日の進捗は、自動でグラフ化され、\n週末には振り返りができるようになります。")
                            .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    } else if step == 2 {
                        Image(systemName: "square.and.pencil").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.green)
                        Text("KPTで振り返る").font(.title2.bold())
                        Text("このアプリの最大の特徴は\n**KPT（Keep / Problem / Try）**\nを使った振り返り機能です。\n\n**Keep**: できたこと・続けたいこと\n**Problem**: 課題・できなかったこと\n**Try**: 次に試すアクション\n\n週末や月末にこれらを書き出すことで、\n確実な成長に繋がります。")
                            .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    } else if step == 3 {
                        Image(systemName: "sparkles").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.pink)
                        Text("準備完了です！").font(.title2.bold())
                        Text("さあ、新しい習慣を始めましょう！\n\n後から「カレンダー」タブで\n月次目標や週次目標も追加できます。")
                            .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    if step == 0 {
                        Button(action: { withAnimation { step += 1 } }) {
                            Text("次へ")
                                .font(.headline).foregroundColor(.white)
                                .padding().frame(maxWidth: .infinity)
                                .background(firstGoalTitle.isEmpty ? Color.gray : Color.blue)
                                .cornerRadius(12).padding(.horizontal, 40)
                        }.disabled(firstGoalTitle.isEmpty)
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
        
        // 🟢 アプリ開始日を記録（すでにある場合は上書きしない）
        if viewModel.appSettings.appStartDate == nil {
            viewModel.appSettings.appStartDate = today
            viewModel.saveSettings()
        }
    }
}
