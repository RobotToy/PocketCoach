import SwiftUI

enum FieldTheme {
    static let background = Color(red: 0.04, green: 0.06, blue: 0.08)
    static let surface = Color(red: 0.09, green: 0.12, blue: 0.16)
    static let surfaceRaised = Color(red: 0.13, green: 0.17, blue: 0.23)
    static let stroke = Color.white.opacity(0.12)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.72, green: 0.76, blue: 0.80)
    static let handler = Color(red: 0.49, green: 0.71, blue: 1.0)
    static let cutter = Color(red: 1.0, green: 0.71, blue: 0.42)
    static let flex = Color(red: 0.78, green: 0.70, blue: 1.0)
    static let score = Color(red: 0.24, green: 0.86, blue: 0.59)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.48)
    static let warn = Color(red: 1.0, green: 0.80, blue: 0.30)
    static let accent = Color(red: 0.35, green: 0.78, blue: 1.0)
}

struct FieldScreen<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            FieldTheme.background.ignoresSafeArea()
            content
        }
        .preferredColorScheme(.dark)
    }
}

struct FieldButtonStyle: ButtonStyle {
    var fill: Color = FieldTheme.surfaceRaised
    var foreground: Color = FieldTheme.textPrimary
    var minHeight: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(fill.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FieldTheme.stroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct RoleBadge: View {
    let role: PlayerRole
    var compact: Bool = false

    var color: Color {
        switch role {
        case .handler: FieldTheme.handler
        case .cutter: FieldTheme.cutter
        case .flex: FieldTheme.flex
        }
    }

    var body: some View {
        Text(compact ? role.shortLabel : role.displayName)
            .font(compact ? .caption.weight(.bold) : .caption.weight(.semibold))
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
            .accessibilityLabel(role.displayName)
    }
}

struct StatusBadge: View {
    let status: PlayerStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(status == .active ? FieldTheme.score : FieldTheme.danger)
            .background((status == .active ? FieldTheme.score : FieldTheme.danger).opacity(0.16))
            .clipShape(Capsule())
    }
}

struct InlineWarning: View {
    let text: String
    var tone: Color = FieldTheme.warn

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tone)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FieldTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tone.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tone.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
