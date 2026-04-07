import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var newTaskTitle = ""
    @State private var showResetAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text(dataManager.dateKey(dataManager.selectedDate))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                StreakBadgeView(streak: dataManager.calculateDailyStreak(from: dataManager.selectedDate))
                
                HStack {
                    TextField("新しいタスク...", text: $newTaskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        if !newTaskTitle.isEmpty {
                            var note = dataManager.getNote(for: dataManager.selectedDate)
                            note.tasks.append(Task(title: newTaskTitle))
                            dataManager.saveNote(note, for: dataManager.selectedDate)
                            newTaskTitle = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill").font(.title)
                    }
                }.padding()
                
                List {
                    Section {
                        let currentTasks = dataManager.getNote(for: dataManager.selectedDate).tasks
                        ForEach(currentTasks) { task in
                            HStack {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.isCompleted ? .green : .gray)
                                
                                if task.title.hasPrefix("日次: ") {
                                    Text(task.title.replacingOccurrences(of: "日次: ", with: ""))
                                        .strikethrough(task.isCompleted)
                                } else if task.title.hasPrefix("昨日のTry: ") {
                                    Text(task.title)
                                        .strikethrough(task.isCompleted)
                                        .foregroundColor(.blue)
                                } else {
                                    Text(task.title)
                                        .strikethrough(task.isCompleted)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if task.isYearlyReflection && Calendar.current.component(.month, from: dataManager.selectedDate) != 12 { return }
                                
                                var note = dataManager.getNote(for: dataManager.selectedDate)
                                if let idx = note.tasks.firstIndex(where: { $0.id == task.id }) {
                                    note.tasks[idx].isCompleted.toggle()
                                    dataManager.saveNote(note, for: dataManager.selectedDate)
                                }
                            }
                        }
                        .onDelete { offsets in
                            var note = dataManager.getNote(for: dataManager.selectedDate)
                            note.tasks.remove(atOffsets: offsets)
                            dataManager.saveNote(note, for: dataManager.selectedDate)
                        }
                    }
                }
            }
            .navigationTitle("今日のタスク")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } }
            }
        }
    }
}

struct StatBox: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundColor(.gray)
            Text(value).font(.title3).bold().foregroundColor(color)
        }.frame(maxWidth: .infinity).padding(.vertical, 8).background(Color(.systemGray6)).cornerRadius(10)
    }
}

