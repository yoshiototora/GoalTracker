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
    
    @AppStorage("showHomeHint") private var showHomeHint = true
    @AppStorage("hasCompletedMainTutorial") private var hasCompletedTutorial = false
    
    private var isToday: Bool { Calendar.current.isDateInToday(viewModel.selectedDate) }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                StreakBadgeView(streak: viewModel.currentDailyStreak)
                
                if hasCompletedTutorial {
                    InlineHintCard(
                        title: "今日のタスクをこなそう",
                        message: "カレンダーで設定した「日次目標」と、振り返りで決めた「Try」がここに並びます。完了したらタップ！\n💡 タスクを左にスワイプすると編集ができます。削除できるのは追加した「今日やること」のみです。日次・週次目標はカレンダー画面から削除してください。",
                        isShowing: $showHomeHint
                    )
                }
                
                HStack {
                    TextField(isToday ? "今日やること..." : "この日のタスク...", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isInputFocused)
                        .onSubmit { addTask() }
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }.padding()
                
                let currentTasks = viewModel.currentDailyNote.tasks
                let hasDailyGoals = !viewModel.currentMonthData.dailyGoals.isEmpty
                
                if currentTasks.isEmpty {
                    if !hasDailyGoals {
                        EmptyStateView(title: "目標を設定しましょう", description: "まずはカレンダータブから日次目標を追加してみましょう。", buttonTitle: "カレンダーを開く", iconName: "target", action: { selectedTab = 2; if tutorialStep == 0 { tutorialStep = 1 } })
                    } else {
                        EmptyStateView(title: isToday ? "今日のタスクはありません" : "タスクはありません", description: "やるべきことを追加してみましょう", buttonTitle: "タスクを追加", iconName: "checklist.unchecked", action: { isInputFocused = true })
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
                                    
                                    if task.type == .tryCarryOver {
                                        Text("Try")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(task.isCompleted ? Color.gray.opacity(0.8) : Color.orange)
                                            .cornerRadius(6)
                                    }
                                    
                                    Text(task.title)
                                        .bold(task.type == .dailyGoal)
                                        .strikethrough(task.isCompleted)
                                        .foregroundColor(task.isCompleted ? .gray : .primary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if task.isYearlyReflection && Calendar.current.component(.month, from: viewModel.selectedDate) != 12 { return }
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    viewModel.toggleTask(id: task.id, for: viewModel.selectedDate)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if task.type == .normal {
                                        Button(role: .destructive) {
                                            if let idx = currentTasks.firstIndex(where: { $0.id == task.id }) {
                                                viewModel.removeTasks(at: IndexSet(integer: idx), for: viewModel.selectedDate)
                                            }
                                        } label: { Image(systemName: "trash") }
                                    }
                                    Button { editingTask = task } label: { Image(systemName: "pencil") }.tint(.orange)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollDismissesKeyboard(.interactively)
                    .sheet(item: $editingTask) { task in
                        EditItemSheet(viewModel: viewModel, title: task.title, categoryId: task.categoryId) { newTitle, newCatId in
                            viewModel.editTask(id: task.id, newTitle: newTitle, newCategoryId: newCatId, for: viewModel.selectedDate)
                        }
                    }
                }
            }
            .navigationTitle(isToday ? "今日のタスク" : viewModel.getDailyTitle(for: viewModel.selectedDate))
            .onAppear { viewModel.syncAll(for: viewModel.selectedDate) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isToday {
                        Button(action: { withAnimation { viewModel.selectedDate = Date() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle")
                                Text("今日に戻る")
                            }
                            .font(.caption).bold().foregroundColor(.blue)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1)).cornerRadius(12)
                        }
                    }
                }
            }
            .contentShape(Rectangle()).onTapGesture { hideKeyboard() }
        }
    }
    
    private func addTask() {
        if !newTaskTitle.isEmpty {
            viewModel.addTask(title: newTaskTitle, for: viewModel.selectedDate)
            newTaskTitle = ""
        }
    }
}

struct EmptyStateView: View {
    let title: String; let description: String; let buttonTitle: String; let iconName: String; let action: () -> Void
    var body: some View { VStack(spacing: 20) { Spacer(); Image(systemName: iconName).font(.system(size: 70)).foregroundColor(.orange.opacity(0.7)).padding(.bottom, 10); Text(title).font(.title3).bold().foregroundColor(.primary); Text(description).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40); Button(action: action) { HStack { Image(systemName: "plus"); Text(buttonTitle) }.font(.headline).foregroundColor(.white).padding(.horizontal, 24).padding(.vertical, 12).background(Color.blue).cornerRadius(20).shadow(color: .blue.opacity(0.3), radius: 5, y: 3) }.padding(.top, 10); Spacer() }.contentShape(Rectangle()) }
}

struct ProgressListView: View {
    let title: String
    let items: [(title: String, progress: String)]
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.caption).bold().foregroundColor(.secondary)
                ForEach(items, id: \.title) { item in
                    HStack {
                        Text(item.title).font(.subheadline).foregroundColor(.primary)
                        Spacer()
                        Text(item.progress).font(.system(.subheadline, design: .rounded)).foregroundColor(.secondary)
                    }
                    Divider()
                }
            }
            .padding(16).background(Color(.systemBackground)).cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 10, y: 5).padding(.horizontal)
        }
    }
}

// MARK: - 振り返り画面
struct ReflectionView: View {
    @ObservedObject var viewModel: GoalViewModel
    @State private var reflectionType = 0
    @State private var showYearlyAnimation = false
    
    @AppStorage("showReflectionHint") private var showReflectionHint = true
    @AppStorage("hasCompletedMainTutorial") private var hasCompletedTutorial = false
    @AppStorage("showWeeklyHint") private var showWeeklyHint = true
    @AppStorage("showMonthlyHint") private var showMonthlyHint = true
    @AppStorage("showYearlyHint") private var showYearlyHint = true
    
    private var isToday: Bool { Calendar.current.isDateInToday(viewModel.selectedDate) }
    private var isDecember: Bool { Calendar.current.component(.month, from: viewModel.selectedDate) == 12 }
    
    private var isBeforeStart: Bool {
        guard let start = viewModel.appSettings.appStartDate else { return false }
        return Calendar.current.startOfDay(for: viewModel.selectedDate) < Calendar.current.startOfDay(for: start)
    }
    
    private var shouldShowWeeklyReflection: Bool {
        if isBeforeStart { return false }
        let cal = Calendar.current
        let isTargetWeekday = cal.component(.weekday, from: viewModel.selectedDate) == viewModel.appSettings.weeklyReflectionWeekday
        guard isTargetWeekday else { return false }
        let weekData = viewModel.getWeekData(for: viewModel.selectedDate)
        let hasReflection = !weekData.keep.isEmpty || !weekData.problem.isEmpty || !weekData.reflection.isEmpty || !weekData.tryList.isEmpty
        return !hasReflection
    }
    
