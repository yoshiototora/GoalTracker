import SwiftUI

struct HomeView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var newTaskTitle = ""; @State private var showResetAlert = false
    var body: some View {
        NavigationView {
            VStack {
                Text(dataManager.dateKey(dataManager.selectedDate)).font(.caption).foregroundColor(.gray)
                HStack {
                    TextField("新しいタスク...", text: $newTaskTitle).textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        if !newTaskTitle.isEmpty {
                            var note = dataManager.getNote(for: dataManager.selectedDate)
                            note.tasks.append(Task(title: newTaskTitle))
                            dataManager.saveNote(note, for: dataManager.selectedDate)
                            newTaskTitle = ""
                        }
                    }) { Image(systemName: "plus.circle.fill").font(.title) }
                }.padding()
                List {
                    Section {
                        let currentTasks = dataManager.getNote(for: dataManager.selectedDate).tasks
                        ForEach(currentTasks) { task in
                            HStack {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(task.isCompleted ? .green : .gray)
                                
                                if task.title.hasPrefix("日次: ") {
                                    Image(systemName: "circle.fill").foregroundColor(.green).font(.system(size: 10))
                                    Text(task.title.replacingOccurrences(of: "日次: ", with: "")).strikethrough(task.isCompleted)
                                } else if task.title.hasPrefix("昨日のTry: ") {
                                    Image(systemName: "flame.fill").foregroundColor(.red).font(.system(size: 12))
                                    Text(task.title.replacingOccurrences(of: "昨日のTry: ", with: "")).strikethrough(task.isCompleted)
                                } else {
                                    Text(task.title).strikethrough(task.isCompleted)
                                }
                            }.onTapGesture {
                                var note = dataManager.getNote(for: dataManager.selectedDate)
                                if let i = note.tasks.firstIndex(where: { $0.id == task.id }) {
                                    note.tasks[i].isCompleted.toggle()
                                    dataManager.saveNote(note, for: dataManager.selectedDate)
                                }
                            }
                        }.onDelete { offsets in
                            var note = dataManager.getNote(for: dataManager.selectedDate)
                            note.tasks.remove(atOffsets: offsets)
                            dataManager.saveNote(note, for: dataManager.selectedDate)
                        }
                    }
                }
            }
            .navigationTitle("今日のタスク")
            .onAppear { dataManager.syncAll(for: dataManager.selectedDate) }
            .onChange(of: dataManager.selectedDate) { _, newDate in dataManager.syncAll(for: newDate) }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button(action: { showResetAlert = true }) { Image(systemName: "trash").foregroundColor(.red) } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } }
            }
            .alert("全データをリセット", isPresented: $showResetAlert) {
                Button("キャンセル", role: .cancel) { }; Button("削除する", role: .destructive) { dataManager.resetAllData() }
            } message: { Text("保存されているすべてのデータが消去されます。") }
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
    
    private var isSunday: Bool { Calendar.current.component(.weekday, from: dataManager.selectedDate) == 1 }
    private var isLastDayOfMonth: Bool {
        let cal = Calendar.current; let date = dataManager.selectedDate
        let nextDay = cal.date(byAdding: .day, value: 1, to: date) ?? date
        return cal.component(.month, from: date) != cal.component(.month, from: nextDay)
    }
    
    var body: some View {
        let note = dataManager.getNote(for: dataManager.selectedDate)
        let weekData = dataManager.getWeekData(for: dataManager.selectedDate)
        let monthData = dataManager.getMonthData(for: dataManager.selectedDate)
        
        let nextMonthDate = Calendar.current.date(byAdding: .month, value: 1, to: dataManager.selectedDate) ?? dataManager.selectedDate
        let nextMonthData = dataManager.getMonthData(for: nextMonthDate)
        
        NavigationView {
            VStack(spacing: 0) { // 🌟 Pickerと下のスワイプ画面の隙間をなくす
                
                // 🌟 上部の切り替えボタン（スワイプと連動します）
                Picker("振り返り", selection: $reflectionType) {
                    Text("日次").tag(0)
                    if isSunday { Text("週次").tag(1) }
                    if isLastDayOfMonth { Text("月次").tag(2) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: dataManager.selectedDate) { _, _ in
                    if reflectionType == 1 && !isSunday { reflectionType = 0 }
                    if reflectionType == 2 && !isLastDayOfMonth { reflectionType = 0 }
                }
                
                // 🌟 TabViewを使って横スワイプを実現！
                TabView(selection: $reflectionType) {
                    
                    // --- 📌 1ページ目：日次の振り返り (Tag: 0) ---
                    ScrollView {
                        VStack(spacing: 15) {
                            ReflectionAchievementCard(title: "\(dataManager.getDailyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getDailyCompletionRate(for: dataManager.selectedDate), rate2: nil, rate3: nil, color2: .clear, color3: .clear)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                TextEditorView(title: "Keep", text: Binding(get: { note.keep }, set: { updateNote($0, f: .keep) }), placeholder: "できたこと、継続したいこと")
                                TextEditorView(title: "Problem", text: Binding(get: { note.problem }, set: { updateNote($0, f: .problem) }), placeholder: "できなかったこと")
                                BulletInputSection(title: "Try", items: note.tryList, placeholder: "明日どうするか、どう改善するか") { newList in var n = dataManager.getNote(for: dataManager.selectedDate); n.tryList = newList; dataManager.saveNote(n, for: dataManager.selectedDate) }
                            }.padding(.horizontal)
                        }.padding(.vertical)
                    }
                    .tag(0) // 👈 これがPickerの .tag(0) と紐づきます
                    
                    // --- 📌 2ページ目：週次の振り返り (Tag: 1) ※日曜のみ表示 ---
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
                                    
                                    TextEditorView(title: "今週の振り返り", text: Binding(get: { weekData.reflection }, set: { var d = weekData; d.reflection = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) }), minHeight: 120)
                                    
                                }.padding(.horizontal)
                            }.padding(.vertical)
                        }
                        .tag(1) // 👈 Pickerの .tag(1) と紐づきます
                    }
                    
                    // --- 📌 3ページ目：月次の振り返り (Tag: 2) ※月末のみ表示 ---
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
                                    
                                    TextEditorView(title: "今月の振り返り", text: Binding(get: { monthData.reflection }, set: { var d = monthData; d.reflection = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) }), minHeight: 120)
                                    
                                    Divider().padding(.vertical, 8)
                                    Text("🚀 来月に向けて").font(.subheadline).bold().foregroundColor(.purple)
                                    GoalListSection(title: "来月の月次目標を設定", iconColor: .blue, goals: nextMonthData.monthlyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: nextMonthDate); d.monthlyGoals = $0; dataManager.saveMonthData(d, for: nextMonthDate) })
                                    GoalListSection(title: "来月の週次目標を設定", iconColor: .orange, goals: nextMonthData.weeklyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: nextMonthDate); d.weeklyGoals = $0; dataManager.saveMonthData(d, for: nextMonthDate) })
                                    GoalListSection(title: "来月の日次目標を設定", iconColor: .green, goals: nextMonthData.dailyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: nextMonthDate); d.dailyGoals = $0; dataManager.saveMonthData(d, for: nextMonthDate) })
                                    
                                }.padding(.horizontal)
                            }.padding(.vertical)
                        }
                        .tag(2) // 👈 Pickerの .tag(2) と紐づきます
                    }
                    
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // 🌟 これを追加するだけでスワイプ可能になります！
            }
            .navigationTitle("振り返り")
            .onAppear { dataManager.syncAll(for: dataManager.selectedDate) }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } }
            }
        }
    }
    
    enum F { case keep, problem }
    func updateNote(_ t: String, f: F) { var n = dataManager.getNote(for: dataManager.selectedDate); if f == .keep { n.keep = t } else { n.problem = t }; dataManager.saveNote(n, for: dataManager.selectedDate) }
}


