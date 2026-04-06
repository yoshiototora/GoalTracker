//
//  Models.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/06.
//

import Foundation

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
    var reflection: String = ""
}

struct MonthData: Codable {
    var monthlyGoals: [Goal] = []
    var weeklyGoals: [Goal] = []
    var dailyGoals: [Goal] = []
    var reflection: String = ""
    
    enum CodingKeys: String, CodingKey {
        case monthlyGoals, weeklyGoals, dailyGoals, reflection
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthlyGoals = try container.decodeIfPresent([Goal].self, forKey: .monthlyGoals) ?? []
        weeklyGoals = try container.decodeIfPresent([Goal].self, forKey: .weeklyGoals) ?? []
        dailyGoals = try container.decodeIfPresent([Goal].self, forKey: .dailyGoals) ?? []
        reflection = try container.decodeIfPresent(String.self, forKey: .reflection) ?? ""
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monthlyGoals, forKey: .monthlyGoals)
        try container.encode(weeklyGoals, forKey: .weeklyGoals)
        try container.encode(dailyGoals, forKey: .dailyGoals)
        try container.encode(reflection, forKey: .reflection)
    }
}

struct Task: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool = false
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct AppSettings: Codable {
    var goalNotificationEnabled: Bool = false
    var goalNotificationTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    
    var reflectionNotificationEnabled: Bool = false
    var reflectionNotificationTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
}
