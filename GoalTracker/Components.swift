//
//  Components.swift
//  GoalTracker
//
//  Created by 吉岡晃基　 on 2026/04/06.
//

import SwiftUI

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

struct ReflectionAchievementCard: View {
    let title: String; let rate1: Double; let rate2: Double?; let rate3: Double?; let color2: Color; let color3: Color
    var body: some View {
        let count = (rate3 != nil ? 3.0 : (rate2 != nil ? 2.0 : 1.0))
        let total = (rate1 + (rate2 ?? 0) + (rate3 ?? 0)) / count
        VStack(spacing: 12) {
            Text(title).font(.subheadline).foregroundColor(.secondary).bold()
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(total * 100))%").font(.system(size: 40, weight: .bold, design: .rounded))
                    HStack(spacing: 6) { Circle().fill(Color.green).frame(width: 10, height: 10); Text("日次タスク: \(Int(rate1 * 100))%").font(.caption).foregroundColor(.gray) }
                    if let r2 = rate2 { HStack(spacing: 6) { Circle().fill(color2).frame(width: 10, height: 10); Text("週の目標: \(Int(r2 * 100))%").font(.caption).foregroundColor(.gray) } }
                    if let r3 = rate3 { HStack(spacing: 6) { Circle().fill(color3).frame(width: 10, height: 10); Text("月の目標: \(Int(r3 * 100))%").font(.caption).foregroundColor(.gray) } }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 10)
                    Circle().trim(from: 0, to: rate1 / count).stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                    if let r2 = rate2 { Circle().trim(from: rate1 / count, to: (rate1 + r2) / count).stroke(color2, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90)) }
                    if let r2 = rate2, let r3 = rate3 { Circle().trim(from: (rate1 + r2) / count, to: (rate1 + r2 + r3) / count).stroke(color3, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90)) }
                }.frame(width: 80, height: 80)
            }
        }.padding().background(Color(.systemBackground)).cornerRadius(15).shadow(radius: 2).padding(.horizontal)
    }
}

struct CompositeSummaryCard: View {
    let title: String; let rate1: Double; let rate2: Double?; let rate3: Double?; let color2: Color; let color3: Color
    var body: some View {
        let count = (rate3 != nil ? 3.0 : (rate2 != nil ? 2.0 : 1.0))
        let total = (rate1 + (rate2 ?? 0) + (rate3 ?? 0)) / count
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(total * 100))%").font(.headline).bold()
                    HStack(spacing: 4) { Circle().fill(Color.green).frame(width: 6, height: 6); Text("日次: \(Int(rate1 * 100))%").font(.system(size: 9)).foregroundColor(.gray) }
                    if let r2 = rate2 { HStack(spacing: 4) { Circle().fill(color2).frame(width: 6, height: 6); Text("週次: \(Int(r2 * 100))%").font(.system(size: 9)).foregroundColor(.gray) } }
                    if let r3 = rate3 {
                        HStack(spacing: 4) { Circle().fill(color3).frame(width: 6, height: 6); Text("月次: \(Int(r3 * 100))%").font(.system(size: 9)).foregroundColor(.gray) }
                    } else {
                        HStack(spacing: 4) { Circle().fill(Color.clear).frame(width: 6, height: 6); Text(" ").font(.system(size: 9)) }
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 5)
                    Circle().trim(from: 0, to: rate1 / count).stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                    if let r2 = rate2 { Circle().trim(from: rate1 / count, to: (rate1 + r2) / count).stroke(color2, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)) }
                    if let r2 = rate2, let r3 = rate3 { Circle().trim(from: (rate1 + r2) / count, to: (rate1 + r2 + r3) / count).stroke(color3, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)) }
                }.frame(width: 35, height: 35)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

struct GoalListSection: View {
    let title: String; let iconColor: Color; var goals: [Goal]; var showCheckboxes: Bool; var onUpdate: ([Goal]) -> Void; var onCopy: (() -> Void)? = nil
    @State private var temp = ""; @State private var show = false
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "circle.fill").foregroundColor(iconColor).font(.system(size: 10))
                Text(title).font(.caption).bold().foregroundColor(.primary)
                Spacer()
                if let onCopy = onCopy { Button(action: onCopy) { Image(systemName: "doc.on.clipboard").font(.system(size: 12)) }.padding(.trailing, 5) }
                Button(action: { show = true }) { Image(systemName: "plus").font(.system(size: 12, weight: .bold)) }
            }
            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                HStack {
                    if showCheckboxes {
                        Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(goal.isCompleted ? .green : .gray)
                            .onTapGesture {
                                var newGoals = goals
                                newGoals[index].isCompleted.toggle()
                                onUpdate(newGoals)
                            }
                    }
                    else { Text("・").foregroundColor(iconColor) }
                    Text(goal.title).font(.subheadline).strikethrough(showCheckboxes && goal.isCompleted); Spacer()
                    Button(action: {
                        var newGoals = goals
                        newGoals.remove(at: index)
                        onUpdate(newGoals)
                    }) { Image(systemName: "xmark.circle").foregroundColor(.gray) }
                }.padding(.vertical, 1)
            }
        }.padding(10).background(Color(.systemBackground)).cornerRadius(8).shadow(radius: 1)
        .alert("追加", isPresented: $show) {
            TextField("...", text: $temp); Button("キャンセル", role: .cancel) { temp = "" }; Button("追加") { if !temp.isEmpty { var n = goals; n.append(Goal(title: temp)); onUpdate(n); temp = "" } }
        }
    }
}

