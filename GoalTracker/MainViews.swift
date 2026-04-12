//
//  MainViews.swift
//  GoalTracker
//

import SwiftUI
import UIKit

// MARK: - ホーム画面
struct HomeView: View {
    @ObservedObject var viewModel: GoalViewModel
    @Binding var selectedTab: Int
    @State private var newTaskTitle = ""
    @FocusState private var isInputFocused: Bool
    
    @AppStorage("goalTutorialStep") var tutorialStep = 0
    @State private var editingTask: Task? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                Text(viewModel.dateKey(viewModel.selectedDate)).font(.caption).foregroundColor(.gray)
                StreakBadgeView(streak: viewModel.currentDailyStreak)
                HStack {
                    TextField("今日だけのタスク...", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isInputFocused)
                        .onSubmit { addTask() }
                    Button(action: addTask) { Image(systemName: "plus.circle.fill").font(.title).foregroundColor(.gray) }
                }.padding()
                
                let currentTasks = viewModel.currentDailyNote.tasks
                let hasDailyGoals = !viewModel.currentMonthData.dailyGoals.isEmpty
                
                if currentTasks.isEmpty {
                    if !hasDailyGoals {
                        EmptyStateView(
                            title: "目標・習慣を設定しましょう",
                            description: "このアプリはあなたの「習慣化」をサポートします！\nまずはカレンダータブから、今月の日次目標（毎日やりたい習慣）を追加してみましょう。",
                            buttonTitle: "カレンダーを開く",
                            iconName: "target",
                            action: {
                                selectedTab = 2
                                if tutorialStep == 0 { tutorialStep = 1 }
                            }
                        )
                    } else {
                        EmptyStateView(
                            title: "今日のタスクはありません",
                            description: "今日のやるべきことを追加してみましょう！",
                            buttonTitle: "タスクを追加",
                            iconName: "checklist.unchecked",
                            action: { isInputFocused = true }
                        )
                    }
                } else {
                    List {
                        Section {
                            ForEach(currentTasks) { task in
                                let cat = viewModel.getCategory(id: task.categoryId)
                                HStack(spacing: 12) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(task.isCompleted ? .green : cat.color)
                                        .font(.system(size: 22))
                                    
                                    if task.type == .dailyGoal {
                                        Text(task.title).bold()
                                            .strikethrough(task.isCompleted)
                                            .foregroundColor(task.isCompleted ? .gray : .primary)
                                    }
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        if let idx = currentTasks.firstIndex(where: { $0.id == task.id }) {
                                            viewModel.removeTasks(at: IndexSet(integer: idx), for: viewModel.selectedDate)
                                        }
                                    } label: { Image(systemName: "trash") }
                                    
                                    Button {
                                        editingTask = task
                                    } label: { Image(systemName: "pencil") }.tint(.orange)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .sheet(item: $editingTask) { task in
                        EditItemSheet(viewModel: viewModel, title: task.title, categoryId: task.categoryId) { newTitle, newCatId in
                            viewModel.editTask(id: task.id, newTitle: newTitle, newCategoryId: newCatId, for: viewModel.selectedDate)
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
    let title: String; let description: String; let buttonTitle: String; let iconName: String; let action: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: iconName).font(.system(size: 70)).foregroundColor(.orange.opacity(0.7)).padding(.bottom, 10)
            Text(title).font(.title3).bold().foregroundColor(.primary)
            Text(description).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: action) { HStack { Image(systemName: "plus"); Text(buttonTitle) }.font(.headline).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 12).background(Color.blue).cornerRadius(20).shadow(color: .blue.opacity(0.3), radius: 5, y: 3) }.padding(.top, 10)
            Spacer()
        }
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
    
    let dailyTemplates = ["読書を10分", "水を1.5L飲む", "スクワット15回", "日記を1行書く", "5分片付け"]
    let weeklyTemplates = ["ジムに2回行く", "本を1冊読む", "休肝日を2日作る", "作り置きをする", "週末に掃除機"]
    let monthlyTemplates = ["体重を1kg落とす", "本を3冊読む", "映画を3本見る", "貯金1万円", "新しい場所に行く"]
    
    var body: some View {
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
                    
                    if isSunday {
                        ScrollView {
                            VStack(spacing: 15) {
                                ReflectionAchievementCard(title: "\(viewModel.getWeeklyTitle(for: viewModel.selectedDate))の達成度", rate1: viewModel.getWeeklyDailyAvgRate(for: viewModel.selectedDate), rate2: viewModel.getWeeklyGoalRate(for: viewModel.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                                VStack(alignment: .leading, spacing: 10) {
                                    GoalListSection(title: "今週の目標チェック", iconColor: .orange, goals: weekData.goals, viewModel: viewModel, showCheckboxes: true, templates: weeklyTemplates, onUpdate: { viewModel.updateWeeklyGoals($0, date: viewModel.selectedDate) })
                                    TextEditorView(title: "今週のKeep", text: Binding(get: { weekData.keep }, set: { viewModel.updateWeeklyText($0, field: .keep, date: viewModel.selectedDate) }), placeholder: "例：週の前半は毎日読書の時間を確保できた").focused($isKeyboardVisible)
                                    TextEditorView(title: "今週のProblem", text: Binding(get: { weekData.problem }, set: { viewModel.updateWeeklyText($0, field: .problem, date: viewModel.selectedDate) }), placeholder: "例：木曜以降、疲れが溜まって早起きができなかった").focused($isKeyboardVisible)
                                    BulletInputSection(title: "来週のTry", items: weekData.tryList, placeholder: "例：水曜日は意識して早く寝る日を作る", onUpdate: { viewModel.updateWeeklyTryList($0, date: viewModel.selectedDate) })
                                    TextEditorView(title: "振り返り（自由記述）", text: Binding(get: { weekData.reflection }, set: { viewModel.updateWeeklyText($0, field: .reflection, date: viewModel.selectedDate) }), minHeight: 120, placeholder: "例：今週は全体的に集中力が高かった。来週もこのペースを維持したい！").focused($isKeyboardVisible)
                                }.padding(.horizontal)
                            }.padding(.vertical)
                        }.tag(1)
                    }
                    
                    if isLastDayOfMonth {
                        ScrollView {
                            VStack(spacing: 15) {
                                ReflectionAchievementCard(title: "\(viewModel.getMonthlyTitle(for: viewModel.selectedDate))の達成度", rate1: viewModel.getMonthlyDailyAvgRate(for: viewModel.selectedDate), rate2: viewModel.getMonthlyWeeklyGoalAvgRate(for: viewModel.selectedDate), rate3: viewModel.getMonthlyGoalRate(for: viewModel.selectedDate), color2: .orange, color3: .blue)
                                VStack(alignment: .leading, spacing: 10) {
                                    GoalListSection(title: "今月の目標チェック", iconColor: .blue, goals: monthData.monthlyGoals, viewModel: viewModel, showCheckboxes: true, templates: monthlyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: viewModel.selectedDate) })
                                    TextEditorView(title: "今月のKeep", text: Binding(get: { monthData.keep }, set: { viewModel.updateMonthlyText($0, field: .keep, date: viewModel.selectedDate) }), placeholder: "例：新しい習慣を1ヶ月間途切れずに継続できた！").focused($isKeyboardVisible)
                                    TextEditorView(title: "今月のProblem", text: Binding(get: { monthData.problem }, set: { viewModel.updateMonthlyText($0, field: .problem, date: viewModel.selectedDate) }), placeholder: "例：月末にかけてタスクの消化率が落ちてしまった").focused($isKeyboardVisible)
                                    BulletInputSection(title: "来月のTry", items: monthData.tryList, placeholder: "例：毎週末に翌週のスケジュールを立てる時間を取る", onUpdate: { viewModel.updateMonthlyTryList($0, date: viewModel.selectedDate) })
                                    TextEditorView(title: "振り返り（自由記述）", text: Binding(get: { monthData.reflection }, set: { viewModel.updateMonthlyText($0, field: .reflection, date: viewModel.selectedDate) }), minHeight: 120, placeholder: "例：目標の7割は達成できた良い月だった。来月はもう少し高めの目標に挑戦する。").focused($isKeyboardVisible)
                                    Divider().padding(.vertical, 8)
                                    Text("🚀 来月に向けて").font(.subheadline).bold().foregroundColor(.blue)
                                    GoalListSection(title: "来月の月次目標", iconColor: .blue, goals: nextMonthData.monthlyGoals, viewModel: viewModel, showCheckboxes: false, templates: monthlyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: nextMonthDate) })
                                    GoalListSection(title: "来月の週次目標", iconColor: .orange, goals: nextMonthData.weeklyGoals, viewModel: viewModel, showCheckboxes: false, templates: weeklyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .weekly, date: nextMonthDate) })
                                    GoalListSection(title: "来月の日次目標", iconColor: .green, goals: nextMonthData.dailyGoals, viewModel: viewModel, showCheckboxes: false, templates: dailyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .daily, date: nextMonthDate) })
                                }.padding(.horizontal)
                            }.padding(.vertical)
                        }.tag(2)
                    }
                    
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
                                                
                                                if !vision.subTasks.isEmpty {
                                                    Divider().padding(.vertical, 4)
                                                    VStack(alignment: .leading, spacing: 8) {
                                                        ForEach(vision.subTasks) { subTask in
                                                            HStack {
                                                                Button(action: { viewModel.toggleSubTaskCompleted(visionId: vision.id, subTaskId: subTask.id) }) { Image(systemName: subTask.isCompleted ? "checkmark.square.fill" : "square").foregroundColor(subTask.isCompleted ? .pink : .gray).font(.system(size: 18)) }.buttonStyle(PlainButtonStyle())
                                                                Text(subTask.title).font(.subheadline).strikethrough(subTask.isCompleted).foregroundColor(subTask.isCompleted ? .secondary : .primary)
                                                                Spacer()
                                                            }
                                                        }
                                                    }
                                                }
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
    @AppStorage("goalTutorialStep") var tutorialStep = 0
    
    private func displayDate(for offset: Int) -> Date { let c = Calendar.current; return c.date(byAdding: .month, value: offset, to: c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()) ?? Date() }

    let dailyTemplates = ["読書を10分", "水を1.5L飲む", "スクワット15回", "日記を1行書く", "5分片付け"]
    let weeklyTemplates = ["ジムに2回行く", "本を1冊読む", "休肝日を2日作る", "作り置きをする", "週末に掃除機"]
    let monthlyTemplates = ["体重を1kg落とす", "本を3冊読む", "映画を3本見る", "貯金1万円", "新しい場所に行く"]

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
                                HStack { Image(systemName: "arrowshape.turn.up.right.fill").foregroundColor(.blue).font(.caption); Text("前回のTry").font(.caption).bold().foregroundColor(.secondary) }.padding(.horizontal)
                                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { BatonTag(title: "先月より", items: viewModel.getLastMonthlyTryList(for: currentDisplayDate), color: .blue); BatonTag(title: "先週より", items: viewModel.getLastWeeklyTryList(for: viewModel.selectedDate), color: .orange); BatonTag(title: "昨日より", items: viewModel.getYesterdayTryList(for: viewModel.selectedDate), color: .green) }.padding(.horizontal) }
                            }.padding(.vertical, 5)
                            
                            VStack(spacing: 10) {
                                if tutorialStep == 1 {
                                    TutorialBubble(text: "💡 まずは「今月の目標」を立てましょう！\n大きめの目標や、1ヶ月で達成したいことを書きます。\n例：体重を1kg落とす、本を3冊読む", step: $tutorialStep)
                                }
                                GoalListSection(title: "\(viewModel.getMonthlyTitle(for: currentDisplayDate))の月次目標", iconColor: .blue, goals: monthData.monthlyGoals, viewModel: viewModel, showCheckboxes: false, templates: monthlyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: currentDisplayDate) }, onCopy: { copyPrev(field: .monthly, date: currentDisplayDate) })
                                
                                if tutorialStep == 2 {
                                    TutorialBubble(text: "💡 次に、月次目標を達成するための「今週の目標」に落とし込みます。\n例：週に2回ジムに行く", step: $tutorialStep)
                                }
                                GoalListSection(title: "\(viewModel.getMonthlyTitle(for: currentDisplayDate))の週次目標", iconColor: .orange, goals: monthData.weeklyGoals, viewModel: viewModel, showCheckboxes: false, templates: weeklyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .weekly, date: currentDisplayDate) }, onCopy: { copyPrev(field: .weekly, date: currentDisplayDate) })
                                
                                if tutorialStep == 3 {
                                    TutorialBubble(text: "💡 最後に、毎日やるべき「日次目標（習慣）」を決めます。\nこれが毎日ホーム画面にタスクとして表示されます！\n例：毎日スクワット15回", step: $tutorialStep, isLast: true)
                                }
                                GoalListSection(title: "\(viewModel.getMonthlyTitle(for: currentDisplayDate))の日次目標", iconColor: .green, goals: monthData.dailyGoals, viewModel: viewModel, showCheckboxes: false, templates: dailyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .daily, date: currentDisplayDate) }, onCopy: { copyPrev(field: .daily, date: currentDisplayDate) })
                                
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
        
        for g in newGoals { if !existingTitles.contains(g.title) { currentGoals.append(Goal(title: g.title, categoryId: g.categoryId)) } }
        viewModel.updateMonthlyGoals(currentGoals, field: field, date: date)
        viewModel.syncAll(for: viewModel.selectedDate)
    }
}