struct ReflectionView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var reflectionType = 0
    @State private var newFutureVision = ""
    @State private var showYearlyAnimation = false
    
    private var isSunday: Bool { Calendar.current.component(.weekday, from: dataManager.selectedDate) == 1 }
    private var isLastDayOfMonth: Bool {
        let cal = Calendar.current; let date = dataManager.selectedDate
        let nextDay = cal.date(byAdding: .day, value: 1, to: date) ?? date
        return cal.component(.month, from: date) != cal.component(.month, from: nextDay)
    }
    private var isDecember: Bool { Calendar.current.component(.month, from: dataManager.selectedDate) == 12 }
    
    var body: some View {
        let note = dataManager.getNote(for: dataManager.selectedDate)
        let weekData = dataManager.getWeekData(for: dataManager.selectedDate)
        let monthData = dataManager.getMonthData(for: dataManager.selectedDate)
        let nextMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: dataManager.selectedDate) ?? dataManager.selectedDate
        let nextMonthData = dataManager.getMonthData(for: nextMonthDate)
        
        NavigationView {
            VStack(spacing: 0) {
                Picker("振り返り", selection: $reflectionType) {
                    Text("日次").tag(0)
                    if isSunday { Text("週次").tag(1) }
                    if isLastDayOfMonth { Text("月次").tag(2) }
                    if isDecember { Text("年次").tag(3) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: dataManager.selectedDate) { _, _ in
                    if reflectionType == 1 && !isSunday { reflectionType = 0 }
                    if reflectionType == 2 && !isLastDayOfMonth { reflectionType = 0 }
                    if reflectionType == 3 && !isDecember { reflectionType = 0 }
                }
                
                TabView(selection: $reflectionType) {
                    // 🌟 日次振り返り
                    ScrollView {
                        VStack(spacing: 15) {
                            ReflectionAchievementCard(title: "\(dataManager.getDailyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getDailyCompletionRate(for: dataManager.selectedDate), rate2: nil, rate3: nil, color2: .clear, color3: .clear)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                TextEditorView(title: "Keep（できたこと、継続したいこと）", text: Binding(get: { note.keep }, set: { updateNote($0, f: .keep) }), placeholder: "例：集中できた時間帯を維持する！")
                                TextEditorView(title: "Problem（できなかったこと、課題）", text: Binding(get: { note.problem }, set: { updateNote($0, f: .problem) }), placeholder: "例：SNSを見すぎて作業できなかった")
                                BulletInputSection(title: "Try（次回へのアクション）", items: note.tryList, placeholder: "例：朝はスマホを触らず作業開始する") { newList in
                                    var n = dataManager.getNote(for: dataManager.selectedDate); n.tryList = newList; dataManager.saveNote(n, for: dataManager.selectedDate)
                                }
                            }.padding(.horizontal)
                        }.padding(.vertical)
                    }.tag(0)
                    
                    // 🌟 週次振り返り
                    if isSunday {
                        ScrollView {
                            VStack(spacing: 15) {
                                ReflectionAchievementCard(title: "\(dataManager.getWeeklyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getWeeklyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getWeeklyGoalRate(for: dataManager.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("🏆 今週の達成記録").font(.caption).bold().foregroundColor(.primary)
                                        HStack {
                                            StatBox(title: "完了タスク", value: "\(dataManager.getCompletedTasksCount(for: dataManager.selectedDate, isWeekly: true))個", color: .green)
                                            StatBox(title: "Try実行", value: "\(dataManager.getTryExecutionCount(for: dataManager.selectedDate, isWeekly: true))回", color: .red)
                                        }
                                        let compText = dataManager.getComparisonText(for: dataManager.selectedDate, isWeekly: true)
                                        Text(compText).font(.caption).bold().foregroundColor(compText.contains("アップ") ? .orange : .gray).padding(.top, 4)
                                    }
                                    
                                    GoalListSection(title: "今週の目標チェック", iconColor: .orange, goals: weekData.goals, showCheckboxes: true, onUpdate: { var d = dataManager.getWeekData(for: dataManager.selectedDate); d.goals = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) })
                                    
                                    TextEditorView(title: "今週のKeep（今週できたこと、継続したいこと）", text: Binding(get: { weekData.keep }, set: { var d = weekData; d.keep = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) }), placeholder: "例：平日は毎日30分は必ず作業できた！")
                                    TextEditorView(title: "今週のProblem（今週できなかったこと、課題）", text: Binding(get: { weekData.problem }, set: { var d = weekData; d.problem = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) }), placeholder: "例：水曜と木曜は帰宅後にダラけて作業できなかった")
                                    BulletInputSection(title: "来週のTry（来週へのアクション）", items: weekData.tryList, placeholder: "例：作業時間中はスマホを別の部屋に置く") { newList in
                                        var d = dataManager.getWeekData(for: dataManager.selectedDate); d.tryList = newList; dataManager.saveWeekData(d, for: dataManager.selectedDate)
                                    }
                                    
                                    // 🌟 エラー修正箇所：minHeight と placeholder の順番を逆にしました
                                    TextEditorView(title: "今週の振り返り（自由記述）", text: Binding(get: { weekData.reflection }, set: { var d = weekData; d.reflection = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) }), minHeight: 120, placeholder: "今週の気づきや学びを自由に記録...")
                                    
                                }.padding(.horizontal)
                            }.padding(.vertical)
                        }.tag(1)
                    }
                    
                    // 🌟 月次振り返り
                    if isLastDayOfMonth {
                        ScrollView {
                            VStack(spacing: 15) {
                                ReflectionAchievementCard(title: "\(dataManager.getMonthlyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getMonthlyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getMonthlyWeeklyGoalAvgRate(for: dataManager.selectedDate), rate3: dataManager.getMonthlyGoalRate(for: dataManager.selectedDate), color2: .orange, color3: .blue)
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("🏆 今月の達成記録").font(.caption).bold().foregroundColor(.primary)
                                        HStack {
                                            StatBox(title: "完了タスク", value: "\(dataManager.getCompletedTasksCount(for: dataManager.selectedDate, isWeekly: false))個", color: .green)
                                            StatBox(title: "Try実行", value: "\(dataManager.getTryExecutionCount(for: dataManager.selectedDate, isWeekly: false))回", color: .red)
                                        }
                                        let compText = dataManager.getComparisonText(for: dataManager.selectedDate, isWeekly: false)
                                        Text(compText).font(.caption).bold().foregroundColor(compText.contains("アップ") ? .blue : .gray).padding(.top, 4)
                                    }

                                    GoalListSection(title: "今月の目標チェック", iconColor: .blue, goals: monthData.monthlyGoals, showCheckboxes: true, onUpdate: { var d = dataManager.getMonthData(for: dataManager.selectedDate); d.monthlyGoals = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) })
                                    
                                    TextEditorView(title: "今月のKeep（今月できたこと）", text: Binding(get: { monthData.keep }, set: { var d = monthData; d.keep = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) }), placeholder: "例：作業時間を記録する習慣が定着した！")
                                    TextEditorView(title: "今月のProblem（今月できなかったこと）", text: Binding(get: { monthData.problem }, set: { var d = monthData; d.problem = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) }), placeholder: "例：計画を詰め込みすぎて、未完了のタスクが多くなってしまった")
                                    BulletInputSection(title: "来月のTry（来月へのアクション）", items: monthData.tryList, placeholder: "例：来月はタスクをさらに小さく分割して、実行のハードルを下げる") { newList in
                                        var d = dataManager.getMonthData(for: dataManager.selectedDate); d.tryList = newList; dataManager.saveMonthData(d, for: dataManager.selectedDate)
                                    }
                                    
                                    // 🌟 エラー修正箇所：minHeight と placeholder の順番を逆にしました
                                    TextEditorView(title: "今月の振り返り（自由記述）", text: Binding(get: { monthData.reflection }, set: { var d = monthData; d.reflection = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) }), minHeight: 120, placeholder: "今月の気づきや学びを自由に記録...")
                                    
                                    Divider().padding(.vertical, 8)
                                    Text("🚀 来月に向けて").font(.subheadline).bold().foregroundColor(.blue)
                                    GoalListSection(title: "来月の月次目標を設定", iconColor: .blue, goals: nextMonthData.monthlyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: nextMonthDate); d.monthlyGoals = $0; dataManager.saveMonthData(d, for: nextMonthDate) })
                                    GoalListSection(title: "来月の週次目標を設定", iconColor: .orange, goals: nextMonthData.weeklyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: nextMonthDate); d.weeklyGoals = $0; dataManager.saveMonthData(d, for: nextMonthDate) })
                                    GoalListSection(title: "来月の日次目標を設定", iconColor: .green, goals: nextMonthData.dailyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: nextMonthDate); d.dailyGoals = $0; dataManager.saveMonthData(d, for: nextMonthDate) })
                                    
                                }.padding(.horizontal)
                            }.padding(.vertical)
                        }.tag(2)
                    }
                    
                    if isDecember {
                        ZStack {
                            ScrollView {
                                VStack(spacing: 20) {
                                    Text("🎉 年末の振り返り").font(.title2).bold().padding(.top)
                                    Text("今年1年間で達成した「未来の自分」を確認しましょう！\n（「未来の自分」タブと自動で連動しています）").font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                                    
                                    VStack(alignment: .leading, spacing: 10) {
                                        ForEach(dataManager.futureVisions) { vision in
                                            VStack(alignment: .leading, spacing: 8) {
                                                // 大目標のチェック
                                                HStack {
                                                    Button(action: {
                                                        withAnimation(.spring()) {
                                                            dataManager.toggleFutureVisionCompleted(id: vision.id)
                                                            if let updatedVision = dataManager.futureVisions.first(where: { $0.id == vision.id }), updatedVision.isCompleted {
                                                                showYearlyAnimation = true
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showYearlyAnimation = false }
                                                            }
                                                        }
                                                    }) {
                                                        Image(systemName: vision.isCompleted ? "checkmark.circle.fill" : "circle")
                                                            .foregroundColor(vision.isCompleted ? .pink : .gray).font(.title2)
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                    
                                                    Text(vision.title).strikethrough(vision.isCompleted).foregroundColor(vision.isCompleted ? .secondary : .primary)
                                                }
                                                
                                                // 具体的なステップ（サブタスク）のチェック
                                                if !vision.subTasks.isEmpty {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        ForEach(vision.subTasks) { subTask in
                                                            HStack {
                                                                Button(action: {
                                                                    dataManager.toggleSubTaskCompleted(visionId: vision.id, subTaskId: subTask.id)
                                                                }) {
                                                                    Image(systemName: subTask.isCompleted ? "checkmark.square.fill" : "square")
                                                                        .foregroundColor(subTask.isCompleted ? .pink : .gray)
                                                                }
                                                                .buttonStyle(PlainButtonStyle())
                                                                
                                                                Text(subTask.title)
                                                                    .font(.subheadline)
                                                                    .strikethrough(subTask.isCompleted)
                                                                    .foregroundColor(subTask.isCompleted ? .secondary : .gray)
                                                                
                                                                Spacer()
                                                                
                                                                Button(action: {
                                                                    UIPasteboard.general.string = subTask.title
                                                                }) {
                                                                    Image(systemName: "doc.on.clipboard")
                                                                        .foregroundColor(.gray)
                                                                        .font(.system(size: 14))
                                                                }
                                                                .buttonStyle(PlainButtonStyle())
                                                            }
                                                        }
                                                    }
                                                    .padding(.leading, 35) // 少し右にずらして階層を表現
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            Divider() // 項目ごとの区切り線
                                        }
                                    }
                                    .padding().background(Color(.systemBackground)).cornerRadius(12).shadow(radius: 2).padding(.horizontal)
                                }.padding(.bottom, 50)
                            }
                            if showYearlyAnimation {
                                let completedCount = dataManager.futureVisions.filter { $0.isCompleted }.count
                                LuxuriousCompletionEffect(completedCount: completedCount)
                                    .transition(.opacity)
                                    .zIndex(1)
                            }
                        }.tag(3)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("振り返り")
            .onAppear { dataManager.syncAll(for: dataManager.selectedDate) }
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } } }
        }
    }
    enum F { case keep, problem }
    func updateNote(_ t: String, f: F) { var n = dataManager.getNote(for: dataManager.selectedDate); if f == .keep { n.keep = t } else { n.problem = t }; dataManager.saveNote(n, for: dataManager.selectedDate) }
}

