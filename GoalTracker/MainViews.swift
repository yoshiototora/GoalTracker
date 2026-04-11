//
//  MainViews.swift
//  GoalTracker
//

import SwiftUI
import UIKit

// MARK: - ホーム画面
struct HomeView: View {
    @ObservedObject var viewModel: GoalViewModel
    @State private var newTaskTitle = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                Text(viewModel.dateKey(viewModel.selectedDate)).font(.caption).foregroundColor(.gray)
                StreakBadgeView(streak: viewModel.currentDailyStreak) // キャッシュを参照
                HStack {
                    TextField("新しいタスク...", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isInputFocused)
                        .onSubmit { addTask() }
                    Button(action: addTask) { Image(systemName: "plus.circle.fill").font(.title) }
                }.padding()
                
                let currentTasks = viewModel.currentDailyNote.tasks // キャッシュを参照
                if currentTasks.isEmpty {
                    EmptyStateView(title: "今日のタスクはありません", description: "小さなことでも大丈夫です。\n今日の目標や、やるべきことを追加してみましょう！", action: { isInputFocused = true })
                } else {
                    List {
                        Section {
                            ForEach(currentTasks) { task in
                                HStack {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(task.isCompleted ? .green : .gray)
                                    if task.type == .dailyGoal { Text("日次: \(task.title)").strikethrough(task.isCompleted) }
                                    else if task.type == .tryCarryOver { Text(task.title).strikethrough(task.isCompleted).foregroundColor(.blue) }
                                    else { Text(task.title).strikethrough(task.isCompleted) }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if task.isYearlyReflection && Calendar.current.component(.month, from: viewModel.selectedDate) != 12 { return }
                                    let impact = UIImpactFeedbackGenerator(style: .medium); impact.impactOccurred()
                                    viewModel.toggleTask(id: task.id, for: viewModel.selectedDate)
                                }
                            }
                            .onDelete { offsets in viewModel.removeTasks(at: offsets, for: viewModel.selectedDate) }
                        }
                    }
                }
            }
            .navigationTitle("今日のタスク")
            .onAppear { viewModel.syncAll(for: viewModel.selectedDate) }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { isInputFocused = false } } }
        }
    }
    private func addTask() { if !newTaskTitle.isEmpty { viewModel.addTask(title: newTaskTitle, for: viewModel.selectedDate); newTaskTitle = "" } }
}

struct EmptyStateView: View {
    let title: String; let description: String; let action: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checklist.unchecked").font(.system(size: 70)).foregroundColor(.orange.opacity(0.7)).padding(.bottom, 10)
            Text(title).font(.title3).bold().foregroundColor(.primary)
            Text(description).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: action) { HStack { Image(systemName: "plus"); Text("タスクを追加") }.font(.headline).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 12).background(Color.blue).cornerRadius(20).shadow(color: .blue.opacity(0.3), radius: 5, y: 3) }.padding(.top, 10)
            Spacer()
        }
    }
}

struct StatBox: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) { Text(title).font(.caption2).foregroundColor(.gray); Text(value).font(.title3).bold().foregroundColor(color) }
        .frame(maxWidth: .infinity).padding(.vertical, 8).background(Color(.systemGray6)).cornerRadius(10)
    }
}


// MARK: - 振り返り画面
struct ReflectionView: View {
    @ObservedObject var viewModel: GoalViewModel
    @State private var reflectionType = 0
    @State private var showYearlyAnimation = false
    @FocusState private var isKeyboardVisible: Bool
    
    private var isSunday: Bool { Calendar.current.component(.weekday, from: viewModel.selectedDate) == 1 }
    private var isLastDayOfMonth: Bool { let cal = Calendar.current; let date = viewModel.selectedDate; let nextDay = cal.date(byAdding: .day, value: 1, to: date) ?? date; return cal.component(.month, from: date) != cal.component(.month, from: nextDay) }
    private var isDecember: Bool { Calendar.current.component(.month, from: viewModel.selectedDate) == 12 }
    
