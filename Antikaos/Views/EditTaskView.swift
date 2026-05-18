import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss

    private let task: TaskItem?
    private let onSave: (TaskFormData) -> Void

    @State private var title: String
    @State private var perceivedDifficulty: Double
    @State private var totalSessions: Int
    @State private var completedSessions: Int
    @State private var deadlineDate: Date
    @State private var notes: String

    init(task: TaskItem? = nil, onSave: @escaping (TaskFormData) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task?.title ?? "")
        _perceivedDifficulty = State(initialValue: Double(task?.perceivedDifficulty ?? 50))
        _totalSessions = State(initialValue: max(task?.totalSessions ?? 4, 1))
        _completedSessions = State(initialValue: max(task?.completedSessions ?? 0, 0))
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
                            }
                        }

                        inputCard {
                            DatePicker(
                                AppStrings.localized("task.field.deadline"),
                                selection: $deadlineDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .tint(AppTheme.primaryChaos)
                            .foregroundStyle(AppTheme.primaryText)
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

    private func save() {
        let formData = TaskFormData(
            title: title,
            perceivedDifficulty: Int(perceivedDifficulty.rounded()),
            totalSessions: totalSessions,
            completedSessions: normalizedCompletedSessions,
            deadlineDate: deadlineDate,
            notes: notes
        )

        onSave(formData)
    }
}

#Preview {
    EditTaskView(task: nil) { _ in }
}
