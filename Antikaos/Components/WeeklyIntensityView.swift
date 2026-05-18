import SwiftUI

struct WeeklyIntensityPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

struct WeeklyIntensityView: View {
    let points: [WeeklyIntensityPoint]

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ForEach(points) { point in
                let level = ChaosLevel(value: point.value)

                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(level.tint.opacity(0.85))
                        .frame(width: 22, height: barHeight(for: point.value))
                        .animation(.spring(response: 0.45, dampingFraction: 0.84), value: point.value)

                    Text(shortWeekday(for: point.date))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .bottom)
    }

    private func barHeight(for value: Int) -> CGFloat {
        22 + (CGFloat(value) / 100) * 54
    }

    private func shortWeekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EE")
        return formatter.string(from: date).capitalized
    }
}

#Preview {
    WeeklyIntensityView(points: [
        WeeklyIntensityPoint(date: .now, value: 22),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(86_400), value: 35),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(172_800), value: 47),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(259_200), value: 62),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(345_600), value: 58),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(432_000), value: 42),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(518_400), value: 31),
    ])
    .padding()
    .background(AppTheme.background)
}