    var body: some View {
        // ViewModelのキャッシュを参照
        let note = viewModel.currentDailyNote
        let weekData = viewModel.currentWeekData
        let monthData = viewModel.currentMonthData
        let nextMonthData = viewModel.nextMonthData
        let nextMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        
        NavigationView {
            VStack(spacing: 0) {
                Picker("振り返り", selection: $reflectionType) {
                    Text("日次").tag(0); if isSunday { Text("週次").tag(1) }; if isLastDayOfMonth { Text("月次").tag(2) }; if isDecember { Text("年次").tag(3) }
                }.pickerStyle(SegmentedPickerStyle()).padding()
                .onChange(of: viewModel.selectedDate) { _, _ in if reflectionType == 1 && !isSunday { reflectionType = 0 }; if reflectionType == 2 && !isLastDayOfMonth { reflectionType = 0 }; if reflectionType == 3 && !isDecember { reflectionType = 0 } }
                
                TabView(selection: $reflectionType) {
                    
                    // 🟢 日次振り返り
                    ScrollView {
                        VStack(spacing: 15) {
                            ReflectionAchievementCard(title: "\(viewModel.getDailyTitle(for: viewModel.selectedDate))の達成度", rate1: viewModel.getDailyCompletionRate(for: viewModel.selectedDate), rate2: nil, rate3: nil, color2: .clear, color3: .clear)
                            VStack(alignment: .leading, spacing: 10) {
                                TextEditorView(title: "Keep（できたこと）", text: Binding(get: { note.keep }, set: { viewModel.updateDailyNote($0, field: .keep, date: viewModel.selectedDate) }), placeholder: "例：午前中に一番重いタスクを終わらせることができた！").focused($isKeyboardVisible)
                                
                                TextEditorView(title: "Problem（課題）", text: Binding(get: { note.problem }, set: { viewModel.updateDailyNote($0, field: .problem, date: viewModel.selectedDate) }), placeholder: "例：夕方、SNSを無意識に見てしまい時間が溶けた").focused($isKeyboardVisible)
                                
                                BulletInputSection(title: "Try（次回へのアクション）", items: note.tryList, placeholder: "例：作業中はスマホを別の部屋に置く", onUpdate: { viewModel.updateDailyTryList($0, date: viewModel.selectedDate) })
                            }.padding(.horizontal)
                        }.padding(.vertical)
                    }.tag(0)
                    
                    // 🟠 週次振り返り
                    if isSunday {
                        ScrollView {
                            VStack(spacing: 15) {
                                ReflectionAchievementCard(title: "\(viewModel.getWeeklyTitle(for: viewModel.selectedDate))の達成度", rate1: viewModel.getWeeklyDailyAvgRate(for: viewModel.selectedDate), rate2: viewModel.getWeeklyGoalRate(for: viewModel.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                                VStack(alignment: .leading, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("🏆 今週の達成記録").font(.caption).bold().foregroundColor(.primary)
                                        HStack { StatBox(title: "完了タスク", value: "\(viewModel.getCompletedTasksCount(for: viewModel.selectedDate, isWeekly: true))個", color: .green); StatBox(title: "Try実行", value: "\(viewModel.getTryExecutionCount(for: viewModel.selectedDate, isWeekly: true))回", color: .red) }
                                        let compText = viewModel.getComparisonText(for: viewModel.selectedDate, isWeekly: true)
                                        Text(compText).font(.caption).bold().foregroundColor(compText.contains("アップ") ? .orange : .gray).padding(.top, 4)
                                    }
                                    GoalListSection(title: "今週の目標チェック", iconColor: .orange, goals: weekData.goals, showCheckboxes: true, onUpdate: { viewModel.updateWeeklyGoals($0, date: viewModel.selectedDate) })
                                    
                                    TextEditorView(title: "今週のKeep", text: Binding(get: { weekData.keep }, set: { viewModel.updateWeeklyText($0, field: .keep, date: viewModel.selectedDate) }), placeholder: "例：週の前半は毎日読書の時間を確保できた").focused($isKeyboardVisible)
                                    
                                    TextEditorView(title: "今週のProblem", text: Binding(get: { weekData.problem }, set: { viewModel.updateWeeklyText($0, field: .problem, date: viewModel.selectedDate) }), placeholder: "例：木曜以降、疲れが溜まって早起きができなかった").focused($isKeyboardVisible)
                                    
                                    BulletInputSection(title: "来週のTry", items: weekData.tryList, placeholder: "例：水曜日は意識して早く寝る日を作る", onUpdate: { viewModel.updateWeeklyTryList($0, date: viewModel.selectedDate) })
                                    
                                    TextEditorView(title: "振り返り（自由記述）", text: Binding(get: { weekData.reflection }, set: { viewModel.updateWeeklyText($0, field: .reflection, date: viewModel.selectedDate) }), minHeight: 120, placeholder: "例：今週は全体的に集中力が高かった。来週もこのペースを維持したい！").focused($isKeyboardVisible)
                                }.padding(.horizontal)
                            }.padding(.vertical)
                        }.tag(1)
                    }
                    
                    // 🔵 月次振り返り
                    if isLastDayOfMonth {
                        ScrollView {
                            VStack(spacing: 15) {
                                ReflectionAchievementCard(title: "\(viewModel.getMonthlyTitle(for: viewModel.selectedDate))の達成度", rate1: viewModel.getMonthlyDailyAvgRate(for: viewModel.selectedDate), rate2: viewModel.getMonthlyWeeklyGoalAvgRate(for: viewModel.selectedDate), rate3: viewModel.getMonthlyGoalRate(for: viewModel.selectedDate), color2: .orange, color3: .blue)
                                VStack(alignment: .leading, spacing: 10) {
                                    GoalListSection(title: "今月の目標チェック", iconColor: .blue, goals: monthData.monthlyGoals, showCheckboxes: true, onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: viewModel.selectedDate) })
                                    
                                    TextEditorView(title: "今月のKeep", text: Binding(get: { monthData.keep }, set: { viewModel.updateMonthlyText($0, field: .keep, date: viewModel.selectedDate) }), placeholder: "例：新しい習慣を1ヶ月間途切れずに継続できた！").focused($isKeyboardVisible)
                                    
                                    TextEditorView(title: "今月のProblem", text: Binding(get: { monthData.problem }, set: { viewModel.updateMonthlyText($0, field: .problem, date: viewModel.selectedDate) }), placeholder: "例：月末にかけてタスクの消化率が落ちてしまった").focused($isKeyboardVisible)
                                    
                                    BulletInputSection(title: "来月のTry", items: monthData.tryList, placeholder: "例：毎週末に翌週のスケジュールを立てる時間を取る", onUpdate: { viewModel.updateMonthlyTryList($0, date: viewModel.selectedDate) })
                                    
                                    TextEditorView(title: "振り返り（自由記述）", text: Binding(get: { monthData.reflection }, set: { viewModel.updateMonthlyText($0, field: .reflection, date: viewModel.selectedDate) }), minHeight: 120, placeholder: "例：目標の7割は達成できた良い月だった。来月はもう少し高めの目標に挑戦する。").focused($isKeyboardVisible)
                                    
                                    Divider().padding(.vertical, 8)
                                    Text("🚀 来月に向けて").font(.subheadline).bold().foregroundColor(.blue)
                                    GoalListSection(title: "来月の月次目標", iconColor: .blue, goals: nextMonthData.monthlyGoals, showCheckboxes: false, onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: nextMonthDate) })
                                    GoalListSection(title: "来月の週次目標", iconColor: .orange, goals: nextMonthData.weeklyGoals, showCheckboxes: false, onUpdate: { viewModel.updateMonthlyGoals($0, field: .weekly, date: nextMonthDate) })
                                    GoalListSection(title: "来月の日次目標", iconColor: .green, goals: nextMonthData.dailyGoals, showCheckboxes: false, onUpdate: { viewModel.updateMonthlyGoals($0, field: .daily, date: nextMonthDate) })
                                }.padding(.horizontal)
                            }.padding(.vertical)
                        }.tag(2)
                    }
                    
                    // 🎉 年次振り返り
                    if isDecember {
                        ZStack {
                            ScrollView {
                                VStack(spacing: 20) {
                                    Text("🎉 年末の振り返り").font(.title2).bold().padding(.top)
                                    VStack(alignment: .leading, spacing: 15) {
                                        ForEach(viewModel.futureVisions) { vision in
                                            let isReadyToComplete = vision.subTasks.isEmpty ? true : vision.subTasks.allSatisfy { $0.isCompleted }
                                            VStack(alignment: .leading, spacing: 12) {
                                                HStack {
                                                    Button(action: {
                                                        withAnimation(.spring()) {
                                                            viewModel.toggleFutureVisionCompleted(id: vision.id)
                                                            if let updated = viewModel.futureVisions.first(where: { $0.id == vision.id }), updated.isCompleted {
                                                                showYearlyAnimation = true; DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showYearlyAnimation = false }
                                                            }
                                                        }
                                                    }) { Image(systemName: vision.isCompleted ? "checkmark.circle.fill" : (isReadyToComplete ? "arrow.up.circle.fill" : "circle")).foregroundColor(vision.isCompleted ? .pink : (isReadyToComplete ? .orange : .gray)).font(.title2) }.disabled(!isReadyToComplete && !vision.isCompleted).buttonStyle(PlainButtonStyle())
                                                    Text(vision.title).font(.headline).strikethrough(vision.isCompleted).foregroundColor(vision.isCompleted ? .secondary : .primary); Spacer()
                                                    Text("\(Int(vision.progress * 100))%").font(.system(.subheadline, design: .rounded)).bold().foregroundColor(vision.progress == 1.0 ? .pink : .secondary)
                                                }
                                                ProgressView(value: vision.progress).tint(vision.progress == 1.0 ? .pink : .orange).scaleEffect(x: 1, y: 1.5)
                                                
                                                // 👇 追加：具体的なステップ（サブタスク）のリスト表示
                                                if !vision.subTasks.isEmpty {
                                                    Divider().padding(.vertical, 4)
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        ForEach(vision.subTasks) { subTask in
                                                            HStack {
                                                                Button(action: {
                                                                    viewModel.toggleSubTaskCompleted(visionId: vision.id, subTaskId: subTask.id)
                                                                }) {
                                                                    Image(systemName: subTask.isCompleted ? "checkmark.square.fill" : "square")
                                                                        .foregroundColor(subTask.isCompleted ? .pink : .gray)
                                                                        .font(.system(size: 18))
                                                                }
                                                                .buttonStyle(PlainButtonStyle())
                                                                
                                                                Text(subTask.title)
                                                                    .font(.subheadline)
                                                                    .strikethrough(subTask.isCompleted)
                                                                    .foregroundColor(subTask.isCompleted ? .secondary : .primary)
                                                                Spacer()
                                                            }
                                                        }
                                                    }
                                                }
                                                // 👆 追加ここまで
                                                
                                            }.padding().background(vision.isCompleted ? Color.pink.opacity(0.05) : Color(.systemGray6).opacity(0.3)).cornerRadius(15).padding(.horizontal)
                                        }
                                    }
                                }.padding(.bottom, 50)
                            }
                            if showYearlyAnimation { LuxuriousCompletionEffect(completedCount: viewModel.futureVisions.filter { $0.isCompleted }.count).transition(.opacity).zIndex(1) }
                        }.tag(3)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never))
            }.navigationTitle("振り返り")
            .onAppear { viewModel.syncAll(for: viewModel.selectedDate) }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { isKeyboardVisible = false } } }
        }
    }
}

