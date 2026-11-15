import SwiftUI
import SwiftData
import Charts

/// Time ranges for totals.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All time"

    var id: String { rawValue }

    var longName: String {
        switch self {
        case .today: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        case .all: return "All time"
        }
    }

    /// First and last day keys ("yyyy-MM-dd") of the period, or nil for all time.
    func dayRange(now: Date = .now) -> ClosedRange<String>? {
        let calendar = Calendar.current
        let component: Calendar.Component
        switch self {
        case .today: return DailyTally.key(for: now)...DailyTally.key(for: now)
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        case .all: return nil
        }
        guard let interval = calendar.dateInterval(of: component, for: now) else { return nil }
        let last = interval.end.addingTimeInterval(-1)
        return DailyTally.key(for: interval.start)...DailyTally.key(for: last)
    }
}

/// Day-by-day counts plus an all-time total, with helpers for each period.
struct DayTotals {
    let byDay: [String: Int]
    let allTime: Int

    func total(_ period: StatsPeriod) -> Int {
        guard let range = period.dayRange() else { return allTime }
        return byDay.reduce(0) { range.contains($1.key) ? $0 + $1.value : $0 }
    }

    struct Bucket: Identifiable {
        let id: Int
        let label: String
        let value: Int
    }

    /// Bars for the chart: days of the week or month, months of the year, or years.
    func buckets(_ period: StatsPeriod) -> [Bucket] {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .today:
            return []
        case .week, .month:
            guard let interval = calendar.dateInterval(of: period == .week ? .weekOfYear : .month, for: now) else { return [] }
            var buckets: [Bucket] = []
            var date = interval.start
            while date < interval.end {
                let label = period == .week
                    ? date.formatted(.dateTime.weekday(.abbreviated))
                    : "\(calendar.component(.day, from: date))"
                buckets.append(Bucket(id: buckets.count, label: label, value: byDay[DailyTally.key(for: date)] ?? 0))
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = next
            }
            return buckets
        case .year:
            let year = calendar.component(.year, from: now)
            return (1...12).map { month in
                let prefix = String(format: "%04d-%02d", year, month)
                let label = calendar.shortMonthSymbols[month - 1]
                return Bucket(id: month, label: label, value: sum(prefix: prefix))
            }
        case .all:
            let years = byDay.keys.compactMap { Int($0.prefix(4)) }
            let current = calendar.component(.year, from: now)
            let first = min(years.min() ?? current, current)
            return (first...current).map { year in
                Bucket(id: year, label: String(year), value: sum(prefix: String(format: "%04d", year)))
            }
        }
    }

    private func sum(prefix: String) -> Int {
        byDay.reduce(0) { $1.key.hasPrefix(prefix) ? $0 + $1.value : $0 }
    }
}

/// The Stats tab: totals for every period across all zikrs, a chart, and each zikr's share.
struct StatsView: View {
    @Query private var tallies: [DailyTally]
    @Query private var dayCounts: [ZikrDayCount]
    @Query(sort: \ZikrItem.createdAt) private var items: [ZikrItem]
    @State private var period: StatsPeriod = .week

    private var overall: DayTotals {
        var byDay: [String: Int] = [:]
        for tally in tallies { byDay[tally.day, default: 0] += tally.total }
        let allTime = max(byDay.values.reduce(0, +), items.reduce(0) { $0 + $1.totalCount })
        return DayTotals(byDay: byDay, allTime: allTime)
    }

