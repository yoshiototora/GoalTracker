//
//  Models.swift
//  GoalTracker
//

import Foundation

struct AppSettings: Codable {
    var goalNotificationEnabled: Bool = false
    var goalNotificationTime: Date = Date()
    var reflectionNotificationEnabled: Bool = false
    var reflectionNotificationTime: Date = Date()
}

struct DailyNote: Codable {
    var tasks: [Task] = []
    var keep: String = ""
    var problem: String = ""
    var tryList: [String] = []
}

struct Goal: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct WeekData: Codable {
    var goals: [Goal] = []
    var keep: String = ""
    var problem: String = ""
    var tryList: [String] = []
    var reflection: String = ""
}

struct MonthData: Codable {
    var monthlyGoals: [Goal] = []
    var weeklyGoals: [Goal] = []
    var dailyGoals: [Goal] = []
    var keep: String = ""
    var problem: String = ""
    var tryList: [String] = []
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
        tryList = try container.decodeIfPresent([String].self, forKey: .tryList) ?? []
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

struct Task: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var isYearlyReflection: Bool
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, isYearlyReflection: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isYearlyReflection = isYearlyReflection
    }
}

// サブタスク用構造体
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

// 未来の自分（サブタスク対応版）
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

struct UserStats: Codable {
    var dailyStreak: Int = 0
    var lastCompletedDate: String = ""
    var monthlyReflectionStreak: Int = 0
    var lastReflectionMonth: String = ""
}
