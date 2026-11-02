import SwiftUI
import SwiftData

/// One zikr's color journey: the colors it has unlocked (every 100
/// recitations) and the ones still ahead.
struct AchievementsView: View {
    let item: ZikrItem
    @Query private var unlocks: [AchievementUnlock]
    @State private var selected: HueJourney.Achievement?

    init(item: ZikrItem) {
        self.item = item
        let id = item.id
        _unlocks = Query(filter: #Predicate<AchievementUnlock> { $0.itemID == id })
    }

    private var unlocked: Int { item.unlockedTiers }
    private var toNext: Int { HueJourney.recitationsPerColor - item.totalCount % HueJourney.recitationsPerColor }
    /// Show everything unlocked plus a few still to come.
    private var shownTiers: ClosedRange<Int> { 1...max(12, unlocked + 3) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Text("\(unlocked) of \(shownTiers.upperBound) colors")
                    .font(.title2.bold())

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 14)], spacing: 18) {
                    ForEach(Array(shownTiers), id: \.self) { tier in
                        let achievement = HueJourney.Achievement(tier: tier, zikrTitle: item.title)
                        Button {
                            selected = achievement
                        } label: {
                            Medallion(
                                achievement: achievement,
                                isUnlocked: tier <= unlocked,
                                date: unlocks.first { $0.tier == tier }?.date
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .themedBackground()
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { achievement in
            AchievementDetail(
                achievement: achievement,
                isUnlocked: achievement.tier <= unlocked,
                remaining: max(0, achievement.count - item.totalCount),
                date: unlocks.first { $0.tier == achievement.tier }?.date
            )
            .presentationDetents([.medium])
        }
    }

    private var header: some View {
        let next = HueJourney.stop(forTier: unlocked + 1)
        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(HueJourney.color(for: item.totalCount).gradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: HueJourney.color(for: item.totalCount).opacity(0.6), radius: 30)
                Text(item.totalCount.formatted())
                    .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Text(item.title).font(.title3.bold()).multilineTextAlignment(.center)
            Text("\(toNext) more to reach \(next.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(HueJourney.recitationsPerColor - toNext), total: Double(HueJourney.recitationsPerColor))
                .tint(HueJourney.color(for: item.totalCount))
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }
}

/// A round color badge: full color when unlocked, dim with a lock when not.
struct Medallion: View {
    let achievement: HueJourney.Achievement
    let isUnlocked: Bool
    var date: Date?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? AnyShapeStyle(achievement.stop.color.gradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                    .overlay(Circle().stroke(achievement.stop.color.opacity(isUnlocked ? 0.9 : 0.35), lineWidth: 2))
                    .shadow(color: isUnlocked ? achievement.stop.color.opacity(0.5) : .clear, radius: 12)
                if isUnlocked {
                    Text(achievement.count.formatted())
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(achievement.stop.color.opacity(0.6))
                }
            }
            .frame(width: 74, height: 74)
            Text(achievement.stop.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isUnlocked ? .white : .secondary)
                .lineLimit(1)
            Text(isUnlocked ? achievement.stop.title : "at \(achievement.count.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .opacity(isUnlocked ? 1 : 0.75)
    }
}

private struct AchievementDetail: View {
    let achievement: HueJourney.Achievement
    let isUnlocked: Bool
    let remaining: Int
    let date: Date?

    var body: some View {
        VStack(spacing: 16) {
            Medallion(achievement: achievement, isUnlocked: isUnlocked)
                .scaleEffect(1.3)
                .padding(.top, 30)
            Text(achievement.headline)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(achievement.description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if isUnlocked, let date {
                Label("Unlocked \(date.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.seal.fill")
                    .font(.footnote)
                    .foregroundStyle(achievement.stop.color)
            } else if !isUnlocked {
                Label("\(remaining.formatted()) more to unlock", systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

/// The pop-up shown the moment a new color is unlocked, with a burst of color.
struct AchievementToast: View {
    let achievement: HueJourney.Achievement

    var body: some View {
        ZStack {
            ColorBurst(color: achievement.stop.color)
            HStack(spacing: 14) {
                Circle()
                    .fill(achievement.stop.color.gradient)
                    .frame(width: 46, height: 46)
                    .overlay(Image(systemName: "sparkles").foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 3) {
                    Text("New color unlocked").font(.caption.weight(.semibold)).foregroundStyle(achievement.stop.color)
                    Text(achievement.headline).font(.headline).foregroundStyle(.white)
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(achievement.stop.color.opacity(0.5)))
            .padding(.horizontal, 16)
        }
        .allowsHitTesting(false)
    }
}

/// Dots of color flying outward, for celebrations.
private struct ColorBurst: View {
    let color: Color
    @State private var go = false

    private let particles: [(angle: Double, distance: Double, size: Double)] = (0..<26).map { _ in
        (Double.random(in: 0..<(2 * .pi)), Double.random(in: 90...190), Double.random(in: 5...11))
    }

    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { i in
                let p = particles[i]
                Circle()
                    .fill(i.isMultiple(of: 3) ? Color.white : color)
                    .frame(width: p.size, height: p.size)
                    .offset(x: go ? cos(p.angle) * p.distance : 0, y: go ? sin(p.angle) * p.distance : 0)
                    .opacity(go ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { go = true }
        }
    }
}

extension View {
    /// Shows an achievement pop-up at the top for a few seconds.
    func achievementToast(_ achievement: Binding<HueJourney.Achievement?>) -> some View {
        overlay(alignment: .top) {
            if let value = achievement.wrappedValue {
                AchievementToast(achievement: value)
                    .padding(.top, 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(value.id)
                    .task(id: value.id) {
                        try? await Task.sleep(for: .seconds(3.2))
                        withAnimation(.smooth) { achievement.wrappedValue = nil }
                    }
            }
        }
        .sensoryFeedback(.success, trigger: achievement.wrappedValue?.id)
    }
}
