import SwiftUI

struct PollComposerCard: View {
    @Binding var pollDraft: PollDraft
    let onRemove: () -> Void

    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case question
        case option(Int)
    }

    private var hasExpiry: Bool {
        pollDraft.closesAt != nil
    }

    private var expiryRange: ClosedRange<Date> {
        let start = Date().addingTimeInterval(60)
        let end = Date().addingTimeInterval(30 * 24 * 60 * 60)
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.loopedCustom(.semibold, size: 16))
                    .foregroundColor(.loopedPrimary)
                Text("Poll")
                    .font(.loopedSubBodyBold)
                    .foregroundColor(.loopedTextPrimary)
                Spacer()
                Button("Remove") { onRemove() }
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(.loopedSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Question")
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedTextSecondary)

                TextField("Ask something…", text: $pollDraft.question, axis: .vertical)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .focused($focusedField, equals: .question)
                    .lineLimit(2...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.loopedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.loopedTextSecondary.opacity(0.18), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedTextSecondary)

                VStack(spacing: 8) {
                    ForEach(Array(pollDraft.options.indices), id: \.self) { index in
                        HStack(spacing: 10) {
                            TextField("Option \(index + 1)", text: bindingForOption(index), axis: .vertical)
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextPrimary)
                                .focused($focusedField, equals: .option(index))
                                .lineLimit(1...2)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.loopedBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.loopedTextSecondary.opacity(0.18), lineWidth: 1)
                                )

                            if pollDraft.options.count > 2 {
                                Button(action: { removeOption(at: index) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.loopedCustom(.semibold, size: 18))
                                        .foregroundColor(.loopedTextSecondary.opacity(0.7))
                                }
                                .accessibilityLabel("Remove option \(index + 1)")
                            }
                        }
                    }

                    Button(action: addOption) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.loopedCustom(.semibold, size: 16))
                            Text("Add option")
                                .font(.loopedSubBodyMedium)
                        }
                        .foregroundColor(.loopedPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.loopedTextSecondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(pollDraft.options.count >= 20)
                }

                if pollDraft.hasDuplicateOptions {
                    Text("Options must be unique.")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedError)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("End date (optional)")
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedTextSecondary)

                Toggle(isOn: Binding(
                    get: { hasExpiry },
                    set: { enabled in
                        if enabled {
                            pollDraft.closesAt = pollDraft.closesAt ?? Date().addingTimeInterval(24 * 60 * 60)
                        } else {
                            pollDraft.closesAt = nil
                        }
                    }
                )) {
                    Text("Set end date")
                        .font(.loopedSubBodyMedium)
                        .foregroundColor(.loopedTextPrimary)
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.loopedSecondary))

                if let closesAt = pollDraft.closesAt {
                    DatePicker(
                        "Ends",
                        selection: Binding(
                            get: { closesAt },
                            set: { pollDraft.closesAt = $0 }
                        ),
                        in: expiryRange,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)

                    Text("Max end date is 30 days.")
                        .font(.loopedSmallText)
                        .foregroundColor(.loopedTextSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.loopedMutedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            pollDraft.maxSelections = 1
        }
        .onChange(of: pollDraft.options) { _, _ in
            pollDraft.maxSelections = 1
        }
    }

    private func bindingForOption(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard pollDraft.options.indices.contains(index) else { return "" }
                return pollDraft.options[index]
            },
            set: { newValue in
                guard pollDraft.options.indices.contains(index) else { return }
                pollDraft.options[index] = newValue
            }
        )
    }

    private func addOption() {
        guard pollDraft.options.count < 20 else { return }
        pollDraft.options.append("")
        focusedField = .option(pollDraft.options.count - 1)
    }

    private func removeOption(at index: Int) {
        guard pollDraft.options.count > 2 else { return }
        guard pollDraft.options.indices.contains(index) else { return }
        pollDraft.options.remove(at: index)
    }
}
