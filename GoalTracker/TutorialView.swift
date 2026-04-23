import SwiftUI
import WidgetKit // 🌟 ウィジェット更新用

struct TutorialView: View {
    // 🟢 ContentViewから直接渡されるため、@ObservedObjectに変更
    @ObservedObject var viewModel: GoalViewModel
    @Binding var isShowing: Bool
    
    @State private var step = 0
    @State private var firstGoalTitle = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if step == 0 {
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.mint) // アプリのテーマカラーに合わせる
                Text("HabitSparkへようこそ")
                    .font(.title.bold())
                Text("まずは、習慣化したい\n「最初の目標」を決めましょう。")
                    .multilineTextAlignment(.center)
                
                TextField("例：毎日10分読書する", text: $firstGoalTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
            } else if step == 1 {
                Image(systemName: "calendar.badge.checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.orange)
                Text("いいですね！")
                    .font(.title2.bold())
                // 🌟 修正版（記録に変更）
                Text("この目標は、毎日のタスクとして\n自動でカレンダーに登録されます。\n\n日々の記録は、ヒートマップや\n連続記録として可視化されます。")
                    .multilineTextAlignment(.center)
            } else if step == 2 {
                            Image(systemName: "square.and.pencil")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.green)
                            
                            Text("なぜ「KPT」で振り返るのか？")
                                .font(.title2.bold())
                            
                            // 🌟 修正版：KPTそれぞれの意味と「なぜやるのか」を明確化
                            VStack(spacing: 20) {
                                Text("振り返りを、次の行動につなげるためです。")
                                    .multilineTextAlignment(.center)
                                
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(alignment: .top) {
                                        Text("K").font(.headline).foregroundColor(.green).frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Keep（できたこと）").font(.subheadline).bold()
                                            Text("できたことを振り返り、自信と継続につなげる").font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    HStack(alignment: .top) {
                                        Text("P").font(.headline).foregroundColor(.orange).frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Problem（課題）").font(.subheadline).bold()
                                            Text("できなかった原因を整理する").font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    HStack(alignment: .top) {
                                        Text("T").font(.headline).foregroundColor(.blue).frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Try（次の行動）").font(.subheadline).bold()
                                            Text("後悔を、明日の「具体的なアクション」に変換する").font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Text("小さな改善を積み重ねて、少しずつ前に進みましょう。")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                            }

        
            } else if step == 3 {
                Image(systemName: "bell.badge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                Text("通知とウィジェット")
                    .font(.title2.bold())
                // 🌟 修正版（シンプルに）
                Text("通知とウィジェットで、\n継続をサポートします。\n\n通知を設定すれば、振り返りも忘れません。\nウィジェットで、今日のタスクもすぐ確認できます。")
                    .multilineTextAlignment(.center)
            } else if step == 4 {
                Image(systemName: "sparkles")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.pink)
                Text("準備完了です！")
                    .font(.title2.bold())
                // 🌟 そのまま採用（素晴らしい締め）
                Text("さあ、今日から始めましょう。\n\n小さな一歩が、未来を変えます。")
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // 🟢 インジケーター（ステップ数に合わせて5つに変更）
            HStack(spacing: 8) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i == step ? Color.mint : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
            
            // 🟢 ボタンエリア
            if step < 4 { // stepが4未満なら「次へ」
                Button(action: {
                    withAnimation { step += 1 }
                }) {
                    Text("次へ")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(firstGoalTitle.isEmpty && step == 0 ? Color.gray : Color.mint)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                .disabled(firstGoalTitle.isEmpty && step == 0) // 目標未入力なら押せない
            } else { // step4なら「はじめる」
                Button(action: {
                    saveFirstGoal()
                    UserDefaults.standard.set(true, forKey: "hasCompletedMainTutorial")
                    isShowing = false
                }) {
                    Text("はじめる")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.mint)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer().frame(height: 20)
        }
    }
    
    // 🟢 最初の目標を保存し、ウィジェットを更新する処理
    private func saveFirstGoal() {
        let today = Date()
        
        // 1. アプリ開始日を記録
        if viewModel.appSettings.appStartDate == nil {
            viewModel.appSettings.appStartDate = today
            viewModel.saveSettings()
        }
        
        // 2. 新しいデータ構造（カレンダーの「日次目標」）として保存
        if !firstGoalTitle.isEmpty {
            var currentMonthData = viewModel.getMonthData(for: today)
            
            // "action"カテゴリー（行動習慣）として日次目標に追加
            currentMonthData.dailyGoals.append(Goal(title: firstGoalTitle, categoryId: "action"))
            
            // ViewModelのメソッドを経由して保存することで、自動的に今日のタスクに展開され、CoreDataにも保存される
            viewModel.updateMonthlyGoals(currentMonthData.dailyGoals, field: .daily, date: today)
        }
        
        // 3. ウィジェットを即時更新して反映
        WidgetCenter.shared.reloadAllTimelines()
    }
}