// MARK: - チュートリアル用の吹き出しUI
struct TutorialBubble: View {
    let text: String
    @Binding var step: Int
    var isLast: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.subheadline).bold()
                .foregroundColor(.white)
                .lineSpacing(4)
            
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        if isLast { step = -1 } else { step += 1 }
                    }
                }) {
                    Text(isLast ? "完了して目標を書く！" : "次へ")
                        .font(.caption).bold()
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color.blue)
        .cornerRadius(12)
        .overlay(
            Path { path in
                path.move(to: CGPoint(x: 20, y: 0))
                path.addLine(to: CGPoint(x: 40, y: 0))
                path.addLine(to: CGPoint(x: 30, y: 10))
                path.closeSubpath()
            }
            .fill(Color.blue)
            .offset(y: 10),
            alignment: .bottomLeading
        )
        .padding(.bottom, 10)
    }
}

// MARK: - 目標リスト（編集・削除対応）
struct GoalListSection: View {
    let title: String; let iconColor: Color; var goals: [Goal]
    @ObservedObject var viewModel: GoalViewModel
    var showCheckboxes: Bool
    var templates: [String]
    var onUpdate: ([Goal]) -> Void; var onCopy: (() -> Void)? = nil
    
    @State private var tempTitle = ""
    @State private var selectedCategoryId = "action"
    @State private var isAdding = false
    