struct CalendarView: View {
    @ObservedObject var dataManager: AppDataManager
    @Binding var selectedTab: Int
    @State private var calendarDisplayDate = Date()
    var body: some View {
        let monthData = dataManager.getMonthData(for: calendarDisplayDate)
        NavigationView {
            ScrollView {
                VStack(spacing: 15) {
                    HStack(spacing: 10) {
                        CompositeSummaryCard(title: "\(dataManager.getWeeklyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getWeeklyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getWeeklyGoalRate(for: dataManager.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                        CompositeSummaryCard(title: "\(dataManager.getMonthlyTitle(for: calendarDisplayDate))の達成度", rate1: dataManager.getMonthlyDailyAvgRate(for: calendarDisplayDate), rate2: dataManager.getMonthlyWeeklyGoalAvgRate(for: calendarDisplayDate), rate3: dataManager.getMonthlyGoalRate(for: calendarDisplayDate), color2: .orange, color3: .blue)
                    }.padding(.horizontal)

                    VStack(spacing: 10) {
                        GoalListSection(title: "\(dataManager.getMonthlyTitle(for: calendarDisplayDate))の月次目標", iconColor: .blue, goals: monthData.monthlyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: calendarDisplayDate); d.monthlyGoals = $0; dataManager.saveMonthData(d, for: calendarDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) {
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate) ?? calendarDisplayDate).monthlyGoals, field: .monthly)
                        }
                        GoalListSection(title: "\(dataManager.getMonthlyTitle(for: calendarDisplayDate))の週次目標", iconColor: .orange, goals: monthData.weeklyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: calendarDisplayDate); d.weeklyGoals = $0; dataManager.saveMonthData(d, for: calendarDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) {
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate) ?? calendarDisplayDate).weeklyGoals, field: .weekly)
                        }
                        GoalListSection(title: "\(dataManager.getMonthlyTitle(for: calendarDisplayDate))の日次目標", iconColor: .green, goals: monthData.dailyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: calendarDisplayDate); d.dailyGoals = $0; dataManager.saveMonthData(d, for: calendarDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) {
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate) ?? calendarDisplayDate).dailyGoals, field: .daily)
                        }
                    }.padding(.horizontal)

                    HStack {
                        Button(action: { calendarDisplayDate = Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate) ?? calendarDisplayDate }) { Image(systemName: "chevron.left") }
                        Spacer(); Text(dataManager.getMonthlyTitle(for: calendarDisplayDate)).font(.headline); Spacer()
                        Button(action: { calendarDisplayDate = Calendar.current.date(byAdding: .month, value: 1, to: calendarDisplayDate) ?? calendarDisplayDate }) { Image(systemName: "chevron.right") }
                    }.padding(.horizontal)
                    
                    CalendarGridView(dataManager: dataManager, displayDate: calendarDisplayDate, selectedDate: $dataManager.selectedDate, selectedTab: $selectedTab)
                }
                .padding(.top, 10)
            }
            .navigationTitle("カレンダー")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完了") { hideKeyboard() } }
            }
        }
    }
    
    enum F { case monthly, weekly, daily }
    
    func copyPrev(prev: [Goal], field: F) {
        var curr: [Goal]
        switch field {
        case .monthly: curr = dataManager.getMonthData(for: calendarDisplayDate).monthlyGoals
        case .weekly: curr = dataManager.getMonthData(for: calendarDisplayDate).weeklyGoals
        case .daily: curr = dataManager.getMonthData(for: calendarDisplayDate).dailyGoals
        }
        let titles = curr.map { $0.title }
        var new = curr; for g in prev { if !titles.contains(g.title) { new.append(Goal(title: g.title)) } }
        var d = dataManager.getMonthData(for: calendarDisplayDate)
        if field == .monthly { d.monthlyGoals = new }
        else if field == .weekly { d.weeklyGoals = new }
        else { d.dailyGoals = new }
        dataManager.saveMonthData(d, for: calendarDisplayDate)
        dataManager.syncAll(for: dataManager.selectedDate)
    }
}

