import SwiftUI

enum Theme {
    /// Mint green used for the tap panel, dots and highlights.
    static let mint = Color(red: 0.40, green: 0.80, blue: 0.58)
    static let green = mint
    /// Slightly deeper mint for the panel gradient.
    static let mintDeep = Color(red: 0.30, green: 0.72, blue: 0.52)
    static let gold = Color(red: 0.83, green: 0.66, blue: 0.29)
    /// Dark grey page background with black cards on top.
    static let background = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let card = Color.black
    static let cardRadius: CGFloat = 22

    static func arabicFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

/// A rounded black card used across the app.
struct CardBackground: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardBackground(padding: padding)) }

    /// Dark page background for scroll views and lists.
    func themedBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }
}

/// Arabic, transliteration and translation of a dua.
struct DuaTextView: View {
    let arabic: String
    let transliteration: String
    let translation: String
    let source: String
    var arabicSize: CGFloat = 28
    var showTransliteration = true
    var showTranslation = true

    var body: some View {
        VStack(spacing: 18) {
            if !arabic.isEmpty {
                Text(arabic)
                    .font(Theme.arabicFont(size: arabicSize))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .rightToLeft)
                    .textSelection(.enabled)
            }
            if showTransliteration && !transliteration.isEmpty {
                Text(transliteration)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            if showTranslation && !translation.isEmpty {
                Text(translation)
                    .font(.body.italic())
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
            if !source.isEmpty {
                Label(source, systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A list row: mint dot, title, optional badge and chevron.
struct BulletRow: View {
    let title: String
    var subtitle: String? = nil
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(Theme.mint).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let badge {
                Text(badge)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.mint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.mint.opacity(0.15), in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// A big section header card: icon, title, quote, count badge, chevron.
struct SectionCard: View {
    let title: String
    let quote: String
    let symbol: String
    let count: Int
    var expandable = false
    var expanded = false
    var disabledLabel: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(Theme.mint.opacity(disabledLabel == nil ? 1 : 0.5), in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(.white.opacity(disabledLabel == nil ? 1 : 0.5))
                    .multilineTextAlignment(.leading)
                Text(quote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            if let disabledLabel {
                Text(disabledLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: Capsule())
            } else {
                Text("\(count)")
                    .font(.headline)
                    .foregroundStyle(Theme.mint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.mint.opacity(0.15), in: Capsule())
                Image(systemName: expandable ? "chevron.down" : "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(expandable && expanded ? 180 : 0))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .contentShape(Rectangle())
    }
}