    @State private var editingGoal: Goal? = nil
    
    var body: some View {
        let categories = viewModel.appSettings.categories
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .foregroundColor(iconColor)
                    .font(.system(size: 10))
                
                Text(title).font(.caption).bold().foregroundColor(.primary)
                Spacer()
                if let onCopy = onCopy { Button(action: onCopy) { Image(systemName: "doc.on.clipboard").font(.system(size: 14)) }.padding(.trailing, 5) }
                Button(action: { withAnimation { isAdding.toggle() } }) { Image(systemName: "plus").font(.system(size: 14, weight: .bold)) }
            }
            .padding(.bottom, 2)
            
            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                let cat = categories.first(where: { $0.id == goal.categoryId }) ?? (categories.first ?? CategoryItem(name: "指定なし", colorName: "gray"))
                
                HStack(spacing: 10) {
                    if showCheckboxes {
                        Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(goal.isCompleted ? .green : cat.color)
                            .font(.system(size: 20))
                            .onTapGesture { var newGoals = goals; newGoals[index].isCompleted.toggle(); onUpdate(newGoals) }
                    } else {
                        Rectangle()
                            .fill(cat.color)
                            .frame(width: 4, height: 20)
                            .cornerRadius(2)
                    }
                    
                    Text(goal.title)
                        .font(.subheadline)
                        .strikethrough(showCheckboxes && goal.isCompleted)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 編集ボタン（えんぴつアイコン）
                    Button(action: { editingGoal = goal }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray.opacity(0.8))
                            .font(.system(size: 14))
                            .padding(4)
                    }
                    