// MARK: - カレンダー画面
struct CalendarView: View {
    @ObservedObject var viewModel: GoalViewModel; @Binding var selectedTab: Int
    @State private var monthOffset: Int = 0
    private func displayDate(for offset: Int) -> Date { let c = Calendar.current; return c.date(byAdding: .month, value: offset, to: c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()) ?? Date() }

    var body: some View {
        NavigationView {
            TabView(selection: $monthOffset) {
                ForEach(-60..<61, id: \.self) { offset in
                    let currentDisplayDate = displayDate(for: offset)
                    let monthData = viewModel.getMonthData(for: currentDisplayDate)
                    ScrollView {
                        VStack(spacing: 15) {
                            HStack(spacing: 10) {
                                CompositeSummaryCard(title: "\(viewModel.getWeeklyTitle(for: viewModel.selectedDate))の達成度", rate1: viewModel.getWeeklyDailyAvgRate(for: viewModel.selectedDate), rate2: viewModel.getWeeklyGoalRate(for: viewModel.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                                CompositeSummaryCard(title: "\(viewModel.getMonthlyTitle(for: currentDisplayDate))の達成度", rate1: viewModel.getMonthlyDailyAvgRate(for: currentDisplayDate), rate2: viewModel.getMonthlyWeeklyGoalAvgRate(for: currentDisplayDate), rate3: viewModel.getMonthlyGoalRate(for: currentDisplayDate), color2: .orange, color3: .blue)
                            }.padding(.horizontal)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Image(systemName: "arrowshape.turn.up.right.fill").foregroundColor(.blue).font(.caption); Text("過去からのバトン").font(.caption).bold().foregroundColor(.secondary) }.padding(.horizontal)
                                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { BatonTag(title: "先月より", items: viewModel.getLastMonthlyTryList(for: currentDisplayDate), color: .blue); BatonTag(title: "先週より", items: viewModel.getLastWeeklyTryList(for: viewModel.selectedDate), color: .orange); BatonTag(title: "昨日より", items: viewModel.getYesterdayTryList(for: viewModel.selectedDate), color: .green) }.padding(.horizontal) }
                            }.padding(.vertical, 5)
                            VStack(spacing: 10) {
                                GoalListSection(title: "\(viewModel.getMonthlyTitle(for: currentDisplayDate))の月次目標", iconColor: .blue, goals: monthData.monthlyGoals, showCheckboxes: false, onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: currentDisplayDate) }, onCopy: { copyPrev(field: .monthly, date: currentDisplayDate) })
                                GoalListSection(title: "\(viewModel.getMonthlyTitle(for: currentDisplayDate))の週次目標", iconColor: .orange, goals: monthData.weeklyGoals, showCheckboxes: false, onUpdate: { viewModel.updateMonthlyGoals($0, field: .weekly, date: currentDisplayDate) }, onCopy: { copyPrev(field: .weekly, date: currentDisplayDate) })
                                GoalListSection(title: "\(viewModel.getMonthlyTitle(for: currentDisplayDate))の日次目標", iconColor: .green, goals: monthData.dailyGoals, showCheckboxes: false, onUpdate: { viewModel.updateMonthlyGoals($0, field: .daily, date: currentDisplayDate) }, onCopy: { copyPrev(field: .daily, date: currentDisplayDate) })
                            }.padding(.horizontal)
                            CalendarGridView(viewModel: viewModel, displayDate: currentDisplayDate, selectedDate: $viewModel.selectedDate, selectedTab: $selectedTab)
                        }.padding(.top, 10).tag(offset)
                    }
                }
            }.tabViewStyle(.page(indexDisplayMode: .never)).navigationTitle(viewModel.getMonthlyTitle(for: displayDate(for: monthOffset))).navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func copyPrev(field: GoalViewModel.GoalField, date: Date) {
        let prevDate = Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date
        let prevData = viewModel.getMonthData(for: prevDate)
        var newGoals = [Goal]()
        if field == .monthly { newGoals = prevData.monthlyGoals } else if field == .weekly { newGoals = prevData.weeklyGoals } else { newGoals = prevData.dailyGoals }
        
        let currentData = viewModel.getMonthData(for: date)
        var currentGoals = field == .monthly ? currentData.monthlyGoals : (field == .weekly ? currentData.weeklyGoals : currentData.dailyGoals)
        let existingTitles = currentGoals.map { $0.title }
        
        for g in newGoals { if !existingTitles.contains(g.title) { currentGoals.append(Goal(title: g.title)) } }
        viewModel.updateMonthlyGoals(currentGoals, field: field, date: date)
        viewModel.syncAll(for: viewModel.selectedDate)
    }
}

