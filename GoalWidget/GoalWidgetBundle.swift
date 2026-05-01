import WidgetKit
import SwiftUI

// MARK: - データ提供部分
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [Task(title: String(localized: "目標を確認"), isCompleted: false)])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let tasks = fetchTodayTasks()
        completion(SimpleEntry(date: Date(), tasks: tasks))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let tasks = fetchTodayTasks()
        let entry = SimpleEntry(date: Date(), tasks: tasks)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
    
    private func fetchTodayTasks() -> [Task] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: Date())
        return CoreDataService.shared.fetchTasks(for: dateKey)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let tasks: [Task]
}

struct GoalWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        let uncompleted = entry.tasks.filter { !$0.isCompleted }
        let total = entry.tasks.count
        let completed = total - uncompleted.count
        let progress = total > 0 ? Double(completed) / Double(total) : 0.0
        
        let displayTasks = entry.tasks.sorted {
            if $0.isCompleted != $1.isCompleted {
                return !$0.isCompleted && $1.isCompleted
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "target").font(.system(size: 10))
                    Text(uncompleted.isEmpty ? String(localized: "完了！") : String(localized: "未完了: \(uncompleted.count)"))
                        .font(.system(size: 10, weight: .bold))
                }
                .widgetAccentable()
                .padding(.bottom, 2)
                
                VStack(alignment: .leading, spacing: 1) {
                    if uncompleted.count <= 3 {
                        ForEach(uncompleted) { task in widgetTaskRow(task: task, fontSize: 11) }
                    } else {
                        ForEach(uncompleted.prefix(2)) { task in widgetTaskRow(task: task, fontSize: 11) }
                        Text(String(localized: "...他 \(uncompleted.count - 2)件"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.leading, 14)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .accessoryInline:
            Text(uncompleted.isEmpty ? String(localized: "タスク完了") : String(localized: "残り: \(uncompleted.count)件"))
            
        case .systemMedium:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom) {
                    Text(entry.date, format: .dateTime.month().day().weekday())
                        .font(.headline).bold()
                    Spacer()
                    Text(uncompleted.isEmpty ? String(localized: "すべて完了！") : String(localized: "残り \(uncompleted.count)件"))
                        .font(.subheadline).bold()
                        .foregroundColor(uncompleted.isEmpty ? .green : .blue)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule().fill(uncompleted.isEmpty ? Color.green : Color.blue)
                            .frame(width: max(geo.size.width * CGFloat(progress), 0))
                    }
                }
                .frame(height: 6)
                
                if displayTasks.isEmpty {
                    Spacer()
                    Text("今日のタスクはありません").font(.caption).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(displayTasks.prefix(3)) { task in widgetTaskRow(task: task) }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        
                        if displayTasks.count > 3 {
                            VStack(alignment: .leading, spacing: 6) {
                                let nextTasks = Array(displayTasks.dropFirst(3))
                                ForEach(nextTasks.prefix(3)) { task in widgetTaskRow(task: task) }
                                if nextTasks.count > 3 {
                                    Text(String(localized: "...他 \(nextTasks.count - 3)件")).font(.system(size: 10)).foregroundColor(.secondary).padding(.leading, 14)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.date, format: .dateTime.day().weekday())
                            .font(.headline).bold()
                        Text(uncompleted.isEmpty ? String(localized: "完了！") : String(localized: "残り \(uncompleted.count)件"))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        Circle().trim(from: 0, to: CGFloat(progress))
                            .stroke(uncompleted.isEmpty ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 30, height: 30)
                }
                
                Divider().padding(.vertical, 2)
                
                if displayTasks.isEmpty {
                    Spacer()
                    Text("予定なし").font(.caption).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        if displayTasks.count <= 3 {
                            ForEach(displayTasks) { task in widgetTaskRow(task: task) }
                        } else {
                            ForEach(displayTasks.prefix(2)) { task in widgetTaskRow(task: task) }
                            Text(String(localized: "...他 \(displayTasks.count - 2)件"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
        }
    }
    
    @ViewBuilder
    private func widgetTaskRow(task: Task, fontSize: CGFloat = 11) -> some View {
        HStack(spacing: 4) {
            if task.type == .tryCarryOver {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(task.isCompleted ? .gray.opacity(0.6) : .orange)
                    .font(.system(size: fontSize - 1))
            }
            Text(task.title)
                .font(.system(size: fontSize, weight: task.isCompleted ? .regular : .medium))
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .lineLimit(1)
        }
    }
    
    struct GoalWidget: Widget {
        let kind: String = "GoalWidget"
        
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: Provider()) { entry in
                GoalWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(UIColor.systemBackground)
                    }
            }
            .configurationDisplayName(String(localized: "HabitSpark"))
            .description(String(localized: "今日のタスクの進捗をすばやく確認できます。"))
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        }
    }
    
    @main
    struct GoalWidgetBundle: WidgetBundle {
        var body: some Widget {
            GoalWidget()
        }
    }
}
