import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TaskItem.deadlineDate, order: .forward) private var tasks: [TaskItem]
    @Query(sort: \GeneratedTaskItem.scheduledDate, order: .forward) private var generatedTasks: [GeneratedTaskItem]

    @State private var displayedMonth: Date = .now
    @State private var selectedDate: Date = .now
    @State private var externalEvents: [AppleCalendarExternalEvent] = []

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

    private var selectedDayPlanEntries: [CalendarPlanEntry] {
        let deadlineEntries = activeTasks
            .filter { calendar.isDate($0.deadlineDate, inSameDayAs: selectedDate) }
            .map {
                CalendarPlanEntry(
                    id: "deadline-\($0.id.uuidString)",
                    title: $0.title,
                    date: $0.deadlineDate,
                    dedicationMinutes: nil,
                    chaosScore: $0.chaosScore,
                    tint: $0.chaosLevel.tint
                )
            }

        let generatedEntries = generatedTasks
            .filter { calendar.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
            .map {
                CalendarPlanEntry(
                    id: "generated-\($0.id.uuidString)",
                    title: $0.title,
                    date: $0.scheduledDate,
                    dedicationMinutes: $0.dedicationMinutes,
                    chaosScore: nil,
                    tint: $0.isCompleted ? AppTheme.supportGreen : AppTheme.primaryChaos,
                    symbolName: $0.isCompleted ? "checkmark" : "hourglass"
                )
            }

        let externalEntries = externalEvents
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .map {
                CalendarPlanEntry(
                    id: "external-\($0.id)",
                    title: $0.title,
                    date: $0.date,
                    dedicationMinutes: nil,
                    chaosScore: nil,
                    tint: AppTheme.secondaryText,
                    symbolName: "calendar.badge.clock"
                )
            }

        return (deadlineEntries + generatedEntries + externalEntries)
            .sorted {
                if $0.date != $1.date {
                    return $0.date < $1.date
                }

                return $0.title < $1.title
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
        .onAppear {
            TaskManager(modelContext: modelContext).rebalanceGeneratedTasks()
            TaskManager(modelContext: modelContext).syncAppleReminderCompletions()
            loadExternalEvents()
        }
        .onChange(of: displayedMonth) {
            loadExternalEvents()
        }
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
                .font(AppTheme.schoolbell(24))
                .foregroundStyle(AppTheme.primaryText)

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
                    .font(AppTheme.schoolbell(14))
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
                                .font(AppTheme.schoolbell(18))
                                .foregroundStyle(isSelected(date) ? Color.white : AppTheme.primaryText)

                            HStack(spacing: 4) {
                                if hasTask(on: date) {
                                    Circle()
                                        .fill(isSelected(date) ? Color.white.opacity(0.82) : AppTheme.primaryChaos.opacity(0.82))
                                        .frame(width: 6, height: 6)
                                }

                                if hasExternalEvent(on: date) {
                                    Circle()
                                        .fill(isSelected(date) ? Color.white.opacity(0.82) : Color(red: 0.95, green: 0.76, blue: 0.22))
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .frame(height: 6)
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
                .font(AppTheme.schoolbell(24))
                .foregroundStyle(AppTheme.primaryText)

            if selectedDayPlanEntries.isEmpty {
                Text(AppStrings.localized("calendar.empty"))
                    .font(AppTheme.schoolbell(16))
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(selectedDayPlanEntries) { entry in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(entry.tint.opacity(0.18))
                            .frame(width: 40, height: 40)
                            .overlay {
                                if let chaosScore = entry.chaosScore {
                                    Text("\(chaosScore)")
                                        .font(AppTheme.schoolbell(16))
                                        .foregroundStyle(entry.tint)
                                } else {
                                    Image(systemName: entry.symbolName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(entry.tint)
                                }
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(AppTheme.schoolbell(18))
                                .foregroundStyle(AppTheme.primaryText)

                            HStack(spacing: 8) {
                                if let dedicationMinutes = entry.dedicationMinutes {
                                    Text("\(dedicationMinutes) min")
                                        .font(AppTheme.schoolbell(14))
                                        .foregroundStyle(AppTheme.supportGreen)
                                }

                                Text(AppStrings.deadlineRelativeString(for: entry.date))
                                    .font(AppTheme.schoolbell(14))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
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
            || generatedTasks.contains { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    private func hasExternalEvent(on date: Date) -> Bool {
        externalEvents.contains { calendar.isDate($0.date, inSameDayAs: date) }
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

    private func loadExternalEvents() {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return }

        Task {
            let events = await AppleCalendarSyncManager.shared.externalEvents(from: interval.start, to: interval.end)
            externalEvents = events
        }
    }
}

private struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let isInDisplayedMonth: Bool
}

private struct CalendarPlanEntry: Identifiable {
    let id: String
    let title: String
    let date: Date
    let dedicationMinutes: Int?
    let chaosScore: Int?
    let tint: Color
    var symbolName: String = "checkmark"
}

#Preview {
    NavigationStack {
        CalendarView()
            .modelContainer(TaskManager.previewContainer)
    }
}