                    Button(action: { var newGoals = goals; newGoals.remove(at: index); onUpdate(newGoals) }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.system(size: 12, weight: .bold))
                            .padding(4)
                    }
                }.padding(.vertical, 2)
            }
            
            if isAdding {
                VStack(alignment: .leading, spacing: 10) {
                    if goals.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("💡 おすすめの習慣").font(.caption2).foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(templates, id: \.self) { sug in
                                        Button(action: { tempTitle = sug }) {
                                            Text(sug).font(.caption).padding(.horizontal, 10).padding(.vertical, 5).background(Color(.systemGray6)).cornerRadius(8).foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                        }.padding(.bottom, 4)
                    }
                    
                    HStack {
                        TextField("新しい目標...", text: $tempTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit { addGoal() }
                        Button(action: addGoal) {
                            Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundColor(.blue)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories) { cat in
                                Text(cat.name)
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(selectedCategoryId == cat.id ? cat.color : Color(.systemGray5))
                                    .foregroundColor(selectedCategoryId == cat.id ? .white : .primary)
                                    .clipShape(Capsule())
                                    .onTapGesture { selectedCategoryId = cat.id }
                            }
                            
                            NavigationLink(destination: CategorySettingsView(viewModel: viewModel)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("編集")
                                }
                                .font(.caption2).bold()
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(2)
                    }
                }.padding(.top, 4)
            }
            
        }.padding(12).background(Color(.systemBackground)).cornerRadius(10).shadow(color: Color.black.opacity(0.05), radius: 3)
        .onAppear { if let first = categories.first { selectedCategoryId = first.id } }
        // 編集シートの表示
        .sheet(item: $editingGoal) { goal in
            EditItemSheet(viewModel: viewModel, title: goal.title, categoryId: goal.categoryId) { newTitle, newCatId in
                if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                    var newGoals = goals
                    newGoals[idx].title = newTitle
                    newGoals[idx].categoryId = newCatId
                    onUpdate(newGoals)
                }
            }
        }
    }
    
    private func addGoal() {
        if !tempTitle.isEmpty {
            var n = goals
            n.append(Goal(title: tempTitle, categoryId: selectedCategoryId))
            onUpdate(n)
            tempTitle = ""
            isAdding = false
        }
    }
}

