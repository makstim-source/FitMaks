import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.dismiss) var dismiss
    var allFoodEntries: [FoodEntry]
    var allSetups: [DailySetup]
    var baseCalories: Double
    var baseProtein: Double
    @State private var weeklySteps: [String: Double] = [:]
    @State private var showBars = false
    @State private var weekOffset = 0
    
    var dateRangeText: String {
        if weekOffset == 0 { return "This Week" }
        if weekOffset == 1 { return "Last Week" }
        return "\(weekOffset) Weeks Ago"
    }
    
    var stats: [(date: Date, consumed: Double, target: Double, mode: DayMode, protein: Double, pTarget: Double, steps: Double)] {
        var s = [(Date, Double, Double, DayMode, Double, Double, Double)]()
        let cal = Calendar.current
        let startDaysAgo = weekOffset * 7
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: -(i + startDaysAgo), to: Date())!
            let id = DateFormatter.yyyyMMdd.string(from: d)
            let mode = allSetups.first(where: { $0.dateID == id }).flatMap { DayMode(rawValue: $0.mode) } ?? .chill
            let dayFood = allFoodEntries.filter { cal.isDate($0.date, inSameDayAs: d) }
            let consumed = dayFood.reduce(0) { $0 + $1.calories }
            let prot = dayFood.reduce(0) { $0 + $1.protein }
            let target = mode == .padel ? baseCalories + 500 : (mode == .gym ? baseCalories + 300 : baseCalories)
            let pTarget = mode == .padel ? baseProtein + 15 : (mode == .gym ? baseProtein + 25 : baseProtein)
            s.append((d, consumed, target, mode, prot, pTarget, weeklySteps[id] ?? 0))
        }
        return s.reversed()
    }
    
    var avgCals: Double { stats.map{$0.consumed}.reduce(0, +) / 7.0 }
    var totalSteps: Double { stats.map{$0.steps}.reduce(0, +) }
    var successDays: Int { stats.filter{$0.consumed > 0 && $0.consumed <= $0.target}.count }

    var body: some View {
        NavigationView {
            ZStack {
                Color.darkGrey.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 25) {
                        HStack {
                            Button(action: { withAnimation { weekOffset += 1 } }) { Image(systemName: "chevron.left").foregroundColor(.neonGreen).padding() }
                            Spacer()
                            Text(dateRangeText).font(.headline).bold().foregroundColor(.white)
                            Spacer()
                            Button(action: { withAnimation { weekOffset -= 1 } }) { Image(systemName: "chevron.right").foregroundColor(weekOffset > 0 ? .neonGreen : .gray).padding() }.disabled(weekOffset == 0)
                        }.background(RoundedRectangle(cornerRadius: 15).fill(Color.black.opacity(0.3)))

                        topMetrics
                        barChart
                        stepMetrics
                    }.padding()
                }
            }
            .navigationTitle("Your Dashboard 📊").navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() }.foregroundColor(.neonGreen).bold() } }
            .onAppear {
                HealthKitManager.shared.fetchWeeklySteps { dict in DispatchQueue.main.async { self.weeklySteps = dict } }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { showBars = true }
            }
        }.preferredColorScheme(.dark)
    }
    
    private var topMetrics: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading) { Text("AVG CALORIES").font(.system(size: 10, weight: .bold)).foregroundColor(.gray); Text("\(Int(avgCals))").font(.system(size: 32, weight: .heavy)).foregroundColor(.white) }.padding().frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.3)))
            VStack(alignment: .leading) { Text("SUCCESS DAYS").font(.system(size: 10, weight: .bold)).foregroundColor(.gray); Text("\(successDays)/7").font(.system(size: 32, weight: .heavy)).foregroundColor(.neonGreen) }.padding().frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.3)))
        }
    }
    
    private var barChart: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("CALS & PROTEIN").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                Spacer()
                HStack(spacing: 10) { Circle().fill(Color.neonGreen).frame(width: 8); Text("Kcal").font(.caption2).foregroundColor(.gray); Circle().fill(Color.neonCyan).frame(width: 8); Text("Prot").font(.caption2).foregroundColor(.gray) }
            }
            
            ZStack(alignment: .bottom) {
                VStack { Spacer(); Divider().background(Color.white.opacity(0.2)); Spacer().frame(height: 90) }.frame(height: 180)
                
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(stats, id: \.date) { stat in
                        VStack(spacing: 6) {
                            HStack(alignment: .bottom, spacing: 4) {
                                // КАЛОРИИ
                                let calH = min((stat.consumed / stat.target) * 90.0, 150.0)
                                RoundedRectangle(cornerRadius: 4).fill(stat.consumed > stat.target ? Color.red : Color.neonGreen).frame(width: 10, height: showBars && stat.consumed > 0 ? calH : 4)
                                
                                // БЕЛОК
                                let protH = min((stat.protein / stat.pTarget) * 90.0, 150.0)
                                RoundedRectangle(cornerRadius: 4).fill(stat.protein >= stat.pTarget ? Color.neonCyan : Color.neonCyan.opacity(0.4)).frame(width: 10, height: showBars && stat.protein > 0 ? protH : 4)
                            }
                            // ДЕНЬ И ИКОНКА АКТИВНОСТИ
                            Text(dayName(stat.date)).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            Text(stat.mode == .chill ? "🛋️" : (stat.mode == .padel ? "🎾" : "🏋️‍♂️")).font(.caption2)
                        }.frame(maxWidth: .infinity)
                    }
                }.frame(height: 180)
            }
        }.padding().background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.3)))
    }
    
    private var stepMetrics: some View {
        HStack { Image(systemName: "figure.walk").font(.title).foregroundColor(.neonCyan); VStack(alignment: .leading) { Text("TOTAL WEEKLY STEPS").font(.system(size: 10, weight: .bold)).foregroundColor(.gray); Text("\(Int(totalSteps))").font(.title2).bold().foregroundColor(.white) }; Spacer() }.padding().background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.3)))
    }
    
    func dayName(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: d).uppercased() }
}