    private var shouldShowMonthlyReflection: Bool {
        if isBeforeStart { return false }
        let cal = Calendar.current
        let date = viewModel.selectedDate
        let nextDay = cal.date(byAdding: .day, value: 1, to: date) ?? date
        let isLastDayOfMonth = cal.component(.month, from: date) != cal.component(.month, from: nextDay)
        guard isLastDayOfMonth else { return false }
        let monthDates = viewModel.getMonthDates(for: viewModel.selectedDate)
        let hasAnyActivity = monthDates.contains { !viewModel.getNote(for: $0).tasks.isEmpty }
        let hasLastMonthTry = !viewModel.getLastMonthlyTryList(for: viewModel.selectedDate).isEmpty
        return hasLastMonthTry || hasAnyActivity
    }
    
    private var shouldShowLastWeekInMonthly: Bool {
        if isBeforeStart { return false }
        let cal = Calendar.current
        let date = viewModel.selectedDate
        let nextDay = cal.date(byAdding: .day, value: 1, to: date) ?? date
        let isLastDayOfMonth = cal.component(.month, from: date) != cal.component(.month, from: nextDay)
        let isTargetWeekday = cal.component(.weekday, from: date) == viewModel.appSettings.weeklyReflectionWeekday
        guard isLastDayOfMonth && !isTargetWeekday else { return false }
        let lastWeekDate = cal.date(byAdding: .day, value: -7, to: date) ?? date
        let lastWeekData = viewModel.getWeekData(for: lastWeekDate)
        let hasReflection = !lastWeekData.keep.isEmpty || !lastWeekData.problem.isEmpty || !lastWeekData.reflection.isEmpty || !lastWeekData.tryList.isEmpty
        return !hasReflection
    }
    