// MARK: - 共通：編集用の画面（シート）
struct EditItemSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: GoalViewModel
    
    @State var title: String
    @State var categoryId: String
    
    var onSave: (String, String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("内容")) {
                    TextField("名前", text: $title)
                        .submitLabel(.done)
                }
                Section(header: Text("カテゴリー")) {
                    Picker("カテゴリー", selection: $categoryId) {
                        ForEach(viewModel.appSettings.categories) { cat in
                            HStack {
                                Circle().fill(cat.color).frame(width: 10, height: 10)
                                Text(cat.name)
                            }
                            .tag(cat.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationTitle("編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(title, categoryId)
                        presentationMode.wrappedValue.dismiss()
                    }.disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - 設定画面（ここが前回消えてしまっていました！）
struct SettingsView: View {
    @ObservedObject var viewModel: GoalViewModel
    @State private var isTutorial = false
    var body: some View {
        NavigationView {
            Form {
                Section("通知設定") {
                    Toggle("目標通知", isOn: Binding(get: { viewModel.appSettings.goalNotificationEnabled }, set: { viewModel.appSettings.goalNotificationEnabled = $0; viewModel.saveSettings() }))
                    if viewModel.appSettings.goalNotificationEnabled { DatePicker("時間", selection: Binding(get: { viewModel.appSettings.goalNotificationTime }, set: { viewModel.appSettings.goalNotificationTime = $0; viewModel.saveSettings() }), displayedComponents: .hourAndMinute) }
                    Toggle("振り返り通知", isOn: Binding(get: { viewModel.appSettings.reflectionNotificationEnabled }, set: { viewModel.appSettings.reflectionNotificationEnabled = $0; viewModel.saveSettings() }))
                    if viewModel.appSettings.reflectionNotificationEnabled { DatePicker("時間", selection: Binding(get: { viewModel.appSettings.reflectionNotificationTime }, set: { viewModel.appSettings.reflectionNotificationTime = $0; viewModel.saveSettings() }), displayedComponents: .hourAndMinute) }
                }
                
                Section("カスタマイズ") {
                    NavigationLink(destination: CategorySettingsView(viewModel: viewModel)) {
                        HStack {
                            Image(systemName: "paintpalette.fill").foregroundColor(.purple).frame(width: 24)
                            Text("カテゴリーの追加・編集")
                        }
                    }
                }
                
                Section("サポート") {
                    Button(action: { isTutorial = true }) {
                        HStack { Image(systemName: "book.fill").foregroundColor(.blue).frame(width: 24); Text("使い方ガイド（見直す）").foregroundColor(.primary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary) }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.navigationTitle("設定")
            .fullScreenCover(isPresented: $isTutorial) { TutorialView(viewModel: viewModel, isShowing: $isTutorial) }
        }
    }
}

// MARK: - カテゴリー設定画面
struct CategorySettingsView: View {
    @ObservedObject var viewModel: GoalViewModel
    @State private var newName = ""
    @State private var selectedColor = "blue"
    
    let availableColors = [
        ("青", "blue", Color.blue), ("水色", "teal", Color.teal),
        ("緑", "green", Color.green), ("黄", "yellow", Color.yellow),
        ("橙", "orange", Color.orange), ("赤", "red", Color.red),
        ("紫", "purple", Color.purple), ("藍色", "indigo", Color.indigo),
        ("茶色", "brown", Color.brown), ("グレー", "gray", Color.gray)
    ]
    
    var body: some View {
        Form {
            Section(header: Text("新しいカテゴリーを作る")) {
                TextField("カテゴリー名（例：勉強）", text: $newName)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableColors, id: \.1) { colorInfo in
                            Circle()
                                .fill(colorInfo.2)
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary.opacity(0.8), lineWidth: selectedColor == colorInfo.1 ? 3 : 0).padding(-4))
                                .onTapGesture { selectedColor = colorInfo.1 }
                        }
                    }
                    .padding(8)
                }.padding(.vertical, 4)
                
                Button("追加する") {
                    if !newName.isEmpty {
                        let newCat = CategoryItem(name: newName, colorName: selectedColor)
                        viewModel.appSettings.categories.append(newCat)
                        viewModel.saveSettings()
                        newName = ""
                    }
                }.disabled(newName.isEmpty)
            }
            
            Section(header: Text("現在のカテゴリー")) {
                List {
                    ForEach(viewModel.appSettings.categories) { cat in
                        HStack {
                            Circle().fill(cat.color).frame(width: 15, height: 15)
                            Text(cat.name)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.appSettings.categories.remove(atOffsets: offsets)
                        viewModel.saveSettings()
                    }
                }
            }
        }
        .navigationTitle("カテゴリー編集")
    }
}

// MARK: - 未来の自分画面
struct FutureVisionView: View {
    @ObservedObject var viewModel: GoalViewModel; @State private var newVisionTitle = ""
    @FocusState private var isInputFocused: Bool
    
    // 🟢 編集用の状態（大目標用）
    @State private var editingVision: FutureVision? = nil
    @State private var editingVisionTitle = ""
    @State private var showEditAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("目標を達成した先に、どうなっていたいですか？\n大きな目標に対して、具体的なステップを追加して夢を可視化しましょう。。\n（例：「海外で働く」に向けて「日常英会話をマスターする」「英文レジュメを作る」など）").font(.caption).foregroundColor(.secondary).padding()
                HStack {
                    TextField("例：海外で働く！", text: $newVisionTitle).textFieldStyle(RoundedBorderTextFieldStyle()).focused($isInputFocused).onSubmit { if !newVisionTitle.isEmpty { viewModel.addFutureVision(title: newVisionTitle); newVisionTitle = "" } }
                    Button(action: { if !newVisionTitle.isEmpty { viewModel.addFutureVision(title: newVisionTitle); newVisionTitle = "" } }) { Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.pink) }.buttonStyle(PlainButtonStyle())
                }.padding(.horizontal)
                
                List {
                    ForEach(viewModel.futureVisions) { vision in
                        FutureVisionRow(vision: vision, viewModel: viewModel)
                            // 🟢 スワイプアクションで編集・削除を実装
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    if let idx = viewModel.futureVisions.firstIndex(where: { $0.id == vision.id }) {
                                        viewModel.removeFutureVision(at: IndexSet(integer: idx))
                                    }
                                } label: { Image(systemName: "trash") }
                                
                                Button {
                                    editingVision = vision
                                    editingVisionTitle = vision.title
                                    showEditAlert = true
                                } label: { Image(systemName: "pencil") }.tint(.orange)
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("✨ 未来の自分")
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { isInputFocused = false } } }
            // 🟢 その場で編集できるアラートを追加
            .alert("目標の編集", isPresented: $showEditAlert) {
                TextField("目標タイトル", text: $editingVisionTitle)
                Button("キャンセル", role: .cancel) { editingVision = nil }
                Button("保存") {
                    if let v = editingVision, !editingVisionTitle.isEmpty {
                        viewModel.editFutureVision(id: v.id, newTitle: editingVisionTitle)
                    }
                    editingVision = nil
                }
            }
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
    
    // 🟢 編集用の状態（具体的なステップ用）
    @State private var editingSubTask: SubTask? = nil
    @State private var editingSubTaskTitle = ""
    @State private var showSubTaskEditAlert = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(vision.subTasks) { subTask in
                    HStack {
                        Button(action: { viewModel.toggleSubTaskCompleted(visionId: vision.id, subTaskId: subTask.id) }) { Image(systemName: subTask.isCompleted ? "checkmark.square.fill" : "square").foregroundColor(subTask.isCompleted ? .pink : .gray).font(.system(size: 20)) }.buttonStyle(PlainButtonStyle())
                        Text(subTask.title).strikethrough(subTask.isCompleted).foregroundColor(subTask.isCompleted ? .secondary : .primary); Spacer()
                        
                        // 🟢 ステップ名の横に編集ボタン（鉛筆）を追加
                        Button(action: {
                            editingSubTask = subTask
                            editingSubTaskTitle = subTask.title
                            showSubTaskEditAlert = true
                        }) { Image(systemName: "pencil").foregroundColor(.orange.opacity(0.8)).font(.system(size: 16)) }.buttonStyle(PlainButtonStyle()).padding(.trailing, 6)
                        
                        Button(action: { if let index = vision.subTasks.firstIndex(where: { $0.id == subTask.id }) { viewModel.deleteSubTasks(visionId: vision.id, at: IndexSet(integer: index)) } }) { Image(systemName: "trash").foregroundColor(.red.opacity(0.6)).font(.system(size: 16)) }.buttonStyle(PlainButtonStyle()).padding(.leading, 2)
                    }.padding(.vertical, 2)
                }
                HStack {
                    Image(systemName: "arrow.turn.down.right").foregroundColor(.gray).font(.caption)
                    TextField("具体的なステップを追加...", text: $newSubTaskText).textFieldStyle(PlainTextFieldStyle()).focused($isSubTaskFocused).onSubmit { addSubTask() }
                    Button(action: { addSubTask() }) { Image(systemName: "plus.circle.fill").foregroundColor(newSubTaskText.isEmpty ? .gray.opacity(0.3) : .pink).font(.system(size: 24)) }.disabled(newSubTaskText.isEmpty).buttonStyle(PlainButtonStyle())
                }.padding(.top, 5)
            }
            .padding(.leading, 10)
            // 🟢 その場で編集できるアラートを追加
            .alert("ステップの編集", isPresented: $showSubTaskEditAlert) {
                TextField("ステップ名", text: $editingSubTaskTitle)
                Button("キャンセル", role: .cancel) { editingSubTask = nil }
                Button("保存") {
                    if let s = editingSubTask, !editingSubTaskTitle.isEmpty {
                        viewModel.editSubTask(visionId: vision.id, subTaskId: s.id, newTitle: editingSubTaskTitle)
                    }
                    editingSubTask = nil
                }
            }
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
