import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct TextEditorView: View {
    let title: LocalizedStringKey; @Binding var text: String; var minHeight: CGFloat = 100; var placeholder: LocalizedStringKey = "入力..."
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).bold().foregroundColor(.secondary)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(5...)
                .padding(12)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .animation(.easeInOut(duration: 0.2), value: text)
        }.padding(.vertical, 4)
    }
}

struct ReflectionAchievementCard: View {
    let title: LocalizedStringKey; let rate1: Double; let rate2: Double?; let rate3: Double?; let color2: Color; let color3: Color
    let comparisonText: String?; let totalDoneCount: Int; let tryDoneCount: Int
    
    var body: some View {
        // 🌟 修正: 非nilの達成率だけを分母にする(AchievementMath参照)
        let ringItems = AchievementMath.validPairs([(rate: rate1, value: Color.green), (rate: rate2, value: color2), (rate: rate3, value: color3)])
        let segments = AchievementMath.segmentBounds([rate1, rate2, rate3])
        let total = AchievementMath.average([rate1, rate2, rate3])

        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.subheadline).foregroundColor(.secondary).bold()
                    Text("\(Int(total * 100))%").font(.system(size: 44, weight: .black, design: .rounded))
                    if let trend = comparisonText {
                        let isPositive = trend.contains("＋") || trend.contains("+")
                        Text(trend).font(.caption.bold()).foregroundColor(isPositive ? .orange : .secondary).padding(.horizontal, 10).padding(.vertical, 4).background(isPositive ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1)).cornerRadius(20).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.1), lineWidth: 12)
                    ForEach(0..<segments.count, id: \.self) { i in
                        Circle().trim(from: segments[i].from, to: segments[i].to).stroke(ringItems[i].value, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                    }
                    Image(systemName: total >= 0.8 ? "crown.fill" : (total >= 0.5 ? "star.fill" : "sparkles")).font(.title2).foregroundColor(total >= 0.8 ? .yellow : .orange.opacity(0.5))
                }.frame(width: 90, height: 90)
            }
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading) { Text("完了タスク").font(.caption2).foregroundColor(.secondary); Text("\(totalDoneCount)個").font(.headline).bold() }
                Divider().frame(height: 30)
                VStack(alignment: .leading) { Text("Tryの実行").font(.caption2).foregroundColor(.secondary); Text("\(tryDoneCount)回").font(.headline).bold().foregroundColor(.blue) }
                Spacer()
                Text(total >= 0.8 ? String(localized: "最高のペース") : (total >= 0.5 ? String(localized: "いい調子です") : String(localized: "一歩ずつ進もう"))).font(.caption2.bold()).foregroundColor(.secondary).padding(.horizontal, 10).padding(.vertical, 6).background(Color(.systemGray6)).cornerRadius(8)
            }
        }.padding(20).background(Color(.systemBackground)).cornerRadius(20).shadow(color: .black.opacity(0.05), radius: 10, y: 5).padding(.horizontal)
    }
}

struct CompositeSummaryCard: View {
    let title: LocalizedStringKey; let rate1: Double; let rate2: Double?; let rate3: Double?; let color2: Color; let color3: Color
    let comparisonText: String?
    var body: some View {
        // 🌟 修正: 非nilの達成率だけを分母にする(AchievementMath参照)
        let ringItems = AchievementMath.validPairs([(rate: rate1, value: Color.green), (rate: rate2, value: color2), (rate: rate3, value: color3)])
        let segments = AchievementMath.segmentBounds([rate1, rate2, rate3])
        let total = AchievementMath.average([rate1, rate2, rate3])
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(.secondary).bold().lineLimit(1)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(total * 100))%").font(.system(size: 28, weight: .bold, design: .rounded))
                    if let comp = comparisonText { let isPositive = comp.contains("＋") || comp.contains("+"); Text(comp).font(.system(size: 10, weight: .bold)).foregroundColor(isPositive ? .orange : .secondary).lineLimit(1).minimumScaleFactor(0.7) }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 6)
                    ForEach(0..<segments.count, id: \.self) { i in
                        Circle().trim(from: segments[i].from, to: segments[i].to).stroke(ringItems[i].value, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                    }
                }.frame(width: 40, height: 40)
            }
            HStack(spacing: 8) {
                HStack(spacing: 4) { Circle().fill(Color.green).frame(width: 6, height: 6); Text("\(Int(rate1 * 100))%").font(.system(size: 11)).foregroundColor(.secondary).bold() }
                if let r2 = rate2 { HStack(spacing: 4) { Circle().fill(color2).frame(width: 6, height: 6); Text("\(Int(r2 * 100))%").font(.system(size: 11)).foregroundColor(.secondary).bold() } }
                if let r3 = rate3 { HStack(spacing: 4) { Circle().fill(color3).frame(width: 6, height: 6); Text("\(Int(r3 * 100))%").font(.system(size: 11)).foregroundColor(.secondary).bold() } }
            }
        }.padding(12).frame(maxWidth: .infinity).background(Color(.systemBackground)).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

