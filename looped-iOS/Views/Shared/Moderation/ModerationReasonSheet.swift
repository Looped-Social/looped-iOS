import SwiftUI

struct ModerationReasonSheet: View {
    let title: String
    let subtitle: String?
    let placeholder: String
    let submitTitle: String
    let onSubmit: (String) async throws -> Void
    let onSuccess: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var reason: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.loopedSubheadMedium)
                        .foregroundColor(.loopedTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextSecondary.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $reason)
                        .font(.loopedBody)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .background(Color.loopedMutedBackground.opacity(0.6))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.loopedTextSecondary.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)

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
                        Text(isSubmitting ? "Submitting..." : submitTitle)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.loopedSecondary)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var isSubmitEnabled: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard isSubmitEnabled, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            defer { isSubmitting = false }
            do {
                let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                try await onSubmit(trimmed)
                onSuccess?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ModerationReasonSheet(
        title: "Report Post",
        subtitle: "Tell us what's going on.",
        placeholder: "Add a short description...",
        submitTitle: "Submit",
        onSubmit: { _ in },
        onSuccess: nil
    )
}
