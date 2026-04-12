//
//  Components.swift
//  GoalTracker
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
        .padding(8).frame(maxWidth: .infinity).background(Color(.systemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}


struct TextEditorView: View {
    let title: String; @Binding var text: String; var minHeight: CGFloat = 60; var placeholder: String = "入力..."
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextField(placeholder, text: $text, axis: .vertical).lineLimit(4...15).padding(8).background(Color(.systemGray6)).cornerRadius(8).frame(minHeight: minHeight, alignment: .top)
        }.padding(.vertical, 4)
    }
}

struct BulletInputSection: View {
    let title: String; var items: [String]; var placeholder: String = "..."
    var onUpdate: ([String]) -> Void
    @State private var t = ""; @State private var s = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.caption).foregroundColor(.gray); Spacer(); Button(action: { s = true }) { Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.blue) } }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 4) {
                        Text("・").font(.body).foregroundColor(.secondary); Text(items[index]).font(.body); Spacer()
                        Button(action: { var n = items; n.remove(at: index); onUpdate(n) }) { Image(systemName: "xmark.circle.fill").foregroundColor(Color.gray.opacity(0.5)) }
                    }.padding(.vertical, 8).padding(.horizontal, 12)
                }
                if items.isEmpty { Text(placeholder).font(.body).foregroundColor(Color(UIColor.placeholderText)).padding(12) }
            }.frame(maxWidth: .infinity, alignment: .topLeading).background(Color(.systemGray6)).cornerRadius(8).onTapGesture { s = true }
        }
        .alert("\(title)を追加", isPresented: $s) {
            TextField(placeholder, text: $t); Button("キャンセル", role: .cancel) { t = "" }
            Button("追加") { if !t.isEmpty { var n = items; n.append(t); onUpdate(n); t = "" } }
        }
    }
}

struct CalendarGridView: View {
    @ObservedObject var viewModel: GoalViewModel
    let displayDate: Date; @Binding var selectedDate: Date; @Binding var selectedTab: Int
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
                        .overlay(Text("\(Calendar.current.component(.day, from: d))").font(.caption).foregroundColor(isFut ? .gray : (rate(d) >= 0.4 ? .white : .primary)))
                        .simultaneousGesture(TapGesture(count: 2).onEnded { if !isFut { selectedDate = d; selectedTab = 1 } })
                        .simultaneousGesture(TapGesture(count: 1).onEnded { if !isFut { selectedDate = d } })
                } else { Color.clear }
            }
        }.padding()
    }
    
    func rate(_ d: Date) -> Double { viewModel.getDailyCompletionRate(for: d) }
    func getCol(_ d: Date) -> Color {
        let r = rate(d); let note = viewModel.getNote(for: d)
        let hasReflection = !note.keep.isEmpty || !note.problem.isEmpty || note.tryList.contains { !$0.isEmpty }
        if r == 0 && !hasReflection { return Color(.systemGray6) }
        if r == 0 { return Color.yellow.opacity(0.3) }
        switch r {
        case ..<0.4: return Color(red: 0.65, green: 0.9, blue: 0.65)
        case 0.4..<0.75: return Color(red: 0.3, green: 0.75, blue: 0.3)
        case 0.75..<1.0: return Color(red: 0.15, green: 0.55, blue: 0.15)
        default: return Color(red: 0.05, green: 0.35, blue: 0.15)
        }
    }
    func generateDays() -> [Date?] {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: displayDate)), let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let firstDay = cal.component(.weekday, from: start)
        var days: [Date?] = Array(repeating: nil, count: firstDay - 1)
        for i in 0..<range.count { if let d = cal.date(byAdding: .day, value: i, to: start) { days.append(d) } }
        return days
    }
}

struct LuxuriousCompletionEffect: View {
    let completedCount: Int
    
    // 💡 達成感を高めるメッセージ
    let messages = [
        "1年間の努力が結実しました！",
        "着実な一歩が未来を作りました！",
        "過去の自分を見事に超えました！",
        "継続は力なり、ですね！",
        "この素晴らしい軌跡を誇りに思いましょう！"
    ]
    @State private var randomMessage = ""
    
    // アニメーション用の状態
    @State private var showContent = false
    @State private var opacities: [Double] = Array(repeating: 0.0, count: 42)
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    
    var body: some View {
        ZStack {
            // 1. 緑のヒートマップ（画面を暗くする処理をなくし、明るさをキープ！）
            if completedCount >= 1 {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(0..<42, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.15, green: 0.55, blue: 0.15))
                            .aspectRatio(1, contentMode: .fit)
                            .opacity(opacities[index])
                    }
                }
                .padding(40)
            }
            
            // 2. すりガラス風の明るく上品なカードで文字を表示
            if completedCount >= 1 {
                VStack(spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundColor(.orange) // 達成感のある温かい色に
                        .scaleEffect(showContent ? 1.0 : 0.5)
                    
                    VStack(spacing: 12) {
                        Text("未来の自分に到達")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .tracking(2)
                        
                        Text(randomMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4) // 行間を少し開けて読みやすく
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                // 💡 ここがポイント：暗くせず、背景を美しくぼかすiOSネイティブの表現
                .background(.regularMaterial)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 10)
            }
        }
        .onAppear {
            randomMessage = messages.randomElement() ?? messages[0]
            
            if completedCount >= 1 {
                // ヒートマップのブロックアニメーション
                for i in 0..<42 {
                    withAnimation(.easeOut(duration: 0.5).delay(Double.random(in: 0...1.0))) {
                        opacities[i] = 1.0
                    }
                    withAnimation(.easeIn(duration: 1.0).delay(Double.random(in: 4.0...5.0))) {
                        opacities[i] = 0.0
                    }
                }
                
                // テキストカードのフェードイン
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    showContent = true
                }
                
                // 4.5秒後にゆっくりフェードアウト（十分に読む時間を確保）
                withAnimation(.easeIn(duration: 1.0).delay(4.5)) {
                    showContent = false
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct StreakBadgeView: View {
    let streak: Int
    var body: some View {
        if streak > 0 {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundColor(streak >= 7 ? .red : .orange)
                Text("\(streak)日連続達成中！").font(.subheadline).bold().foregroundColor(streak >= 7 ? .red : .orange)
                if streak >= 30 { Image(systemName: "crown.fill").foregroundColor(.yellow) } else if streak >= 7 { Image(systemName: "medal.fill").foregroundColor(.yellow) }
            }.padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1))).padding(.horizontal)
        }
    }
}