struct CalendarView: View {
    @ObservedObject var dataManager: AppDataManager; @Binding var selectedTab: Int
    @State private var monthOffset: Int = 0
    
    private func displayDate(for offset: Int) -> Date {
        let comp = Calendar.current.dateComponents([.year, .month], from: Date())
        let startOfCurrentMonth = Calendar.current.date(from: comp) ?? Date()
        return Calendar.current.date(byAdding: .month, value: offset, to: startOfCurrentMonth) ?? Date()
    }

    var body: some View {
        NavigationView {
            TabView(selection: $monthOffset) {
                ForEach(-60...60, id: \.self) { offset in
                    let currentDisplayDate = displayDate(for: offset)
                    let monthData = dataManager.getMonthData(for: currentDisplayDate)
                    
                    ScrollView {
                        VStack(spacing: 15) {
                            HStack(spacing: 10) {
                                CompositeSummaryCard(title: "\(dataManager.getWeeklyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getWeeklyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getWeeklyGoalRate(for: dataManager.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                                CompositeSummaryCard(title: "\(dataManager.getMonthlyTitle(for: currentDisplayDate))の達成度", rate1: dataManager.getMonthlyDailyAvgRate(for: currentDisplayDate), rate2: dataManager.getMonthlyWeeklyGoalAvgRate(for: currentDisplayDate), rate3: dataManager.getMonthlyGoalRate(for: currentDisplayDate), color2: .orange, color3: .blue)
                            }.padding(.horizontal)

                            VStack(spacing: 10) {
                                GoalListSection(title: "\(dataManager.getMonthlyTitle(for: currentDisplayDate))の月次目標", iconColor: .blue, goals: monthData.monthlyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: currentDisplayDate); d.monthlyGoals = $0; dataManager.saveMonthData(d, for: currentDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) { copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: currentDisplayDate) ?? currentDisplayDate).monthlyGoals, field: .monthly, date: currentDisplayDate) }
                                GoalListSection(title: "\(dataManager.getMonthlyTitle(for: currentDisplayDate))の週次目標", iconColor: .orange, goals: monthData.weeklyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: currentDisplayDate); d.weeklyGoals = $0; dataManager.saveMonthData(d, for: currentDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) { copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: currentDisplayDate) ?? currentDisplayDate).weeklyGoals, field: .weekly, date: currentDisplayDate) }
                                GoalListSection(title: "\(dataManager.getMonthlyTitle(for: currentDisplayDate))の日次目標", iconColor: .green, goals: monthData.dailyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: currentDisplayDate); d.dailyGoals = $0; dataManager.saveMonthData(d, for: currentDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) { copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: currentDisplayDate) ?? currentDisplayDate).dailyGoals, field: .daily, date: currentDisplayDate) }
                            }.padding(.horizontal)

                            CalendarGridView(dataManager: dataManager, displayDate: currentDisplayDate, selectedDate: $dataManager.selectedDate, selectedTab: $selectedTab)
                        }.padding(.top, 10).tag(offset)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle(dataManager.getMonthlyTitle(for: displayDate(for: monthOffset)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } }
                ToolbarItem(placement: .navigationBarLeading) { Button(action: { withAnimation { monthOffset -= 1 } }) { Image(systemName: "chevron.left") } }
                ToolbarItem(placement: .navigationBarTrailing) { Button(action: { withAnimation { monthOffset += 1 } }) { Image(systemName: "chevron.right") } }
            }
        }
    }
    
    enum F { case monthly, weekly, daily }
    func copyPrev(prev: [Goal], field: F, date: Date) {
        var curr: [Goal]
        switch field { case .monthly: curr = dataManager.getMonthData(for: date).monthlyGoals; case .weekly: curr = dataManager.getMonthData(for: date).weeklyGoals; case .daily: curr = dataManager.getMonthData(for: date).dailyGoals }
        let titles = curr.map { $0.title }
        var new = curr; for g in prev { if !titles.contains(g.title) { new.append(Goal(title: g.title)) } }
        var d = dataManager.getMonthData(for: date)
        if field == .monthly { d.monthlyGoals = new } else if field == .weekly { d.weeklyGoals = new } else { d.dailyGoals = new }
        dataManager.saveMonthData(d, for: date); dataManager.syncAll(for: dataManager.selectedDate)
    }
}

