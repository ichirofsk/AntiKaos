import SwiftUI

struct ChaosCircle: View {
    let value: Int

    var body: some View {
        let level = ChaosLevel(value: value)

        ZStack {
            Circle()
                .stroke(AppTheme.track, lineWidth: 18)

            Circle()
                .trim(from: 0, to: CGFloat(Double(value) / 100))
                .stroke(
                    level.tint,
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.45, dampingFraction: 0.88), value: value)

            VStack(spacing: 6) {
                Text(AppStrings.scoreValue(value))
                    .font(AppTheme.schoolbell(40))
                    .foregroundStyle(AppTheme.primaryText)
                    .contentTransition(.numericText(value: Double(value)))

                Text(AppStrings.localized(level.titleKey))
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(AppTheme.primaryChaos)
            }
        }
        .frame(width: 208, height: 208)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        ChaosCircle(value: 64)
    }
}