    let dailyTemplates = ["読書を10分", "水を1.5L飲む", "スクワット15回", "日記を1行書く", "5分片付け"]
    let weeklyTemplates = ["ジムに2回行く", "本を1冊読む", "休肝日を2日作る", "作り置きをする", "週末に掃除機"]
    let monthlyTemplates = ["体重を1kg落とす", "本を3冊読む", "映画を3本見る", "貯金1万円", "新しい場所に行く"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("振り返り", selection: $reflectionType) {
                    Text("日次").tag(0)
                    if shouldShowWeeklyReflection { Text("週次").tag(1) }
                    if shouldShowMonthlyReflection { Text("月次").tag(2) }
                    if isDecember { Text("年次").tag(3) }
                }
                .pickerStyle(SegmentedPickerStyle()).padding()
                .onChange(of: viewModel.selectedDate) { _, _ in
                    if reflectionType == 1 && !shouldShowWeeklyReflection { reflectionType = 0 }
                    if reflectionType == 2 && !shouldShowMonthlyReflection { reflectionType = 0 }
                    if reflectionType == 3 && !isDecember { reflectionType = 0 }
                }
                
                TabView(selection: $reflectionType) {
                    dailyTab().tag(0)
                    if shouldShowWeeklyReflection { weeklyTab().tag(1) }
                    if shouldShowMonthlyReflection { monthlyTab().tag(2) }
                    if isDecember { yearlyTab().tag(3) }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(isToday ? "振り返り" : "\(viewModel.getDailyTitle(for: viewModel.selectedDate))")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.syncAll(for: viewModel.selectedDate) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isToday {
                        Button(action: { withAnimation { viewModel.selectedDate = Date() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle")
                                Text("今日に戻る")
                            }
                            .font(.caption).bold().foregroundColor(.blue)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1)).cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder private func dailyTab() -> some View {
        let note = viewModel.currentDailyNote
        ScrollView {
            VStack(spacing: 15) {
                if hasCompletedTutorial {
                    InlineHintCard(
                        title: "今日の振り返りが明日のヒントに",
                        message: "Keep（できたこと）とProblem（課題）を書き出し、解決策を Try（アクション） に追加しましょう。Tryは明日のタスクに自動で追加されます。また、日曜日には週次、月末には月次、年末には年次の振り返りタブも登場します！",
                        isShowing: $showReflectionHint
                    )
                }
                
                ReflectionAchievementCard(title: "\(viewModel.getDailyTitle(for: viewModel.selectedDate))の達成度", rate1: viewModel.getDailyCompletionRate(for: viewModel.selectedDate), rate2: nil, rate3: nil, color2: .clear, color3: .clear, comparisonText: nil, totalDoneCount: note.tasks.filter { $0.isCompleted }.count, tryDoneCount: note.tasks.filter { $0.isCompleted && $0.type == .tryCarryOver }.count)
                
                VStack(alignment: .leading, spacing: 10) {
                    TextEditorView(title: "Keep（できたこと）", text: Binding(get: { note.keep }, set: { viewModel.updateDailyNote($0, field: .keep, date: viewModel.selectedDate) }), placeholder: "例：朝30分早く起きて読書できた")
                    TextEditorView(title: "Problem（課題）", text: Binding(get: { note.problem }, set: { viewModel.updateDailyNote($0, field: .problem, date: viewModel.selectedDate) }), placeholder: "例：ついスマホを見すぎて寝るのが遅くなった")
                    GoalListSection(title: "Try（アクション）", iconColor: .blue, goals: note.tryList, viewModel: viewModel, showCheckboxes: false, templates: [], placeholder: "例：23時以降はスマホを触らない", onUpdate: { viewModel.updateDailyTryList($0, date: viewModel.selectedDate) })
                    TextEditorView(title: "振り返り（自由記述）", text: Binding(get: { note.reflection }, set: { viewModel.updateDailyNote($0, field: .reflection, date: viewModel.selectedDate) }), minHeight: 120, placeholder: "今日一日の感想を自由に書いてください")
                }.padding(.horizontal)
            }
            .padding(.vertical).padding(.bottom, 250)
        }.scrollDismissesKeyboard(.interactively)
    }
    
    @ViewBuilder private func weeklyTab() -> some View {
        let weekData = viewModel.currentWeekData
        ScrollView {
            VStack(spacing: 15) {
                if hasCompletedTutorial {
                    InlineHintCard(
                        title: "1週間の歩みを振り返る",
                        message: "今週もお疲れ様でした！日々の達成度を振り返り、良かったことや課題を整理しましょう。来週をさらに充実させるためのTryを決めるチャンスです。",
                        isShowing: $showWeeklyHint
                    )
                }

                ReflectionAchievementCard(title: "今週の達成度", rate1: viewModel.getWeeklyDailyAvgRate(for: viewModel.selectedDate), rate2: viewModel.getWeeklyGoalRate(for: viewModel.selectedDate), rate3: nil, color2: .orange, color3: .clear, comparisonText: viewModel.getComparisonText(for: viewModel.selectedDate, isWeekly: true), totalDoneCount: viewModel.getCompletedTasksCount(for: viewModel.selectedDate, isWeekly: true), tryDoneCount: viewModel.getTryExecutionCount(for: viewModel.selectedDate, isWeekly: true))
                ProgressListView(title: "日次目標の達成状況", items: viewModel.getDailyGoalsProgressStats(for: viewModel.selectedDate, isWeekly: true))
                VStack(alignment: .leading, spacing: 10) {
                    GoalListSection(title: "先週のTryの実行チェック", iconColor: .gray, goals: viewModel.getLastWeeklyTryList(for: viewModel.selectedDate), viewModel: viewModel, showCheckboxes: true, templates: [], onUpdate: { viewModel.updateWeeklyTryList($0, date: viewModel.getPreviousWeekDate(from: viewModel.selectedDate)) })
                    GoalListSection(title: "今週の目標チェック", iconColor: .orange, goals: weekData.goals, viewModel: viewModel, showCheckboxes: true, templates: weeklyTemplates, onUpdate: { viewModel.updateWeeklyGoals($0, date: viewModel.selectedDate) })
                    TextEditorView(title: "今週のKeep", text: Binding(get: { weekData.keep }, set: { viewModel.updateWeeklyText($0, field: .keep, date: viewModel.selectedDate) }), placeholder: "例：週の目標だったジムに2回行けた")
                    TextEditorView(title: "今週のProblem", text: Binding(get: { weekData.problem }, set: { viewModel.updateWeeklyText($0, field: .problem, date: viewModel.selectedDate) }), placeholder: "例：木曜日に疲れが溜まってタスクをサボってしまった")
                    GoalListSection(title: "来週のTry", iconColor: .blue, goals: weekData.tryList, viewModel: viewModel, showCheckboxes: false, templates: [], placeholder: "できなかったことに対するネクストアクション", onUpdate: { viewModel.updateWeeklyTryList($0, date: viewModel.selectedDate) })
                    TextEditorView(title: "振り返り（自由記述）", text: Binding(get: { weekData.reflection }, set: { viewModel.updateWeeklyText($0, field: .reflection, date: viewModel.selectedDate) }), minHeight: 120, placeholder: "例：今週はよく頑張った。来週は睡眠時間を確保したい。")
                }.padding(.horizontal)
            }.padding(.vertical).padding(.bottom, 250).contentShape(Rectangle()).onTapGesture { hideKeyboard() }
        }.scrollDismissesKeyboard(.interactively)
    }
    
    @ViewBuilder private func monthlyTab() -> some View {
        let monthData = viewModel.currentMonthData
        let nextMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
        let nextMonthData = viewModel.getMonthData(for: nextMonthDate)
        let weekData = viewModel.currentWeekData
        
        let targetRefDate = Calendar.current.startOfDay(for: viewModel.selectedDate)
        
        ScrollView {
            VStack(spacing: 15) {
                if hasCompletedTutorial {
                    InlineHintCard(
                        title: "1ヶ月の成果をチェック",
                        message: "この1ヶ月の取り組みを振り返りましょう。目標の達成率を振り返りながら、翌月の新しい目標を計画してみましょう。",
                        isShowing: $showMonthlyHint
                    )
                }

                ReflectionAchievementCard(title: "今月の達成度", rate1: viewModel.getMonthlyDailyAvgRate(for: viewModel.selectedDate), rate2: viewModel.getMonthlyWeeklyGoalAvgRate(for: viewModel.selectedDate), rate3: viewModel.getMonthlyGoalRate(for: viewModel.selectedDate), color2: .orange, color3: .blue, comparisonText: viewModel.getComparisonText(for: viewModel.selectedDate, isWeekly: false), totalDoneCount: viewModel.getCompletedTasksCount(for: viewModel.selectedDate, isWeekly: false), tryDoneCount: viewModel.getTryExecutionCount(for: viewModel.selectedDate, isWeekly: false))
                ProgressListView(title: "日次目標の達成状況", items: viewModel.getDailyGoalsProgressStats(for: viewModel.selectedDate, isWeekly: false))
                ProgressListView(title: "週次目標の達成状況", items: viewModel.getWeeklyGoalsProgressStats(for: viewModel.selectedDate))
                
                VStack(alignment: .leading, spacing: 10) {
                    GoalListSection(title: "先月のTryの実行チェック", iconColor: .gray, goals: viewModel.getLastMonthlyTryList(for: viewModel.selectedDate), viewModel: viewModel, showCheckboxes: true, templates: [], onUpdate: { viewModel.updateMonthlyTryList($0, date: viewModel.getPreviousMonthDate(from: viewModel.selectedDate)) })
                    
                    if shouldShowLastWeekInMonthly {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🗓 最終週の振り返り（月またぎ前）").font(.caption).bold().foregroundColor(.orange).padding(.top, 4)
                            GoalListSection(title: "最終週のTry実行チェック", iconColor: .gray, goals: viewModel.getLastWeeklyTryList(for: viewModel.selectedDate), viewModel: viewModel, showCheckboxes: true, templates: [], onUpdate: { viewModel.updateWeeklyTryList($0, date: viewModel.getPreviousWeekDate(from: viewModel.selectedDate)) })
                            GoalListSection(title: "最終週の週次目標チェック", iconColor: .orange, goals: weekData.goals, viewModel: viewModel, showCheckboxes: true, templates: weeklyTemplates, onUpdate: { viewModel.updateWeeklyGoals($0, date: viewModel.selectedDate) })
                            Divider().padding(.bottom, 4)
                        }
                    }
                    
                    GoalListSection(
                        title: "今月の目標チェック",
                        iconColor: .blue,
                        goals: monthData.monthlyGoals.filter { Calendar.current.startOfDay(for: $0.startDate) <= targetRefDate },
                        viewModel: viewModel,
                        showCheckboxes: true,
                        templates: monthlyTemplates,
                        onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: viewModel.selectedDate) }
                    )
                    
                    TextEditorView(title: "今月のKeep", text: Binding(get: { monthData.keep }, set: { viewModel.updateMonthlyText($0, field: .keep, date: viewModel.selectedDate) }), placeholder: "例：1ヶ月間、毎日5分の片付けを継続できた")
                    TextEditorView(title: "今月のProblem", text: Binding(get: { monthData.problem }, set: { viewModel.updateMonthlyText($0, field: .problem, date: viewModel.selectedDate) }), placeholder: "例：月の後半はモチベーションが下がってしまった")
                    GoalListSection(title: "来月のTry", iconColor: .blue, goals: viewModel.currentMonthData.tryList, viewModel: viewModel, showCheckboxes: false, templates: [], placeholder: "できなかったことに対するネクストアクション", onUpdate: { viewModel.updateMonthlyTryList($0, date: viewModel.selectedDate) })
                    TextEditorView(title: "振り返り（自由記述）", text: Binding(get: { monthData.reflection }, set: { viewModel.updateMonthlyText($0, field: .reflection, date: viewModel.selectedDate) }), minHeight: 120, placeholder: "例：新しい習慣が身について良かった。来月も継続する")
                    Divider().padding(.vertical, 8); Text("🚀 来月に向けて").font(.subheadline).bold().foregroundColor(.blue)
                    GoalListSection(title: "来月の月次目標", iconColor: .blue, goals: nextMonthData.monthlyGoals, viewModel: viewModel, showCheckboxes: false, templates: monthlyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: nextMonthDate) })
                    GoalListSection(title: "来月の週次目標", iconColor: .orange, goals: nextMonthData.weeklyGoals, viewModel: viewModel, showCheckboxes: false, templates: weeklyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .weekly, date: nextMonthDate) })
                    GoalListSection(title: "来月の日次目標", iconColor: .green, goals: nextMonthData.dailyGoals, viewModel: viewModel, showCheckboxes: false, templates: dailyTemplates, onUpdate: { viewModel.updateMonthlyGoals($0, field: .daily, date: nextMonthDate) })
                }.padding(.horizontal)
            }.padding(.vertical).padding(.bottom, 250).contentShape(Rectangle()).onTapGesture { hideKeyboard() }
        }.scrollDismissesKeyboard(.interactively)
    }
    
    @ViewBuilder private func yearlyTab() -> some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    if hasCompletedTutorial {
                        InlineHintCard(
                            title: "1年の集大成を祝う",
                            message: "素晴らしい1年でしたね！「未来の自分」にどれだけ近づけたか確認しましょう。達成した項目にチェックを入れて、自分を最大限に褒めてあげてください。",
                            isShowing: $showYearlyHint
                        ).padding(.top)
                    } else {
                        Text("🎉 年末の振り返り").font(.title2).bold().padding(.top)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(viewModel.futureVisions) { vision in
                            let isReadyToComplete = vision.subTasks.isEmpty ? true : vision.subTasks.allSatisfy { $0.isCompleted }
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Button(action: { withAnimation(.spring()) { viewModel.toggleFutureVisionCompleted(id: vision.id); if let updated = viewModel.futureVisions.first(where: { $0.id == vision.id }), updated.isCompleted { showYearlyAnimation = true; DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showYearlyAnimation = false } } } }) { Image(systemName: vision.isCompleted ? "checkmark.circle.fill" : (isReadyToComplete ? "arrow.up.circle.fill" : "circle")).foregroundColor(vision.isCompleted ? .pink : (isReadyToComplete ? .orange : .gray)).font(.title2) }.disabled(!isReadyToComplete && !vision.isCompleted).buttonStyle(PlainButtonStyle())
                                    Text(vision.title).font(.headline).strikethrough(vision.isCompleted).foregroundColor(vision.isCompleted ? .secondary : .primary); Spacer()
                                    Text("\(Int(vision.progress * 100))%").font(.system(.subheadline, design: .rounded)).bold().foregroundColor(vision.progress == 1.0 ? .pink : .secondary)
                                }
                                ProgressView(value: vision.progress).tint(vision.progress == 1.0 ? .pink : .orange).scaleEffect(x: 1, y: 1.5)
                            }.padding().background(vision.isCompleted ? Color.pink.opacity(0.05) : Color(.systemGray6).opacity(0.3)).cornerRadius(15).padding(.horizontal)
                        }
                    }
                }.padding(.bottom, 150).contentShape(Rectangle()).onTapGesture { hideKeyboard() }
            }.scrollDismissesKeyboard(.interactively)
            if showYearlyAnimation { LuxuriousCompletionEffect(completedCount: viewModel.futureVisions.filter { $0.isCompleted }.count).transition(.opacity).zIndex(1) }
        }
    }
}

