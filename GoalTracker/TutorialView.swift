import SwiftUI
import WidgetKit

struct TutorialView: View {
    @ObservedObject var viewModel: GoalViewModel
    @Binding var isShowing: Bool
    
    @State private var step = 0
    @State private var firstGoalTitle = ""
    
    // 過去に一度でもチュートリアルを完了したかどうかのフラグ
    @AppStorage("hasCompletedMainTutorial") private var hasCompletedTutorial = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if step == 0 {
                Image(systemName: "flame.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.mint)
                Text("HabitSparkへようこそ")
                    .font(.title.bold())
                Text("まずは、習慣化したい\n「最初の目標」を決めましょう。")
                    .multilineTextAlignment(.center)
                
                TextField(LocalizedStringKey("例：毎日10分読書する"), text: $firstGoalTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                
                if hasCompletedTutorial {
                    Text("※以前入力した目標がある場合は、空欄のままスキップできます。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
            } else if step == 1 {
                Image(systemName: "calendar.badge.checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.orange)
                Text("いいですね！")
                    .font(.title2.bold())
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
                Text("さあ、今日から始めましょう。\n\n小さな一歩が、未来を変えます。")
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i == step ? Color.mint : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
            
            if step < 4 {
                Button(action: {
                    withAnimation { step += 1 }
                }) {
                    // 🌟 修正：三項演算子の結果をString(localized:)で囲む
                    Text((step == 0 && firstGoalTitle.isEmpty && hasCompletedTutorial) ? String(localized: "スキップ") : String(localized: "次へ"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((firstGoalTitle.isEmpty && step == 0 && !hasCompletedTutorial) ? Color.gray : Color.mint)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                .disabled(firstGoalTitle.isEmpty && step == 0 && !hasCompletedTutorial)
                
            } else {
                Button(action: {
                    saveFirstGoal()
                    hasCompletedTutorial = true
                    isShowing = false
                }) {
                    // 🌟 修正：三項演算子の結果をString(localized:)で囲む
                    Text(hasCompletedTutorial ? String(localized: "閉じる") : String(localized: "はじめる"))
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
    
    private func saveFirstGoal() {
        let today = Date()
        
        if viewModel.appSettings.appStartDate == nil {
            viewModel.appSettings.appStartDate = today
            viewModel.saveSettings()
        }
        
        if !firstGoalTitle.isEmpty {
            var currentMonthData = viewModel.getMonthData(for: today)
            currentMonthData.dailyGoals.append(Goal(title: firstGoalTitle, categoryId: "action", startDate: today))
            viewModel.updateMonthlyGoals(currentMonthData.dailyGoals, field: .daily, date: today)
        }
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}