// MARK: - 設定画面
struct SettingsView: View {
    @ObservedObject var viewModel: GoalViewModel; @State private var isTutorial = false
    var body: some View {
        NavigationView {
            Form {
                Section("通知設定") {
                    Toggle("目標通知", isOn: Binding(get: { viewModel.appSettings.goalNotificationEnabled }, set: { viewModel.appSettings.goalNotificationEnabled = $0; viewModel.saveSettings() }))
                    if viewModel.appSettings.goalNotificationEnabled { DatePicker("時間", selection: Binding(get: { viewModel.appSettings.goalNotificationTime }, set: { viewModel.appSettings.goalNotificationTime = $0; viewModel.saveSettings() }), displayedComponents: .hourAndMinute) }
                    Toggle("振り返り通知", isOn: Binding(get: { viewModel.appSettings.reflectionNotificationEnabled }, set: { viewModel.appSettings.reflectionNotificationEnabled = $0; viewModel.saveSettings() }))
                    if viewModel.appSettings.reflectionNotificationEnabled { DatePicker("時間", selection: Binding(get: { viewModel.appSettings.reflectionNotificationTime }, set: { viewModel.appSettings.reflectionNotificationTime = $0; viewModel.saveSettings() }), displayedComponents: .hourAndMinute) }
                }
                Section("サポート") { Button(action: { isTutorial = true }) { HStack { Image(systemName: "book.fill").foregroundColor(.blue).frame(width: 24); Text("使い方ガイド").foregroundColor(.primary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary) }.contentShape(Rectangle()) }.buttonStyle(.plain) }
            }.navigationTitle("設定").sheet(isPresented: $isTutorial) { TutorialView(isShowing: $isTutorial) }
        }
    }
}