// MARK: - カレンダー画面
struct CalendarView: View {
    @ObservedObject var viewModel: GoalViewModel; @Binding var selectedTab: Int
    @State private var monthOffset: Int = 0; @State private var showDatePicker = false
    @State private var jumpYear = Calendar.current.component(.year, from: Date())
    @State private var jumpMonth = Calendar.current.component(.month, from: Date())
    
    private func displayDate(for offset: Int) -> Date { let c = Calendar.current; return c.date(byAdding: .month, value: offset, to: c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()) ?? Date() }
    private var isCurrentMonth: Bool { monthOffset == 0 }

    private var minOffset: Int {
        guard let start = viewModel.appSettings.appStartDate else { return 0 }
        let cal = Calendar.current
        let startMonth = cal.date(from: cal.dateComponents([.year, .month], from: start))!
        let currentMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let diff = cal.dateComponents([.month], from: startMonth, to: currentMonth).month ?? 0
        return -diff
    }
    
    private var startYear: Int { Calendar.current.component(.year, from: viewModel.appSettings.appStartDate ?? Date()) }
    private var startMonth: Int { Calendar.current.component(.month, from: viewModel.appSettings.appStartDate ?? Date()) }

    var body: some View {
        NavigationView {
            TabView(selection: $monthOffset) {
                ForEach(minOffset..<61, id: \.self) { offset in
                    CalendarPage(viewModel: viewModel, offset: offset, displayDate: displayDate(for: offset), selectedTab: $selectedTab).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle(viewModel.getMonthlyTitle(for: displayDate(for: monthOffset)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !isCurrentMonth { Button(action: { withAnimation { monthOffset = 0; viewModel.selectedDate = Date() } }) { HStack(spacing: 4) { Image(systemName: "arrow.uturn.backward.circle"); Text("今日").font(.caption.bold()) }.foregroundColor(.blue).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).cornerRadius(12) } }
                        Button(action: {
                            let currentDisp = displayDate(for: monthOffset)
                            jumpYear = Calendar.current.component(.year, from: currentDisp)
                            jumpMonth = Calendar.current.component(.month, from: currentDisp)
                            showDatePicker = true
                        }) { Image(systemName: "calendar.badge.clock").font(.body.bold()) }
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    VStack {
                        HStack {
                            Picker("年", selection: $jumpYear) {
                                ForEach(startYear...2050, id: \.self) { y in Text("\(y)年").tag(y) }
                            }.pickerStyle(WheelPickerStyle())
                            
                            Picker("月", selection: $jumpMonth) {
                                ForEach(1...12, id: \.self) { m in
                                    if jumpYear > startYear || m >= startMonth {
                                        Text("\(m)月").tag(m)
                                    }
                                }
                            }.pickerStyle(WheelPickerStyle())
                        }.padding(); Spacer()
                    }
                    .navigationTitle("指定した月へ移動").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { showDatePicker = false } }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("移動") {
                                let cal = Calendar.current
                                var comps = DateComponents(); comps.year = jumpYear; comps.month = jumpMonth; comps.day = 1
                                if let target = cal.date(from: comps), let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) {
                                    monthOffset = cal.dateComponents([.month], from: currentMonthStart, to: target).month ?? 0
                                }; showDatePicker = false
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CalendarPage: View {
    @ObservedObject var viewModel: GoalViewModel
    let offset: Int
    let displayDate: Date
    @Binding var selectedTab: Int
    @AppStorage("goalTutorialStep") var tutorialStep = 0
    
    @AppStorage("showCalendarHint") private var showCalendarHint = true
    @AppStorage("hasCompletedMainTutorial") private var hasCompletedTutorial = false
    
    let dailyTemplates = ["読書を10分", "水を1.5L飲む", "スクワット15回", "日記を1行書く", "5分片付け"]
    let weeklyTemplates = ["ジムに2回行く", "本を1冊読む", "休肝日を2日作る", "作り置きをする", "週末に掃除機"]
    let monthlyTemplates = ["体重を1kg落とす", "本を3冊読む", "映画を3本見る", "貯金1万円", "新しい場所に行く"]

    var body: some View {
        let referenceDate = Calendar.current.isDate(displayDate, equalTo: viewModel.selectedDate, toGranularity: .month) ? viewModel.selectedDate : displayDate
        let monthData = viewModel.getMonthData(for: displayDate)
        let targetRefDate = Calendar.current.startOfDay(for: referenceDate)
        
        ScrollView {
            VStack(spacing: 15) {
                HStack(spacing: 10) {
                    CompositeSummaryCard(title: "\(viewModel.getWeeklyTitle(for: referenceDate))の達成度", rate1: viewModel.getWeeklyDailyAvgRate(for: referenceDate), rate2: viewModel.getWeeklyGoalRate(for: referenceDate), rate3: nil, color2: .orange, color3: .clear, comparisonText: viewModel.getComparisonText(for: referenceDate, isWeekly: true))
                    CompositeSummaryCard(title: "\(viewModel.getMonthlyTitle(for: displayDate))の達成度", rate1: viewModel.getMonthlyDailyAvgRate(for: displayDate), rate2: viewModel.getMonthlyWeeklyGoalAvgRate(for: displayDate), rate3: viewModel.getMonthlyGoalRate(for: displayDate), color2: .orange, color3: .blue, comparisonText: viewModel.getComparisonText(for: displayDate, isWeekly: false))
                }.padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Image(systemName: "arrowshape.turn.up.right.fill").foregroundColor(.blue).font(.caption); Text("前回のTry").font(.caption).bold().foregroundColor(.secondary) }.padding(.horizontal)
                    let monthlyTrys = viewModel.getLastMonthlyTryList(for: displayDate).map { $0.title }
                    let weeklyTrys = viewModel.getLastWeeklyTryList(for: referenceDate).map { $0.title }
                    let yesterdayTrys = viewModel.getYesterdayTryList(for: referenceDate)
                    if monthlyTrys.isEmpty && weeklyTrys.isEmpty && yesterdayTrys.isEmpty {
                        HStack { Image(systemName: "checkmark.seal.fill").foregroundColor(.green.opacity(0.8)); Text("引き継ぐアクションはありません").font(.caption).bold().foregroundColor(.secondary); Spacer() }.padding(12).background(Color(.systemGray6)).cornerRadius(10).padding(.horizontal)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 10) { BatonTag(title: "先月より", items: monthlyTrys, color: .blue); BatonTag(title: "先週より", items: weeklyTrys, color: .orange); BatonTag(title: "昨日より", items: yesterdayTrys, color: .green) }.padding(.horizontal) }
                    }
                }.padding(.vertical, 5)

                if hasCompletedTutorial {
                    InlineHintCard(
                        title: "目標を立てて今日の一歩に",
                        message: "月次・週次の目標を立てましょう。日次目標（習慣）は毎日ホーム画面に自動で表示されます。",
                        isShowing: $showCalendarHint
                    )
                }
                
                VStack(spacing: 10) {
                    if tutorialStep == 1 { TutorialBubble(text: "まずは「今月の目標」を立てましょう\n例：体重を1kg落とす", step: $tutorialStep) }
                    GoalListSection(
                        title: "\(viewModel.getMonthlyTitle(for: displayDate))の月次目標",
                        iconColor: .blue,
                        goals: monthData.monthlyGoals.filter { Calendar.current.startOfDay(for: $0.startDate) <= targetRefDate },
                        viewModel: viewModel,
                        showCheckboxes: false,
                        templates: monthlyTemplates,
                        onUpdate: { viewModel.updateMonthlyGoals($0, field: .monthly, date: displayDate) },
                        onCopy: { copyPrev(field: .monthly, date: displayDate) }
                    )
                    
                    if tutorialStep == 2 { TutorialBubble(text: "次に、月次目標を達成するための「今週の目標」を決めます。", step: $tutorialStep) }
                    GoalListSection(
                        title: "\(viewModel.getMonthlyTitle(for: displayDate))の週次目標",
                        iconColor: .orange,
                        goals: monthData.weeklyGoals.filter { Calendar.current.startOfDay(for: $0.startDate) <= targetRefDate },
                        viewModel: viewModel,
                        showCheckboxes: false,
                        templates: weeklyTemplates,
                        onUpdate: { viewModel.updateMonthlyGoals($0, field: .weekly, date: displayDate) },
                        onCopy: { copyPrev(field: .weekly, date: displayDate) }
                    )
                    
                    if tutorialStep == 3 { TutorialBubble(text: "最後に、毎日やるべき「日次目標」を決めます。", step: $tutorialStep, isLast: true) }
                    GoalListSection(
                        title: "\(viewModel.getMonthlyTitle(for: displayDate))の日次目標",
                        iconColor: .green,
                        goals: monthData.dailyGoals.filter { Calendar.current.startOfDay(for: $0.startDate) <= targetRefDate },
                        viewModel: viewModel,
                        showCheckboxes: false,
                        templates: dailyTemplates,
                        onUpdate: { viewModel.updateMonthlyGoals($0, field: .daily, date: displayDate) },
                        onCopy: { copyPrev(field: .daily, date: displayDate) }
                    )
                }.padding(.horizontal)
                
                CalendarGridView(viewModel: viewModel, displayDate: displayDate, selectedDate: $viewModel.selectedDate, selectedTab: $selectedTab)
            }
            .padding(.top, 10).padding(.bottom, 40)
        }.scrollDismissesKeyboard(.interactively)
    }
    
    func copyPrev(field: GoalViewModel.GoalField, date: Date) {
        let prevDate = Calendar.current.date(byAdding: .month, value: -1, to: date) ?? date
        let prevData = viewModel.getMonthData(for: prevDate)
        var newGoals = [Goal]()
        if field == .monthly { newGoals = prevData.monthlyGoals }
        else if field == .weekly { newGoals = prevData.weeklyGoals }
        else { newGoals = prevData.dailyGoals }
        
        let currentData = viewModel.getMonthData(for: date)
        var currentGoals = field == .monthly ? currentData.monthlyGoals : (field == .weekly ? currentData.weeklyGoals : currentData.dailyGoals)
        
        let existingTitles = currentGoals.map { $0.title }
        for g in newGoals {
            if !existingTitles.contains(g.title) {
                // startDateも引き継ぐ
                currentGoals.append(Goal(title: g.title, categoryId: g.categoryId, startDate: g.startDate))
            }
        }
        viewModel.updateMonthlyGoals(currentGoals, field: field, date: date)
        viewModel.syncAll(for: viewModel.selectedDate)
    }
}

// MARK: - 未来の自分画面
struct FutureVisionView: View {
    @ObservedObject var viewModel: GoalViewModel
    @State private var newVisionTitle = ""
    @FocusState private var isInputFocused: Bool
    
