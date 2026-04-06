//
//  MainViews.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/06.
//
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
            }.navigationTitle("今日のタスク").id(dataManager.selectedDate)
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

struct ReflectionView: View {
    @ObservedObject var dataManager: AppDataManager
    @State private var reflectionType = 0
    
    private var isSunday: Bool { Calendar.current.component(.weekday, from: dataManager.selectedDate) == 1 }
    private var isLastDayOfMonth: Bool {
        let cal = Calendar.current; let date = dataManager.selectedDate
        let nextDay = cal.date(byAdding: .day, value: 1, to: date)!
        return cal.component(.month, from: date) != cal.component(.month, from: nextDay)
    }
    
    var body: some View {
        let note = dataManager.getNote(for: dataManager.selectedDate)
        let weekData = dataManager.getWeekData(for: dataManager.selectedDate)
        let monthData = dataManager.getMonthData(for: dataManager.selectedDate)
        
        NavigationView {
            VStack {
                Picker("振り返り", selection: $reflectionType) {
                    Text("日次").tag(0)
                    if isSunday { Text("週次").tag(1) }
                    if isLastDayOfMonth { Text("月次").tag(2) }
                }
                .pickerStyle(SegmentedPickerStyle()).padding()
                .onChange(of: dataManager.selectedDate) { _, _ in
                    if reflectionType == 1 && !isSunday { reflectionType = 0 }
                    if reflectionType == 2 && !isLastDayOfMonth { reflectionType = 0 }
                }
                
                if reflectionType == 0 {
                    ReflectionAchievementCard(title: "\(dataManager.getDailyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getDailyCompletionRate(for: dataManager.selectedDate), rate2: nil, rate3: nil, color2: .clear, color3: .clear)
                } else if reflectionType == 1 {
                    ReflectionAchievementCard(title: "\(dataManager.getWeeklyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getWeeklyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getWeeklyGoalRate(for: dataManager.selectedDate), rate3: nil, color2: .orange, color3: .clear)
                } else {
                    ReflectionAchievementCard(title: "\(dataManager.getMonthlyTitle(for: dataManager.selectedDate))の達成度", rate1: dataManager.getMonthlyDailyAvgRate(for: dataManager.selectedDate), rate2: dataManager.getMonthlyWeeklyGoalAvgRate(for: dataManager.selectedDate), rate3: dataManager.getMonthlyGoalRate(for: dataManager.selectedDate), color2: .orange, color3: .blue)
                }

                ScrollView {
                    VStack(spacing: 15) {
                        if reflectionType == 0 {
                            VStack(alignment: .leading, spacing: 10) {
                                TextEditorView(title: "Keep", text: Binding(get: { note.keep }, set: { updateNote($0, f: .keep) }))
                                TextEditorView(title: "Problem", text: Binding(get: { note.problem }, set: { updateNote($0, f: .problem) }))
                                BulletInputSection(title: "Try", items: note.tryList) { newList in var n = dataManager.getNote(for: dataManager.selectedDate); n.tryList = newList; dataManager.saveNote(n, for: dataManager.selectedDate) }
                            }.padding(.horizontal)
                        } else if reflectionType == 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                GoalListSection(title: "今週の目標チェック", iconColor: .orange, goals: weekData.goals, showCheckboxes: true, onUpdate: { var d = dataManager.getWeekData(for: dataManager.selectedDate); d.goals = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) })
                                if isSunday {
                                    TextEditorView(title: "今週の振り返り", text: Binding(get: { weekData.reflection }, set: { var d = dataManager.getWeekData(for: dataManager.selectedDate); d.reflection = $0; dataManager.saveWeekData(d, for: dataManager.selectedDate) }), minHeight: 120)
                                } else {
                                    VStack(alignment: .leading) {
                                        Text("今週の振り返り (※編集は週の最終日のみ)").font(.caption).foregroundColor(.gray)
                                        Text(weekData.reflection.isEmpty ? "未記入" : weekData.reflection).padding(8).frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading).background(Color(.systemGray6)).cornerRadius(8)
                                    }.padding(.vertical, 4)
                                }
                            }.padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                GoalListSection(title: "今月の目標チェック", iconColor: .blue, goals: monthData.monthlyGoals, showCheckboxes: true, onUpdate: { var d = dataManager.getMonthData(for: dataManager.selectedDate); d.monthlyGoals = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) })
                                if isLastDayOfMonth {
                                    TextEditorView(title: "今月の振り返り", text: Binding(get: { monthData.reflection }, set: { var d = dataManager.getMonthData(for: dataManager.selectedDate); d.reflection = $0; dataManager.saveMonthData(d, for: dataManager.selectedDate) }), minHeight: 120)
                                } else {
                                    VStack(alignment: .leading) {
                                        Text("今月の振り返り (※編集は月末のみ)").font(.caption).foregroundColor(.gray)
                                        Text(monthData.reflection.isEmpty ? "未記入" : monthData.reflection).padding(8).frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading).background(Color(.systemGray6)).cornerRadius(8)
                                    }.padding(.vertical, 4)
                                }
                            }.padding(.horizontal)
                        }
                    }.padding(.vertical)
                }
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
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)!).monthlyGoals, field: .monthly)
                        }
                        GoalListSection(title: "\(dataManager.getMonthlyTitle(for: calendarDisplayDate))の週次目標", iconColor: .orange, goals: monthData.weeklyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: calendarDisplayDate); d.weeklyGoals = $0; dataManager.saveMonthData(d, for: calendarDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) {
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)!).weeklyGoals, field: .weekly)
                        }
                        GoalListSection(title: "\(dataManager.getMonthlyTitle(for: calendarDisplayDate))の日次目標", iconColor: .green, goals: monthData.dailyGoals, showCheckboxes: false, onUpdate: { var d = dataManager.getMonthData(for: calendarDisplayDate); d.dailyGoals = $0; dataManager.saveMonthData(d, for: calendarDisplayDate); dataManager.syncAll(for: dataManager.selectedDate) }) {
                            copyPrev(prev: dataManager.getMonthData(for: Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)!).dailyGoals, field: .daily)
                        }
                    }.padding(.horizontal)

                    HStack {
                        Button(action: { calendarDisplayDate = Calendar.current.date(byAdding: .month, value: -1, to: calendarDisplayDate)! }) { Image(systemName: "chevron.left") }
                        Spacer(); Text(dataManager.getMonthlyTitle(for: calendarDisplayDate)).font(.headline); Spacer()
                        Button(action: { calendarDisplayDate = Calendar.current.date(byAdding: .month, value: 1, to: calendarDisplayDate)! }) { Image(systemName: "chevron.right") }
                    }.padding(.horizontal)
                    
                    CalendarGridView(dataManager: dataManager, displayDate: calendarDisplayDate, selectedDate: $dataManager.selectedDate, selectedTab: $selectedTab)
                }
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

