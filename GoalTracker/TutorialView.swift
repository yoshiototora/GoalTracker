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
            
            VStack(spacing: 30) {
                Spacer()
                
                if step == 0 {
                    Image(systemName: "target").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.blue)
                    Text("ようこそ！\nまずは最初の目標を決めましょう").font(.title2.bold()).multilineTextAlignment(.center)
                    Text("このアプリはあなたの「習慣化」をサポートします。\n毎日続けたい行動を1つ教えてください。\n（例：読書を10分、水を1L飲む）").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    
                    TextField("最初の目標を入力...", text: $firstGoalTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isInputFocused)
                        .padding(.horizontal, 40)
                    
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
                    
                } else if step == 1 {
                    Image(systemName: "house.fill").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.orange)
                    Text("目標が毎日のタスクに").font(.title2.bold())
                    Text("先ほど入力した目標は、\n毎日「ホーム画面」にタスクとして自動で表示されます。\n完了したらタップしてチェックを入れましょう！").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    
                    nextButton()
                } else if step == 2 {
                    Image(systemName: "square.and.pencil").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.green)
                    Text("KPTで振り返り").font(.title2.bold())
                    Text("1日の終わりには「振り返り」画面で\nKeep(よかったこと)、Problem(課題)、Try(次やること)\nを記録して自己成長に繋げましょう。\n\n日曜日には週次、月末には月次、年末には年次の\n特別な振り返りも登場します！").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    
                    nextButton()
                } else if step == 3 {
                    Image(systemName: "calendar").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.purple)
                    Text("努力をカレンダーに刻む").font(.title2.bold())
                    Text("毎日のタスクを達成すると、カレンダーの\nヒートマップが濃く色付いていきます。\n色の濃さがあなたの継続の証です！").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    
                    nextButton()
                } else if step == 4 {
                    Image(systemName: "sparkles").resizable().scaledToFit().frame(width: 100, height: 100).foregroundColor(.pink)
                    Text("未来の自分を描く").font(.title2.bold())
                    Text("「未来の自分」画面では、いつか叶えたい大きな夢を\n具体的なステップに分解して管理できます。\nすべてのステップをクリアすると特別な演出が…！").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    
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
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(0..<5) { i in
                        Circle().fill(i == step ? Color.blue : Color.gray.opacity(0.3)).frame(width: 8, height: 8)
                    }
                }.padding(.bottom, 20)
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
            // 🟢 カテゴリーを action から none（指定なし）に変更
            currentMonthData.dailyGoals.append(Goal(title: firstGoalTitle, categoryId: "none"))
            viewModel.updateMonthlyGoals(currentMonthData.dailyGoals, field: .daily, date: today)
            viewModel.syncAll(for: today)
        }
    }
}
