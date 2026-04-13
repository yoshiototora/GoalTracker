//
//  CoreDataService.swift
//  GoalTracker
//

import Foundation
import CoreData

class CoreDataService {
    static let shared = CoreDataService()
    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "GoalTrackerModel")
        container.loadPersistentStores { description, error in
            if let error = error { fatalError("CoreDataエラー: \(error.localizedDescription)") }
        }
    }
    
    func saveContext() {
        if container.viewContext.hasChanges { _ = try? container.viewContext.save() }
    }

    // MARK: - Daily (Task & Note)
    func fetchTasks(for dateKey: String) -> [Task] {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", dateKey)
        if let entities = try? container.viewContext.fetch(request) {
            return entities.map {
                Task(id: $0.id ?? UUID(), title: $0.title ?? "", isCompleted: $0.isCompleted, isYearlyReflection: $0.isYearlyReflection, type: TaskType(rawValue: $0.type ?? "normal") ?? .normal, categoryId: $0.category ?? "none")
            }
        }
        return []
    }
    
    func saveTasks(_ tasks: [Task], for dateKey: String) {
        let context = container.viewContext
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", dateKey)
        
        if let existingEntities = try? context.fetch(request) {
            for entity in existingEntities { context.delete(entity) }
        }
        
        for task in tasks {
            let entity = TaskEntity(context: context)
            entity.id = task.id; entity.title = task.title; entity.isCompleted = task.isCompleted; entity.isYearlyReflection = task.isYearlyReflection; entity.type = task.type.rawValue; entity.dateKey = dateKey
            entity.category = task.categoryId
        }
        saveContext()
    }
    
    func fetchDailyNote(for dateKey: String) -> DailyNote {
        let request: NSFetchRequest<DailyNoteEntity> = DailyNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", dateKey)
        if let entity = try? container.viewContext.fetch(request).first {
            var tryList: [Goal] = []
            if let data = entity.tryListData, let decoded = try? JSONDecoder().decode([Goal].self, from: data) { tryList = decoded }
            var note = DailyNote(keep: entity.keep ?? "", problem: entity.problem ?? "", tryList: tryList)
            
            // 💡 追加：保存された振り返りを読み込む
            note.reflection = entity.reflection ?? ""
            
            note.tasks = fetchTasks(for: dateKey)
            return note
        }
        return DailyNote()
    }
    
    func saveDailyNote(_ note: DailyNote, for dateKey: String) {
        let context = container.viewContext
        let request: NSFetchRequest<DailyNoteEntity> = DailyNoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", dateKey)
        let entity = (try? context.fetch(request).first) ?? DailyNoteEntity(context: context)
        
        entity.dateKey = dateKey; entity.keep = note.keep; entity.problem = note.problem
        
        // 💡 追加：振り返りを保存する
        entity.reflection = note.reflection
        
        if let encoded = try? JSONEncoder().encode(note.tryList) { entity.tryListData = encoded }
        saveTasks(note.tasks, for: dateKey)
        saveContext()
    }

    // MARK: - Weekly
    func fetchWeekData(for key: String) -> WeekData {
        let request: NSFetchRequest<WeekDataEntity> = WeekDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", key)
        if let entity = try? container.viewContext.fetch(request).first {
            var w = WeekData()
            w.keep = entity.keep ?? ""; w.problem = entity.problem ?? ""; w.reflection = entity.reflection ?? ""
            if let data = entity.tryListData, let dec = try? JSONDecoder().decode([Goal].self, from: data) { w.tryList = dec }
            if let data = entity.goalsData, let dec = try? JSONDecoder().decode([Goal].self, from: data) { w.goals = dec }
            return w
        }
        return WeekData()
    }
    
    func saveWeekData(_ data: WeekData, for key: String) {
        let context = container.viewContext
        let request: NSFetchRequest<WeekDataEntity> = WeekDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", key)
        let entity = (try? context.fetch(request).first) ?? WeekDataEntity(context: context)
        
        entity.dateKey = key; entity.keep = data.keep; entity.problem = data.problem; entity.reflection = data.reflection
        if let enc = try? JSONEncoder().encode(data.tryList) { entity.tryListData = enc }
        if let enc = try? JSONEncoder().encode(data.goals) { entity.goalsData = enc }
        saveContext()
    }

    // MARK: - Monthly
    func fetchMonthData(for key: String) -> MonthData {
        let request: NSFetchRequest<MonthDataEntity> = MonthDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", key)
        if let entity = try? container.viewContext.fetch(request).first {
            var m = MonthData()
            m.keep = entity.keep ?? ""; m.problem = entity.problem ?? ""; m.reflection = entity.reflection ?? ""
            if let data = entity.tryListData, let dec = try? JSONDecoder().decode([Goal].self, from: data) { m.tryList = dec }
            if let data = entity.monthlyGoalsData, let dec = try? JSONDecoder().decode([Goal].self, from: data) { m.monthlyGoals = dec }
            if let data = entity.weeklyGoalsData, let dec = try? JSONDecoder().decode([Goal].self, from: data) { m.weeklyGoals = dec }
            if let data = entity.dailyGoalsData, let dec = try? JSONDecoder().decode([Goal].self, from: data) { m.dailyGoals = dec }
            return m
        }
        return MonthData()
    }
    
    func saveMonthData(_ data: MonthData, for key: String) {
        let context = container.viewContext
        let request: NSFetchRequest<MonthDataEntity> = MonthDataEntity.fetchRequest()
        request.predicate = NSPredicate(format: "dateKey == %@", key)
        let entity = (try? context.fetch(request).first) ?? MonthDataEntity(context: context)
        
        entity.dateKey = key; entity.keep = data.keep; entity.problem = data.problem; entity.reflection = data.reflection
        if let enc = try? JSONEncoder().encode(data.tryList) { entity.tryListData = enc }
        if let enc = try? JSONEncoder().encode(data.monthlyGoals) { entity.monthlyGoalsData = enc }
        if let enc = try? JSONEncoder().encode(data.weeklyGoals) { entity.weeklyGoalsData = enc }
        if let enc = try? JSONEncoder().encode(data.dailyGoals) { entity.dailyGoalsData = enc }
        saveContext()
    }

    // MARK: - Future Vision
    func fetchFutureVisions() -> [FutureVision] {
        let request: NSFetchRequest<FutureVisionEntity> = FutureVisionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        if let entities = try? container.viewContext.fetch(request) {
            return entities.map { e in
                var subs: [SubTask] = []
                if let data = e.subTasksData, let dec = try? JSONDecoder().decode([SubTask].self, from: data) { subs = dec }
                return FutureVision(id: e.id ?? UUID(), title: e.title ?? "", isCompleted: e.isCompleted, subTasks: subs)
            }
        }
        return []
    }
    
    func saveFutureVisions(_ visions: [FutureVision]) {
        let context = container.viewContext
        let request: NSFetchRequest<FutureVisionEntity> = FutureVisionEntity.fetchRequest()
        
        if let existingEntities = try? context.fetch(request) {
            for entity in existingEntities { context.delete(entity) }
        }
        
        for (index, v) in visions.enumerated() {
            let entity = FutureVisionEntity(context: context)
            entity.id = v.id; entity.title = v.title; entity.isCompleted = v.isCompleted; entity.orderIndex = Int16(index)
            if let enc = try? JSONEncoder().encode(v.subTasks) { entity.subTasksData = enc }
        }
        saveContext()
    }
}