    private func totals(for item: ZikrItem) -> DayTotals {
        var byDay: [String: Int] = [:]
        for entry in dayCounts where entry.itemID == item.id { byDay[entry.day, default: 0] += entry.total }
        return DayTotals(byDay: byDay, allTime: item.totalCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatsPanel(totals: overall, period: $period, title: "All zikrs")

                    let ranked = items
                        .map { RankedZikr(item: $0, value: totals(for: $0).total(period)) }
                        .filter { $0.value > 0 }
                        .sorted { $0.value > $1.value }

                    if !items.isEmpty {
                        Text("Achievements")
                            .font(.title2.bold())
                            .padding(.top, 8)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(items.sorted { $0.totalCount > $1.totalCount }) { item in
                                    NavigationLink {
                                        AchievementsView(item: item)
                                    } label: {
                                        AchievementChip(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Text("By zikr · \(period.longName.lowercased())")
                        .font(.title2.bold())
                        .padding(.top, 8)

                    if ranked.isEmpty {
                        Text("Nothing counted \(period == .all ? "yet" : period.longName.lowercased()). Open a counter and swipe to start.")
                            .foregroundStyle(.secondary)
                            .card()
                    } else {
                        let top = ranked.first?.value ?? 1
                        ForEach(ranked) { entry in
                            NavigationLink {
                                ZikrStatsDetail(item: entry.item, totals: totals(for: entry.item))
                            } label: {
                                ZikrShareRow(item: entry.item, value: entry.value, share: Double(entry.value) / Double(max(1, top)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .themedBackground()
            .navigationTitle("Stats")
        }
    }
}

/// Small card in the Stats tab: a zikr's current color and colors unlocked.
private struct AchievementChip: View {
    let item: ZikrItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(HueJourney.color(for: item.totalCount).gradient)
                    .frame(width: 44, height: 44)
                Image(systemName: "trophy.fill").foregroundStyle(.white)
            }
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(item.unlockedTiers) color\(item.unlockedTiers == 1 ? "" : "s") unlocked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140, alignment: .leading)
        .card(padding: 14)
    }
}

/// Row linking to a zikr's achievements, showing progress to the next color.
struct AchievementSummaryRow: View {
    let item: ZikrItem

    var body: some View {
        let next = HueJourney.stop(forTier: item.unlockedTiers + 1)
        let toNext = HueJourney.recitationsPerColor - item.totalCount % HueJourney.recitationsPerColor
        return HStack(spacing: 14) {
            Circle()
                .fill(HueJourney.color(for: item.totalCount).gradient)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "trophy.fill").font(.footnote).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text("Achievements · \(item.unlockedTiers) unlocked")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(toNext) more to reach \(next.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .card()
    }
}

private struct RankedZikr: Identifiable {
    let item: ZikrItem
    let value: Int
    var id: UUID { item.id }
}

/// Period picker, big total, the five period tiles and the chart.
struct StatsPanel: View {
    let totals: DayTotals
    @Binding var period: StatsPeriod
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Period", selection: $period.animation(.smooth)) {
                ForEach(StatsPeriod.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(title) · \(period.longName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(totals.total(period).formatted())
                    .font(.system(size: 54, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .foregroundStyle(.white)
                if period != .today && period != .all {
                    let days = max(1, totals.buckets(period).filter { $0.value > 0 }.count)
                    Text("≈ \(totals.total(period) / days) a day on days you counted")
                        .font(.footnote)
                        .foregroundStyle(Theme.mint)
                }

                let buckets = totals.buckets(period)
                if !buckets.isEmpty {
                    Chart(buckets) { bucket in
                        BarMark(
                            x: .value("Period", bucket.label),
                            y: .value("Count", bucket.value)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.mint, Theme.mintDeep], startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            if period != .month || (value.index % 5 == 0) {
                                AxisValueLabel()
                            }
                        }
                    }
                    .frame(height: 180)
                    .padding(.top, 10)
                }
            }
            .card(padding: 18)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(StatsPeriod.allCases) { option in
                    Button {
                        withAnimation(.smooth) { period = option }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.longName)
                                .font(.caption)
                                .foregroundStyle(option == period ? .black.opacity(0.7) : .secondary)
                            Text(totals.total(option).formatted())
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(option == period ? .black : .white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            option == period ? AnyShapeStyle(Theme.mint) : AnyShapeStyle(Theme.card),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ZikrShareRow: View {
    let item: ZikrItem
    let value: Int
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !item.arabic.isEmpty {
                        Text(item.arabic)
                            .font(Theme.arabicFont(size: 16))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(value.formatted())
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Theme.mint)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                Capsule()
                    .fill(Theme.mint.opacity(0.8))
                    .frame(width: max(6, geo.size.width * share))
            }
            .frame(height: 4)
        }
        .card()
    }
}

/// One zikr's totals for every period, with its chart.
struct ZikrStatsDetail: View {
    let item: ZikrItem
    let totals: DayTotals
    @EnvironmentObject private var router: AppRouter
    @State private var period: StatsPeriod = .week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !item.arabic.isEmpty {
                    Text(item.arabic)
                        .font(Theme.arabicFont(size: 26))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity)
                        .card(padding: 20)
                }
                StatsPanel(totals: totals, period: $period, title: item.title)
                NavigationLink {
                    AchievementsView(item: item)
                } label: {
                    AchievementSummaryRow(item: item)
                }
                .buttonStyle(.plain)
                Button {
                    router.openCounter(item)
                } label: {
                    Label("Open counter", systemImage: "hand.tap.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .themedBackground()
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
