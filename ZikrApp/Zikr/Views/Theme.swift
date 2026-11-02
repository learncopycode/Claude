import SwiftUI

enum Theme {
    static let gold = Color(red: 0.83, green: 0.66, blue: 0.29)
    static let green = Color.accentColor

    static func arabicFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }
}

/// A rounded card background used across the app.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
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
        VStack(spacing: 14) {
            if !arabic.isEmpty {
                Text(arabic)
                    .font(Theme.arabicFont(size: arabicSize))
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, .rightToLeft)
                    .textSelection(.enabled)
            }
            if showTransliteration && !transliteration.isEmpty {
                Text(transliteration)
                    .font(.callout.italic())
                    .foregroundStyle(Theme.green)
                    .multilineTextAlignment(.center)
            }
            if showTranslation && !translation.isEmpty {
                Text(translation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !source.isEmpty {
                Label(source, systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
