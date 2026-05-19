import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \TaskItem.deadlineDate, order: .forward) private var tasks: [TaskItem]

    @State private var displayedMonth: Date = .now
    @State private var selectedDate: Date = .now

    private let calendar = Calendar.current

    private var activeTasks: [TaskItem] {
        tasks.filter { !$0.isPastDeadline && $0.remainingSessions > 0 }
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: displayedMonth).capitalized
    }

    private var calendarDays: [CalendarDay] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = calendar.date(from: calendar.dateComponents([.year, .month], from: interval.start)),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstDayWeekday = calendar.component(.weekday, from: firstWeekday)
        let leadingOffset = (firstDayWeekday - calendar.firstWeekday + 7) % 7

        var days: [CalendarDay] = Array(repeating: CalendarDay(date: nil, isInDisplayedMonth: false), count: leadingOffset)

        for day in dayRange {
            let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start)
            days.append(CalendarDay(date: date, isInDisplayedMonth: true))
        }

        return days
    }

    private var selectedDayTasks: [TaskItem] {
        let exactMatches = activeTasks.filter { calendar.isDate($0.deadlineDate, inSameDayAs: selectedDate) }

        if !exactMatches.isEmpty {
            return exactMatches
        }

        return activeTasks.filter { task in
            let difference = abs(calendar.dateComponents([.day], from: selectedDate, to: task.deadlineDate).day ?? 99)
            return difference <= 2
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    monthHeader
                    weekdayHeader
                    daysGrid
                    planCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle(AppStrings.localized("calendar.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(.snappy) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthLabel)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.black)

            Spacer()

            Button {
                withAnimation(.snappy) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        let symbols = orderedWeekdaySymbols()

        return HStack {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
    }

    private var daysGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 10) {
            ForEach(calendarDays) { day in
                if let date = day.date {
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 6) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(isSelected(date) ? Color.white : AppTheme.primaryText)

                            Circle()
                                .fill(hasTask(on: date) ? (isSelected(date) ? Color.white.opacity(0.82) : AppTheme.primaryChaos.opacity(0.74)) : Color.clear)
                                .frame(width: 6, height: 6)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(backgroundColor(for: date), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(height: 52)
                }
            }
        }
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppStrings.planHeader(for: selectedDate))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.black)

            if selectedDayTasks.isEmpty {
                Text(AppStrings.localized("calendar.empty"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(selectedDayTasks) { task in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(task.chaosLevel.tint.opacity(0.18))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text("\(task.chaosScore)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(task.chaosLevel.tint)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.primaryText)

                            Text(AppStrings.deadlineRelativeString(for: task.deadlineDate))
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()
                    }
                }
            }
        }
        .softCard()
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func hasTask(on date: Date) -> Bool {
        activeTasks.contains { calendar.isDate($0.deadlineDate, inSameDayAs: date) }
    }

    private func backgroundColor(for date: Date) -> Color {
        if isSelected(date) {
            return AppTheme.primaryChaos
        }

        if hasTask(on: date) {
            return AppTheme.secondarySurface
        }

        return Color.white.opacity(0.64)
    }

    private func orderedWeekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? calendar.veryShortWeekdaySymbols
        let shift = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[shift...]) + Array(symbols[..<shift])
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let isInDisplayedMonth: Bool
}

#Preview {
    NavigationStack {
        CalendarView()
            .modelContainer(TaskManager.previewContainer)
    }
}
