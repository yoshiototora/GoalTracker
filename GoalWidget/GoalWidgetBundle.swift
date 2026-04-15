import WidgetKit
import SwiftUI

// MARK: - データ提供部分
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), tasks: [Task(title: "目標を確認", isCompleted: false)])
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

// MARK: - ウィジェットの見た目
struct GoalWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let uncompleted = entry.tasks.filter { !$0.isCompleted }

        switch family {
        case .accessoryRectangular:
            // 🟢 ロック画面（長方形）：2列にして横幅をフル活用！
            VStack(alignment: .leading, spacing: 2) {
                Text(uncompleted.isEmpty ? "🎉 今日のタスク完了！" : "未完了: \(uncompleted.count)件")
                    .font(.system(size: 12, weight: .bold))
                    .widgetAccentable()
                
                HStack(alignment: .top, spacing: 10) {
                    // 左列（1〜2件目）
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(uncompleted.prefix(2)) { task in
                            Text("• \(task.title)")
                                .font(.system(size: 10))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 右列（3〜4件目）空いている横のスペースを活用！
                    if uncompleted.count > 2 {
                        VStack(alignment: .leading, spacing: 2) {
                            let nextTasks = Array(uncompleted.dropFirst(2))
                            ForEach(nextTasks.prefix(2)) { task in
                                Text("• \(task.title)")
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
        case .accessoryInline:
            // 🟢 ロック画面（一行）
            let count = uncompleted.count
            Text(count == 0 ? "🎯 タスク完了" : "📝 残り: \(count)件")
            
        case .systemMedium:
            // 🟢 ホームウィジェット（中）：2列でタスクを最大8件表示
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // 🌟 変更：タイトルを未完了件数に変更！
                    Text(uncompleted.isEmpty ? "🎉 すべて完了！" : "未完了: \(uncompleted.count)件")
                        .font(.caption).bold().foregroundColor(.secondary)
                    Spacer()
                    Text("\(entry.tasks.filter{$0.isCompleted}.count)/\(entry.tasks.count)").font(.caption2).foregroundColor(.secondary)
                }
                
                if entry.tasks.isEmpty {
                    Text("タスクはありません").font(.caption).foregroundColor(.gray)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        // 左列（1〜4件目）
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(entry.tasks.prefix(4)) { task in
                                widgetTaskRow(task: task)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if entry.tasks.count > 4 {
                            Divider()
                            // 右列（5〜8件目）
                            VStack(alignment: .leading, spacing: 4) {
                                let nextTasks = Array(entry.tasks.dropFirst(4))
                                ForEach(nextTasks.prefix(4)) { task in
                                    widgetTaskRow(task: task)
                                }
                                if nextTasks.count > 4 {
                                    Text("...他 \(nextTasks.count - 4)件").font(.system(size: 9)).foregroundColor(.secondary).padding(.leading, 14)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer().frame(maxWidth: .infinity)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            
        default:
            // 🟢 ホームウィジェット（小）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // 🌟 変更：タイトルを未完了件数に変更！
                    Text(uncompleted.isEmpty ? "🎉 すべて完了！" : "未完了: \(uncompleted.count)件")
                        .font(.caption).bold().foregroundColor(.secondary)
                }
                if entry.tasks.isEmpty {
                    Text("タスクはありません").font(.caption).foregroundColor(.gray)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entry.tasks.prefix(4)) { task in
                            widgetTaskRow(task: task)
                        }
                    }
                }
                Spacer()
            }
            .padding(10)
        }
    }
    
    // ウィジェット用のタスク行コンポーネント
    @ViewBuilder
    private func widgetTaskRow(task: Task) -> some View {
        HStack(spacing: 4) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .gray)
                .font(.system(size: 10))
            Text(task.title)
                .font(.system(size: 10))
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .gray : .primary)
                .lineLimit(1)
        }
    }
}

// MARK: - ウィジェット本体とBundle
struct GoalWidget: Widget {
    let kind: String = "GoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GoalWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(UIColor.systemBackground)
                }
        }
        .configurationDisplayName("HabitSpark")
        .description("今日のタスクをすばやく確認できます。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct GoalWidgetBundle: WidgetBundle {
    var body: some Widget {
        GoalWidget()
    }
}