    @AppStorage("showFutureVisionHint") private var showFutureVisionHint = true
    @AppStorage("hasCompletedMainTutorial") private var hasCompletedTutorial = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if hasCompletedTutorial {
                    InlineHintCard(
                        title: "「なりたい自分」を可視化",
                        message: "最終的にどんな自分になりたいかを描いてみましょう。\nその先の姿を考えることで、目標へのモチベーションが高まります。\n「ステップを追加」で道のりを整理できます。\n💡 各項目は左にスワイプで編集・削除できます。",
                        isShowing: $showFutureVisionHint
                    ).padding(.top, 10)
                } else {
                    Text("目標を達成した先に、どうなっていたいですか？\n具体的なステップを追加して夢を可視化しましょう。")
                        .font(.caption).foregroundColor(.secondary).padding()
                }
                
                HStack {
                    TextField("例：海外で働く", text: $newVisionTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isInputFocused)
                        .onSubmit { if !newVisionTitle.isEmpty { viewModel.addFutureVision(title: newVisionTitle); newVisionTitle = "" } }
                    Button(action: { if !newVisionTitle.isEmpty { viewModel.addFutureVision(title: newVisionTitle); newVisionTitle = "" } }) {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.pink)
                    }.buttonStyle(PlainButtonStyle())
                }.padding(.horizontal).padding(.bottom, 10)
                