struct SettingsView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var isShowingTutorial = false
    
    var body: some View {
        NavigationView {
            Form {
                // --- 通知設定セクション ---
                Section(header: Text("通知設定")) {
                    Toggle("今日の目標通知", isOn: Binding(
                        get: { dataManager.appSettings.goalNotificationEnabled },
                        set: { dataManager.appSettings.goalNotificationEnabled = $0; dataManager.saveSettings() }
                    ))
                    
                    if dataManager.appSettings.goalNotificationEnabled {
                        DatePicker("通知時間", selection: Binding(
                            get: { dataManager.appSettings.goalNotificationTime },
                            set: { dataManager.appSettings.goalNotificationTime = $0; dataManager.saveSettings() }
                        ), displayedComponents: .hourAndMinute)
                    }
                    
                    Toggle("振り返り通知", isOn: Binding(
                        get: { dataManager.appSettings.reflectionNotificationEnabled },
                        set: { dataManager.appSettings.reflectionNotificationEnabled = $0; dataManager.saveSettings() }
                    ))
                    
                    if dataManager.appSettings.reflectionNotificationEnabled {
                        DatePicker("通知時間", selection: Binding(
                            get: { dataManager.appSettings.reflectionNotificationTime },
                            set: { dataManager.appSettings.reflectionNotificationTime = $0; dataManager.saveSettings() }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
                
                // --- サポートセクション ---
                Section(header: Text("サポート")) {
                    // 🌟 修正：行全体をタップ可能にしたボタン
                    Button(action: {
                        isShowingTutorial = true
                    }) {
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("使い方ガイドを見る")
                                .foregroundColor(.primary)
                            Spacer() // 👈 これで右端まで領域を広げる
                            Image(systemName: "chevron.right") // 👈 押せることを示す矢印
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle()) // 👈 透明な隙間でもタップに反応させる
                    }
                    .buttonStyle(PlainButtonStyle()) // 👈 ボタン特有の青文字化を防ぐ
                }
                
                // --- プレミアム ---
                Section(header: Text("プレミアム")) {
                    Button(action: {
                        // 課金処理（将来用）
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text("プロ版にアップグレード")
                                    .foregroundColor(.primary)
                                Text("広告を非表示にする")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // --- アプリ情報 ---
                Section(header: Text("このアプリについて")) {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $isShowingTutorial) {
                TutorialView(isShowing: $isShowingTutorial)
            }
        }
    }
}
