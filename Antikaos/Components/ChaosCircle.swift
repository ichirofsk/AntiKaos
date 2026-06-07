import SwiftUI

struct ChaosCircle: View {
    let value: Int
    var size: CGFloat = 208

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
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(value)")
                        .font(AppTheme.schoolbell(52))
                        .foregroundStyle(AppTheme.primaryText)
                        .contentTransition(.numericText(value: Double(value)))

                    Text("/100")
                        .font(AppTheme.schoolbell(24))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.82))
                }
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)

                VStack(spacing: 0) {
                    Text("Sobrecarga")
                        .font(AppTheme.schoolbell(max(size * 0.085, 15)))
                        .foregroundStyle(level.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(levelName(for: level))
                        .font(AppTheme.schoolbell(max(size * 0.078, 14)))
                        .foregroundStyle(level.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
    }

    private func levelName(for level: ChaosLevel) -> String {
        AppStrings.localized(level.titleKey)
            .replacingOccurrences(of: "Sobrecarga ", with: "")
            .capitalized
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        ChaosCircle(value: 64)
    }
}
