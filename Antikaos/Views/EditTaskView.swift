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
    @State private var notes: String

    init(task: TaskItem? = nil, onSave: @escaping (TaskFormData) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _perceivedDifficulty = State(initialValue: Double(task?.perceivedDifficulty ?? 50))
        _deadlineKind = State(initialValue: task?.deadlineKind)
        _recurrences = State(initialValue: task?.recurrences ?? [.daily])
        _totalSessions = State(initialValue: max(task?.totalSessions ?? 4, 1))
        _completedSessions = State(initialValue: max(task?.completedSessions ?? 0, 0))
        _dedicationMinutes = State(initialValue: max(task?.dedicationMinutes ?? 30, 0))
        _deadlineDate = State(initialValue: task?.deadlineDate ?? Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now)
        _notes = State(initialValue: task?.notes ?? "")
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
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.secondaryText)

                                TextField("", text: $title, prompt: Text(AppStrings.localized("task.placeholder.title")))
                                    .textInputAutocapitalization(.sentences)
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                        }

                        inputCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(AppStrings.localized("task.field.difficulty"))
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(AppTheme.secondaryText)

                                    Spacer()

                                    Text(AppStrings.integerValue(Int(perceivedDifficulty.rounded())))
                                        .font(.subheadline.weight(.semibold))
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
                                        .font(.footnote.weight(.medium))
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
                                        range: 1...20
                                    )

                                    Divider()

                                    stepperRow(
                                        title: AppStrings.localized("task.field.completedSessions"),
                                        value: $completedSessions,
                                        range: 0...max(totalSessions, 1)
                                    )

                                    Divider()

                                    stepperRow(
                                        title: AppStrings.localized("task.field.dedicationMinutes"),
                                        value: $dedicationMinutes,
                                        range: 0...600
                                    )
                                }
                            }
                        }

                        inputCard {
                            VStack(spacing: 16) {
                                DatePicker(
                                    AppStrings.localized("task.field.deadline"),
                                    selection: $deadlineDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.graphical)
                                .foregroundStyle(Color.black)
                                .environment(\.colorScheme, .light)

                                Divider()

                                DatePicker(
                                    AppStrings.localized("task.field.deadlineTime"),
                                    selection: $deadlineDate,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                .foregroundStyle(Color.black)
                                .environment(\.colorScheme, .light)
                            }
                            .tint(AppTheme.primaryChaos)
                            .foregroundStyle(Color.black)
                        }

                        inputCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(AppStrings.localized("task.field.notes"))
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.secondaryText)

                                TextEditor(text: $notes)
                                    .frame(minHeight: 120)
                                    .scrollContentBackground(.hidden)
                                    .foregroundStyle(AppTheme.primaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
            .navigationTitle(viewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.localized("common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.localized("common.save")) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .softCard()
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Stepper(value: value, in: range) {
                Text(AppStrings.integerValue(value.wrappedValue))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(minWidth: 28, alignment: .trailing)
            }
            .tint(AppTheme.primaryChaos)
        }
        .onChange(of: totalSessions) { _, newValue in
            completedSessions = min(completedSessions, newValue)
        }
    }

    private func deadlineKindButton(_ kind: DeadlineKind) -> some View {
        Button {
            deadlineKind = kind
        } label: {
            Text(AppStrings.localized(kind == .continuous ? "task.kind.continuous" : "task.kind.punctual"))
                .font(.subheadline.weight(.semibold))
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
                .font(.footnote.weight(.semibold))
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
}

#Preview {
    EditTaskView(task: nil) { _ in }
}
