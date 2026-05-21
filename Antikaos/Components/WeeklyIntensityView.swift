import SwiftUI

struct WeeklyIntensityPoint: Identifiable {
    let id = UUID()
    let date: Date
    let stars: Int
    let hasTasks: Bool
}

struct WeeklyIntensityView: View {
    let points: [WeeklyIntensityPoint]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(points) { point in
                VStack(spacing: 8) {
                    Group {
                        if point.hasTasks {
                            VStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { index in
                                    Image(systemName: index < point.stars ? "star.fill" : "star")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(index < point.stars ? Color.yellow : AppTheme.track)
                                }
                            }
                        } else {
                            Image(systemName: "zzz")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(AppTheme.inkSoft)
                        }
                    }
                    .frame(height: 50, alignment: .center)
                    .animation(.spring(response: 0.45, dampingFraction: 0.84), value: point.stars)
                    .animation(.spring(response: 0.45, dampingFraction: 0.84), value: point.hasTasks)

                    Text(dayLabel(for: point.date))
                        .font(AppTheme.schoolbell(16))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottom)
    }

    private func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Hoje"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EE")
        return formatter.string(from: date).capitalized
    }
}

#Preview {
    WeeklyIntensityView(points: [
        WeeklyIntensityPoint(date: .now.addingTimeInterval(-518_400), stars: 1, hasTasks: true),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(-432_000), stars: 3, hasTasks: true),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(-345_600), stars: 2, hasTasks: true),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(-259_200), stars: 0, hasTasks: true),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(-172_800), stars: 0, hasTasks: false),
        WeeklyIntensityPoint(date: .now.addingTimeInterval(-86_400), stars: 2, hasTasks: true),
        WeeklyIntensityPoint(date: .now, stars: 3, hasTasks: true),
    ])
    .padding()
    .background(AppTheme.background)
}
