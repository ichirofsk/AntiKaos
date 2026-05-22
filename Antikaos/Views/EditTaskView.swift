import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss

    private let task: TaskItem?
    private let onSave: (TaskFormData) -> Void

    @State private var title: String
    @State private var perceivedDifficulty: Double
    @State private var deadlineKind: DeadlineKind?
    @State private var recurrences: Set<DeadlineRecurrence>
    @State private var totalSessions: Int
    @State private var completedSessions: Int
    @State private var dedicationMinutes: Int
    @State private var deadlineDate: Date
    @State private var draftDeadlineDate: Date
    @State private var isEditingDeadlineDate = false
    @State private var notes: String
    @State private var draftNotes: String
    @State private var isEditingNotes = false
    @FocusState private var focusedNumericField: NumericField?

    init(task: TaskItem? = nil, onSave: @escaping (TaskFormData) -> Void) {
        self.task = task
        self.onSave = onSave
        let initialDeadlineDate = task?.deadlineDate ?? Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now
        let initialNotes = task?.notes ?? ""
        _title = State(initialValue: task?.title ?? "")
        _perceivedDifficulty = State(initialValue: Double(task?.perceivedDifficulty ?? 50))
        _deadlineKind = State(initialValue: task?.deadlineKind)
        _recurrences = State(initialValue: task?.recurrences ?? [.daily])
        _totalSessions = State(initialValue: max(task?.totalSessions ?? 4, 1))
        _completedSessions = State(initialValue: max(task?.completedSessions ?? 0, 0))
        _dedicationMinutes = State(initialValue: max(task?.dedicationMinutes ?? 30, 0))
        _deadlineDate = State(initialValue: initialDeadlineDate)
        _draftDeadlineDate = State(initialValue: initialDeadlineDate)
        _notes = State(initialValue: initialNotes)
        _draftNotes = State(initialValue: initialNotes)
    }

    private var viewTitle: String {
        task == nil ? AppStrings.localized("createTask.title") : AppStrings.localized("editTask.title")
    }

    private var normalizedCompletedSessions: Int {
        min(max(completedSessions, 0), max(totalSessions, 1))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && deadlineKind != nil
            && (deadlineKind != .continuous || !recurrences.isEmpty)
            && (deadlineKind != .punctual || totalSessions <= maxPunctualSessions)
    }

    private var maxPunctualSessions: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let deadlineDay = calendar.startOfDay(for: deadlineDate)
        let daysBeforeDeadline = calendar.dateComponents([.day], from: startOfToday, to: deadlineDay).day ?? 0
        return max(daysBeforeDeadline * 8, 24)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        inputCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(AppStrings.localized("task.field.title"))
                                    .font(AppTheme.schoolbell(16))
                                    .foregroundStyle(AppTheme.secondaryText)

                                TextField(
                                    "",
                                    text: $title,
                                    prompt: Text(AppStrings.localized("task.placeholder.title"))
                                        .font(AppTheme.schoolbell(18))
                                        .foregroundStyle(AppTheme.secondaryText)
                                )
                                    .textInputAutocapitalization(.sentences)
                                    .font(AppTheme.schoolbell(18))
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                        }

                        inputCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(AppStrings.localized("task.field.difficulty"))
                                        .font(AppTheme.schoolbell(16))
                                        .foregroundStyle(AppTheme.secondaryText)

                                    Spacer()

                                    Text(AppStrings.integerValue(Int(perceivedDifficulty.rounded())))
                                        .font(AppTheme.schoolbell(18))
                                        .foregroundStyle(AppTheme.primaryText)
                                        .contentTransition(.numericText(value: perceivedDifficulty))
                                }

                                Slider(value: $perceivedDifficulty, in: 0...100, step: 1)
                                    .tint(ChaosLevel(value: Int(perceivedDifficulty.rounded())).tint)
                            }
                        }

                        inputCard {
                            HStack(spacing: 10) {
                                deadlineKindButton(.continuous)
                                deadlineKindButton(.punctual)
                            }
                        }

                        if deadlineKind == .continuous {
                            inputCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(AppStrings.localized("task.field.recurrence"))
                                        .font(AppTheme.schoolbell(16))
                                        .foregroundStyle(AppTheme.secondaryText)

                                    LazyVGrid(columns: recurrenceColumns, spacing: 10) {
                                        ForEach(DeadlineRecurrence.allCases, id: \.self) { recurrenceOption in
                                            recurrenceButton(recurrenceOption)
                                        }
                                    }
                                }
                            }
                        }

                        if deadlineKind == .punctual {
                            inputCard {
                                VStack(spacing: 16) {
                                    stepperRow(
                                        title: AppStrings.localized("task.field.totalSessions"),
                                        value: $totalSessions,
                                        range: 1...maxPunctualSessions,
                                        field: .totalSessions
                                    )

                                    Divider()

                                    stepperRow(
                                        title: AppStrings.localized("task.field.completedSessions"),
                                        value: $completedSessions,
                                        range: 0...max(totalSessions, 1),
                                        field: .completedSessions
                                    )

                                    Divider()

                                    stepperRow(
                                        title: AppStrings.localized("task.field.dedicationMinutes"),
                                        value: $dedicationMinutes,
                                        range: 0...600,
                                        field: .dedicationMinutes
                                    )
                                }
                            }
                        }

                        inputCard {
                            deadlineDateSection
                        }

                        inputCard {
                            notesSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle(viewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                totalSessions = min(totalSessions, maxPunctualSessions)
                completedSessions = min(completedSessions, totalSessions)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.localized("common.cancel")) {
                        dismiss()
                    }
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(AppTheme.primaryChaos)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.localized("common.save")) {
                        save()
                    }
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(canSave ? AppTheme.primaryChaos : AppTheme.secondaryText)
                    .disabled(!canSave)
                }
            }
            .dismissKeyboardOnTap()
        }
    }

    private func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .softCard()
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, field: NumericField) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.schoolbell(16))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    value.wrappedValue = max(value.wrappedValue - 1, range.lowerBound)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primaryChaos)
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue <= range.lowerBound)
                .opacity(value.wrappedValue <= range.lowerBound ? 0.35 : 1)

                TextField(
                    "",
                    value: value,
                    format: .number
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(AppTheme.schoolbell(18))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 58, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .focused($focusedNumericField, equals: field)
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
                }

                Button {
                    value.wrappedValue = min(value.wrappedValue + 1, range.upperBound)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primaryChaos)
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue >= range.upperBound)
                .opacity(value.wrappedValue >= range.upperBound ? 0.35 : 1)
            }
        }
        .onChange(of: totalSessions) { _, newValue in
            completedSessions = min(completedSessions, newValue)
        }
    }


    private var deadlineDateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppStrings.localized("task.field.deadline"))
                    .font(AppTheme.schoolbell(16))
                    .foregroundStyle(AppTheme.secondaryText)

                Spacer()

                deadlineDateSaveButton
                deadlineDateEditButton
            }

            if isEditingDeadlineDate {
                VStack(spacing: 16) {
                    DatePicker(
                        AppStrings.localized("task.field.deadline"),
                        selection: $draftDeadlineDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .foregroundStyle(AppTheme.primaryText)
                    .environment(\.colorScheme, .light)

                    Divider()

                    DatePicker(
                        AppStrings.localized("task.field.deadlineTime"),
                        selection: $draftDeadlineDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .foregroundStyle(AppTheme.primaryText)
                    .environment(\.colorScheme, .light)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deadlineDateDisplay)
                            .font(AppTheme.schoolbell(20))
                            .foregroundStyle(AppTheme.primaryText)

                        Text(deadlineTimeDisplay)
                            .font(AppTheme.schoolbell(18))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .tint(AppTheme.primaryChaos)
        .foregroundStyle(AppTheme.primaryText)
    }

    private var deadlineDateSaveButton: some View {
        Group {
            if isEditingDeadlineDate {
                Button {
                    applyDraftDeadlineDate()

                    withAnimation(.snappy(duration: 0.22)) {
                        isEditingDeadlineDate = false
                    }
                } label: {
                    Text(AppStrings.localized("common.save"))
                        .font(AppTheme.schoolbell(18))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(AppTheme.primaryChaos)
                        )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .accessibilityLabel(AppStrings.localized("common.save"))
            }
        }
    }

    private var deadlineDateEditButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                if isEditingDeadlineDate {
                    draftDeadlineDate = deadlineDate
                    isEditingDeadlineDate = false
                } else {
                    draftDeadlineDate = deadlineDate
                    isEditingDeadlineDate = true
                }
            }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEditingDeadlineDate ? Color.white : AppTheme.primaryChaos)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isEditingDeadlineDate ? AppTheme.primaryChaos : Color.white.opacity(0.72))
                        .overlay {
                            Circle()
                                .stroke(AppTheme.primaryText.opacity(0.12), lineWidth: 1)
                        }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEditingDeadlineDate ? "Cancelar edição da data" : "Editar data")
    }

    private func applyDraftDeadlineDate() {
        deadlineDate = draftDeadlineDate
        totalSessions = min(totalSessions, maxPunctualSessions)
        completedSessions = min(completedSessions, totalSessions)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppStrings.localized("task.field.notes"))
                    .font(AppTheme.schoolbell(16))
                    .foregroundStyle(AppTheme.secondaryText)

                Spacer()

                notesSaveButton
                notesEditButton
            }

            if isEditingNotes {
                TextEditor(text: $draftNotes)
                    .font(AppTheme.schoolbell(18))
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.46))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Text(notesDisplay)
                    .font(AppTheme.schoolbell(18))
                    .foregroundStyle(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.secondaryText : AppTheme.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
                    .padding(.vertical, 2)
            }
        }
    }

    private var notesSaveButton: some View {
        Group {
            if isEditingNotes {
                Button {
                    notes = draftNotes

                    withAnimation(.snappy(duration: 0.22)) {
                        isEditingNotes = false
                    }
                } label: {
                    Text(AppStrings.localized("common.save"))
                        .font(AppTheme.schoolbell(18))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(AppTheme.primaryChaos)
                        )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .accessibilityLabel(AppStrings.localized("common.save"))
            }
        }
    }

    private var notesEditButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                if isEditingNotes {
                    draftNotes = notes
                    isEditingNotes = false
                } else {
                    draftNotes = notes
                    isEditingNotes = true
                }
            }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEditingNotes ? Color.white : AppTheme.primaryChaos)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isEditingNotes ? AppTheme.primaryChaos : Color.white.opacity(0.72))
                        .overlay {
                            Circle()
                                .stroke(AppTheme.primaryText.opacity(0.12), lineWidth: 1)
                        }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEditingNotes ? "Cancelar edição das notas" : "Editar notas")
    }

    private func deadlineKindButton(_ kind: DeadlineKind) -> some View {
        Button {
            deadlineKind = kind
        } label: {
            Text(AppStrings.localized(kind == .continuous ? "task.kind.continuous" : "task.kind.punctual"))
                .font(AppTheme.schoolbell(20))
                .foregroundStyle(deadlineKind == kind ? Color.white : AppTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(deadlineKind == kind ? AppTheme.primaryChaos : AppTheme.secondarySurface)
                )
        }
        .buttonStyle(.plain)
    }

    private var recurrenceColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private func recurrenceButton(_ recurrenceOption: DeadlineRecurrence) -> some View {
        let isSelected = recurrences.contains(recurrenceOption)

        return Button {
            toggleRecurrence(recurrenceOption)
        } label: {
            Text(AppStrings.localized(recurrenceOption.titleKey))
                .font(AppTheme.schoolbell(16))
                .foregroundStyle(isSelected ? Color.white : AppTheme.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? AppTheme.primaryChaos : AppTheme.secondarySurface)
                )
        }
        .buttonStyle(.plain)
    }

    private func toggleRecurrence(_ recurrenceOption: DeadlineRecurrence) {
        if recurrenceOption.isExclusive {
            recurrences = [recurrenceOption]
            return
        }

        recurrences.remove(.daily)
        recurrences.remove(.everyTwoDays)

        if recurrences.contains(recurrenceOption) {
            recurrences.remove(recurrenceOption)
        } else {
            recurrences.insert(recurrenceOption)
        }
    }

    private func save() {
        let formData = TaskFormData(
            title: title,
            perceivedDifficulty: Int(perceivedDifficulty.rounded()),
            deadlineKind: deadlineKind ?? .punctual,
            recurrences: deadlineKind == .continuous ? recurrences : [.daily],
            totalSessions: deadlineKind == .continuous ? 1 : totalSessions,
            completedSessions: deadlineKind == .continuous ? 0 : normalizedCompletedSessions,
            dedicationMinutes: deadlineKind == .continuous ? 0 : dedicationMinutes,
            deadlineDate: normalizedDeadlineDate,
            notes: notes
        )

        onSave(formData)
    }

    private var normalizedDeadlineDate: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: deadlineDate)
        return calendar.date(from: components) ?? deadlineDate
    }

    private var deadlineDateDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d MMMM yyyy")
        return formatter.string(from: deadlineDate).capitalized
    }

    private var deadlineTimeDisplay: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: deadlineDate)
    }

    private var notesDisplay: String {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNotes.isEmpty ? AppStrings.localized("task.field.notes.empty") : notes
    }
}

private enum NumericField: Hashable {
    case totalSessions
    case completedSessions
    case dedicationMinutes
}

#Preview {
    EditTaskView(task: nil) { _ in }
}