struct CalendarGridView: View {
    @ObservedObject var viewModel: GoalViewModel
    let displayDate: Date; @Binding var selectedDate: Date; @Binding var selectedTab: Int
    let cols = Array(repeating: GridItem(.flexible()), count: 7)
    
    private var firstDisplayWeekday: Int {
        (viewModel.appSettings.weeklyReflectionWeekday % 7) + 1
    }
    
    var weekdays: [String] {
        let all = [String(localized: "日"), String(localized: "月"), String(localized: "火"), String(localized: "水"), String(localized: "木"), String(localized: "金"), String(localized: "土")]
        return (0..<7).map { all[(firstDisplayWeekday - 1 + $0) % 7] }
    }
    
    var body: some View {
        let days = generateDays()
        let today = Calendar.current.startOfDay(for: Date())
        let start = viewModel.appSettings.appStartDate.map { Calendar.current.startOfDay(for: $0) } ?? Date.distantPast
        
        VStack(spacing: 8) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day).font(.caption).bold().foregroundColor(day == String(localized: "日") ? .red : (day == String(localized: "土") ? .blue : .secondary)).frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(0..<days.count, id: \.self) { i in
                    if let d = days[i] {
                        let isSel = Calendar.current.isDate(d, inSameDayAs: selectedDate)
                        let isFut = d > today
                        let isBeforeStart = Calendar.current.startOfDay(for: d) < start
                        let isDisabled = isFut || isBeforeStart
                        let isStartDay = viewModel.appSettings.appStartDate != nil && Calendar.current.isDate(d, inSameDayAs: start)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isDisabled ? Color(.systemGray6) : getCol(d))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSel ? Color.blue : Color.clear, lineWidth: isSel ? 3 : 0))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                ZStack {
                                    Text("\(Calendar.current.component(.day, from: d))")
                                        .font(.caption)
                                        .foregroundColor(isDisabled ? .gray : dayTextColor(for: d))
                                    
                                    if isStartDay {
                                        VStack {
                                            HStack {
                                                Spacer()
                                                Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(.yellow).padding(4)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                            )
                            .simultaneousGesture(TapGesture(count: 2).onEnded { if !isDisabled { selectedDate = d; selectedTab = 1 } })
                            .simultaneousGesture(TapGesture(count: 1).onEnded { if !isDisabled { selectedDate = d } })
                    } else { Color.clear }
                }
            }
        }.padding()
    }
    
    func rate(_ d: Date) -> Double { viewModel.getDailyCompletionRate(for: d) }

    // 🌟 修正: ダークモードのコントラスト対応。
    // 達成率が0より大きく0.4未満のセルは背景が「固定の薄緑」(getColを参照。両モード共通)のため、
    // .primary(ダークモードで白)だと読みにくい。背景色に合わせて黒文字に固定する。
    // 率0のセルは背景がシステム色/半透明の黄でモードに追従するため、従来どおり.primaryを使う。
    func dayTextColor(for d: Date) -> Color {
        let r = rate(d)
        if r >= 0.4 { return .white }
        if r > 0 { return .black }
        return .primary
    }
    func getCol(_ d: Date) -> Color {
        let r = rate(d); let note = viewModel.getNote(for: d)
        let hasReflection = !note.keep.isEmpty || !note.problem.isEmpty || note.tryList.contains { !$0.title.isEmpty }
        if r == 0 && !hasReflection { return Color(.systemGray6) }
        if r == 0 { return Color.yellow.opacity(0.3) }
        switch r { case ..<0.4: return Color(red: 0.65, green: 0.9, blue: 0.65); case 0.4..<0.75: return Color(red: 0.3, green: 0.75, blue: 0.3); case 0.75..<1.0: return Color(red: 0.15, green: 0.55, blue: 0.15); default: return Color(red: 0.05, green: 0.35, blue: 0.15) }
    }
    
    func generateDays() -> [Date?] {
        var cal = Calendar.current
        cal.firstWeekday = firstDisplayWeekday
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: displayDate)), let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        
        let weekday = cal.component(.weekday, from: start)
        let emptyCount = (weekday - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: emptyCount)
        
        for i in 0..<range.count { if let d = cal.date(byAdding: .day, value: i, to: start) { days.append(d) } }; return days
    }
}