struct SettingsView: View {
    @ObservedObject var dataManager: AppDataManager; @State private var isTutorial = false
    var body: some View {
        NavigationView {
            Form {
                Section("通知設定") {
                    Toggle("目標通知", isOn: Binding(get: { dataManager.appSettings.goalNotificationEnabled }, set: { dataManager.appSettings.goalNotificationEnabled = $0; dataManager.saveSettings() }))
                    if dataManager.appSettings.goalNotificationEnabled { DatePicker("時間", selection: Binding(get: { dataManager.appSettings.goalNotificationTime }, set: { dataManager.appSettings.goalNotificationTime = $0; dataManager.saveSettings() }), displayedComponents: .hourAndMinute) }
                    Toggle("振り返り通知", isOn: Binding(get: { dataManager.appSettings.reflectionNotificationEnabled }, set: { dataManager.appSettings.reflectionNotificationEnabled = $0; dataManager.saveSettings() }))
                    if dataManager.appSettings.reflectionNotificationEnabled { DatePicker("時間", selection: Binding(get: { dataManager.appSettings.reflectionNotificationTime }, set: { dataManager.appSettings.reflectionNotificationTime = $0; dataManager.saveSettings() }), displayedComponents: .hourAndMinute) }
                }
                Section("サポート") {
                    Button(action: { isTutorial = true }) {
                        HStack { Image(systemName: "book.fill").foregroundColor(.blue).frame(width: 24); Text("使い方ガイド").foregroundColor(.primary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary) }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Section("アプリ情報") { HStack { Text("バージョン"); Spacer(); Text("1.0.0").foregroundColor(.secondary) } }
            }.navigationTitle("設定").sheet(isPresented: $isTutorial) { TutorialView(isShowing: $isTutorial) }
        }
    }
}

struct FutureVisionView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var newVisionTitle = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text("目標を達成した先に、どうなっていたいですか？\n「海外で働く」といった大きな目標に対して、「TOEICで900点を取る」などの具体的なステップを追加して夢を可視化しましょう。")
                    .font(.caption).foregroundColor(.secondary).padding()

                HStack {
                    TextField("例：海外で働く！", text: $newVisionTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        if !newVisionTitle.isEmpty {
                            dataManager.futureVisions.append(FutureVision(title: newVisionTitle))
                            dataManager.saveFutureVisions()
                            newVisionTitle = ""
                        }
                    }) { Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.pink) }
                    .buttonStyle(PlainButtonStyle())
                }.padding(.horizontal)

                List {
                    ForEach(dataManager.futureVisions) { vision in
                        FutureVisionRow(vision: vision, dataManager: dataManager)
                    }
                    .onDelete { indexSet in
                        dataManager.futureVisions.remove(atOffsets: indexSet)
                        dataManager.saveFutureVisions()
                    }
                }
            }
            .navigationTitle("✨ 未来の自分")
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } } }
        }
    }
}