// MARK: - 未来の自分画面
struct FutureVisionView: View {
    @ObservedObject var viewModel: GoalViewModel; @State private var newVisionTitle = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                Text("目標を達成した先に、どうなっていたいですか？\n大きな目標に対して、具体的なステップを追加して夢を可視化しましょう。").font(.caption).foregroundColor(.secondary).padding()
                HStack {
                    TextField("例：海外で働く！", text: $newVisionTitle).textFieldStyle(RoundedBorderTextFieldStyle()).focused($isInputFocused).onSubmit { if !newVisionTitle.isEmpty { viewModel.addFutureVision(title: newVisionTitle); newVisionTitle = "" } }
                    Button(action: { if !newVisionTitle.isEmpty { viewModel.addFutureVision(title: newVisionTitle); newVisionTitle = "" } }) { Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.pink) }.buttonStyle(PlainButtonStyle())
                }.padding(.horizontal)
                List {
                    ForEach(viewModel.futureVisions) { vision in FutureVisionRow(vision: vision, viewModel: viewModel) }
                    .onDelete { offsets in viewModel.removeFutureVision(at: offsets) }
                }
            }
            .navigationTitle("✨ 未来の自分")
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { isInputFocused = false } } }
        }
    }
}

struct BatonTag: View {
    let title: String; let items: [String]; let color: Color
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 9, weight: .bold)).foregroundColor(color)
                ForEach(items, id: \.self) { item in Text("• \(item)").font(.system(size: 11)).lineLimit(1).foregroundColor(.primary) }
            }.padding(8).background(color.opacity(0.1)).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }
}