struct LuxuriousCompletionEffect: View {
    let completedCount: Int; let messages = [String(localized: "素晴らしい軌跡を誇りに思いましょう"), String(localized: "継続は力なり、ですね")]
    @State private var showContent = false; @State private var opacities: [Double] = Array(repeating: 0.0, count: 42)
    var body: some View {
        ZStack {
            if completedCount >= 1 { LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) { ForEach(0..<42, id: \.self) { index in RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.15, green: 0.55, blue: 0.15)).aspectRatio(1, contentMode: .fit).opacity(opacities[index]) } }.padding(40) }
            if completedCount >= 1 { VStack(spacing: 20) { Image(systemName: "sparkles").font(.system(size: 40, weight: .regular)).foregroundColor(.orange).scaleEffect(showContent ? 1.0 : 0.5); VStack(spacing: 12) { Text("未来の自分に到達").font(.title2.bold()).foregroundColor(.primary).tracking(2); Text(messages[0]).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).lineSpacing(4) } }.padding(.horizontal, 32).padding(.vertical, 28).background(.regularMaterial).cornerRadius(20).shadow(color: Color.black.opacity(0.1), radius: 10, y: 5).opacity(showContent ? 1.0 : 0.0).offset(y: showContent ? 0 : 10) }
        }
        .onAppear {
            if completedCount >= 1 {
                for i in 0..<42 { withAnimation(.easeOut(duration: 0.5).delay(Double.random(in: 0...1.0))) { opacities[i] = 1.0 }; withAnimation(.easeIn(duration: 1.0).delay(Double.random(in: 4.0...5.0))) { opacities[i] = 0.0 } }
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) { showContent = true }; withAnimation(.easeIn(duration: 1.0).delay(4.5)) { showContent = false }
            }
        }.allowsHitTesting(false)
    }
}

struct StreakBadgeView: View {
    let streak: Int
    var body: some View {
        if streak > 0 {
            HStack(spacing: 8) { Image(systemName: "flame.fill").foregroundColor(streak >= 7 ? .red : .orange); Text(String(localized: "\(streak)日連続達成中")).font(.subheadline).bold().foregroundColor(streak >= 7 ? .red : .orange); if streak >= 30 { Image(systemName: "crown.fill").foregroundColor(.yellow) } else if streak >= 7 { Image(systemName: "medal.fill").foregroundColor(.yellow) } }.padding(.horizontal, 16).padding(.vertical, 10).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1))).padding(.horizontal)
        }
    }
}

struct InlineHintCard: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.fill").foregroundColor(.orange)
                    Text(title).font(.headline).foregroundColor(.primary)
                    Spacer()
                    Button(action: { withAnimation(.easeInOut) { isShowing = false } }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).font(.system(size: 20))
                    }
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
