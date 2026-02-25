import SwiftUI

struct ReportReasonSheet: View {
    private static let customReasonOption = "None of these apply (add custom reason)"

    let title: String
    let onSubmit: (String) async throws -> Void
    let onSuccess: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: String?
    @State private var customReason: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let reasons: [String] = [
        "Spam",
        "Bullying or Harassment",
        "Nudity or Pornography",
        "Hate Speech",
        "Self-harm or Suicide",
        "Violence or Gore",
        Self.customReasonOption
    ]

    private var isOtherSelected: Bool {
        selectedReason == Self.customReasonOption
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Why are you reporting this?")
                    .font(.loopedHeading)
                    .foregroundColor(.loopedTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(reasons, id: \.self) { reason in
                        Button(action: { selectedReason = reason }) {
                            Text(reason)
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(chipBackground(for: reason))
                                .cornerRadius(14)
                        }
                    }
                }

                if isOtherSelected {
                    ZStack(alignment: .topLeading) {
                        if customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("None of these apply? Add your custom reason...")
                                .font(.loopedBody)
                                .foregroundColor(.loopedTextSecondary.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        }

                        TextEditor(text: $customReason)
                            .font(.loopedBody)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .background(Color.loopedMutedBackground.opacity(0.6))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedError)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .loopedWhite))
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Report")
                            .font(.loopedBodyMedium)
                    }
                    .foregroundColor(.loopedWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isSubmitEnabled ? Color.loopedPrimary : Color.loopedTextSecondary.opacity(0.3))
                    .cornerRadius(14)
                }
                .disabled(!isSubmitEnabled || isSubmitting)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LoopedCancelTextButton(action: { dismiss() })
                }
            }
        }
    }

    private var isSubmitEnabled: Bool {
        guard let selectedReason else { return false }
        if selectedReason == Self.customReasonOption {
            return !customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func chipBackground(for reason: String) -> Color {
        if reason == selectedReason {
            return Color.loopedPrimary.opacity(0.2)
        }
        return Color.loopedTextSecondary.opacity(0.08)
    }

    private func submit() {
        guard isSubmitEnabled, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            defer { isSubmitting = false }
            do {
                let reason = selectedReason == Self.customReasonOption
                    ? customReason.trimmingCharacters(in: .whitespacesAndNewlines)
                    : (selectedReason ?? "")
                try await onSubmit(reason)
                onSuccess?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ReportReasonSheet(title: "Report User", onSubmit: { _ in }, onSuccess: nil)
}