                List {
                    ForEach(viewModel.futureVisions) { vision in
                        FutureVisionRow(vision: vision, viewModel: viewModel)
                    }
                }
                .listStyle(PlainListStyle())
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("未来の自分")
            .contentShape(Rectangle()).onTapGesture { hideKeyboard() }
        }
    }
}

struct FutureVisionRow: View {
    let vision: FutureVision; @ObservedObject var viewModel: GoalViewModel
    @State private var isExpanded = false; @State private var newSubTaskText = ""; @State private var showEditAlert = false; @State private var editTitle = ""; @State private var editingSubTaskId: UUID? = nil
    var body: some View {
        HStack {
            Button(action: { viewModel.toggleFutureVisionCompleted(id: vision.id) }) { Image(systemName: vision.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(vision.isCompleted ? .pink : .gray).font(.title3) }.buttonStyle(PlainButtonStyle())
            Text(vision.title).font(.headline).strikethrough(vision.isCompleted).foregroundColor(vision.isCompleted ? .secondary : .primary); Spacer()
            if !vision.subTasks.isEmpty { ProgressView(value: vision.progress).tint(.pink).scaleEffect(x: 1, y: 0.5, anchor: .center).frame(width: 40) }
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right").foregroundColor(.gray).font(.caption)
        }.contentShape(Rectangle()).padding(.vertical, 6).onTapGesture { withAnimation { isExpanded.toggle() } }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: { if let index = viewModel.futureVisions.firstIndex(where: { $0.id == vision.id }) { viewModel.removeFutureVision(at: IndexSet(integer: index)) } }) { Image(systemName: "trash") }
            Button(action: { editingSubTaskId = nil; editTitle = vision.title; showEditAlert = true }) { Image(systemName: "pencil") }.tint(.orange)
        }.alert("目標の編集", isPresented: $showEditAlert) { TextField("内容", text: $editTitle); Button("キャンセル", role: .cancel) { }; Button("保存") { if !editTitle.isEmpty { if let subId = editingSubTaskId { viewModel.updateSubTask(visionId: vision.id, subTaskId: subId, title: editTitle) } else { viewModel.updateFutureVision(id: vision.id, title: editTitle) } } } }
        
        if isExpanded {
            ForEach(vision.subTasks) { subTask in
                HStack {
                    Button(action: { viewModel.toggleSubTaskCompleted(visionId: vision.id, subTaskId: subTask.id) }) { Image(systemName: subTask.isCompleted ? "checkmark.square.fill" : "square").foregroundColor(subTask.isCompleted ? .pink : .gray).font(.system(size: 18)) }.buttonStyle(PlainButtonStyle())
                    Text(subTask.title).font(.subheadline).strikethrough(subTask.isCompleted).foregroundColor(subTask.isCompleted ? .secondary : .primary); Spacer()
                }.padding(.leading, 20).padding(.vertical, 2)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive, action: { if let index = vision.subTasks.firstIndex(where: { $0.id == subTask.id }) { viewModel.deleteSubTasks(visionId: vision.id, at: IndexSet(integer: index)) } }) { Image(systemName: "trash") }
                    Button(action: { editingSubTaskId = subTask.id; editTitle = subTask.title; showEditAlert = true }) { Image(systemName: "pencil") }.tint(.orange)
                }
            }
            HStack { Image(systemName: "arrow.turn.down.right").foregroundColor(.gray).font(.caption); TextField("ステップを追加...", text: $newSubTaskText).textFieldStyle(PlainTextFieldStyle()).onSubmit { addSubTask() }; Button(action: { addSubTask() }) { Image(systemName: "plus.circle.fill").foregroundColor(newSubTaskText.isEmpty ? .gray.opacity(0.3) : .pink).font(.system(size: 20)) }.disabled(newSubTaskText.isEmpty).buttonStyle(PlainButtonStyle()) }.padding(.leading, 20).padding(.vertical, 2)
        }
    }
    private func addSubTask() { guard !newSubTaskText.isEmpty else { return }; viewModel.addSubTask(to: vision.id, title: newSubTaskText); newSubTaskText = "" }
}

