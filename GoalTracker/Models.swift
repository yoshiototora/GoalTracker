//
//  Models.swift
//  GoalTracker
//

import Foundation
import SwiftUI

struct AppSettings: Codable {
    var goalNotificationEnabled: Bool = false
    var goalNotificationTime: Date = Date()
    var reflectionNotificationEnabled: Bool = false
    var reflectionNotificationTime: Date = Date()
    
    var skipShortFirstWeek: Bool = true
    var shortWeekThreshold: Int = 3
    var skipShortLastWeek: Bool = true
    var shortLastWeekThreshold: Int = 3
    
    var appStartDate: Date? = nil
    
    var categories: [CategoryItem] = [
        CategoryItem(id: "action", name: "行動習慣", colorName: "blue"),
        CategoryItem(id: "lifestyle", name: "生活習慣", colorName: "yellow"),
        CategoryItem(id: "none", name: "指定なし", colorName: "gray")
    ]
    
    // 🌟 追加：週次振り返りの曜日（デフォルトは 1 = 日曜日）
    var weeklyReflectionWeekday: Int = 1
    
    // 🟢 古いものを削除し、1つにまとめました
    enum CodingKeys: String, CodingKey {
        case goalNotificationEnabled, goalNotificationTime, reflectionNotificationEnabled, reflectionNotificationTime
        case skipShortFirstWeek, shortWeekThreshold, skipShortLastWeek, shortLastWeekThreshold, appStartDate, categories
        case weeklyReflectionWeekday
    }
    
    // 新規作成時の初期化用
    init() {}
    
    // 🟢 追加：既存ユーザーがアップデートした際のクラッシュを防ぐ安全装置
    // （古い保存データに「weeklyReflectionWeekday」が無くてもエラーにならないようにします）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        goalNotificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .goalNotificationEnabled) ?? false
        goalNotificationTime = try container.decodeIfPresent(Date.self, forKey: .goalNotificationTime) ?? Date()
        reflectionNotificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .reflectionNotificationEnabled) ?? false
        reflectionNotificationTime = try container.decodeIfPresent(Date.self, forKey: .reflectionNotificationTime) ?? Date()
        
        skipShortFirstWeek = try container.decodeIfPresent(Bool.self, forKey: .skipShortFirstWeek) ?? true
        shortWeekThreshold = try container.decodeIfPresent(Int.self, forKey: .shortWeekThreshold) ?? 3
        skipShortLastWeek = try container.decodeIfPresent(Bool.self, forKey: .skipShortLastWeek) ?? true
        shortLastWeekThreshold = try container.decodeIfPresent(Int.self, forKey: .shortLastWeekThreshold) ?? 3
        
        appStartDate = try container.decodeIfPresent(Date.self, forKey: .appStartDate)
        
        categories = try container.decodeIfPresent([CategoryItem].self, forKey: .categories) ?? [
            CategoryItem(id: "action", name: "行動習慣", colorName: "blue"),
            CategoryItem(id: "lifestyle", name: "生活習慣", colorName: "yellow"),
            CategoryItem(id: "none", name: "指定なし", colorName: "gray")
        ]
        
        // 古いデータには存在しない項目なので、無ければ 1(日曜日) を入れる
        weeklyReflectionWeekday = try container.decodeIfPresent(Int.self, forKey: .weeklyReflectionWeekday) ?? 1
    }
}


struct CategoryItem: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var colorName: String
    
    var color: Color {
        switch colorName {
        case "blue": return .blue
        case "teal": return .teal
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "indigo": return .indigo
        case "brown": return .brown
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .gray
        }
    }
}

struct DailyNote: Codable {
    var tasks: [Task] = []
    var keep: String = ""
    var problem: String = ""
    var reflection: String = ""
    var tryList: [Goal] = []
    var dismissedTaskTitles: [String] = []
}

struct Goal: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var categoryId: String
    var startDate: Date    // 実際に作成した日時（達成率の計算基準）
    var targetDate: Date   // いつの分として設定したか（UIの表示基準）
    
    // 新規作成時のイニシャライザ
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, categoryId: String = "none", startDate: Date = Date(), targetDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.categoryId = categoryId
        self.startDate = startDate
        // targetDateの指定がなければ、作成日（startDate）と同じにする
        self.targetDate = targetDate ?? startDate
    }
    
    // 保存データと紐づけるためのキー
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, categoryId, startDate, targetDate
    }
    
    // アプリ起動時に保存データを読み込む時の処理（後方互換性）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId) ?? "none"
        
        // 🌟 古いデータ（v1.0.1以前）がクラッシュしないように過去の日付を入れる
        let decodedStartDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date.distantPast
        startDate = decodedStartDate
        
        // 🌟 targetDateを持たない古いデータの場合は、自動的にstartDateと同じ値をセットする
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate) ?? decodedStartDate
    }
}

struct WeekData: Codable {
    var goals: [Goal] = []
    var keep: String = ""
    var problem: String = ""
    var tryList: [Goal] = []
    var reflection: String = ""
}

struct MonthData: Codable {
    var monthlyGoals: [Goal] = []
    var weeklyGoals: [Goal] = []
    var dailyGoals: [Goal] = []
    var keep: String = ""
    var problem: String = ""
    var tryList: [Goal] = []
    var reflection: String = ""
    var futureSelf: String = ""
    
    enum CodingKeys: String, CodingKey {
        case monthlyGoals, weeklyGoals, dailyGoals, reflection, keep, problem, tryList, futureSelf
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlyGoals = try container.decodeIfPresent([Goal].self, forKey: .monthlyGoals) ?? []
        weeklyGoals = try container.decodeIfPresent([Goal].self, forKey: .weeklyGoals) ?? []
        dailyGoals = try container.decodeIfPresent([Goal].self, forKey: .dailyGoals) ?? []
        keep = try container.decodeIfPresent(String.self, forKey: .keep) ?? ""
        problem = try container.decodeIfPresent(String.self, forKey: .problem) ?? ""
        tryList = try container.decodeIfPresent([Goal].self, forKey: .tryList) ?? []
        reflection = try container.decodeIfPresent(String.self, forKey: .reflection) ?? ""
        futureSelf = try container.decodeIfPresent(String.self, forKey: .futureSelf) ?? ""
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthlyGoals, forKey: .monthlyGoals)
        try container.encode(weeklyGoals, forKey: .weeklyGoals)
        try container.encode(dailyGoals, forKey: .dailyGoals)
        try container.encode(keep, forKey: .keep)
        try container.encode(problem, forKey: .problem)
        try container.encode(tryList, forKey: .tryList)
        try container.encode(reflection, forKey: .reflection)
        try container.encode(futureSelf, forKey: .futureSelf)
    }
}

enum TaskType: String, Codable, Equatable {
    case normal
    case dailyGoal
    case tryCarryOver
}

struct Task: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var isYearlyReflection: Bool
    var type: TaskType
    var categoryId: String
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, isYearlyReflection: Bool = false, type: TaskType = .normal, categoryId: String = "none") {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isYearlyReflection = isYearlyReflection
        self.type = type
        self.categoryId = categoryId
    }
}

struct SubTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct FutureVision: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var subTasks: [SubTask] = []
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, subTasks: [SubTask] = []) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.subTasks = subTasks
    }
    
    var progress: Double {
        guard !subTasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        let completed = subTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(subTasks.count)
    }
}
