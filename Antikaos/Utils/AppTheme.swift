import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.97, green: 0.94, blue: 0.89)
    static let paper = Color(red: 0.99, green: 0.98, blue: 0.96)
    static let secondarySurface = Color(red: 0.97, green: 0.95, blue: 0.92)
    static let track = Color(red: 0.88, green: 0.84, blue: 0.78)

    static let primaryText = Color(red: 0.17, green: 0.18, blue: 0.22)
    static let secondaryText = Color(red: 0.40, green: 0.41, blue: 0.45)
    static let ink = Color(red: 0.25, green: 0.31, blue: 0.50)
    static let inkSoft = Color(red: 0.63, green: 0.68, blue: 0.81)

    static let primaryChaos = Color(red: 0.82, green: 0.53, blue: 0.22)
    static let supportGreen = Color(red: 0.45, green: 0.61, blue: 0.48)
    static let critical = Color(red: 0.72, green: 0.34, blue: 0.27)
    static let chaosGlow = Color(red: 0.94, green: 0.78, blue: 0.57)
}

private struct SoftCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(AppTheme.paper.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(AppTheme.ink.opacity(0.14), lineWidth: 1.1)
                    )
                    .shadow(color: AppTheme.ink.opacity(0.08), radius: 18, x: 0, y: 10)
            )
    }
}

private struct OutlineCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(AppTheme.paper.opacity(0.62))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(AppTheme.ink.opacity(0.32), lineWidth: 1.5)
                    )
            )
    }
}

private struct ScribbleBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    AppTheme.background

                    Circle()
                        .stroke(AppTheme.ink.opacity(0.08), lineWidth: 1.4)
                        .frame(width: 280, height: 280)
                        .offset(x: 118, y: -210)

                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.06), style: StrokeStyle(lineWidth: 1.2, dash: [6, 8]))
                        .frame(width: 250, height: 120)
                        .rotationEffect(.degrees(-8))
                        .offset(x: -92, y: 248)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func softCard() -> some View {
        modifier(SoftCardModifier())
    }

    func outlineCard() -> some View {
        modifier(OutlineCardModifier())
    }

    func scribbleBackground() -> some View {
        modifier(ScribbleBackgroundModifier())
    }
}