// MARK: - 設定画面
struct SettingsView: View {
    @ObservedObject var viewModel: GoalViewModel
    @State private var isTutorial = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("通知設定") {
                    Toggle("目標通知", isOn: Binding(get: { viewModel.appSettings.goalNotificationEnabled }, set: { viewModel.appSettings.goalNotificationEnabled = $0; viewModel.saveSettings() }))
                    if viewModel.appSettings.goalNotificationEnabled {
                        DatePicker("時間", selection: Binding(get: { viewModel.appSettings.goalNotificationTime }, set: { viewModel.appSettings.goalNotificationTime = $0; viewModel.saveSettings() }), displayedComponents: .hourAndMinute)
                    }
                    Toggle("振り返り通知", isOn: Binding(get: { viewModel.appSettings.reflectionNotificationEnabled }, set: { viewModel.appSettings.reflectionNotificationEnabled = $0; viewModel.saveSettings() }))
                    if viewModel.appSettings.reflectionNotificationEnabled {
                        DatePicker("時間", selection: Binding(get: { viewModel.appSettings.reflectionNotificationTime }, set: { viewModel.appSettings.reflectionNotificationTime = $0; viewModel.saveSettings() }), displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("振り返りの設定") {
                    Picker("週次振り返りの曜日", selection: Binding(
                        get: { viewModel.appSettings.weeklyReflectionWeekday },
                        set: { viewModel.appSettings.weeklyReflectionWeekday = $0; viewModel.saveSettings() }
                    )) {
                        Text("日曜日").tag(1)
                        Text("月曜日").tag(2)
                        Text("火曜日").tag(3)
                        Text("水曜日").tag(4)
                        Text("木曜日").tag(5)
                        Text("金曜日").tag(6)
                        Text("土曜日").tag(7)
                    }
                    Toggle("月の初週をスキップ", isOn: Binding(get: { viewModel.appSettings.skipShortFirstWeek }, set: { viewModel.appSettings.skipShortFirstWeek = $0; viewModel.saveSettings() }))
                    if viewModel.appSettings.skipShortFirstWeek {
                        Stepper(value: Binding(get: { viewModel.appSettings.shortWeekThreshold }, set: { viewModel.appSettings.shortWeekThreshold = $0; viewModel.saveSettings() }), in: 1...6) {
                            HStack { Text("初週のスキップ日数"); Spacer(); Text("\(viewModel.appSettings.shortWeekThreshold)日以下").foregroundColor(.secondary).bold() }
                        }
                    }
                    
                    Toggle("月の最終週をスキップ", isOn: Binding(get: { viewModel.appSettings.skipShortLastWeek }, set: { viewModel.appSettings.skipShortLastWeek = $0; viewModel.saveSettings() }))
                    if viewModel.appSettings.skipShortLastWeek {
                        Stepper(value: Binding(get: { viewModel.appSettings.shortLastWeekThreshold }, set: { viewModel.appSettings.shortLastWeekThreshold = $0; viewModel.saveSettings() }), in: 1...6) {
                            HStack { Text("最終週のスキップ日数"); Spacer(); Text("\(viewModel.appSettings.shortLastWeekThreshold)日以下").foregroundColor(.secondary).bold() }
                        }
                    }
                }
                
                Section("カスタマイズ") {
                    NavigationLink(destination: CategorySettingsView(viewModel: viewModel)) {
                        HStack { Image(systemName: "paintpalette.fill").foregroundColor(.purple).frame(width: 24); Text("カテゴリーの追加・編集") }
                    }
                }
                
                Section("サポート") {
                    Button(action: { isTutorial = true }) {
                        HStack { Image(systemName: "book.fill").foregroundColor(.blue).frame(width: 24); Text("使い方ガイド").foregroundColor(.primary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary) }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            .navigationTitle("設定").fullScreenCover(isPresented: $isTutorial) { TutorialView(viewModel: viewModel, isShowing: $isTutorial) }
        }
    }
}

struct CategorySettingsView: View {
    @ObservedObject var viewModel: GoalViewModel; @State private var newName = ""; @State private var selectedColor = "blue"
    let availableColors = [("青", "blue", Color.blue), ("水色", "teal", Color.teal), ("緑", "green", Color.green), ("黄", "yellow", Color.yellow), ("橙", "orange", Color.orange), ("赤", "red", Color.red), ("紫", "purple", Color.purple), ("藍色", "indigo", Color.indigo), ("茶色", "brown", Color.brown), ("グレー", "gray", Color.gray)]
    var body: some View {
        Form {
            Section(header: Text("新しいカテゴリーを作る")) { TextField("カテゴリー名", text: $newName); ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(availableColors, id: \.1) { colorInfo in Circle().fill(colorInfo.2).frame(width: 30, height: 30).overlay(Circle().stroke(Color.primary.opacity(0.8), lineWidth: selectedColor == colorInfo.1 ? 3 : 0).padding(-4)).onTapGesture { selectedColor = colorInfo.1 } } }.padding(8) }.padding(.vertical, 4); Button("追加する") { if !newName.isEmpty { let newCat = CategoryItem(name: newName, colorName: selectedColor); viewModel.appSettings.categories.append(newCat); viewModel.saveSettings(); newName = "" } }.disabled(newName.isEmpty) }
            Section(header: Text("現在のカテゴリー")) { List { ForEach(viewModel.appSettings.categories) { cat in HStack { Circle().fill(cat.color).frame(width: 15, height: 15); Text(cat.name) } }.onDelete { offsets in viewModel.appSettings.categories.remove(atOffsets: offsets); viewModel.saveSettings() } } }
        }.navigationTitle("カテゴリー編集").scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - 共用部品（バッジ・GoalListなど）
struct BatonTag: View {
    let title: String; let items: [String]; let color: Color
    var body: some View {
        if !items.isEmpty { VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 9, weight: .bold)).foregroundColor(color); ForEach(items, id: \.self) { item in Text("• \(item)").font(.system(size: 11)).lineLimit(1).foregroundColor(.primary) } }.padding(8).background(color.opacity(0.1)).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.2), lineWidth: 1)) }
    }
}

struct TutorialBubble: View {
    let text: String; @Binding var step: Int; var isLast: Bool = false
    var body: some View { VStack(alignment: .leading, spacing: 10) { Text(text).font(.subheadline).bold().foregroundColor(.white).lineSpacing(4); HStack { Spacer(); Button(action: { withAnimation { if isLast { step = -1 } else { step += 1 } } }) { Text(isLast ? "完了" : "次へ").font(.caption).bold().padding(.horizontal, 16).padding(.vertical, 8).background(Color.white).foregroundColor(.blue).cornerRadius(20) } } }.padding().background(Color.blue).cornerRadius(12).padding(.bottom, 10) }
}