struct CalendarGridView: View {
    @ObservedObject var dataManager: AppDataManager; let displayDate: Date; @Binding var selectedDate: Date; @Binding var selectedTab: Int
    let cols = Array(repeating: GridItem(.flexible()), count: 7)
    var body: some View {
        let days = generateDays(); let today = Calendar.current.startOfDay(for: Date())
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(0..<days.count, id: \.self) { i in
                if let d = days[i] {
                    let isSel = Calendar.current.isDate(d, inSameDayAs: selectedDate); let isFut = d > today
                    RoundedRectangle(cornerRadius: 6).fill(isFut ? Color(.systemGray6) : getCol(d))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSel ? Color.blue : Color.clear, lineWidth: isSel ? 3 : 0))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Text("\(Calendar.current.component(.day, from: d))").font(.caption).foregroundColor(isFut ? .gray : (rate(d) >= 0.75 ? .white : .primary)))
                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                            if !isFut { selectedDate = d; selectedTab = 1 }
                        })
                        .simultaneousGesture(TapGesture(count: 1).onEnded {
                            if !isFut { selectedDate = d }
                        })
                } else { Color.clear }
            }
        }.padding()
    }
    func rate(_ d: Date) -> Double { dataManager.getDailyCompletionRate(for: d) }
    
    func getCol(_ d: Date) -> Color {
        let r = rate(d)
        let note = dataManager.getNote(for: d)
        
        let hasReflection = !note.keep.isEmpty || !note.problem.isEmpty || note.tryList.contains { !$0.isEmpty }
        
        if r == 0 && !hasReflection { return Color(.systemGray6) }
        if r == 0 { return Color.green.opacity(0.1) }
        switch r {
        case ..<0.25: return Color.green.opacity(0.25)
        case 0.25..<0.5: return Color.green.opacity(0.5)
        case 0.5..<0.75: return Color.green.opacity(0.7)
        case 0.75..<1.0: return Color.green.opacity(0.85)
        default: return Color.green
        }
    }
    
    func generateDays() -> [Date?] {
        let cal = Calendar.current; let start = cal.date(from: cal.dateComponents([.year, .month], from: displayDate))!; let range = cal.range(of: .day, in: .month, for: start)!; let firstDay = cal.component(.weekday, from: start)
        var days: [Date?] = Array(repeating: nil, count: firstDay - 1); for i in 0..<range.count { days.append(cal.date(byAdding: .day, value: i, to: start)!) }; return days
    }
}

struct SettingsView: View {
    @ObservedObject var dataManager: AppDataManager
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("目標の通知")) {
                    Toggle("オン", isOn: Binding(get: { dataManager.appSettings.goalNotificationEnabled }, set: { dataManager.appSettings.goalNotificationEnabled = $0; dataManager.saveSettings() }))
                    if dataManager.appSettings.goalNotificationEnabled { DatePicker("時間", selection: Binding(get: { dataManager.appSettings.goalNotificationTime }, set: { dataManager.appSettings.goalNotificationTime = $0; dataManager.saveSettings() }), displayedComponents: .hourAndMinute) }
                }
                Section(header: Text("振り返りの通知")) {
                    Toggle("オン", isOn: Binding(get: { dataManager.appSettings.reflectionNotificationEnabled }, set: { dataManager.appSettings.reflectionNotificationEnabled = $0; dataManager.saveSettings() }))
                    if dataManager.appSettings.reflectionNotificationEnabled { DatePicker("時間", selection: Binding(get: { dataManager.appSettings.reflectionNotificationTime }, set: { dataManager.appSettings.reflectionNotificationTime = $0; dataManager.saveSettings() }), displayedComponents: .hourAndMinute) }
                }
            }.navigationTitle("設定")
        }
    }
}