struct FutureVisionRow: View {
    let vision: FutureVision; @ObservedObject var viewModel: GoalViewModel
    @State private var isExpanded = false; @State private var newSubTaskText = ""
    @FocusState private var isSubTaskFocused: Bool
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(vision.subTasks) { subTask in
                    HStack {
                        Button(action: { viewModel.toggleSubTaskCompleted(visionId: vision.id, subTaskId: subTask.id) }) { Image(systemName: subTask.isCompleted ? "checkmark.square.fill" : "square").foregroundColor(subTask.isCompleted ? .pink : .gray).font(.system(size: 20)) }.buttonStyle(PlainButtonStyle())
                        Text(subTask.title).strikethrough(subTask.isCompleted).foregroundColor(subTask.isCompleted ? .secondary : .primary); Spacer()
                        Button(action: { if let index = vision.subTasks.firstIndex(where: { $0.id == subTask.id }) { viewModel.deleteSubTasks(visionId: vision.id, at: IndexSet(integer: index)) } }) { Image(systemName: "trash").foregroundColor(.red.opacity(0.6)).font(.system(size: 16)) }.buttonStyle(PlainButtonStyle()).padding(.leading, 6)
                    }.padding(.vertical, 2)
                }
                HStack {
                    Image(systemName: "arrow.turn.down.right").foregroundColor(.gray).font(.caption)
                    TextField("具体的なステップを追加...", text: $newSubTaskText).textFieldStyle(PlainTextFieldStyle()).focused($isSubTaskFocused).onSubmit { addSubTask() }
                    Button(action: { addSubTask() }) { Image(systemName: "plus.circle.fill").foregroundColor(newSubTaskText.isEmpty ? .gray.opacity(0.3) : .pink).font(.system(size: 24)) }.disabled(newSubTaskText.isEmpty).buttonStyle(PlainButtonStyle())
                }.padding(.top, 5)
            }.padding(.leading, 10)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: { viewModel.toggleFutureVisionCompleted(id: vision.id) }) { Image(systemName: vision.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(vision.isCompleted ? .pink : .gray).font(.title3) }.buttonStyle(PlainButtonStyle())
                    Text(vision.title).font(.headline).strikethrough(vision.isCompleted)
                }
                if !vision.subTasks.isEmpty { ProgressView(value: vision.progress).tint(.pink).scaleEffect(x: 1, y: 0.5, anchor: .center) }
            }.padding(.vertical, 4)
        }
    }
    private func addSubTask() { guard !newSubTaskText.isEmpty else { return }; viewModel.addSubTask(to: vision.id, title: newSubTaskText); newSubTaskText = "" }
}