struct GoalListSection: View {
    let title: String; let iconColor: Color; var goals: [Goal]; @ObservedObject var viewModel: GoalViewModel
    var showCheckboxes: Bool; var templates: [String]
    var placeholder: String = "新しい目標..."
    var onUpdate: ([Goal]) -> Void; var onCopy: (() -> Void)? = nil
    @State private var tempTitle = ""; @State private var selectedCategoryId = "action"
    @State private var isAdding = false; @State private var editingGoal: Goal? = nil; @State private var isExpanded: Bool = true
    
    var body: some View {
        let categories = viewModel.appSettings.categories
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Button(action: { withAnimation { isExpanded.toggle() } }) { HStack(spacing: 6) { Image(systemName: "circle.fill").foregroundColor(iconColor).font(.system(size: 10)); Text(title).font(.caption).bold().foregroundColor(.primary); Image(systemName: isExpanded ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(.gray) }.contentShape(Rectangle()) }.buttonStyle(PlainButtonStyle())
                Spacer()
                HStack(spacing: 16) {
                    if let onCopy = onCopy { Button(action: onCopy) { Image(systemName: "doc.on.clipboard").font(.system(size: 14)).foregroundColor(.gray).padding(.vertical, 4) }.buttonStyle(PlainButtonStyle()) }
                    Button(action: { withAnimation { isAdding.toggle(); if isAdding { isExpanded = true } } }) { Image(systemName: "plus").font(.system(size: 18, weight: .medium)).foregroundColor(.blue).padding(.vertical, 4) }.buttonStyle(PlainButtonStyle())
                }
            }.padding(.bottom, 2)
            if isExpanded {
                ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                    let cat = categories.first(where: { $0.id == goal.categoryId }) ?? (categories.first ?? CategoryItem(name: "指定なし", colorName: "gray"))
                    HStack(spacing: 10) {
                        if showCheckboxes { Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(goal.isCompleted ? .green : cat.color).font(.system(size: 20)).onTapGesture { var newGoals = goals; newGoals[index].isCompleted.toggle(); onUpdate(newGoals) } }
                        else { Rectangle().fill(cat.color).frame(width: 4, height: 20).cornerRadius(2) }
                        
                        HStack(spacing: 4) {
                            if goal.startDate > Date.distantPast {
                                Text(goal.startDate, format: .dateTime.month().day())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            Text(goal.title).font(.subheadline).strikethrough(showCheckboxes && goal.isCompleted).foregroundColor(.primary)
                        }
                        
                        Spacer()
                        Button(action: { editingGoal = goal }) { Image(systemName: "pencil").foregroundColor(.gray.opacity(0.8)).font(.system(size: 14)).padding(4) }.buttonStyle(PlainButtonStyle())
                        Button(action: { var newGoals = goals; newGoals.remove(at: index); onUpdate(newGoals) }) { Image(systemName: "xmark").foregroundColor(.gray.opacity(0.6)).font(.system(size: 12, weight: .bold)).padding(4) }.buttonStyle(PlainButtonStyle())
                    }.padding(.vertical, 2)
                }
                if isAdding {
                    VStack(alignment: .leading, spacing: 10) {
                        if goals.isEmpty { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(templates, id: \.self) { sug in Button(action: { tempTitle = sug }) { Text(sug).font(.caption).padding(.horizontal, 10).padding(.vertical, 5).background(Color(.systemGray6)).cornerRadius(8).foregroundColor(.primary) }.buttonStyle(PlainButtonStyle()) } } } }
                        HStack { TextField(placeholder, text: $tempTitle).textFieldStyle(RoundedBorderTextFieldStyle()).onSubmit { addGoal() }; Button(action: addGoal) { Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundColor(.blue) }.buttonStyle(PlainButtonStyle()) }
                        ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { ForEach(categories) { cat in Text(cat.name).font(.caption2).bold().padding(.horizontal, 12).padding(.vertical, 6).background(selectedCategoryId == cat.id ? cat.color : Color(.systemGray5)).foregroundColor(selectedCategoryId == cat.id ? .white : .primary).clipShape(Capsule()).onTapGesture { selectedCategoryId = cat.id } }; NavigationLink(destination: CategorySettingsView(viewModel: viewModel)) { HStack(spacing: 4) { Image(systemName: "pencil"); Text("編集") }.font(.caption2).bold().padding(.horizontal, 12).padding(.vertical, 6).background(Color(.systemGray6)).foregroundColor(.primary).clipShape(Capsule()) }.buttonStyle(PlainButtonStyle()) }.padding(2) }
                    }.padding(.top, 4)
                }
            }
        }.padding(12).background(Color(.systemBackground)).cornerRadius(10).shadow(color: Color.black.opacity(0.05), radius: 3)
        .onAppear { if let first = categories.first { selectedCategoryId = first.id } }
        .sheet(item: $editingGoal) { goal in EditItemSheet(viewModel: viewModel, title: goal.title, categoryId: goal.categoryId) { newTitle, newCatId in if let idx = goals.firstIndex(where: { $0.id == goal.id }) { var newGoals = goals; newGoals[idx].title = newTitle; newGoals[idx].categoryId = newCatId; onUpdate(newGoals) } } }
    }
    private func addGoal() {
        if !tempTitle.isEmpty {
            var n = goals
            // 新規目標には作成日(startDate)を持たせる
            n.append(Goal(title: tempTitle, categoryId: selectedCategoryId, startDate: Date()))
            onUpdate(n)
            tempTitle = ""
            isAdding = false
        }
    }
}

struct EditItemSheet: View {
    @Environment(\.presentationMode) var presentationMode; @ObservedObject var viewModel: GoalViewModel; @State var title: String; @State var categoryId: String; var onSave: (String, String) -> Void
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("内容")) { TextField("名前", text: $title).submitLabel(.done) }
                Section(header: Text("カテゴリー")) { Picker("カテゴリー", selection: $categoryId) { ForEach(viewModel.appSettings.categories) { cat in HStack { Circle().fill(cat.color).frame(width: 10, height: 10); Text(cat.name) }.tag(cat.id) } }.pickerStyle(MenuPickerStyle()) }
            }.navigationTitle("編集").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { presentationMode.wrappedValue.dismiss() } }; ToolbarItem(placement: .navigationBarTrailing) { Button("保存") { onSave(title, categoryId); presentationMode.wrappedValue.dismiss() }.disabled(title.isEmpty) } }.scrollDismissesKeyboard(.interactively)
        }
    }
}
