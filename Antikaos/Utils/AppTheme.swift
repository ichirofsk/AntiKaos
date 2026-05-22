import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(red: 244 / 255, green: 237 / 255, blue: 232 / 255)
    static let paper = Color(red: 250 / 255, green: 245 / 255, blue: 241 / 255)
    static let secondarySurface = Color(red: 248 / 255, green: 242 / 255, blue: 237 / 255)
    static let track = Color(red: 234 / 255, green: 225 / 255, blue: 218 / 255)

    static let primaryText = Color.black.opacity(0.92)
    static let secondaryText = Color.black.opacity(0.64)
    static let ink = Color.black.opacity(0.22)
    static let inkSoft = Color.black.opacity(0.35)

    static let primaryChaos = Color(red: 216 / 255, green: 113 / 255, blue: 66 / 255)
    static let supportGreen = Color(red: 0.45, green: 0.61, blue: 0.48)
    static let critical = Color(red: 0.72, green: 0.34, blue: 0.27)
    static let chaosGlow = Color(red: 244 / 255, green: 201 / 255, blue: 177 / 255)

    static func schoolbell(_ size: CGFloat) -> Font {
        .custom("Schoolbell", size: size)
    }
}

private struct SoftCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.paper.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppTheme.primaryChaos.opacity(0.9), lineWidth: 1)
                    )
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

    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}