// 🌟 修正1：TextEditorViewに placeholder を追加
struct TextEditorView: View {
    let title: String; @Binding var text: String; var minHeight: CGFloat = 60
    var placeholder: String = "入力..." // 👈 デフォルト値を追加
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.gray)
            // 👈 "入力..." の代わりに placeholder 変数を使用するように変更
            TextField(placeholder, text: $text, axis: .vertical).lineLimit(4...15).padding(8).background(Color(.systemGray6)).cornerRadius(8).frame(minHeight: minHeight, alignment: .top)
        }.padding(.vertical, 4)
    }
}

struct BulletInputSection: View {
    let title: String
    var items: [String]
    var placeholder: String = "..."
    var onUpdate: ([String]) -> Void
    
    @State private var t = ""
    @State private var s = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 🌟 タイトルと＋ボタン
            HStack {
                Text(title).font(.caption).foregroundColor(.gray)
                Spacer()
                Button(action: { s = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // 🌟 追加されたTryを1つのグレーの四角の中にまとめて表示
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 4) {
                        Text("・")
                            .font(.body)
                            .foregroundColor(.blue)
                        
                        Text(item)
                            .font(.body)
                        
                        Spacer()
                        
                        // 削除ボタン
                        Button(action: {
                            var n = items
                            n.remove(at: index)
                            onUpdate(n)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.gray.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                
                // 🌟 Tryが空のときはプレースホルダーを表示
                if items.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            // 👇 追加：透明な余白部分も含めてタップを検知させるおまじない
            .contentShape(Rectangle())
            // 👇 追加：グレーの箱全体をタップした時も入力アラートを出す
            .onTapGesture {
                s = true
            }
        }
        // 🌟 ポップアップ（アラート）での入力画面
        .alert("\(title)を追加", isPresented: $s) {
            TextField(placeholder, text: $t)
            Button("追加") {
                if !t.isEmpty {
                    var n = items
                    n.append(t)
                    onUpdate(n)
                    t = ""
                }
            }
            Button("キャンセル", role: .cancel) { t = "" }
        }
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
                        // 🌟 修正: 40%以上(中くらいの緑以上)達成したら文字を白にする
                        .overlay(Text("\(Calendar.current.component(.day, from: d))").font(.caption).foregroundColor(isFut ? .gray : (rate(d) >= 0.4 ? .white : .primary)))
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
    
    // 🌟 修正: タスクが3つの時(33%と67%)でも色がハッキリ分かれるように閾値を調整
    func getCol(_ d: Date) -> Color {
        let r = rate(d)
        let note = dataManager.getNote(for: d)
        let hasReflection = !note.keep.isEmpty || !note.problem.isEmpty || note.tryList.contains { !$0.isEmpty }
        
        if r == 0 && !hasReflection { return Color(.systemGray6) } // 何もしていない日
        if r == 0 { return Color.yellow.opacity(0.3) } // 振り返りのみ
        
        switch r {
        case ..<0.4:
            // タスク1/3(33%)や1/4(25%)など
            return Color(red: 0.65, green: 0.9, blue: 0.65) // 薄い緑
        case 0.4..<0.75:
            // タスク2/3(67%)や1/2(50%)など
            return Color(red: 0.3, green: 0.75, blue: 0.3) // 中くらいの緑
        case 0.75..<1.0:
            // タスク3/4(75%)や4/5(80%)など
            return Color(red: 0.15, green: 0.55, blue: 0.15) // 濃い緑
        default:
            // 100%達成！
            return Color(red: 0.05, green: 0.35, blue: 0.15) // 深緑
        }
    }
    
    func generateDays() -> [Date?] {
        let cal = Calendar.current; let start = cal.date(from: cal.dateComponents([.year, .month], from: displayDate))!; let range = cal.range(of: .day, in: .month, for: start)!; let firstDay = cal.component(.weekday, from: start)
        var days: [Date?] = Array(repeating: nil, count: firstDay - 1); for i in 0..<range.count { days.append(cal.date(byAdding: .day, value: i, to: start)!) }; return days
    }
}