struct FutureVisionRow: View {
    let vision: FutureVision
    @ObservedObject var dataManager: AppDataManager
    
    @State private var isExpanded = false
    @State private var newSubTaskText = ""
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                
                // サブタスク一覧
                ForEach(vision.subTasks) { subTask in
                    HStack {
                        Button(action: {
                            dataManager.toggleSubTaskCompleted(visionId: vision.id, subTaskId: subTask.id)
                        }) {
                            Image(systemName: subTask.isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundColor(subTask.isCompleted ? .pink : .gray)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(subTask.title)
                            .strikethrough(subTask.isCompleted)
                            .foregroundColor(subTask.isCompleted ? .secondary : .primary)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = subTask.title
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 2)
                }
                
                // サブタスク追加枠
                HStack {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                    
                    TextField("具体的なステップ", text: $newSubTaskText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit { addSubTask() }
                    
                    Button(action: { addSubTask() }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(newSubTaskText.isEmpty ? .gray.opacity(0.3) : .pink)
                            .font(.system(size: 24))
                    }
                    .disabled(newSubTaskText.isEmpty)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 5)
            }
            .padding(.leading, 10)
            
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: {
                        dataManager.toggleFutureVisionCompleted(id: vision.id)
                    }) {
                        Image(systemName: vision.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(vision.isCompleted ? .pink : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(vision.title)
                        .font(.headline)
                        .strikethrough(vision.isCompleted)
                }
                
                if !vision.subTasks.isEmpty {
                    ProgressView(value: vision.progress)
                        .tint(.pink)
                        .scaleEffect(x: 1, y: 0.5, anchor: .center)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func addSubTask() {
        guard !newSubTaskText.isEmpty else { return }
        dataManager.addSubTask(to: vision.id, title: newSubTaskText)
        newSubTaskText = ""
    }
}
